// Convert validated historical CSM fixtures to short EVENT programs; no hardware I/O.
package main

import (
 "bytes"
 "crypto/sha256"
 "encoding/json"
 "flag"
 "fmt"
 "os"
 "path/filepath"
 "strings"
)

type short_operation struct {
 Kind string `json:"kind"`
 Reg int `json:"reg,omitempty"`
 Value int `json:"value"`
 Count int `json:"delay_count,omitempty"`
}
type short_fixture struct {
 fields map[string]json.RawMessage
 name string
 event []byte
 event_ops []json.RawMessage
}
type short_job struct {
 input string
 output string
 names string
 selected []short_fixture
}

func main() {
 var job short_job
 flag.StringVar(&job.input,"input","","original CSM cases.json; relative paths use current directory")
 flag.StringVar(&job.output,"output","","fresh output directory for short EVENTs and cases.json")
 flag.StringVar(&job.names,"names","","optional exact comma-separated names; catalog order is preserved")
 flag.Parse()
 if flag.NArg()!=0 {fmt.Fprintln(os.Stderr,"unexpected positional arguments");os.Exit(1)}
 e:=job.run();if e!=nil {fmt.Fprintln(os.Stderr,e);os.Exit(1)}
}
func (job *short_job) run() error {
 if job.input=="" || job.output=="" {return fmt.Errorf("use -input CASES.json -output NEW_DIRECTORY [-names NAME,...]")}
 e:=job.prepare();if e!=nil {return e}
 return job.write()
}
func (job *short_job) prepare() error {
 raw,e:=os.ReadFile(job.input);if e!=nil {return e}
 var records []map[string]json.RawMessage
 e=json.Unmarshal(raw,&records);if e!=nil {return e}
 if len(records)==0 {return fmt.Errorf("empty fixture catalog")}
 requested:=map[string]bool{}
 if job.names!="" {
  for _,name:=range strings.Split(job.names,",") {
   name=strings.TrimSpace(name)
   if name=="" || requested[name] {return fmt.Errorf("empty or duplicate selected name")}
   requested[name]=true
  }
 }
 found:=map[string]bool{}
 job.selected=nil
 for _,fields:=range records {
  fixture:=short_fixture{fields:fields}
  e=fixture.validate();if e!=nil {return e}
  if found[fixture.name] {return fmt.Errorf("duplicate fixture %q",fixture.name)}
  found[fixture.name]=true
  if job.names=="" || requested[fixture.name] {job.selected=append(job.selected,fixture)}
 }
 for name:=range requested {if !found[name] {return fmt.Errorf("unknown fixture %q",name)}}
 return nil
}
func (fixture *short_fixture) validate() error {
 if fixture.fields==nil {return fmt.Errorf("fixture must be an object")}
 name,e:=short_string(fixture.fields,"name");if e!=nil {return e}
 if name=="." || name==".." || strings.IndexFunc(name,func(r rune)bool{return !(r>='a'&&r<='z'||r>='A'&&r<='Z'||r>='0'&&r<='9'||r=='-'||r=='_'||r=='.')})>=0 {return fmt.Errorf("unsafe fixture name %q",name)}
 fixture.name=name
 for _,prefix:=range []string{"init","model_init","event"} {
  path,e:=short_string(fixture.fields,prefix);if e!=nil {return e}
  expected,e:=short_string(fixture.fields,prefix+"_sha256");if e!=nil {return e}
  raw,e:=os.ReadFile(path);if e!=nil {return e}
  actual:=fmt.Sprintf("%x",sha256.Sum256(raw));if expected!=actual {return fmt.Errorf("%s %s hash differs",name,prefix)}
  var operations []short_operation
  e=json.Unmarshal(fixture.fields[prefix+"_operations"],&operations);if e!=nil {return e}
  encoded,e:=encode_short_operations(operations);if e!=nil {return e}
  if !bytes.Equal(encoded,raw) {return fmt.Errorf("%s %s bytecode differs from operations",name,prefix)}
  if prefix!="event" {
   for _,op:=range operations {if op.Kind=="status" {return fmt.Errorf("status in INIT")}}
   continue
  }
  if len(operations)!=4 || operations[0].Kind!="delay" || operations[1].Kind!="write" || operations[2].Kind!="delay" || operations[2].Count!=3072 || operations[3].Kind!="status" {return fmt.Errorf("%s unexpected historical EVENT shape",name)}
  if len(raw)!=11 || !bytes.Equal(raw[len(raw)-5:],[]byte{2,0,12,3,0}) {return fmt.Errorf("%s invalid EVENT suffix",name)}
  fixture.event=append(append([]byte{},raw[:len(raw)-5]...),0)
  e=json.Unmarshal(fixture.fields["event_operations"],&fixture.event_ops);if e!=nil {return e}
 }
 return nil
}
func short_string(fields map[string]json.RawMessage,key string) (string,error) {
 var value string
 e:=json.Unmarshal(fields[key],&value);if e!=nil {return "",fmt.Errorf("invalid %s: %w",key,e)}
 if value=="" {return "",fmt.Errorf("empty %s",key)}
 return value,nil
}
func encode_short_operations(operations []short_operation) ([]byte,error) {
 if len(operations)==0 {return nil,fmt.Errorf("empty operations")}
 var raw []byte
 for _,op:=range operations {
  switch op.Kind {
  case "write":
   if op.Reg<0 || op.Reg>255 || op.Value<0 || op.Value>255 {return nil,fmt.Errorf("write out of range")}
   raw=append(raw,1,byte(op.Reg),byte(op.Value))
  case "delay":
   if op.Count<0 || op.Count>65535 {return nil,fmt.Errorf("delay out of range")}
   raw=append(raw,2,byte(op.Count),byte(op.Count>>8))
  case "status":raw=append(raw,3)
  default:return nil,fmt.Errorf("unknown operation %q",op.Kind)
  }
 }
 raw=append(raw,0)
 if len(raw)>8192 {return nil,fmt.Errorf("program exceeds monitor capacity")}
 return raw,nil
}
func (job *short_job) write() error {
 e:=os.Mkdir(job.output,0755);if e!=nil {return e}
 records:=make([]map[string]json.RawMessage,0,len(job.selected))
 for _,fixture:=range job.selected {
  fields:=make(map[string]json.RawMessage,len(fixture.fields)+5)
  for key,value:=range fixture.fields {fields[key]=value}
  fields["original_event"]=fields["event"]
  fields["original_event_sha256"]=fields["event_sha256"]
  fields["original_event_operations"]=fields["event_operations"]
  path:=filepath.Join(job.output,fixture.name+"-event.bin")
  e=write_short_file(path,fixture.event);if e!=nil {return e}
  fields["event"],e=json.Marshal(path);if e!=nil {return e}
  fields["event_sha256"],e=json.Marshal(fmt.Sprintf("%x",sha256.Sum256(fixture.event)));if e!=nil {return e}
  fields["event_operations"],e=json.Marshal(fixture.event_ops[:2]);if e!=nil {return e}
  fields["event_ends_immediately_after_last_write"]=json.RawMessage("true")
  fields["status_query_is_separate_after_capture"]=json.RawMessage("true")
  records=append(records,fields)
 }
 raw,e:=json.MarshalIndent(records,"","  ");if e!=nil {return e}
 return write_short_file(filepath.Join(job.output,"cases.json"),append(raw,'\n'))
}
func write_short_file(path string,data []byte) error {
 file,e:=os.OpenFile(path,os.O_WRONLY|os.O_CREATE|os.O_EXCL,0600);if e!=nil {return e}
 _,e=file.Write(data);if e!=nil {file.Close();return e}
 return file.Close()
}
