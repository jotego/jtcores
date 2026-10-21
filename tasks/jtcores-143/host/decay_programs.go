// Generate controlled decay, sustain-level and release monitor experiments.
package main

import (
    "crypto/sha256"
    "encoding/json"
    "flag"
    "fmt"
    "os"
    "path/filepath"
)

type decay_case struct {
    Name string `json:"name"`
    Profile string `json:"profile"`
    Rate int `json:"rate"`
    KeyScale int `json:"key_scale"`
    AR int `json:"attack_rate"`
    D1R int `json:"d1_rate"`
    D2R int `json:"d2_rate"`
    D1L int `json:"d1_level"`
    RR int `json:"release_rate"`
    InitialKeyon bool `json:"initial_keyon"`
    Complement bool `json:"complementary_keyon"`
    Init string `json:"init"`
    Event string `json:"event"`
    InitHash string `json:"init_sha256"`
    EventHash string `json:"event_sha256"`
    EventRegister int `json:"event_register"`
    EventValue int `json:"event_value"`
    Multiplier int `json:"multiplier"`
    Increment int `json:"phase_increment_20bit"`
    RecordedIncrement int `json:"recorded_phase_increment_20bit"`
    Stride int `json:"stride"`
    Samples int `json:"recorded_frames"`
    SampleRate float64 `json:"recorded_sample_rate_hz"`
    Window int `json:"projection_window_samples"`
    Pretrigger int `json:"pretrigger_count"`
    Metric string `json:"feature"`
    TailDB *int `json:"expected_tail_attenuation_db,omitempty"`
}

type decay_generation struct {
    base, output, profile, carrier, matrix string
    first, last, pretrigger int
    complements bool
    data []byte
    registers map[byte]int
    cases []decay_case
}

func main() {
    var job decay_generation
    flag.StringVar(&job.matrix,"matrix","legacy","legacy, ks-kc-main or ks-kc-carriers")
    flag.StringVar(&job.base,"base","","canonical tone bytecode")
    flag.StringVar(&job.output,"output","","new output directory")
    flag.StringVar(&job.profile,"profile","all","all, d1, d2, d1l, release, d1-keyon or d2-keyon")
    flag.IntVar(&job.first,"first",0,"first rate or level for one profile")
    flag.IntVar(&job.last,"last",-1,"last rate or level; default profile maximum")
    flag.StringVar(&job.carrier,"carrier","auto","auto, high (MUL8) or divided (MUL0)")
    flag.IntVar(&job.pretrigger,"pretrigger",0,"delay count; zero chooses capture-window default")
    flag.BoolVar(&job.complements,"complements",true,"include selected configured-key-on cases with all")
    flag.Parse()
    e:=job.run();if e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}

func (job *decay_generation) run() error {
    e:=job.validate();if e!=nil { return e }
    if job.matrix!="legacy" { return job.run_matrix() }
    e=job.read_base();if e!=nil { return e }
    e=os.Mkdir(job.output,0755);if e!=nil { return e }
    profiles:=[]string{job.profile}
    if job.profile=="all" { profiles=[]string{"d1","d2","d1l","release"} }
    for _,profile:=range profiles {
        last:=31
        if profile=="d1l" || profile=="release" { last=15 }
        if job.last>=0 { last=job.last }
        for rate:=job.first;rate<=last;rate++ {
            e=job.write_case(profile,rate);if e!=nil { return e }
        }
    }
    if job.profile=="all" && job.complements {
        for _,profile:=range []string{"d1-keyon","d2-keyon"} {
            for _,rate:=range []int{1,8,16,24,31} {
                e=job.write_case(profile,rate);if e!=nil { return e }
            }
        }
    }
    manifest,e:=json.MarshalIndent(job.cases,"","  ");if e!=nil { return e }
    e=os.WriteFile(filepath.Join(job.output,"cases.json"),append(manifest,'\n'),0600)
    if e!=nil { return e }
    fmt.Printf("Generated %d controlled decay/level/release cases\n",len(job.cases))
    return nil
}

