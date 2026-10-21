// Generate finite envelope stage/history controls from the canonical C2 tone.
package main

import (
    "crypto/sha256"
    "encoding/json"
    "flag"
    "fmt"
    "os"
    "path/filepath"
)

type history_write struct {
    Register int `json:"reg"`
    Value int `json:"value"`
    DelayTotal int `json:"preceding_delay_count_total"`
}
type history_case struct {
    Name string `json:"name"`
    Profile string `json:"profile"`
    Rate int `json:"rate"`
    Init string `json:"init"`
    Event string `json:"event"`
    InitHash string `json:"init_sha256"`
    EventHash string `json:"event_sha256"`
    Writes []history_write `json:"event_writes"`
    DelayTotal int `json:"total_delay_count"`
    Stride int `json:"stride"`
    Frames int `json:"recorded_frames"`
    SampleRate float64 `json:"recorded_sample_rate_hz"`
    Increment int `json:"phase_increment_20bit"`
    RecordedIncrement int `json:"recorded_phase_increment_20bit"`
    Window int `json:"projection_window_samples"`
    Pretrigger int `json:"pretrigger_count"`
    Multiplier int `json:"multiplier"`
    KeyScale int `json:"key_scale"`
    KeyCode int `json:"key_code"`
    Feature string `json:"feature"`
    Expectation string `json:"expectation"`
    Baseline *string `json:"baseline_case"`
    Positive bool `json:"positive_control"`
}
type history_generation struct {
    base,output string
    bare []byte
    registers map[byte]int
    cases []history_case
}

func main() {
    var job history_generation
    flag.StringVar(&job.base,"base","","canonical single-C2 tone bytecode")
    flag.StringVar(&job.output,"output","","fresh output directory")
    flag.Parse()
    e:=job.run();if e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}

func (job *history_generation) run() error {
    if job.base=="" || job.output=="" || flag.NArg()!=0 { return fmt.Errorf("use -base TONE.bin -output NEW_DIRECTORY") }
    e:=job.read_base();if e!=nil { return e }
    e=os.Mkdir(job.output,0755);if e!=nil { return e }
    e=job.generate();if e!=nil { return e }
    data,e:=json.MarshalIndent(job.cases,"","  ");if e!=nil { return e }
    e=os.WriteFile(filepath.Join(job.output,"cases.json"),append(data,'\n'),0600);if e!=nil { return e }
    fmt.Printf("Generated %d native envelope history controls\n",len(job.cases))
    return nil
}

