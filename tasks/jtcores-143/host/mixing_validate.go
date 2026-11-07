// Independent literal validator; imports no generator code.
package main
import("bytes";"crypto/sha256";"encoding/json";"flag";"fmt";"io";"os";"path/filepath";"reflect")
type instruction struct {
 Kind string `json:"kind"`;Reg int `json:"reg"`;Value int `json:"value"`;Count int `json:"count"`
}
type record struct {
 Name string `json:"name"`;Group string `json:"group"`;Contributors int `json:"contributors"`;TL int `json:"tl"`;Pans []int `json:"pans"`;ManualMasks []int `json:"manual_masks"`;Pilot bool `json:"pilot"`
 Init string `json:"init"`;InitHash string `json:"init_sha256"`;ModelInit string `json:"model_init"`;ModelInitHash string `json:"model_init_sha256"`;Event string `json:"event"`;EventHash string `json:"event_sha256"`
 InitOperations []instruction `json:"init_operations"`;ModelInitOperations []instruction `json:"model_init_operations"`
 Stride int `json:"stride"`;Frames int `json:"recorded_frames"`;ModelWait int `json:"model_conditioning_master_clocks"`;ModelPreheat int `json:"model_preheat_master_clocks"`;PhysicalPreheat string `json:"physical_preheat"`
}
type expectation struct { name string;n,tl int;mode string }
type audit struct { input string;records []record;wanted map[string]bool }
var expected=[]expectation{
    {"sum-n01-tl00",1,0,"both"},
    {"sum-n01-tl08",1,8,"both"},
    {"sum-n01-tl16",1,16,"both"},
    {"sum-n01-tl24",1,24,"both"},
    {"sum-n01-tl32",1,32,"both"},
    {"sum-n01-tl48",1,48,"both"},
    {"sum-n02-tl00",2,0,"both"},
    {"sum-n02-tl08",2,8,"both"},
    {"sum-n02-tl16",2,16,"both"},
    {"sum-n02-tl24",2,24,"both"},
    {"sum-n02-tl32",2,32,"both"},
    {"sum-n02-tl48",2,48,"both"},
    {"sum-n03-tl00",3,0,"both"},
    {"sum-n03-tl08",3,8,"both"},
    {"sum-n03-tl16",3,16,"both"},
    {"sum-n03-tl24",3,24,"both"},
    {"sum-n03-tl32",3,32,"both"},
    {"sum-n03-tl48",3,48,"both"},
    {"sum-n04-tl00",4,0,"both"},
    {"sum-n04-tl08",4,8,"both"},
    {"sum-n04-tl16",4,16,"both"},
    {"sum-n04-tl24",4,24,"both"},
    {"sum-n04-tl32",4,32,"both"},
    {"sum-n04-tl48",4,48,"both"},
    {"sum-n05-tl00",5,0,"both"},
    {"sum-n05-tl08",5,8,"both"},
    {"sum-n05-tl16",5,16,"both"},
    {"sum-n05-tl24",5,24,"both"},
    {"sum-n05-tl32",5,32,"both"},
    {"sum-n05-tl48",5,48,"both"},
    {"sum-n08-tl00",8,0,"both"},
    {"sum-n08-tl08",8,8,"both"},
    {"sum-n08-tl16",8,16,"both"},
    {"sum-n08-tl24",8,24,"both"},
    {"sum-n08-tl32",8,32,"both"},
    {"sum-n08-tl48",8,48,"both"},
    {"sum-n16-tl00",16,0,"both"},
    {"sum-n16-tl08",16,8,"both"},
    {"sum-n16-tl16",16,16,"both"},
    {"sum-n16-tl24",16,24,"both"},
    {"sum-n16-tl32",16,32,"both"},
    {"sum-n16-tl48",16,48,"both"},
    {"sum-n32-tl00",32,0,"both"},
    {"sum-n32-tl08",32,8,"both"},
    {"sum-n32-tl16",32,16,"both"},
    {"sum-n32-tl24",32,24,"both"},
    {"sum-n32-tl32",32,32,"both"},
    {"sum-n32-tl48",32,48,"both"},
    {"pan-n04-tl32-p00",4,32,"quiet"},
    {"pan-n04-tl32-p40",4,32,"left"},
    {"pan-n04-tl32-p80",4,32,"right"},
    {"pan-n08-tl32-p00",8,32,"quiet"},
    {"pan-n08-tl32-p40",8,32,"left"},
    {"pan-n08-tl32-p80",8,32,"right"},
    {"pan-n32-tl32-p00",32,32,"quiet"},
    {"pan-n32-tl32-p40",32,32,"left"},
    {"pan-n32-tl32-p80",32,32,"right"},
    {"split-tl00-normal",32,0,"normal"},
    {"split-tl00-reversed",32,0,"reversed"},
    {"split-tl24-normal",32,24,"normal"},
    {"split-tl24-reversed",32,24,"reversed"},
    {"split-tl32-normal",32,32,"normal"},
    {"split-tl32-reversed",32,32,"reversed"},
}
// Literal primary-register image; only approved pans/selected TLs vary.
var baseline=[]byte{
 0xc7,0xc7,0xc7,0xc7,0xc7,0xc7,0xc7,0xc7,0x4a,0x4a,0x4a,0x4a,0x4a,0x4a,0x4a,0x4a,
 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,
 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,
 31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,
 31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,
 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
 15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
 15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
}
var contribution=[]struct{tl,ch,key int}{
 {96,0,8},{112,0,16},{104,0,32},{120,0,64},
 {97,1,8},{113,1,16},{105,1,32},{121,1,64},
 {98,2,8},{114,2,16},{106,2,32},{122,2,64},
 {99,3,8},{115,3,16},{107,3,32},{123,3,64},
 {100,4,8},{116,4,16},{108,4,32},{124,4,64},
 {101,5,8},{117,5,16},{109,5,32},{125,5,64},
 {102,6,8},{118,6,16},{110,6,32},{126,6,64},
 {103,7,8},{119,7,16},{111,7,32},{127,7,64},
}
var pilot_names=map[string]bool{
 "sum-n01-tl00":true,"sum-n04-tl00":true,"sum-n05-tl00":true,
 "sum-n08-tl00":true,"sum-n32-tl00":true,"sum-n32-tl32":true,
 "pan-n32-tl32-p40":true,"pan-n32-tl32-p00":true,"split-tl32-normal":true,
}
func main(){
 var job audit
 flag.StringVar(&job.input,"input","","generated directory");flag.Parse()
 e:=job.run();if e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}
}
func(job *audit)run()error{
 if job.input==""||flag.NArg()!=0{return fmt.Errorf("use -input GENERATED_DIRECTORY")}
 job.wanted=map[string]bool{"cases.json":true,"pilot.json":true,"event.bin":true,"cleanup.bin":true}
 e:=job.read_json("cases.json",&job.records);if e!=nil{return e}
 if len(job.records)!=63||len(expected)!=63||len(baseline)!=224{return fmt.Errorf("literal matrix size mismatch")}
 selected:=[]record{}
 for i,want:=range expected{
  got:=job.records[i];e=job.check_record(got,want);if e!=nil{return fmt.Errorf("%s: %w",want.name,e)}
  if got.Pilot{selected=append(selected,got)}
 }
 var pilot []record
 e=job.read_json("pilot.json",&pilot);if e!=nil{return e}
 if len(pilot)!=9||!reflect.DeepEqual(pilot,selected){return fmt.Errorf("pilot list/order/content mismatch")}
 e=job.check_bytes("event.bin",[]byte{0},"");if e!=nil{return e}
 e=job.check_program("cleanup.bin",cleanup_expected(),"");if e!=nil{return e}
 entries,e:=os.ReadDir(job.input);if e!=nil{return e}
 if len(entries)!=130||len(job.wanted)!=130{return fmt.Errorf("directory file count mismatch")}
 for _,item:=range entries{if !job.wanted[item.Name()]||item.Type()&os.ModeSymlink!=0||!item.Type().IsRegular(){return fmt.Errorf("unexpected/nonregular entry %s",item.Name())}}
 return json.NewEncoder(os.Stdout).Encode(map[string]interface{}{"profiles":63,"pilot_profiles":9,"exact_files":130,"literal_validator":"pass","executed_chip_coverage":false})
}
func(job *audit)check_record(got record,want expectation)error{
 group:="sum";if want.mode=="quiet"||want.mode=="left"||want.mode=="right"{group="pan"};if want.mode=="normal"||want.mode=="reversed"{group="split"}
 if got.Name!=want.name||got.Contributors!=want.n||got.TL!=want.tl||got.Group!=group||got.Pilot!=pilot_names[want.name]{return fmt.Errorf("profile metadata mismatch")}
 if got.InitHash==""||got.ModelInitHash==""||got.EventHash==""{return fmt.Errorf("missing required digest")}
 pans:=[]int{192,192,192,192,192,192,192,192}
 switch want.mode{
 case "quiet":pans=[]int{0,0,0,0,0,0,0,0}
 case "left":pans=[]int{64,64,64,64,64,64,64,64}
 case "right":pans=[]int{128,128,128,128,128,128,128,128}
 case "normal":pans=[]int{64,64,64,64,128,128,128,128}
 case "reversed":pans=[]int{128,128,128,128,64,64,64,64}
 }
 image:=append([]byte(nil),baseline...);keys:=[]int{0,0,0,0,0,0,0,0}
 for ch,pan:=range pans{image[ch]=byte(pan+7)}
 for _,op:=range contribution[:want.n]{image[op.tl-32]=byte(want.tl);keys[op.ch]+=op.key}
 if !reflect.DeepEqual(got.Pans,pans)||!reflect.DeepEqual(got.ManualMasks,keys){return fmt.Errorf("pan/key mapping mismatch")}
 ops:=[]instruction{
  {"write",20,48,0},{"write",15,0,0},{"write",1,0,0},
  {"write",16,0,0},{"write",17,0,0},{"write",18,0,0},
  {"write",24,0,0},{"write",25,0,0},{"write",25,128,0},{"write",27,0,0},
  {"write",8,0,0},{"write",8,1,0},{"write",8,2,0},{"write",8,3,0},
  {"write",8,4,0},{"write",8,5,0},{"write",8,6,0},{"write",8,7,0},
 }
 for i,v:=range image{ops=append(ops,instruction{"write",i+32,int(v),0})}
 for ch,key:=range keys{ops=append(ops,instruction{"write",8,key+ch,0})}
 model:=cleanup_expected();model=append(model,instruction{"delay",0,0,55938});model=append(model,ops...);model=append(model,instruction{"delay",0,0,8192})
 if !reflect.DeepEqual(got.InitOperations,ops)||!reflect.DeepEqual(got.ModelInitOperations,model){return fmt.Errorf("operation metadata mismatch")}
 if got.Stride!=1||got.Frames!=16384||got.ModelWait!=1790016||got.ModelPreheat!=262144||got.PhysicalPreheat!="unqualified: root owns physical wait; target INIT has no delay opcode"{return fmt.Errorf("conditioning/geometry metadata mismatch")}
 if got.Init!=want.name+"-init.bin"||got.ModelInit!=want.name+"-model-init.bin"||got.Event!="event.bin"{return fmt.Errorf("noncanonical path")}
 e:=job.check_program(got.Init,ops,got.InitHash);if e!=nil{return e}
 e=job.check_program(got.ModelInit,model,got.ModelInitHash);if e!=nil{return e}
 return job.check_bytes(got.Event,[]byte{0},got.EventHash)
}
func(job *audit)read_json(name string,value interface{})error{
 raw,e:=job.read_file(name,16*1024*1024);if e!=nil{return e}
 token_reader:=json.NewDecoder(bytes.NewReader(raw));e=json_value(token_reader);if e!=nil{return e}
 if _,e=token_reader.Token();e!=io.EOF{return fmt.Errorf("trailing JSON tokens")}
 dec:=json.NewDecoder(bytes.NewReader(raw));dec.DisallowUnknownFields()
 e=dec.Decode(value);if e!=nil{return e}
 var trailing interface{}
 if dec.Decode(&trailing)!=io.EOF{return fmt.Errorf("trailing JSON")}
 return nil
}
func json_value(reader *json.Decoder)error{
 token,e:=reader.Token();if e!=nil{return e}
 delimiter,ok:=token.(json.Delim);if !ok{return nil}
 switch delimiter{
 case '{':
  seen:=map[string]bool{}
  for reader.More(){key,e:=reader.Token();if e!=nil{return e};text,ok:=key.(string);if !ok||seen[text]{return fmt.Errorf("duplicate/invalid JSON object key")};seen[text]=true;e=json_value(reader);if e!=nil{return e}}
  end,e:=reader.Token();if e!=nil||end!=json.Delim('}'){return fmt.Errorf("invalid JSON object end")}
 case '[':
  for reader.More(){e=json_value(reader);if e!=nil{return e}}
  end,e:=reader.Token();if e!=nil||end!=json.Delim(']'){return fmt.Errorf("invalid JSON array end")}
 default:return fmt.Errorf("invalid JSON delimiter")
 }
 return nil
}
func(job *audit)check_program(name string,want []instruction,digest string)error{
 data,e:=job.read_file(name,8192);if e!=nil{return e}
 if digest!=""&&digest!=fmt.Sprintf("%x",sha256.Sum256(data)){return fmt.Errorf("hash mismatch %s",name)}
 got:=[]instruction{};finished:=false
 for pos:=0;pos<len(data);{
  opcode:=data[pos];pos++
  if opcode==0{if pos!=len(data){return fmt.Errorf("trailing bytecode")};finished=true;break}
  if pos+2>len(data){return fmt.Errorf("truncated bytecode")}
  a,b:=int(data[pos]),int(data[pos+1]);pos+=2
  switch opcode{
  case 1:got=append(got,instruction{"write",a,b,0})
  case 2:if a+256*b==0{return fmt.Errorf("zero delay")};got=append(got,instruction{"delay",0,0,a+256*b})
  default:return fmt.Errorf("unknown opcode")
  }
 }
 if !finished||!reflect.DeepEqual(got,want){return fmt.Errorf("exact bytecode order/content mismatch %s",name)}
 return nil
}
func(job *audit)check_bytes(name string,want []byte,digest string)error{
 got,e:=job.read_file(name,8192);if e!=nil{return e}
 if !bytes.Equal(got,want)||(digest!=""&&digest!=fmt.Sprintf("%x",sha256.Sum256(got))){return fmt.Errorf("exact bytes/hash mismatch %s",name)}
 return nil
}
func(job *audit)read_file(name string,limit int64)([]byte,error){
 if filepath.Base(name)!=name||name=="."||name==".."{return nil,fmt.Errorf("unsafe relative path")}
 job.wanted[name]=true;path:=filepath.Join(job.input,name);st,e:=os.Lstat(path);if e!=nil{return nil,e}
 if !st.Mode().IsRegular()||st.Size()>limit{return nil,fmt.Errorf("invalid artifact size/type")}
 return os.ReadFile(path)
}
func cleanup_expected()[]instruction{
 out:=[]instruction{{"write",20,48,0},{"write",15,0,0}}
 for _,reg:=range []int{224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255}{out=append(out,instruction{"write",reg,15,0})}
 return append(out,instruction{"write",8,0,0},instruction{"write",8,1,0},instruction{"write",8,2,0},instruction{"write",8,3,0},instruction{"write",8,4,0},instruction{"write",8,5,0},instruction{"write",8,6,0},instruction{"write",8,7,0})
}