func (job *decay_generation) validate() error {
    if job.matrix!="legacy" && job.matrix!="ks-kc-main" && job.matrix!="ks-kc-carriers" { return fmt.Errorf("invalid fixed matrix") }
    if job.matrix!="legacy" {
        bad:=""
        flag.Visit(func(f *flag.Flag){ if f.Name!="matrix" && f.Name!="base" && f.Name!="output" { bad=f.Name } })
        if bad!="" { return fmt.Errorf("fixed matrix rejects override %s",bad) }
    }
    valid:=map[string]bool{"all":true,"d1":true,"d2":true,"d1l":true,"release":true,"d1-keyon":true,"d2-keyon":true}
    if job.base=="" || job.output=="" || !valid[job.profile] || flag.NArg()!=0 ||
       job.first<0 || job.last < -1 || job.pretrigger<0 || job.pretrigger>65535 ||
       (job.carrier!="auto" && job.carrier!="high" && job.carrier!="divided") {
        return fmt.Errorf("use -base TONE.bin -output NEW_DIRECTORY [-profile NAME -first N -last N -carrier auto|high|divided -pretrigger COUNT]")
    }
    if job.profile=="all" {
        if job.first!=0 || job.last!=-1 { return fmt.Errorf("rate bounds require a single profile") }
        return nil
    }
    maximum:=31
    if job.profile=="d1l" || job.profile=="release" { maximum=15 }
    if job.first>maximum || job.last>maximum || (job.last>=0 && job.first>job.last) {
        return fmt.Errorf("invalid rate/level bounds for %s",job.profile)
    }
    return nil
}

func (job *decay_generation) read_base() error {
    data,e:=os.ReadFile(job.base);if e!=nil { return e }
    if len(data)<28 || len(data)>8192 || string(data[len(data)-4:])!=string([]byte{1,8,0x40,0}) {
        return fmt.Errorf("base must be canonical tone ending with C2 key-on")
    }
    job.data=append(append([]byte(nil),data[:len(data)-4]...),0)
    if (len(job.data)-1)%3!=0 { return fmt.Errorf("base must contain only register writes") }
    job.registers=make(map[byte]int)
    globals:=make(map[byte]bool)
    am_zero,pm_zero:=false,false
    for pos:=0;pos<len(job.data)-1;pos+=3 {
        if job.data[pos]!=1 {
            return fmt.Errorf("base contains non-register initialization")
        }
        reg,value:=job.data[pos+1],job.data[pos+2]
        if pos<24 {
            if reg!=8 || int(value)!=pos/3 { return fmt.Errorf("base must begin with all-channel key-off") }
            continue
        }
        if reg<0x20 {
            allowed:=map[byte]byte{1:0,0x0f:0,0x14:0x30,0x18:0,0x1b:0}
            if reg==0x19 {
                if value==0 { am_zero=true } else if value==0x80 { pm_zero=true } else { return fmt.Errorf("base has nonzero LFO modulation") }
            } else if want,ok:=allowed[reg];!ok || value!=want { return fmt.Errorf("base has noncanonical global register %02x",reg) }
            globals[reg]=true
        }
        job.registers[reg]=pos+2
    }
    for _,reg:=range []byte{1,0x0f,0x14,0x18,0x1b} { if !globals[reg] { return fmt.Errorf("base omits global register %02x",reg) } }
    if !am_zero || !pm_zero { return fmt.Errorf("base must clear both LFO depths") }
    special:=map[int]byte{0x20:0xc7,0x28:0x4a,0x58:1,0x78:0,0x98:31,0xf8:15}
    for reg:=0x20;reg<=0xff;reg++ {
        want:=byte(0)
        if reg>=0x60 && reg<0x80 { want=127 }
        if value,ok:=special[reg];ok { want=value }
        pos,ok:=job.registers[byte(reg)]
        if !ok || job.data[pos]!=want { return fmt.Errorf("base differs from canonical tone at register %02x",reg) }
    }
    return nil
}

