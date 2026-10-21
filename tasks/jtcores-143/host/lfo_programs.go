// Generate controlled LFO measurement programs from the canonical single-C2 tone.
package main

import (
    "crypto/sha256"
    "encoding/json"
    "flag"
    "fmt"
    "os"
    "path/filepath"
)

type lfo_write struct {
    Register int `json:"reg"`
    Value int `json:"value"`
}
type lfo_case struct {
    Name string `json:"name"`
    Profile string `json:"profile"`
    PilotKind string `json:"pilot_kind"`
    Purpose string `json:"purpose"`
    Init string `json:"init"`
    Event string `json:"event"`
    InitHash string `json:"init_sha256"`
    EventHash string `json:"event_sha256"`
    InitWrites []lfo_write `json:"init_writes"`
    EventWrites []lfo_write `json:"event_writes"`
    EventRegister int `json:"event_register"`
    EventValue int `json:"event_value"`
    Waveform int `json:"waveform"`
    AMD int `json:"amd"`
    PMD int `json:"pmd"`
    AMS int `json:"ams"`
    PMS int `json:"pms"`
    AME int `json:"ame"`
    Rate int `json:"rate"`
    LFORate int `json:"lfo_rate"`
    Frequency float64 `json:"nominal_lfo_hz"`
    KeyCode int `json:"key_code"`
    Multiplier int `json:"multiplier"`
    Increment int `json:"phase_increment_20bit"`
    RecordedIncrement int `json:"recorded_phase_increment_20bit"`
    Stride int `json:"stride"`
    Window int `json:"projection_window_samples"`
    Frames int `json:"recorded_frames"`
    SampleRate float64 `json:"recorded_sample_rate_hz"`
    Pretrigger int `json:"pretrigger_count"`
    InitialKeyon bool `json:"initial_keyon"`
    Feature string `json:"feature"`
}
type lfo_generation struct {
    base,output,sampling,profile string
    bare []byte
    registers map[byte]int
    cases []lfo_case
}

func main() {
    var job lfo_generation
    flag.StringVar(&job.base,"base","","canonical single-C2 tone bytecode")
    flag.StringVar(&job.output,"output","","fresh output directory")
    flag.StringVar(&job.sampling,"sampling","extended","native or extended capture horizon")
    flag.StringVar(&job.profile,"profile","pilot","pilot, am-depth or pm-depth")
    flag.Parse()
    e:=job.run();if e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}

func (job *lfo_generation) run() error {
    if job.base=="" || job.output=="" || flag.NArg()!=0 || (job.sampling!="native" && job.sampling!="extended") ||
       (job.profile!="pilot" && job.profile!="am-depth" && job.profile!="pm-depth") {
        return fmt.Errorf("use -base TONE.bin -output NEW_DIRECTORY [-sampling native|extended -profile pilot|am-depth|pm-depth]")
    }
    e:=job.read_base();if e!=nil { return e }
    e=os.Mkdir(job.output,0755);if e!=nil { return e }
    e=job.generate();if e!=nil { return e }
    data,e:=json.MarshalIndent(job.cases,"","  ");if e!=nil { return e }
    e=os.WriteFile(filepath.Join(job.output,"cases.json"),append(data,'\n'),0600);if e!=nil { return e }
    fmt.Printf("Generated %d LFO measurement programs\n",len(job.cases))
    return nil
}

func (job *lfo_generation) read_base() error {
    data,e:=os.ReadFile(job.base);if e!=nil { return e }
    if len(data)<28 || len(data)>8192 || string(data[len(data)-4:])!=string([]byte{1,8,64,0}) { return fmt.Errorf("base must end with canonical C2 key-on and completion") }
    job.bare=append([]byte(nil),data[:len(data)-4]...)
    if len(job.bare)%3!=0 { return fmt.Errorf("base must contain only register writes") }
    job.registers=make(map[byte]int)
    globals:=make(map[byte]bool)
    am_zero,pm_zero:=false,false
    for pos:=0;pos<len(job.bare);pos+=3 {
        reg,value:=job.bare[pos+1],job.bare[pos+2]
        if job.bare[pos]!=1 { return fmt.Errorf("base contains non-register bytecode") }
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
        if !ok || job.bare[pos]!=want { return fmt.Errorf("base differs from canonical tone at register %02x",reg) }
    }
    return nil
}

func (job *lfo_generation) generate() error {
    switch job.profile {
    case "am-depth":return job.generate_am_depth()
    case "pm-depth":return job.generate_pm_depth()
    }
    return job.generate_pilot()
}

