// YM2151 LFO history and 32-route isolation measurement programs.
package main
import("crypto/sha256";"encoding/json";"flag";"fmt";"os";"path/filepath")
type reg_write struct { Register int `json:"reg"`;Value int `json:"value"` }
type operation struct { Kind string `json:"kind"`;Count int `json:"delay_count,omitempty"`;Register int `json:"reg,omitempty"`;Value int `json:"value"`;Role string `json:"role,omitempty"` }
type voice struct { Name string `json:"name"`;Offset int `json:"offset"`;Mask int `json:"key_mask"` }
var voices=[]voice{{"m1",0,8},{"m2",8,32},{"c1",16,16},{"c2",24,64}}
type fixture struct {
 Name string `json:"name"`;Profile string `json:"profile"`;Kind string `json:"test_kind"`;Purpose string `json:"purpose"`;Baseline string `json:"baseline_case"`
 Channel int `json:"channel"`;Operator voice `json:"operator"`;Slot int `json:"slot"`;KeyValue int `json:"key_on_value"`;RemoteChannel int `json:"remote_channel"`;RemoteSlot int `json:"remote_slot"`
 Init string `json:"init"`;Event string `json:"event"`;InitHash string `json:"init_sha256"`;EventHash string `json:"event_sha256"`;InitWrites []reg_write `json:"init_writes"`;Operations []operation `json:"event_operations"`;EventWrites []reg_write `json:"event_writes"`
 AMD int `json:"amd"`;PMD int `json:"pmd"`;AMS int `json:"ams"`;PMS int `json:"pms"`;AME int `json:"ame"`
 Rate int `json:"rate"`;Waveform int `json:"waveform"`;KeyCode int `json:"key_code"`;Multiplier int `json:"multiplier"`;NominalIncrement int `json:"nominal_unqualified_native_increment"`;NominalRecordedIncrement int `json:"nominal_unqualified_recorded_increment"`;CarrierQualification string `json:"carrier_qualification"`
 Stride int `json:"stride"`;Frames int `json:"recorded_frames"`;SampleRate float64 `json:"recorded_sample_rate_hz"`;Period float64 `json:"nominal_lfo_period_recorded_samples"`;Window int `json:"projection_window_samples"`;Weights string `json:"projection_observation_weights"`
 TotalDelay int `json:"total_delay_count"`;FinalInterventionDelay int `json:"final_intervention_delay_count"`;Guard int `json:"post_intervention_guard_samples"`;ConservativeFinalFrame float64 `json:"conservative_final_intervention_frame_upper_bound"`;ConservativeCycles float64 `json:"conservative_post_intervention_cycles"`;ExpectedLeftRuns string `json:"expected_left_long_zero_runs"`;ExpectedRight string `json:"expected_right_audio"`;ForcePeriod bool `json:"period_measurement_applicable"`;Expectations []string `json:"expectations"`
}
type history_generation struct {base,output string;bare []byte;registers map[byte]int;cases []fixture}
func main(){var job history_generation;flag.StringVar(&job.base,"base","","trusted canonical tone bytecode");flag.StringVar(&job.output,"output","","fresh directory");flag.Parse();e:=job.run();if e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}}
func(job *history_generation)run()error{
 if job.base==""||job.output==""||flag.NArg()!=0{return fmt.Errorf("use -base TONE.bin -output NEW_DIRECTORY")}
 e:=job.read_base();if e!=nil{return e};e=os.Mkdir(job.output,0755);if e!=nil{return e}
 for _,profile:=range []string{"baseline","am","pm"}{for channel:=0;channel<8;channel++{for _,op:=range voices{e=job.make_route(profile,channel,op);if e!=nil{return e}}}}
 for _,name:=range []string{"held-reset","release-null","repeat-keyon","repeat-test-zero","keyoff-rekey","keyoff-reset-rekey","short-reset-pulse","long-reset-hold","long-gap-null","repeat-rate","repeat-wave","keyoff-only"}{e=job.make_history(name);if e!=nil{return e}}
 data,e:=json.MarshalIndent(job.cases,"","  ");if e!=nil{return e};e=os.WriteFile(filepath.Join(job.output,"cases.json"),append(data,'\n'),0600);if e!=nil{return e};fmt.Printf("Generated %d fixtures\n",len(job.cases));return nil
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

func(job *history_generation)blank(name,profile string,ch int,op voice)fixture{
 return fixture{Name:name,Profile:profile,Channel:ch,Operator:op,Slot:ch+op.Offset,KeyValue:ch|op.Mask,RemoteChannel:(ch+1)%8,RemoteSlot:ch+(op.Offset+8)%32,Rate:192,Waveform:2,KeyCode:74,Multiplier:0,NominalIncrement:4124,NominalRecordedIncrement:32992,CarrierQualification:"Unmeasured route must be qualified by its own zero-depth baseline; no inherited32-voice calibration",Stride:8,Frames:16384,SampleRate:6992.1875,Period:2048,Window:129,Weights:"squared Hann h^2; h=np.hanning129; separate from permanent128-point h-weight analyzer",Guard:80,ExpectedLeftRuns:"three",ExpectedRight:"bipolar throughout; no long silence",ForcePeriod:true}
}
func(job *history_generation)make_route(profile string,ch int,op voice)error{
 c:=job.blank(fmt.Sprintf("route-ch%d-%s-%s",ch,op.Name,profile),profile,ch,op);c.Baseline=fmt.Sprintf("route-ch%d-%s-baseline",ch,op.Name)
 switch profile{case "baseline":c.Kind="carrier_and_negative_gates";c.AME=1;c.ForcePeriod=false;c.Purpose="Zero-depth initial/final carrier qualification plus inactive remote-channel/AME probes, expected constant output"
 case "am":c.Kind="route_am";c.AMD=64;c.AMS=1;c.AME=1;c.Purpose="Single selected carrier amplitude modulation; all other voices muted/key-off"
 case "pm":c.Kind="route_pm";c.PMD=64;c.PMS=4;c.Purpose="Single selected carrier pitch modulation; all other voices muted/key-off"}
 targets:=[][]reg_write{{},{},{}}
 if profile=="baseline"{targets=[][]reg_write{
 {{25,64},{25,192},{56+c.RemoteChannel,65}},
 {{56+c.RemoteChannel,0},{160+c.Slot,0},{56+c.Channel,1},{160+c.RemoteSlot,128}},
 {{56+c.Channel,0},{160+c.RemoteSlot,0},{160+c.Slot,128},{25,0},{25,128}},
 };c.Expectations=append(c.Expectations,"Whole RIGHT global phase fit must be retained; late zero-depth fit does not hide a negative-gate failure","Marker1 neighbor-channel PMS/AMS must not affect selected voice; marker2 ownAME0 plus remoteAME1 must not enable AM; marker3 clears gates/depths in safe order")}
 c.Operations=job.pan_event(c,true,false,targets,false);return job.write(c)
}
func(job *history_generation)make_history(name string)error{
 c:=job.blank("history-"+name,"history",0,voices[3]);c.Kind=name;c.AMD=64;c.AMS=1;c.AME=1;c.Baseline="history-release-null";targets:=[][]reg_write{{},{},{}};release,long_gap,reset_gap:=true,false,false
 switch name{
 case "held-reset":release=false;c.ForcePeriod=false;c.Purpose="Hold TEST02 for whole capture; measure held waveform stability, no forced period"
 case "release-null":c.Purpose="Release TEST00 and pan-only null; global LFO free-running"
 case "repeat-keyon":targets=[][]reg_write{{{8,64}},{{8,64}},{{8,64}}};c.Purpose="Repeated already-high key level; empirical carrier and LFO phase continuity"
 case "repeat-test-zero":targets=[][]reg_write{{{1,0}},{{1,0}},{{1,0}}};c.Purpose="Empirical history of repeated TEST00 without transition"
 case "keyoff-rekey":targets=[][]reg_write{{{8,0}},{{8,64}},{{8,64}}};c.Purpose="All-keys-off gap without TEST reset; AM phase across gap permits carrier/EG restart";c.ExpectedLeftRuns="may merge while voice is off; not fixed three";c.ExpectedRight="bipolar prefix and post-rekey; intended silent release gap"
 case "keyoff-reset-rekey":targets=[][]reg_write{{{8,0}},{{8,64}},{{8,64}}};reset_gap=true;c.Baseline="history-keyoff-rekey";c.Purpose="Matched silent gap with explicit TEST02/00 positive reset; intentional LFO phase change";c.ExpectedLeftRuns="may merge while voice is off; not fixed three";c.ExpectedRight="bipolar prefix and post-rekey; intended silent release gap"
 case "short-reset-pulse":targets=[][]reg_write{{{1,2}},{{1,0}},{{1,0}}};c.Purpose="Short held waveform segment and positive reset/release"
 case "long-reset-hold":targets=[][]reg_write{{{1,2}},{{1,0}},{{1,0}}};long_gap=true;c.Baseline="history-long-gap-null";c.Purpose="TEST02 hold for at least3 nominal would-be C0 periods then release"
 case "long-gap-null":long_gap=true;c.Purpose="Matched long delay and markers without TEST pulse"
 case "repeat-rate":targets=[][]reg_write{{{24,192}},{{24,192}},{{24,192}}};c.Purpose="Empirical repeated same LFRQ write history"
 case "repeat-wave":targets=[][]reg_write{{{27,2}},{{27,2}},{{27,2}}};c.Purpose="Empirical repeated same W write history"
 case "keyoff-only":targets=[][]reg_write{{{8,0}},{{8,0}},{{8,0}}};c.Purpose="Positive KEYOFF path, prefix tone then sustained silence";c.ForcePeriod=false;c.ExpectedLeftRuns="merged sustained silence, no fixed three";c.ExpectedRight="bipolar prefix; quiet final tail expected"
 }
 c.Operations=job.pan_event(c,release,long_gap,targets,reset_gap)
 c.Expectations=append(c.Expectations,"KON/repeated TEST00/rate/wave/free-run behavior is empirical; manual does not specify every retrigger case","Do not require unchanged carrier phase across intentional KEYOFF/rekey or unchanged LFO phase across intentional TEST reset")
 return job.write(c)
}
func(job *history_generation)pan_event(c fixture,release,long_gap bool,targets [][]reg_write,reset_gap bool)[]operation{
 ops:=[]operation{{Kind:"delay",Count:8192}}
 if release{ops=append(ops,operation{Kind:"write",Register:1,Value:0,Role:"initial_test_release"})}
 ops=append(ops,operation{Kind:"delay",Count:8192})
 for i,duration:=range []int{1024,2048,1024}{
  ops=append(ops,operation{Kind:"write",Register:32+c.Channel,Value:135,Role:"left_marker_off"},operation{Kind:"delay",Count:256})
  for _,w:=range targets[i]{ops=append(ops,operation{Kind:"write",Register:w.Register,Value:w.Value,Role:"intervention"})}
  ops=append(ops,operation{Kind:"delay",Count:duration-256},operation{Kind:"write",Register:32+c.Channel,Value:199,Role:"left_marker_restore"})
  if i<2{
   if i==0&&long_gap{ops=append(ops,operation{Kind:"delay",Count:65535},operation{Kind:"delay",Count:32768})
   }else if i==0&&(c.Kind=="keyoff-rekey"||c.Kind=="keyoff-reset-rekey"){
    ops=append(ops,operation{Kind:"delay",Count:1024});if reset_gap{ops=append(ops,operation{Kind:"write",Register:1,Value:2,Role:"intervention"})}
    ops=append(ops,operation{Kind:"delay",Count:1024});if reset_gap{ops=append(ops,operation{Kind:"write",Register:1,Value:0,Role:"intervention"})}
    ops=append(ops,operation{Kind:"delay",Count:2048})
   }else{ops=append(ops,operation{Kind:"delay",Count:4096})}
  }
 }
 return ops
}
func(job *history_generation)write(c fixture)error{
 init:=append([]byte(nil),job.bare...)
 // Undo the canonical C2/ch0 tone before selecting exactly one route.
 for reg,value:=range map[byte]byte{32:0,40:0,88:0,120:127,152:0,248:0}{init[job.registers[reg]]=value}
 for reg,value:=range map[byte]byte{byte(32+c.Channel):199,byte(40+c.Channel):74,byte(56+c.Channel):byte(c.PMS*16+c.AMS),byte(64+c.Slot):0,byte(96+c.Slot):0,byte(128+c.Slot):31,byte(160+c.Slot):byte(c.AME*128),byte(192+c.Slot):0,byte(224+c.Slot):15}{init[job.registers[reg]]=value}
 for _,w:=range []reg_write{{1,2},{24,192},{25,c.AMD},{25,128|c.PMD},{27,2},{8,c.KeyValue}}{init=append(init,1,byte(w.Register),byte(w.Value))}
 for p:=0;p<len(init);p+=3{c.InitWrites=append(c.InitWrites,reg_write{int(init[p+1]),int(init[p+2])})};init=append(init,0)
 var event []byte;writes:=0
 for _,op:=range c.Operations{if op.Kind=="delay"{c.TotalDelay+=op.Count;event=append(event,2,byte(op.Count),byte(op.Count>>8))}else{writes++;c.FinalInterventionDelay=c.TotalDelay;c.EventWrites=append(c.EventWrites,reg_write{op.Register,op.Value});event=append(event,1,byte(op.Register),byte(op.Value))}}
 event=append(event,0)
 c.ConservativeFinalFrame=float64(c.FinalInterventionDelay*40+writes*512)/512+512
 c.ConservativeCycles=(float64(c.Frames)-c.ConservativeFinalFrame-float64(c.Guard))/c.Period
 if c.ConservativeCycles<2{return fmt.Errorf("%s has insufficient conservative post-intervention horizon",c.Name)}
 c.Expectations=append(c.Expectations,"No alternate TEST bits; no hardware/CPU/ROM changes; literal delays remain approximate across models/PCB","Final-intervention-aware analysis start plus80samples; old fixed5000..14000 window is invalid for long-hold cases")
 c.Init=filepath.Join(job.output,c.Name+"-init.bin");c.Event=filepath.Join(job.output,c.Name+"-event.bin");c.InitHash=fmt.Sprintf("%x",sha256.Sum256(init));c.EventHash=fmt.Sprintf("%x",sha256.Sum256(event))
 e:=os.WriteFile(c.Init,init,0600);if e!=nil{return e};e=os.WriteFile(c.Event,event,0600);if e!=nil{return e};job.cases=append(job.cases,c);return nil
}