func (job *decay_generation) write_case(profile string,rate int) error {
    entry:=decay_case{Name:fmt.Sprintf("%s-%02d",profile,rate),Profile:profile,Rate:rate,
        AR:31,RR:15,Samples:16384,Stride:1,Window:32,Increment:65984,Multiplier:8,
        InitialKeyon:true,Metric:"decay_80_to_40"}
    event_reg,event_value:=byte(8),byte(0x40)
    switch profile {
    case "d1":
        entry.D1L=15
        event_reg,event_value=0xb8,byte(rate)
    case "d2":
        entry.D1R=31
        event_reg,event_value=0xd8,byte(rate)
    case "release":
        entry.D1L=15
        entry.RR=rate
        event_value=0
    case "d1l":
        entry.D1R=31
        entry.D1L=rate
        entry.InitialKeyon=false
        entry.Metric="tail_level"
        attenuation:=3*rate
        if rate==15 { attenuation=93 }
        entry.TailDB=&attenuation
    case "d1-keyon":
        entry.D1R=rate
        entry.D1L=15
        entry.InitialKeyon=false
        entry.Complement=true
        entry.Metric="keyon_configured_decay"
    case "d2-keyon":
        entry.D1R=31
        entry.D2R=rate
        entry.InitialKeyon=false
        entry.Complement=true
        entry.Metric="keyon_configured_decay"
    }
    if rate==0 && (profile=="d1" || profile=="d2") { entry.Metric="hold_level" }
    speed:=rate
    if profile=="release" { speed=2*rate+1 }
    if profile!="d1l" && speed>0 {
        if speed<=7 { entry.Stride=64 }
        if profile!="release" {
            if speed==2 || speed==3 { entry.Samples=8192 }
            if speed==4 || speed==5 { entry.Samples=4096 }
            if speed==6 || speed==7 { entry.Samples=2048 }
        }
        if speed>=8 && speed<=11 { entry.Stride=16;entry.Samples=4096 }
    }
    if job.carrier=="divided" || (job.carrier=="auto" && entry.Stride!=1) {
        entry.Multiplier=0
        entry.Increment=4124
    }
    entry.RecordedIncrement=entry.Increment*entry.Stride
    if entry.RecordedIncrement<=0 || entry.RecordedIncrement>=1<<19 {
        return fmt.Errorf("carrier reaches recorded Nyquist for %s; choose auto or divided carrier",entry.Name)
    }
    for entry.Window*entry.RecordedIncrement<3*(1<<19) { entry.Window*=2 }
    entry.SampleRate=55937.5/float64(entry.Stride)
    entry.Pretrigger=4*entry.Window*entry.Stride
    if entry.Pretrigger<256 { entry.Pretrigger=256 }
    if job.pretrigger!=0 { entry.Pretrigger=job.pretrigger }
    if entry.Pretrigger>65535 { return fmt.Errorf("pretrigger exceeds finite monitor delay") }
    init:=append([]byte(nil),job.data...)
    init[job.registers[0x58]]=byte(entry.Multiplier)
    init[job.registers[0x98]]=31
    init[job.registers[0xb8]]=byte(entry.D1R)
    init[job.registers[0xd8]]=byte(entry.D2R)
    init[job.registers[0xf8]]=byte(entry.D1L<<4|entry.RR)
    if entry.InitialKeyon { init=append(append(init[:len(init)-1],1,8,0x40),0) }
    event:=[]byte{2,byte(entry.Pretrigger),byte(entry.Pretrigger>>8),1,event_reg,event_value,0}
    entry.EventRegister=int(event_reg)
    entry.EventValue=int(event_value)
    entry.Init=filepath.Join(job.output,entry.Name+"-init.bin")
    entry.Event=filepath.Join(job.output,entry.Name+"-event.bin")
    entry.InitHash=fmt.Sprintf("%x",sha256.Sum256(init))
    entry.EventHash=fmt.Sprintf("%x",sha256.Sum256(event))
    e:=os.WriteFile(entry.Init,init,0600);if e!=nil { return e }
    e=os.WriteFile(entry.Event,event,0600);if e!=nil { return e }
    job.cases=append(job.cases,entry)
    return nil
}

