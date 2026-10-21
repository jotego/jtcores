// Fixed complements catalog. Artifact-only; no hardware or model execution.
package main

import("bytes";"crypto/sha256";_ "embed";"encoding/hex";"encoding/json";"flag";"fmt";"os";"path/filepath";"strconv")

//go:embed testdata/audit-complements-method.json
var literal_spec []byte
const literal_spec_hash="14b9c9c1b7635241a508002554bbb02a1f6c243869afb4b159294253d1e612c2"
const cleanup_hash="024e6a9a81173c068190eb78346e3e6c16d893da0eb19674209af9c51a5359ea"
type complement_profile struct {
 Name string `json:"name"`; Batch string `json:"batch"`; Overrides map[string]string `json:"register_image_overrides_hex"`; Globals map[string]string `json:"global_overrides_hex"`; Noise string `json:"initial_NE_NFRQ_hex"`; Keys [][]string `json:"profile_keyons_hex"`; EventHex string `json:"event_hex"`; Minimum int `json:"minimum_actual_post_guard_samples"`
}
type complement_operation struct {Kind string `json:"kind"`;Reg int `json:"register,omitempty"`;Value int `json:"value,omitempty"`;Count int `json:"delay_count,omitempty"`}
type complement_fixture struct {
 Name string `json:"name"`;Batch string `json:"batch"`; Init string `json:"init"`; Event string `json:"event"`;InitHash string `json:"init_sha256"`;EventHash string `json:"event_sha256"`;InitOps []complement_operation `json:"init_operations"`;EventOps []complement_operation `json:"event_operations"`;Frames int `json:"recorded_frames"`;Words int `json:"requested_words"`;Stride int `json:"stride"`;Fs float64 `json:"nominal_recorded_sample_rate_hz"`;Minimum int `json:"minimum_actual_post_guard_samples"`;Prefix int `json:"guaranteed_held_prefix_pending_timing_qualification"`;Guard int `json:"host_post_guard_recorded_samples"`;NativeIncrement int `json:"native_carrier_increment,omitempty"`;RecordedIncrement int `json:"recorded_carrier_increment,omitempty"`;Window int `json:"window,omitempty"`;Hop int `json:"hop,omitempty"`;Stage int `json:"low_stage,omitempty"`;SeparateStatus bool `json:"separate_status_after_capture"`
}
type complement_generation struct {output,spec string; fixtures []complement_fixture; files map[string][]byte}
func main(){var job complement_generation;flag.StringVar(&job.output,"output","","fresh output directory");flag.StringVar(&job.spec,"spec","","optional exact frozen specification; changed bytes are rejected");flag.Parse();if e:=job.run();e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}}
func(job *complement_generation)run()error{
 if job.output==""||flag.NArg()!=0{return fmt.Errorf("use -output NEW_DIRECTORY [-spec EXACT_FROZEN.json]")}
 data:=literal_spec;var e error;if job.spec!=""{data,e=os.ReadFile(job.spec);if e!=nil{return e}}
 profiles,e:=read_complement_spec(data);if e!=nil{return e};job.output,e=filepath.Abs(job.output);if e!=nil{return e};job.files=map[string][]byte{}
 clean:=complement_cleanup();if digest_bytes(clean)!=cleanup_hash{return fmt.Errorf("cleanup bytes changed")};job.files["cleanup.bin"]=clean;job.files["status.bin"]=[]byte{3,0}
 for _,p:=range profiles{e=job.add(p);if e!=nil{return e}}
 report:=map[string]interface{}{"state":"generated_unexecuted_fixed11_catalog","literal_spec_sha256":literal_spec_hash,"source_provenance":"source and executable hashes are pinned in the reviewed handoff","cases":job.fixtures,"capture_totals":map[string]int{"targets":33,"paired_quiets":33,"final_quiets":4,"captures":70,"separate_status":9,"generations":149,"markers":447},"future_start":nil,"future_capture_IDs":nil,"timing_qualification":"PENDING; segmented delay and75s lifecycle must qualify before acquisition","physical_post_upper_clock_hz":3590000,"cleanup_sha256":cleanup_hash}
 raw,e:=json.MarshalIndent(report,"","  ");if e!=nil{return e};job.files["cases.json"]=append(raw,'\n')
 e=os.Mkdir(job.output,0755);if e!=nil{return e};for name,value:=range job.files{e=os.WriteFile(filepath.Join(job.output,name),value,0600);if e!=nil{return e}};return nil
}
func read_complement_spec(data []byte)([]complement_profile,error){
 if digest_bytes(data)!=literal_spec_hash{return nil,fmt.Errorf("specification differs from frozen literal bytes")};var spec struct{Profiles []complement_profile `json:"profiles"`};e:=json.Unmarshal(data,&spec);if e!=nil{return nil,e};names:=[]string{"N0","N1","N2","N3","C2","C3","C4","L0","L1","L2","L3"};if len(spec.Profiles)!=len(names){return nil,fmt.Errorf("catalog length")};for i,p:=range spec.Profiles{if p.Name!=names[i]{return nil,fmt.Errorf("catalog order")}};return spec.Profiles,nil
}
func(job *complement_generation)add(p complement_profile)error{
 init,e:=make_complement_init(p);if e!=nil{return e};event,e:=hex.DecodeString(remove_hex_spaces(p.EventHex));if e!=nil{return e};a,e:=decode_complement(init);if e!=nil{return e};b,e:=decode_complement(event);if e!=nil{return e}
 if len(init)>8192||len(event)!=7&&len(event)!=19{return fmt.Errorf("program bounds")};if p.Batch=="low-lfo"{if len(b)!=6{return fmt.Errorf("low EVENT count")};total:=0;for i:=0;i<5;i++{if b[i].Kind!="delay"{return fmt.Errorf("low EVENT delay order")};total+=b[i].Count};if total!=262144{return fmt.Errorf("segmented delay total")}}
 c:=complement_fixture{Name:p.Name,Batch:p.Batch,Init:filepath.Join(job.output,p.Name+"-init.bin"),Event:filepath.Join(job.output,p.Name+"-event.bin"),InitHash:digest_bytes(init),EventHash:digest_bytes(event),InitOps:a,EventOps:b,Frames:16384,Words:32768,Stride:1,Fs:55937.5,Minimum:p.Minimum,Prefix:512,Guard:128,SeparateStatus:p.Batch=="split-csm"}
 if p.Batch=="low-lfo"{c.Frames=4096;c.Words=8192;c.Stride=1024;c.Fs=55937.5/1024;c.Prefix=128;c.NativeIncrement=162;c.RecordedIncrement=165888;c.Window=16;c.Hop=4;c.Stage=2;if p.Name=="L2"{c.Stage=1}}
 job.files[p.Name+"-init.bin"]=init;job.files[p.Name+"-event.bin"]=event;job.fixtures=append(job.fixtures,c);return nil
}
func make_complement_init(p complement_profile)([]byte,error){
 data:=[]byte{1,0x14,0x30,1,0x0f,0};for ch:=0;ch<8;ch++{data=append(data,1,8,byte(ch))}
 defaults:=map[string]string{"01":"00","10":"00","11":"00","12":"00","18":"00","19:AMD":"00","19:PMD":"80","1B":"00"}
 for _,key:=range []string{"01","10","11","12","18","19:AMD","19:PMD","1B"}{value:=defaults[key];if override,ok:=p.Globals[key];ok{value=override};reg:=key;if len(key)>2{reg=key[:2]};r,e:=hex_byte(reg);if e!=nil{return nil,e};v,e:=hex_byte(value);if e!=nil{return nil,e};data=append(data,1,r,v)}
 for reg:=32;reg<=255;reg++{value:=byte(0);if reg>=96&&reg<128{value=127};if reg>=224{value=15};if override,ok:=p.Overrides[fmt.Sprintf("%02X",reg)];ok{v,e:=hex_byte(override);if e!=nil{return nil,e};value=v};data=append(data,1,byte(reg),value)}
 ne,e:=hex_byte(p.Noise);if e!=nil{return nil,e};data=append(data,1,15,ne,1,20,0);for _,key:=range p.Keys{if len(key)!=2||key[0]!="08"{return nil,fmt.Errorf("invalid fixed key")};v,e:=hex_byte(key[1]);if e!=nil{return nil,e};data=append(data,1,8,v)};data=append(data,2,0,32,0);return data,nil
}
func complement_cleanup()[]byte{data:=[]byte{1,20,48,1,15,0};for reg:=224;reg<=255;reg++{data=append(data,1,byte(reg),15)};for ch:=0;ch<8;ch++{data=append(data,1,8,byte(ch))};return append(data,0)}
func decode_complement(data []byte)([]complement_operation,error){
 if len(data)==0||len(data)>8192{return nil,fmt.Errorf("program size")};out:=[]complement_operation{};for i:=0;i<len(data);{kind:=data[i];i++;if kind==0{if i!=len(data){return nil,fmt.Errorf("trailing bytes")};return out,nil};if kind!=1&&kind!=2||i+2>len(data){return nil,fmt.Errorf("opcode or truncated operand")};a,b:=int(data[i]),int(data[i+1]);i+=2;if kind==1{out=append(out,complement_operation{Kind:"write",Reg:a,Value:b})}else{count:=a|(b<<8);if count==0{return nil,fmt.Errorf("zero delay forbidden")};out=append(out,complement_operation{Kind:"delay",Count:count})}};return nil,fmt.Errorf("missing END")
}
func hex_byte(s string)(byte,error){if len(s)!=2{return 0,fmt.Errorf("hex byte width")};v,e:=strconv.ParseUint(s,16,8);return byte(v),e}
func remove_hex_spaces(s string)string{return string(bytes.ReplaceAll([]byte(s),[]byte(" "),nil))}
func digest_bytes(data []byte)string{return fmt.Sprintf("%x",sha256.Sum256(data))}