func (job *lfo_generation) generate_am_depth() error {
    for wave:=0;wave<4;wave++ {
        for _,amd:=range []int{0,1,2,63,64,126,127} {
            for ams:=0;ams<4;ams++ {
                kind:="depth"
                if amd==0 || ams==0 { kind="gate" }
                name:=fmt.Sprintf("am-w%d-amd%03d-ams%d-ame1",wave,amd,ams)
                e:=job.write_case(name,"lfo-am-depth",kind,"AM depth/sensitivity with operator AM enabled",wave,amd,0,ams,0,1);if e!=nil { return e }
            }
        }
    }
    for wave:=0;wave<4;wave++ {
        for ams:=0;ams<4;ams++ {
            name:=fmt.Sprintf("am-w%d-amd127-ams%d-ame0",wave,ams)
            e:=job.write_case(name,"lfo-am-depth","gate","AM operator-enable gate at maximum depth",wave,127,0,ams,0,0);if e!=nil { return e }
        }
    }
    return nil
}

func (job *lfo_generation) generate_pm_depth() error {
    for wave:=0;wave<4;wave++ {
        for _,pmd:=range []int{0,1,2,63,64,126,127} {
            for pms:=0;pms<8;pms++ {
                kind:="depth"
                if pmd==0 || pms==0 { kind="gate" }
                name:=fmt.Sprintf("pm-w%d-pmd%03d-pms%d",wave,pmd,pms)
                e:=job.write_case(name,"lfo-pm-depth",kind,"PM depth/sensitivity with AM disabled",wave,0,pmd,0,pms,0);if e!=nil { return e }
            }
        }
    }
    return nil
}

func (job *lfo_generation) generate_pilot() error {
    for wave:=0;wave<4;wave++ {
        e:=job.write_case(fmt.Sprintf("am-w%d",wave),"lfo-am","waveform","AM waveform after release from TEST hold",wave,64,0,1,0,1);if e!=nil { return e }
    }
    for _,gate:=range []struct{name string;amd,ams,ame int}{ {"amd0",0,1,1},{"ams0",64,0,1},{"ame0",64,1,0} } {
        e:=job.write_case("am-w2-"+gate.name,"lfo-am","gate","AM disabled independently by "+gate.name,2,gate.amd,0,gate.ams,0,gate.ame);if e!=nil { return e }
    }
    for wave:=0;wave<4;wave++ {
        e:=job.write_case(fmt.Sprintf("pm-w%d",wave),"lfo-pm","waveform","PM waveform after release from TEST hold",wave,0,64,0,4,0);if e!=nil { return e }
    }
    for _,gate:=range []struct{name string;pmd,pms int}{ {"pmd0",0,4},{"pms0",64,0} } {
        e:=job.write_case("pm-w2-"+gate.name,"lfo-pm","gate","PM disabled independently by "+gate.name,2,0,gate.pmd,0,gate.pms,0);if e!=nil { return e }
    }
    return job.write_case("combined-w2","lfo-combined","combined","Simultaneous AM and PM with independent nonzero depths",2,64,64,1,4,1)
}

func (job *lfo_generation) write_case(name,profile,kind,purpose string,wave,amd,pmd,ams,pms,ame int) error {
    entry:=lfo_case{Name:name,Profile:profile,PilotKind:kind,Purpose:purpose,Waveform:wave,AMD:amd,PMD:pmd,AMS:ams,PMS:pms,AME:ame,Rate:0xe0,LFORate:0xe0,Frequency:55937.5/4096,KeyCode:0x4a,Multiplier:8,Increment:65984,RecordedIncrement:65984,Stride:1,Window:32,Frames:16384,SampleRate:55937.5,Pretrigger:8192,InitialKeyon:true,Feature:"lfo_pilot",EventRegister:1}
    if job.sampling=="extended" && wave!=3 {
        entry.Multiplier=4
        entry.Increment=32992
        entry.Stride=2
        entry.SampleRate=27968.75
    }
    init:=append([]byte(nil),job.bare...)
    for reg,value:=range map[byte]byte{0x38:byte(pms<<4|ams),0x58:byte(entry.Multiplier),0xb8:byte(ame<<7)} { init[job.registers[reg]]=value }
    for _,w:=range []lfo_write{{1,2},{0x18,0xe0},{0x19,amd},{0x19,0x80|pmd},{0x1b,wave},{8,0x40}} { init=append(init,1,byte(w.Register),byte(w.Value)) }
    for pos:=0;pos<len(init);pos+=3 { entry.InitWrites=append(entry.InitWrites,lfo_write{int(init[pos+1]),int(init[pos+2])}) }
    init=append(init,0)
    event:=[]byte{2,0,0x20,1,1,0,0}
    entry.EventWrites=[]lfo_write{{1,0}}
    entry.Init=filepath.Join(job.output,name+"-init.bin")
    entry.Event=filepath.Join(job.output,name+"-event.bin")
    entry.InitHash=fmt.Sprintf("%x",sha256.Sum256(init))
    entry.EventHash=fmt.Sprintf("%x",sha256.Sum256(event))
    e:=os.WriteFile(entry.Init,init,0600);if e!=nil { return e }
    e=os.WriteFile(entry.Event,event,0600);if e!=nil { return e }
    job.cases=append(job.cases,entry)
    return nil
}