// New fixed matrices are separate from the byte-compatible legacy path.
type matrix_geometry struct {Name string `json:"name"`;KC int `json:"kc"`;Mul int `json:"multiplier"`;Native int `json:"native_increment_hypothesis"`;Stride int `json:"stride"`;Frames int `json:"recorded_frames"`;Window int `json:"projection_window_samples"`;Hop int `json:"projection_hop_samples"`;Pre int `json:"pretrigger_count"`}
type matrix_write struct {Reg int `json:"reg"`;Value int `json:"value"`}
type matrix_operation struct {Kind string `json:"kind"`;Reg int `json:"reg,omitempty"`;Value int `json:"value,omitempty"`;Count int `json:"count,omitempty"`}
type matrix_entry struct {
 Name string `json:"name"`;Group string `json:"group"`;KC int `json:"kc"`;KS int `json:"ks"`;AR int `json:"ar"`;D1R int `json:"d1r"`;D2R int `json:"d2r"`;D1L int `json:"d1l"`;RR int `json:"rr"`;Initial bool `json:"initial_keyon"`
 Geometry matrix_geometry `json:"geometry"`;Recorded int `json:"recorded_increment_hypothesis"`;Fs float64 `json:"recorded_sample_rate_hz"`;Metric string `json:"metric"`;Zero string `json:"zero_semantics,omitempty"`;Purpose string `json:"purpose"`;CarrierEvidence string `json:"carrier_evidence"`
 EventReg int `json:"event_register"`;EventVal int `json:"event_value"`;Init string `json:"init"`;Event string `json:"event"`;InitHash string `json:"init_sha256"`;EventHash string `json:"event_sha256"`;Writes []matrix_write `json:"init_writes"`;Operations []matrix_operation `json:"event_operations"`
}
func fixed_geometries()map[string]matrix_geometry{return map[string]matrix_geometry{
 "native-kc3e-mul8":{"native-kc3e-mul8",62,8,39232,1,16384,64,8,256},
 "native-kc40-mul8":{"native-kc40-mul8",64,8,41568,1,16384,64,8,256},
 "native-kc41-mul8":{"native-kc41-mul8",65,8,44032,1,16384,64,8,256},
 "stride16-kc40-mul0":{"stride16-kc40-mul0",64,0,2598,16,4096,64,8,4096},
 "stride64-kc40-mul0":{"stride64-kc40-mul0",64,0,2598,64,16384,32,8,8192},}}
