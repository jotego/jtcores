// YM2151 algorithm and feedback measurement programs.
package main
import("crypto/sha256";"encoding/json";"flag";"fmt";"os";"path/filepath")
type operation struct{Kind string `json:"kind"`;Reg int `json:"reg,omitempty"`;Value int `json:"value"`;Count int `json:"delay_count,omitempty"`;Role string `json:"role,omitempty"`}
type fixture struct{
 Name string `json:"name"`;Group string `json:"group"`;Algorithm int `json:"algorithm"`;Feedback int `json:"feedback"`;KeyMask int `json:"key_mask"`;Pan int `json:"pan"`;TL map[string]int `json:"total_levels"`;Expected string `json:"expected_audio"`;Left string `json:"expected_left"`;Right string `json:"expected_right"`;Pilot bool `json:"pilot"`
 Init string `json:"init"`;ModelInit string `json:"model_init"`;Event string `json:"event"`;InitHash string `json:"init_sha256"`;ModelInitHash string `json:"model_init_sha256"`;EventHash string `json:"event_sha256"`;InitOps []operation `json:"init_operations"`;ModelInitOps []operation `json:"model_init_operations"`
 Stride int `json:"stride"`;Frames int `json:"recorded_frames"`;Fs float64 `json:"sample_rate_hz"`;Increment int `json:"native_increment_20bit"`;ModelWait int `json:"model_conditioning_master_clocks"`;PhysicalWait float64 `json:"proposed_physical_wait_after_reply_seconds"`;Preheat int `json:"model_preheat_master_clocks"`;Limits []string `json:"limits"`
}
type generation struct{output string;cases []fixture}
var operators=[]struct{name string;off,mask,tl int}{{"M1",0,8,32},{"M2",8,32,48},{"C1",16,16,40},{"C2",24,64,24}}
func main(){var job generation;flag.StringVar(&job.output,"output","","fresh artifact directory");flag.Parse();e:=job.run();if e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}}
func(job *generation)run()error{
 if job.output==""||flag.NArg()!=0{return fmt.Errorf("use -output NEW_DIRECTORY")};e:=os.Mkdir(job.output,0755);if e!=nil{return e}
 for alg:=0;alg<8;alg++{for fb:=0;fb<8;fb++{c:=job.blank(fmt.Sprintf("all-alg%d-fb%d",alg,fb),"tagged_all",alg,fb,120,192);c.Pilot=fb==0;e=job.add(c);if e!=nil{return e}}}
 for alg:=0;alg<8;alg++{for _,op:=range operators{c:=job.blank(fmt.Sprintf("single-%s-alg%d-fb0",op.name,alg),"single",alg,0,op.mask,192);c.Pilot=alg==7&&op.mask==8;e=job.add(c);if e!=nil{return e}}}
 for fb:=1;fb<8;fb++{for _,op:=range operators{c:=job.blank(fmt.Sprintf("single-%s-alg7-fb%d",op.name,fb),"feedback_isolation",7,fb,op.mask,192);c.Pilot=op.mask==8;e=job.add(c);if e!=nil{return e}}}
 for _,alg:=range []int{0,4,7}{for _,pan:=range []int{0,64,128}{c:=job.blank(fmt.Sprintf("pan-%02x-alg%d-fb0",pan,alg),"static_stereo",alg,0,120,pan);e=job.add(c);if e!=nil{return e}}}
 for alg:=0;alg<8;alg++{for logical:=0;logical<16;logical++{mask,count:=0,0;for i,op:=range operators{if logical&(1<<i)!=0{mask|=op.mask;count++}};if count==1||count==4{continue};c:=job.blank(fmt.Sprintf("subset-%02x-alg%d-fb0",mask,alg),"remaining_subsets",alg,0,mask,192);e=job.add(c);if e!=nil{return e}}}
 for fb:=0;fb<8;fb++{c:=job.blank(fmt.Sprintf("fulllevel-M1-alg7-fb%d",fb),"fulllevel_feedback",7,fb,8,192);c.TL["M1"]=0;e=job.add(c);if e!=nil{return e}}
 if len(job.cases)!=229{return fmt.Errorf("internal profile count")};e=job.write_json("cases.json",job.cases);if e!=nil{return e};pilot:=[]fixture{};for _,c:=range job.cases{if c.Pilot{pilot=append(pilot,c)}};if len(pilot)!=16{return fmt.Errorf("pilot count")};e=job.write_json("pilot.json",pilot);if e!=nil{return e};return os.WriteFile(filepath.Join(job.output,"cleanup.bin"),encode(cleanup()),0600)
}
func(job *generation)blank(name,group string,alg,fb,key,pan int)fixture{
 carriers:=[]int{64,64,64,64,80,112,112,120};expected:="nonblank_static_output_periodicity_unqualified";if key&carriers[alg]==0{expected="quiet_offpath"};if fb>0&&key&8!=0&&expected!="quiet_offpath"{expected="nonblank_feedback_periodicity_unqualified"};left,right:=expected,expected;if pan&64==0{left="quiet_pan_off"};if pan&128==0{right="quiet_pan_off"}
 return fixture{Name:name,Group:group,Algorithm:alg,Feedback:fb,KeyMask:key,Pan:pan,TL:map[string]int{"M1":32,"M2":48,"C1":40,"C2":24},Expected:expected,Left:left,Right:right,Stride:1,Frames:16384,Fs:55937.5,Increment:4124,ModelWait:1790016,PhysicalWait:.5,Preheat:262144,Limits:[]string{"Physical conditioning wait must first be independently qualified; not inferred from model","No noise/LFO/CSM/other channel; everyclock model with explicit finite cleanup wait","High feedback may be nonperiodic; no forced phase/frequency/gain fit","One named M1,C1,M2,C2 mapping; key-mask order differs from register-group order"}}
}
func(job *generation)add(c fixture)error{
 init:=initialize();init=append(init,write(32,c.Pan|c.Feedback<<3|c.Algorithm,"channel pan/FL/CON"),write(40,74,"KC4A"))
 for _,op:=range operators{init=append(init,write(64+op.off,0,"DT1zero MUL0"),write(96+op.off,c.TL[op.name],"asymmetric TL"),write(128+op.off,31,"AR31 KS0"),write(224+op.off,15,"D1L0 RR15"))}
 init=append(init,write(8,c.KeyMask,"one simultaneous key mask"),delay(8192,"preheat; model32master clocks/count"));model:=cleanup();model=append(model,delay(55938,"model finite conditioning1790016master clocks"));model=append(model,init...)
 c.InitOps=init;c.ModelInitOps=model;c.Init=filepath.Join(job.output,c.Name+"-init.bin");c.ModelInit=filepath.Join(job.output,c.Name+"-model-init.bin");c.Event=filepath.Join(job.output,c.Name+"-event.bin");a,b,e:=encode(init),encode(model),[]byte{0};c.InitHash=hash(a);c.ModelInitHash=hash(b);c.EventHash=hash(e)
 err:=os.WriteFile(c.Init,a,0600);if err!=nil{return err};err=os.WriteFile(c.ModelInit,b,0600);if err!=nil{return err};err=os.WriteFile(c.Event,e,0600);if err!=nil{return err};job.cases=append(job.cases,c);return nil
}
func(job *generation)write_json(name string,value interface{})error{b,e:=json.MarshalIndent(value,"","  ");if e!=nil{return e};return os.WriteFile(filepath.Join(job.output,name),append(b,'\n'),0600)}
func cleanup()[]operation{out:=[]operation{write(15,0,"NEoff BEFORE RR/keyoff")};for r:=224;r<256;r++{out=append(out,write(r,15,"ALL RR15 BEFORE all8keyoffs"))};for ch:=0;ch<8;ch++{out=append(out,write(8,ch,"keyoff afterRR15"))};return out}
func initialize()[]operation{out:=[]operation{};for ch:=0;ch<8;ch++{out=append(out,write(8,ch,"all keyoff after conditioning"))};for _,w:=range [][2]int{{1,0},{15,0},{20,48},{24,0},{25,0},{25,128},{27,0}}{out=append(out,write(w[0],w[1],"public globals and both depth selectors"))};for r:=32;r<256;r++{v:=0;if r>=96&&r<128{v=127};out=append(out,write(r,v,"complete target register state"))};return out}
func write(reg,value int,role string)operation{return operation{Kind:"write",Reg:reg,Value:value,Role:role}}
func delay(count int,role string)operation{return operation{Kind:"delay",Count:count,Role:role}}
func encode(ops []operation)[]byte{out:=[]byte{};for _,op:=range ops{if op.Kind=="write"{out=append(out,1,byte(op.Reg),byte(op.Value))}else{out=append(out,2,byte(op.Count),byte(op.Count>>8))}};return append(out,0)}
func hash(v []byte)string{return fmt.Sprintf("%x",sha256.Sum256(v))}
