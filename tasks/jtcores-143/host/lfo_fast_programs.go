// Artifact-only fixed-geometry LFO fast12 stimuli. No hardware/model execution.
package main
import("crypto/sha256";"encoding/json";"flag";"fmt";"math";"os";"path/filepath")
type fast_write struct { Register int `json:"reg"`; Value int `json:"value"` }
type fast_operation struct { Kind string `json:"kind"`; Count int `json:"delay_count,omitempty"`; Register int `json:"reg,omitempty"`; Value int `json:"value"` }
type fast_case struct {
 Name string `json:"name"`; Profile string `json:"profile"`; Rate int `json:"rate"`; AMD int `json:"amd"`; PMD int `json:"pmd"`; AMS int `json:"ams"`; PMS int `json:"pms"`; AME int `json:"ame"`; Wave int `json:"waveform"`
 Init string `json:"init"`; Event string `json:"event"`; InitSHA string `json:"init_sha256"`; EventSHA string `json:"event_sha256"`; Writes []fast_write `json:"init_writes"`; Operations []fast_operation `json:"event_operations"`
 KeyCode int `json:"key_code"`; Multiplier int `json:"multiplier"`; NativeIncrement int `json:"nominal_unqualified_native_increment"`; RecordedIncrement int `json:"nominal_unqualified_recorded_increment"`; Stride int `json:"stride"`; Frames int `json:"recorded_frames"`; Fs float64 `json:"recorded_sample_rate_hz"`; Window int `json:"projection_window_samples"`; Hop int `json:"projection_hop_samples"`; Prefix int `json:"guaranteed_early_prefix_samples"`; Delay int `json:"pretrigger_count"`
 PeriodNumerator int64 `json:"nominal_period_numerator"`; NativeDenominator int64 `json:"nominal_native_period_denominator"`; RecordedDenominator int64 `json:"nominal_recorded_period_denominator"`; Period float64 `json:"nominal_lfo_period_recorded_samples"`; Frequency float64 `json:"nominal_lfo_hz"`; Minimum int `json:"minimum_actual_post_guard_samples"`; LiteralUpper int `json:"conservative_literal_lastwrite_upper_recorded"`; Limits []string `json:"limits"`
}
type fast_generation struct { base,output string; bare []byte; positions map[byte]int; cases []fast_case }
var fast_rates=[]int{0xc0,0xcf,0xd0,0xdf,0xe0,0xe1,0xe7,0xe8,0xee,0xef,0xf0,0xff}
func main(){var job fast_generation;flag.StringVar(&job.base,"base","","strict canonical tone bytecode");flag.StringVar(&job.output,"output","","fresh output directory");flag.Parse();e:=job.run();if e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}}
func(job *fast_generation)run()error{
 if job.base==""||job.output==""||flag.NArg()!=0{return fmt.Errorf("use -base TONE.bin -output NEW_DIRECTORY")}
 e:=job.read_base();if e!=nil{return e};job.output,e=filepath.Abs(job.output);if e!=nil{return e};e=os.Mkdir(job.output,0755);if e!=nil{return e}
 e=job.write_case("carrier-amoff-c0","carrier-control",0xc0,0);if e!=nil{return e};for _,rate:=range fast_rates{e=job.write_case(fmt.Sprintf("rate-%02x",rate),"am-rate",rate,64);if e!=nil{return e}}
 raw,e:=json.MarshalIndent(job.cases,"","  ");if e!=nil{return e};e=os.WriteFile(filepath.Join(job.output,"cases.json"),append(raw,'\n'),0600);if e!=nil{return e};fmt.Println("Generated13 fixed-geometry fixtures; not physical/model coverage");return nil
}
func(job *fast_generation)read_base()error{
 data,e:=os.ReadFile(job.base);if e!=nil{return e};if len(data)<28||len(data)>8192||string(data[len(data)-4:])!=string([]byte{1,8,64,0}){return fmt.Errorf("base must end with exactly canonicalC2 KEYON/END")};job.bare=append([]byte(nil),data[:len(data)-4]...);if len(job.bare)%3!=0{return fmt.Errorf("base must contain register writes only")}
 job.positions=map[byte]int{};globals:=map[byte]int{};am,pm:=false,false;special:=map[byte]byte{0x20:0xc7,0x28:0x4a,0x58:1,0x78:0,0x98:31,0xf8:15}
 for pos:=0;pos<len(job.bare);pos+=3{
  reg,val:=job.bare[pos+1],job.bare[pos+2];if job.bare[pos]!=1{return fmt.Errorf("base non-register bytecode")};if pos<24{if reg!=8||int(val)!=pos/3{return fmt.Errorf("base must begin with ordered allchannel KEYOFF")};continue};if reg==8{return fmt.Errorf("base duplicate/intermediate KEYON/KEYOFF")}
  if reg<0x20{
   allowed:=map[byte]byte{1:0,15:0,20:48,24:0,27:0};if reg==25{if val==0&&!am{am=true}else if val==128&&!pm{pm=true}else{return fmt.Errorf("base contaminated/duplicate depth")}}else{want,ok:=allowed[reg];if !ok||val!=want||globals[reg]!=0{return fmt.Errorf("base contaminated/duplicate global%02x",reg)}};globals[reg]++
  }else{want:=byte(0);if reg>=96&&reg<128{want=127};if x,ok:=special[reg];ok{want=x};if val!=0&&val!=want&&!(reg>=96&&reg<128&&val==127){return fmt.Errorf("base noncanonical intermediate register%02x",reg)}}
  job.positions[reg]=pos+2
 }
 for _,reg:=range []byte{1,15,20,24,27}{if globals[reg]!=1{return fmt.Errorf("base missing global%02x",reg)}};if !am||!pm{return fmt.Errorf("base missing independent depth clears")}
 for r:=32;r<=255;r++{reg:=byte(r);want:=byte(0);if r>=96&&r<128{want=127};if val,ok:=special[reg];ok{want=val};pos,ok:=job.positions[reg];if !ok||job.bare[pos]!=want{return fmt.Errorf("base noncanonical final register%02x",r)}};return nil
}
func(job *fast_generation)write_case(name,profile string,rate,amd int)error{
 init:=append([]byte(nil),job.bare...);for reg,val:=range map[byte]byte{0x38:1,0x58:8,0xb8:128}{init[job.positions[reg]]=val};for _,w:=range []fast_write{{1,2},{24,rate},{25,amd},{25,128},{27,0},{8,64}}{init=append(init,1,byte(w.Register),byte(w.Value))};event:=[]byte{2,0,32,1,1,0,0}
 denominator:=int64(16+(rate&15))<<uint(rate>>4);period:=float64(int64(1)<<30)/float64(denominator*4);minimum:=int(math.Ceil(3*period))+40;if profile=="carrier-control"{minimum=1024}
 c:=fast_case{Name:name,Profile:profile,Rate:rate,AMD:amd,AMS:1,AME:1,KeyCode:74,Multiplier:8,NativeIncrement:65984,RecordedIncrement:263936,Stride:4,Frames:16384,Fs:13984.375,Window:16,Hop:4,Prefix:512,Delay:8192,PeriodNumerator:1<<30,NativeDenominator:denominator,RecordedDenominator:denominator*4,Period:period,Frequency:13984.375/period,Minimum:minimum,LiteralUpper:1794,Limits:[]string{"Exact nominal rational is an independently checked description of the primary rounded frequency table, not printed exact truth or chipcounter architecture","Native/retained carrier needs measured control; no aliased folding","Post=max(actualhostupper+64,conservative literalupper1794)+80; at least immutable fixtureminimum retained","Literalupper is planning40master/count+512master/write+512record schedulingreserve; actualhostupper remains mandatory","First512 constant resetheld baseline, not silent or necessarily fulllevel","Period measured independently; coarsebands unchanged; fine1% separate finitequalification required","No physical/model execution, acceptedbus timing, IRQ, exactkey/TESTphase or cause claim"}}
 for p:=0;p<len(init);p+=3{c.Writes=append(c.Writes,fast_write{int(init[p+1]),int(init[p+2])})};init=append(init,0);c.Operations=[]fast_operation{{Kind:"delay",Count:8192},{Kind:"write",Register:1,Value:0}}
 c.Init=filepath.Join(job.output,name+"-init.bin");c.Event=filepath.Join(job.output,name+"-event.bin");c.InitSHA=fmt.Sprintf("%x",sha256.Sum256(init));c.EventSHA=fmt.Sprintf("%x",sha256.Sum256(event));e:=os.WriteFile(c.Init,init,0600);if e!=nil{return e};e=os.WriteFile(c.Event,event,0600);if e!=nil{return e};job.cases=append(job.cases,c);return nil
}