func matrix_entries(carriers bool)[]matrix_entry{
 var rows []matrix_entry;geometries:=fixed_geometries()
 add:=func(name,group string,kc,ks,ar,d1,d2,level int,initial bool,event_reg,event_value int,geometry,metric,zero,purpose string){g:=geometries[geometry];evidence:="historical nativeKC40 fit; retainedgeometry requires scopedqualification";if kc!=64{evidence="primaryMULlaw times historicalMUL1 fit prediction; newMUL8 physicalcarrier unqualified"};rows=append(rows,matrix_entry{Name:name,Group:group,KC:kc,KS:ks,AR:ar,D1R:d1,D2R:d2,D1L:level,RR:15,Initial:initial,Geometry:g,Recorded:g.Native*g.Stride,Fs:55937.5/float64(g.Stride),Metric:metric,Zero:zero,Purpose:purpose,CarrierEvidence:evidence,EventReg:event_reg,EventVal:event_value})}
 if carriers{for _,kc:=range []int{62,65}{add(fmt.Sprintf("carrier-held-kc%02x-mul8",kc),"carrier",kc,0,31,0,0,0,true,-1,0,fmt.Sprintf("native-kc%02x-mul8",kc),"held_carrier","","independent newMUL8 carrier calibration; no EVENT register intervention")};return rows}
 for ks,ar:=range []int{14,13,11,7}{for _,kc:=range []int{62,64}{add(fmt.Sprintf("attack-carry-kc%02x-ks%d-ar%02d",kc,ks,ar),"A-carry",kc,ks,ar,0,0,0,false,8,64,fmt.Sprintf("native-kc%02x-mul8",kc),"attack_10_to_90","","legalKCcarry effective29to30")}}
 add("attack-note-kc41-ks3-ar07","A-note-control",65,3,7,0,0,0,false,8,64,"native-kc41-mul8","attack_10_to_90","","sameEGindex16 with different legalcarrier")
 for _,ks:=range []int{0,3}{for _,ar:=range []int{0,1}{g:="stride64-kc40-mul0";if ks==3{g="stride16-kc40-mul0"};zero:="";metric:="attack_10_to_90";if ar==0{zero="rawAR0";metric="finite_raw_zero"};add(fmt.Sprintf("attack-endpoint-kc40-ks%d-ar%02d",ks,ar),"B-attack-zero-positive",64,ks,ar,0,0,0,false,8,64,g,metric,zero,"finite rawAR0 vs independent AR1 positive")}}
 for ks:=0;ks<4;ks++{for _,rate:=range []int{0,12}{zero:="";metric:="decay_80_to_40";if rate==0{zero="D1R0hold";metric="hold_absolute_level"};add(fmt.Sprintf("d1-live-kc40-ks%d-r%02d",ks,rate),"C-D1-zero-positive",64,ks,31,0,0,15,true,184,rate,"native-kc40-mul8",metric,zero,"liveD1R intervention after conditioned hold")}}
 for _,rate:=range []int{0,12}{zero:="";metric:="decay_80_to_40";if rate==0{zero="D2R0hold";metric="hold_absolute_level"};add(fmt.Sprintf("d2-live-kc40-ks3-r%02d",rate),"D-D2-zero-positive",64,3,31,31,0,0,true,216,rate,"native-kc40-mul8",metric,zero,"liveD2R intervention after full-levelD2 conditioning")}
 return rows
}
func(job *decay_generation)run_matrix()error{
 data,e:=os.ReadFile(job.base);if e!=nil{return e};if fmt.Sprintf("%x",sha256.Sum256(data))!="d8f414e301521e4522739c7c845693e16dec01e4a265751f2352dbaab07e4c16"{return fmt.Errorf("fixed matrix requires exact trusted canonical tone bytes")}
 if e=job.read_base();e!=nil{return e};rows:=matrix_entries(job.matrix=="ks-kc-carriers");want:=23;if job.matrix=="ks-kc-carriers"{want=2};if len(rows)!=want{return fmt.Errorf("fixed catalog count")}
 for _,row:=range rows{g:=row.Geometry;if g.Native<=0||row.Recorded<=0||row.Recorded>=1<<19||float64(g.Window*row.Recorded)/(1<<20)<1.5{return fmt.Errorf("invalid fixed carrier/window geometry")}}
 output,e:=filepath.Abs(job.output);if e!=nil{return e};if e=os.Mkdir(output,0755);e!=nil{return e}
 for i:=range rows{row:=&rows[i];init:=append([]byte(nil),job.data...)
  for reg,val:=range map[byte]int{0x28:row.KC,0x58:row.Geometry.Mul,0x98:row.KS<<6|row.AR,0xb8:row.D1R,0xd8:row.D2R,0xf8:row.D1L<<4|row.RR}{init[job.registers[reg]]=byte(val)}
  if row.Initial{init=append(append(init[:len(init)-1],1,8,64),0)}
  event:=[]byte{2,byte(row.Geometry.Pre),byte(row.Geometry.Pre>>8)};row.Operations=[]matrix_operation{{Kind:"delay",Count:row.Geometry.Pre}}
  if row.EventReg>=0{event=append(event,1,byte(row.EventReg),byte(row.EventVal));row.Operations=append(row.Operations,matrix_operation{Kind:"write",Reg:row.EventReg,Value:row.EventVal})};event=append(event,0)
  for at:=0;at<len(init)-1;at+=3{row.Writes=append(row.Writes,matrix_write{int(init[at+1]),int(init[at+2])})}
  row.Init=filepath.Join(output,row.Name+"-init.bin");row.Event=filepath.Join(output,row.Name+"-event.bin");row.InitHash=fmt.Sprintf("%x",sha256.Sum256(init));row.EventHash=fmt.Sprintf("%x",sha256.Sum256(event));if len(init)>8192||len(event)>8192{return fmt.Errorf("finite payload bound")};if e=os.WriteFile(row.Init,init,0600);e!=nil{return e};if e=os.WriteFile(row.Event,event,0600);e!=nil{return e}
 }
 manifest,e:=json.MarshalIndent(rows,"","  ");if e!=nil{return e};if e=os.WriteFile(filepath.Join(output,"cases.json"),append(manifest,'\n'),0600);e!=nil{return e};fmt.Printf("Generated %d fixed %s profiles\n",len(rows),job.matrix);return nil
}
