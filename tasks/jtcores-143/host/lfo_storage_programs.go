// Generate independent YM2151 LFO depth-storage and INIT-order measurements.
package main
import (
 "crypto/sha256"
 "encoding/json"
 "flag"
 "fmt"
 "os"
 "path/filepath"
)
type storage_write struct { Register int `json:"reg"`; Value int `json:"value"` }
type storage_operation struct { Kind string `json:"kind"`; Count int `json:"delay_count,omitempty"`; Register int `json:"reg,omitempty"`; Value int `json:"value"` }
type storage_case struct {
 Name string `json:"name"`
 Profile string `json:"profile"`
 Preset string `json:"preset"`
 Purpose string `json:"purpose"`
 Kind string `json:"test_kind"`
 Baseline string `json:"baseline_case"`
 Init string `json:"init"`
 Event string `json:"event"`
 InitHash string `json:"init_sha256"`
 EventHash string `json:"event_sha256"`
 InitWrites []storage_write `json:"init_writes"`
 Operations []storage_operation `json:"event_operations"`
 Writes []storage_write `json:"event_writes"`
 DepthWrites []storage_write `json:"depth_writes"`
 Expectations []string `json:"expectations"`
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
 JointWindow int `json:"joint_projection_window_samples"`
 SampleRate float64 `json:"recorded_sample_rate_hz"`
 Pretrigger int `json:"pretrigger_count"`
 TotalDelay int `json:"total_delay_count"`
 MarkerLatch int `json:"physical_marker_latch"`
 ContinuousLatch int `json:"physical_continuous_latch"`
 MarkerThreshold int `json:"marker_minimum_zero_run_samples"`
}
type storage_generation struct { base,output string;bare []byte;registers map[byte]int;cases []storage_case }
func main() {
 var job storage_generation
 flag.StringVar(&job.base,"base","","trusted canonical single-C2 tone bytecode")
 flag.StringVar(&job.output,"output","","fresh output directory")
 flag.Parse()
 e:=job.run();if e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}