func (job *history_generation) read_base() error {
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

func (job *history_generation) generate() error {
    d1:=job.make_init(31,0,0,15,15,true)
    d2:=job.make_init(31,31,0,0,15,true)
    release:=job.make_init(31,0,0,15,6,true)
    attack:=job.make_init(12,0,0,15,15,false)
    type fixture struct { name,family string; init,event []byte; expectation,baseline string; positive bool }
    fixtures:=[]fixture{
        {"d1-hold-control","history-d1",d1,history_event(history_reg(0xb8,0)),"D1R0 holds full carrier","",false},
        {"d1-inactive-d2","history-d1",d1,history_event(history_reg(0xd8,31)),"Inactive D2 rate must not affect held first decay","d1-hold-control",false},
        {"d1-active-positive","history-d1",d1,history_event(history_reg(0xb8,31)),"Active D1 write produces falling transition","d1-hold-control",true},
        {"d2-hold-control","history-d2",d2,history_event(history_reg(0xd8,0)),"D2R0 holds full carrier after D1L0 transfer","",false},
        {"d2-inactive-d1","history-d2",d2,history_event(history_reg(0xb8,1)),"Inactive D1 rate must not affect held second decay","d2-hold-control",false},
        {"d2-active-positive","history-d2",d2,history_event(history_reg(0xd8,31)),"Active D2 write produces falling transition","d2-hold-control",true},
        {"release-control","history-release",release,history_event(history_reg(8,0)),"RR6 release establishes falling positive control","",true},
        {"release-inactive-d1","history-release",release,history_event(history_reg(8,0),history_delay(1024),history_reg(0xb8,31)),"D1R write during release does not affect release","release-control",false},
        {"release-inactive-d2","history-release",release,history_event(history_reg(8,0),history_delay(1024),history_reg(0xd8,31)),"D2R write during release does not affect release","release-control",false},
        {"release-repeat-keyoff","history-release",release,history_event(history_reg(8,0),history_delay(1024),history_reg(8,0)),"Repeated key-off has no new effect","release-control",false},
        {"release-rekey","history-release",release,history_event(history_reg(8,0),history_delay(4096),history_reg(8,64)),"New off-to-on transition restores full carrier tail with AR31","release-control",true},
        {"held-repeat-keyon","history-held",d1,history_event(history_reg(8,64)),"Repeated held key-on has no amplitude or carrier-phase change","d1-hold-control",false},
        {"held-keyoff-positive","history-held",d1,history_event(history_reg(8,0)),"Key-off changes held carrier to release","d1-hold-control",true},
        {"attack-control","history-attack",attack,history_event(history_reg(8,64)),"AR12 starts a resolved attack from silence","",true},
        {"attack-repeat-keyon","history-attack",attack,history_event(history_reg(8,64),history_delay(1024),history_reg(8,64)),"Repeated high key-on during attack does not create a new key edge","attack-control",false},
        {"attack-keyoff-positive","history-attack",attack,history_event(history_reg(8,64),history_delay(1024),history_reg(8,0)),"Opposite key edge during attack changes envelope","attack-control",true},
    }
    for _,f:=range fixtures {
        entry:=history_case{Name:f.name,Profile:f.family,Rate:len(job.cases),Stride:1,Frames:16384,SampleRate:55937.5,Increment:65984,RecordedIncrement:65984,Window:32,Pretrigger:256,Multiplier:8,KeyCode:0x4a,Feature:"history_control",Expectation:f.expectation,Positive:f.positive}
        if f.baseline!="" { baseline:=f.baseline;entry.Baseline=&baseline }
        e:=job.write_case(entry,f.init,f.event);if e!=nil { return e }
    }
    return nil
}

func (job *history_generation) make_init(ar,d1,d2,d1l,rr byte,keyon bool) []byte {
    data:=append([]byte(nil),job.bare...)
    for reg,value:=range map[byte]byte{0x58:8,0x98:ar,0xb8:d1,0xd8:d2,0xf8:d1l<<4|rr} { data[job.registers[reg]]=value }
    if keyon { data=append(data,1,8,64) }
    return append(data,0)
}

func history_event(items ...[]byte) []byte {
    data:=history_delay(256)
    for _,item:=range items { data=append(data,item...) }
    return append(data,0)
}

func history_reg(reg,value byte) []byte { return []byte{1,reg,value} }
func history_delay(count int) []byte { return []byte{2,byte(count),byte(count>>8)} }

func (job *history_generation) write_case(entry history_case,init,event []byte) error {
    for pos:=0;pos<len(event)-1;pos+=3 {
        switch event[pos] {
        case 2:entry.DelayTotal+=int(event[pos+1])|int(event[pos+2])<<8
        case 1:entry.Writes=append(entry.Writes,history_write{int(event[pos+1]),int(event[pos+2]),entry.DelayTotal})
        default:return fmt.Errorf("invalid internal event opcode")
        }
    }
    if entry.DelayTotal>4352 { return fmt.Errorf("history event exceeds bounded duration") }
    entry.Init=filepath.Join(job.output,entry.Name+"-init.bin")
    entry.Event=filepath.Join(job.output,entry.Name+"-event.bin")
    entry.InitHash=fmt.Sprintf("%x",sha256.Sum256(init))
    entry.EventHash=fmt.Sprintf("%x",sha256.Sum256(event))
    e:=os.WriteFile(entry.Init,init,0600);if e!=nil { return e }
    e=os.WriteFile(entry.Event,event,0600);if e!=nil { return e }
    job.cases=append(job.cases,entry)
    return nil
}
