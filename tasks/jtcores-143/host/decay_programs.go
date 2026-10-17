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
    base, output, profile, carrier string
    first, last, pretrigger int
    complements bool
    data []byte
    registers map[byte]int
    cases []decay_case
}

func main() {
    var job decay_generation
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