func (job *storage_generation) run() error {
 if job.base=="" || job.output=="" || flag.NArg()!=0 { return fmt.Errorf("use -base TONE.bin -output NEW_DIRECTORY") }
 e:=job.read_base();if e!=nil{return e}
 e=os.Mkdir(job.output,0755);if e!=nil{return e}
 for _,name:=range []string{"am-cross-pmd","am-null","am-own-amd","pm-cross-amd","pm-null","pm-own-pmd","combined-amd-first","combined-pmd-first"} {
  e=job.write_case(name);if e!=nil{return e}
 }
 data,e:=json.MarshalIndent(job.cases,"","  ");if e!=nil{return e}
 e=os.WriteFile(filepath.Join(job.output,"cases.json"),append(data,'\n'),0600);if e!=nil{return e}
 fmt.Printf("Generated %d storage/history fixtures\n",len(job.cases));return nil
}
func (job *storage_generation) read_base() error {
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

func (job *storage_generation) write_case(name string) error {
 c:=storage_case{Name:name,Profile:"lfo-storage",Rate:0xc0,Waveform:2,NominalHz:55937.5/16384,KeyCode:0x4a,Multiplier:0,Increment:4124,RecordedIncrement:32992,Stride:8,Frames:16384,Window:64,JointWindow:129,SampleRate:6992.1875,Pretrigger:8192,TotalDelay:28672,MarkerLatch:0,ContinuousLatch:1,MarkerThreshold:16}
 targets:=[]int(nil)
 switch name {
 case "am-cross-pmd":c.Preset="am";c.Kind="cross_depth";c.Baseline="am-null";c.Purpose="PMD writes preserve stored AMD and AM phase while PMS is zero";targets=[]int{0xc0,0xff,0x80}
 case "am-null":c.Preset="am";c.Kind="null_control";c.Baseline="am-null";c.Purpose="Pan-only AM baseline with every depth-slot delay retained"
 case "am-own-amd":c.Preset="am";c.Kind="own_depth_positive";c.Baseline="am-null";c.Purpose="AMD0/127/64 positively change own AM depth and return to64";targets=[]int{0,127,64}
 case "pm-cross-amd":c.Preset="pm";c.Kind="cross_depth";c.Baseline="pm-null";c.Purpose="AMD writes preserve stored PMD and PM phase while AMS/AME are zero";targets=[]int{64,127,0}
 case "pm-null":c.Preset="pm";c.Kind="null_control";c.Baseline="pm-null";c.Purpose="Pan-only PM baseline with every depth-slot delay retained"
 case "pm-own-pmd":c.Preset="pm";c.Kind="own_depth_positive";c.Baseline="pm-null";c.Purpose="PMD0/127/64 positively change own PM depth and return to64";targets=[]int{128,255,192}
 case "combined-amd-first":c.Preset="combined";c.Kind="init_order";c.Baseline="combined-pmd-first";c.Purpose="Set AMD then PMD, preserving both final independently stored depths"
 case "combined-pmd-first":c.Preset="combined";c.Kind="init_order";c.Baseline="combined-amd-first";c.Purpose="Reverse only final INIT depth-write order with same EVENT and final state"
 default:return fmt.Errorf("unknown internal fixture")
 }
 if c.Preset=="am" || c.Preset=="combined" {c.AMD=64;c.AMS=1;c.AME=1}
 if c.Preset=="pm" || c.Preset=="combined" {c.PMD=64;c.PMS=4}
 init:=append([]byte(nil),job.bare...)
 for reg,value:=range map[byte]byte{0x38:byte(c.PMS<<4|c.AMS),0x58:0,0xb8:byte(c.AME<<7)} {init[job.registers[reg]]=value}
 depth:=[]storage_write{{0x19,c.AMD},{0x19,0x80|c.PMD}}
 if name=="combined-pmd-first" {depth[0],depth[1]=depth[1],depth[0]}
 extra:=[]storage_write{{1,2},{0x18,0xc0}}
 extra=append(extra,depth...);extra=append(extra,storage_write{0x1b,2},storage_write{8,0x40})
 for _,w:=range extra {init=append(init,1,byte(w.Register),byte(w.Value))}
 for pos:=0;pos<len(init);pos+=3 {c.InitWrites=append(c.InitWrites,storage_write{int(init[pos+1]),int(init[pos+2])})}
 init=append(init,0)
 c.Operations=[]storage_operation{{Kind:"delay",Count:8192},{Kind:"write",Register:1,Value:0},{Kind:"delay",Count:8192}}
 for i,duration:=range []int{1024,2048,1024} {
  c.Operations=append(c.Operations,storage_operation{Kind:"write",Register:0x20,Value:0x87},storage_operation{Kind:"delay",Count:256})
  if len(targets)>0 {w:=storage_write{0x19,targets[i]};c.DepthWrites=append(c.DepthWrites,w);c.Operations=append(c.Operations,storage_operation{Kind:"write",Register:w.Register,Value:w.Value})}
  c.Operations=append(c.Operations,storage_operation{Kind:"delay",Count:duration-256},storage_operation{Kind:"write",Register:0x20,Value:0xc7})
  if i<2 {c.Operations=append(c.Operations,storage_operation{Kind:"delay",Count:4096})}
 }
 event:=storage_bytecode(c.Operations)
 for _,op:=range c.Operations {if op.Kind=="write" {c.Writes=append(c.Writes,storage_write{op.Register,op.Value})}}
 c.Expectations=[]string{"Three LEFT/latch0 markers; RIGHT/latch1 remains bipolar", "Model API clock is not a physical GPIO timestamp", "Null controls preserve delays but omitted writes change bus execution time; no cross-case sample identity required"}
 if c.Kind=="cross_depth" {c.Expectations=append(c.Expectations,"Stored active depth and global LFO phase persist; qualify against same-device null and late-only coherent prediction")}
 if c.Kind=="own_depth_positive" {c.Expectations=append(c.Expectations,"Own-depth transitions intentionally alter trajectory; do not apply unchanged-trajectory rule; final returned depth64")}
 if c.Kind=="init_order" {c.Expectations=append(c.Expectations,"Final AMD64/PMD64 is independent of INIT write order; combined extractor requires separate32992 qualification")}
 c.Init=filepath.Join(job.output,name+"-init.bin");c.Event=filepath.Join(job.output,name+"-event.bin")
 c.InitHash=fmt.Sprintf("%x",sha256.Sum256(init));c.EventHash=fmt.Sprintf("%x",sha256.Sum256(event))
 e:=os.WriteFile(c.Init,init,0600);if e!=nil{return e}
 e=os.WriteFile(c.Event,event,0600);if e!=nil{return e}
 job.cases=append(job.cases,c);return nil
}
func storage_bytecode(operations []storage_operation) []byte {
 var data []byte
 for _,op:=range operations {if op.Kind=="delay" {data=append(data,2,byte(op.Count),byte(op.Count>>8))} else {data=append(data,1,byte(op.Register),byte(op.Value))}}
 return append(data,0)
}
