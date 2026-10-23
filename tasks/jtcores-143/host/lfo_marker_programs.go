// Generate output-visible LFO pan markers and matched no-pan controls.
package main

import (
    "crypto/sha256"
    "encoding/json"
    "flag"
    "fmt"
    "os"
    "path/filepath"
)

type marker_write struct { Register int `json:"reg"`; Value int `json:"value"` }
type marker_operation struct {
    Kind string `json:"kind"`
    Count int `json:"delay_count,omitempty"`
    Register int `json:"reg,omitempty"`
    Value int `json:"value"`
}
type marker_case struct {
    Name string `json:"name"`
    Profile string `json:"profile"`
    Preset string `json:"preset"`
    Purpose string `json:"purpose"`
    Init string `json:"init"`
    Event string `json:"event"`
    InitHash string `json:"init_sha256"`
    EventHash string `json:"event_sha256"`
    ControlInit string `json:"control_init"`
    ControlEvent string `json:"control_event"`
    ControlInitHash string `json:"control_init_sha256"`
    ControlEventHash string `json:"control_event_sha256"`
    InitWrites []marker_write `json:"init_writes"`
    EventOperations []marker_operation `json:"event_operations"`
    EventWrites []marker_write `json:"event_writes"`
    ControlOperations []marker_operation `json:"control_event_operations"`
    ControlWrites []marker_write `json:"control_event_writes"`
    Rate int `json:"rate"`
    Waveform int `json:"waveform"`
    AMD int `json:"amd"`
    PMD int `json:"pmd"`
    AMS int `json:"ams"`
    PMS int `json:"pms"`
    AME int `json:"ame"`
    NominalHz float64 `json:"nominal_lfo_hz"`
    KeyCode int `json:"key_code"`
    Multiplier int `json:"multiplier"`
    Increment int `json:"phase_increment_20bit"`
    RecordedIncrement int `json:"recorded_phase_increment_20bit"`
    Stride int `json:"stride"`
    Frames int `json:"recorded_frames"`
    Window int `json:"projection_window_samples"`
    SampleRate float64 `json:"recorded_sample_rate_hz"`
    Pretrigger int `json:"pretrigger_count"`
    TotalDelay int `json:"total_delay_count"`
    MarkerLatch int `json:"physical_marker_latch"`
    ContinuousLatch int `json:"physical_continuous_latch"`
    MarkerControl string `json:"marker_role"`
    ContinuousControl string `json:"continuous_role"`
    MarkerThreshold int `json:"marker_minimum_zero_run_samples"`
}
type lfo_marker_generation struct {
    base,output string
    bare []byte
    registers map[byte]int
    cases []marker_case
}

func main() {
    var job lfo_marker_generation
    flag.StringVar(&job.base,"base","","canonical single-C2 tone bytecode")
    flag.StringVar(&job.output,"output","","fresh output directory")
    flag.Parse()
    e:=job.run();if e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}

func (job *lfo_marker_generation) run() error {
    if job.base=="" || job.output=="" || flag.NArg()!=0 { return fmt.Errorf("use -base TONE.bin -output NEW_DIRECTORY") }
    e:=job.read_base();if e!=nil { return e }
    e=os.Mkdir(job.output,0755);if e!=nil { return e }
    for _,preset:=range []string{"constant","am","pm"} {
        e=job.write_case(preset);if e!=nil { return e }
    }
    data,e:=json.MarshalIndent(job.cases,"","  ");if e!=nil { return e }
    e=os.WriteFile(filepath.Join(job.output,"cases.json"),append(data,'\n'),0600);if e!=nil { return e }
    fmt.Printf("Generated %d LFO marker fixtures and matched controls\n",len(job.cases))
    return nil
}

