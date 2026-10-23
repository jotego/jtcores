// YM2151 audio-noise measurement programs and conditioning fixtures.
package main
import("crypto/sha256";"encoding/json";"flag";"fmt";"os";"path/filepath")
type operation struct{Kind string `json:"kind"`;Reg int `json:"reg,omitempty"`;Value int `json:"value"`;Count int `json:"delay_count,omitempty"`;Role string `json:"role,omitempty"`}
type fixture struct{
 Name string `json:"name"`;Profile string `json:"profile"`;Expected string `json:"expected_audio"`;Channel int `json:"channel"`;Slot int `json:"slot"`;KeyMask int `json:"key_mask"`;Code int `json:"noise_code"`;TL int `json:"total_level"`;AR int `json:"attack_rate"`
 Init string `json:"init"`;ModelInit string `json:"model_init"`;ModelInitHash string `json:"model_init_sha256"`;ModelInitOps []operation `json:"model_init_operations"`;Event string `json:"event"`;InitHash string `json:"init_sha256"`;EventHash string `json:"event_sha256"`;InitOps []operation `json:"init_operations"`;EventOps []operation `json:"event_operations"`
 Stride int `json:"stride"`;Frames int `json:"recorded_frames"`;Fs float64 `json:"recorded_sample_rate_hz"`;Increment int `json:"sine_increment_20bit"`;ModelWait int `json:"model_conditioning_wait_master_clocks"`;PhysicalWait float64 `json:"physical_minimum_wait_seconds_after_cleanup_reply"`;Preflight string `json:"conditioning_qualification"`
}
type generation struct{output string;cases []fixture}
func main(){var job generation;flag.StringVar(&job.output,"output","","fresh artifact directory");flag.Parse();e:=job.run();if e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}}
func(job *generation)run()error{
 if job.output==""||flag.NArg()!=0{return fmt.Errorf("use -output NEW_DIRECTORY")}
 e:=os.Mkdir(job.output,0755);if e!=nil{return e}
 e=job.write_program("cleanup",cleanup());if e!=nil{return e}
 for code:=0;code<32;code++{c:=job.blank(fmt.Sprintf("noise-%02x",code),"noise","steady_two_level",7,31,64,code);e=job.add(c);if e!=nil{return e}}
 for _,code:=range []int{0,30,31}{c:=job.blank(fmt.Sprintf("disabled-%02x",code),"disabled","sine",7,31,64,code);e=job.add(c);if e!=nil{return e}}
 for _,ch:=range []int{0,6}{c:=job.blank(fmt.Sprintf("other-channel-%d",ch),"isolation","sine",ch,ch+24,64,31);e=job.add(c);if e!=nil{return e}}
 for _,op:=range []struct{name string;off,mask int}{{"m1",0,8},{"m2",8,32},{"c1",16,16}}{c:=job.blank("other-operator-"+op.name,"isolation","sine",7,7+op.off,op.mask,31);e=job.add(c);if e!=nil{return e}}
 for _,tl:=range []int{16,32,64,127}{c:=job.blank(fmt.Sprintf("tl-%03d",tl),"total_level","steady_two_level_or_quantized_silence",7,31,64,15);c.TL=tl;e=job.add(c);if e!=nil{return e}}
 for _,kind:=range []string{"never-keyed","keyoff","finite-attack","ne-roundtrip"}{expected:=map[string]string{"never-keyed":"quiet","keyoff":"noise_then_quiet","finite-attack":"quiet_then_noise","ne-roundtrip":"sine_noise_sine"}[kind];c:=job.blank(kind,kind,expected,7,31,64,15);if kind=="finite-attack"{c.AR=24};e=job.add(c);if e!=nil{return e}}
 if len(job.cases)!=48{return fmt.Errorf("internal profile count")}
 e=job.write_json("cases.json",job.cases);if e!=nil{return e}
 return job.make_preflight()
}
func(job *generation)write_program(name string,ops []operation)error{data:=encode(ops);return os.WriteFile(filepath.Join(job.output,name+".bin"),data,0600)}
func(job *generation)write_json(name string,value interface{})error{data,e:=json.MarshalIndent(value,"","  ");if e!=nil{return e};return os.WriteFile(filepath.Join(job.output,name),append(data,'\n'),0600)}
func(job *generation)blank(name,profile,expected string,ch,slot,mask,code int)fixture{return fixture{Name:name,Profile:profile,Expected:expected,Channel:ch,Slot:slot,KeyMask:mask,Code:code,AR:31,Stride:1,Frames:16384,Fs:55937.5,Increment:4124,ModelWait:55938*32,PhysicalWait:.5,Preflight:"UNQUALIFIED proposed common wait; physical all-slot RR0 and NE/TL127 preflight must prove quiet4096 both latches before matrix"}}
func(job *generation)add(c fixture)error{
 init:=initialize()
 init=append(init,write(32+c.Channel,199,"ALG7 bothpan"),write(40+c.Channel,74,"KC4A"),write(64+c.Slot,0,"MUL0 DT1zero"),write(96+c.Slot,c.TL,"TL"),write(128+c.Slot,c.AR,"AR andKS0"),write(224+c.Slot,15,"D1L0 RR15"))
 enabled:=c.Profile!="disabled"&&c.Profile!="isolation"&&c.Profile!="ne-roundtrip"
 ne:=c.Code;if enabled{ne|=128};init=append(init,write(15,ne,"initial NE/NFRQ"))
 if c.Profile!="never-keyed"&&c.Profile!="finite-attack"{init=append(init,write(8,c.Channel|c.KeyMask,"single selected operator key-on"))}
 init=append(init,delay(8192,"steady preheat4096 native model frames; physical wait independently bounded"))
 event:=[]operation{}
 switch c.Profile{case "isolation":event=append(event,delay(4096,"audible NEoff prefix"),write(15,128|c.Code,"NEon unrelated voice"))
 case "keyoff":event=append(event,delay(4096,"steady noise prefix"),write(8,c.Channel,"key-off"))
 case "finite-attack":event=append(event,delay(4096,"guaranteed silent prefix"),write(8,c.Channel|c.KeyMask,"key-on finite AR24"))
 case "ne-roundtrip":event=append(event,delay(4096,"sine prefix"),write(15,128|c.Code,"noise"),delay(8192,"noise middle"),write(15,c.Code,"restore sine"))}
 model_init:=cleanup();model_init=append(model_init,delay(55938,"model-only equivalent0.500004s wait; physical uses standalone cleanup and host wait"));model_init=append(model_init,init...);c.ModelInitOps=model_init;c.ModelInit=filepath.Join(job.output,c.Name+"-model-init.bin");c.ModelInitHash=fmt.Sprintf("%x",sha256.Sum256(encode(model_init)));e:=os.WriteFile(c.ModelInit,encode(model_init),0600);if e!=nil{return e};c.InitOps=init;c.EventOps=event;c.Init=filepath.Join(job.output,c.Name+"-init.bin");c.Event=filepath.Join(job.output,c.Name+"-event.bin");a,b:=encode(init),encode(event);c.InitHash=fmt.Sprintf("%x",sha256.Sum256(a));c.EventHash=fmt.Sprintf("%x",sha256.Sum256(b))
 e=os.WriteFile(c.Init,a,0600);if e!=nil{return e};e=os.WriteFile(c.Event,b,0600);if e!=nil{return e};job.cases=append(job.cases,c);return nil
}
func(job *generation)make_preflight()error{
 rows:=[]map[string]interface{}{}
 for _,kind:=range []string{"all32-held-rr0","noise-tl127-held-rr0"}{
  held:=initialize()
  for ch:=0;ch<8;ch++{held=append(held,write(32+ch,199,"ALG7 bothpan"),write(40+ch,74,"KC4A"))}
  if kind=="all32-held-rr0"{for slot:=0;slot<32;slot++{held=append(held,write(64+slot,0,"MUL0"),write(96+slot,0,"audibleTL0"),write(128+slot,31,"AR31"),write(224+slot,0,"RR0"))};for ch:=0;ch<8;ch++{held=append(held,write(8,120|ch,"all four operators held"))}}else{held=append(held,write(95,0,"MUL0"),write(127,127,"TL127 is not silence assumption"),write(159,31,"AR31"),write(255,0,"RR0"),write(15,143,"NEon code15"),write(8,71,"C7/C2 key-on"))}
  held=append(held,delay(8192,"establish adverse held history"))
  clean:=append([]operation(nil),held...);clean=append(clean,cleanup()...);clean=append(clean,delay(55938,"model finite wait1790016 master clocks before capture"))
  for _,state:=range []struct{name string;ops []operation;expected string}{{"held",held,"nonzero_positive_history"},{"clean",clean,"exact_zero_both_latches"}}{name:="preflight-"+kind+"-"+state.name;e:=job.write_program(name+"-init",state.ops);if e!=nil{return e};e=job.write_program(name+"-event",nil);if e!=nil{return e};rows=append(rows,map[string]interface{}{"name":name,"history":kind,"state":state.name,"init":filepath.Join(job.output,name+"-init.bin"),"event":filepath.Join(job.output,name+"-event.bin"),"init_operations":state.ops,"expected_audio":state.expected,"recorded_frames":16384,"stride":1,"required_final_quiet_samples":4096,"note":"Physical executes held-init, observes positive history, standalone cleanup, host>=0.5s AFTER reply, then independent quiet capture; model clean-init includes all histories and finite equivalent clock wait without reset"})}
 }
 return job.write_json("preflight.json",rows)
}
func cleanup()[]operation{out:=[]operation{write(15,0,"disable noise BEFORE releasing old envelopes")};for r:=224;r<256;r++{out=append(out,write(r,15,"all RR15 BEFORE all-channel key-off"))};for ch:=0;ch<8;ch++{out=append(out,write(8,ch,"key-off AFTER RR15"))};return out}
func initialize()[]operation{out:=[]operation{};for ch:=0;ch<8;ch++{out=append(out,write(8,ch,"canonical all-channel key-off"))};for _,w:=range [][2]int{{1,0},{15,0},{20,48},{24,0},{25,0},{25,128},{27,0}}{out=append(out,write(w[0],w[1],"global public register"))};for r:=32;r<256;r++{v:=0;if r>=96&&r<128{v=127};out=append(out,write(r,v,"full canonical target initialization"))};return out}
func write(reg,value int,role string)operation{return operation{Kind:"write",Reg:reg,Value:value,Role:role}}
func delay(count int,role string)operation{return operation{Kind:"delay",Count:count,Role:role}}
func encode(ops []operation)[]byte{out:=[]byte{};for _,op:=range ops{if op.Kind=="write"{out=append(out,1,byte(op.Reg),byte(op.Value))}else{out=append(out,2,byte(op.Count),byte(op.Count>>8))}};return append(out,0)}