func (job *lfo_marker_generation) read_base() error {
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

func (job *lfo_marker_generation) write_case(preset string) error {
    entry:=marker_case{Name:preset,Profile:"lfo-marker",Preset:preset,Purpose:"Three bit6 pan-off markers while bit7 output continues",Rate:0xc0,Waveform:2,NominalHz:55937.5/16384,KeyCode:0x4a,Multiplier:0,Increment:4124,RecordedIncrement:32992,Stride:8,Frames:16384,Window:64,SampleRate:6992.1875,Pretrigger:8192,TotalDelay:28672,MarkerLatch:0,ContinuousLatch:1,MarkerControl:"reg20 bit6 cleared by87; restored byC7",ContinuousControl:"reg20 bit7 remains enabled throughout",MarkerThreshold:16}
    if preset=="am" { entry.AMD=64;entry.AMS=1;entry.AME=1 }
    if preset=="pm" { entry.PMD=64;entry.PMS=4 }
    init:=append([]byte(nil),job.bare...)
    for reg,value:=range map[byte]byte{0x38:byte(entry.PMS<<4|entry.AMS),0x58:0,0xb8:byte(entry.AME<<7)} { init[job.registers[reg]]=value }
    for _,w:=range []marker_write{{1,2},{0x18,0xc0},{0x19,entry.AMD},{0x19,0x80|entry.PMD},{0x1b,2},{8,0x40}} { init=append(init,1,byte(w.Register),byte(w.Value)) }
    for pos:=0;pos<len(init);pos+=3 { entry.InitWrites=append(entry.InitWrites,marker_write{int(init[pos+1]),int(init[pos+2])}) }
    init=append(init,0)
    entry.EventOperations=[]marker_operation{
        {Kind:"delay",Count:8192},{Kind:"write",Register:1,Value:0},
        {Kind:"delay",Count:8192},{Kind:"write",Register:0x20,Value:0x87},
        {Kind:"delay",Count:1024},{Kind:"write",Register:0x20,Value:0xc7},
        {Kind:"delay",Count:4096},{Kind:"write",Register:0x20,Value:0x87},
        {Kind:"delay",Count:2048},{Kind:"write",Register:0x20,Value:0xc7},
        {Kind:"delay",Count:4096},{Kind:"write",Register:0x20,Value:0x87},
        {Kind:"delay",Count:1024},{Kind:"write",Register:0x20,Value:0xc7},
    }
    for _,op:=range entry.EventOperations { if op.Kind=="delay" || op.Register!=0x20 { entry.ControlOperations=append(entry.ControlOperations,op) } }
    event:=marker_bytecode(entry.EventOperations)
    control:=marker_bytecode(entry.ControlOperations)
    for _,op:=range entry.EventOperations { if op.Kind=="write" { entry.EventWrites=append(entry.EventWrites,marker_write{op.Register,op.Value}) } }
    for _,op:=range entry.ControlOperations { if op.Kind=="write" { entry.ControlWrites=append(entry.ControlWrites,marker_write{op.Register,op.Value}) } }
    entry.Init=filepath.Join(job.output,preset+"-init.bin")
    entry.Event=filepath.Join(job.output,preset+"-event.bin")
    entry.ControlInit=entry.Init
    entry.ControlEvent=filepath.Join(job.output,preset+"-control-event.bin")
    entry.InitHash=fmt.Sprintf("%x",sha256.Sum256(init))
    entry.ControlInitHash=entry.InitHash
    entry.EventHash=fmt.Sprintf("%x",sha256.Sum256(event))
    entry.ControlEventHash=fmt.Sprintf("%x",sha256.Sum256(control))
    e:=os.WriteFile(entry.Init,init,0600);if e!=nil { return e }
    e=os.WriteFile(entry.Event,event,0600);if e!=nil { return e }
    e=os.WriteFile(entry.ControlEvent,control,0600);if e!=nil { return e }
    job.cases=append(job.cases,entry)
    return nil
}

func marker_bytecode(operations []marker_operation) []byte {
    var data []byte
    for _,op:=range operations {
        if op.Kind=="delay" { data=append(data,2,byte(op.Count),byte(op.Count>>8)) } else { data=append(data,1,byte(op.Register),byte(op.Value)) }
    }
    return append(data,0)
}
