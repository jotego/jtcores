package main

import (
 "bytes"
 "crypto/sha256"
 "encoding/json"
 "os"
 "path/filepath"
 "reflect"
 "testing"
 "fmt"
)

func TestShortConversionPreservesPayloadAndMetadata(t *testing.T) {
 input,records:=make_short_catalog(t,[]string{"first","second"})
 output:=filepath.Join(t.TempDir(),"converted")
 job:=short_job{input:input,output:output,names:"second,first"}
 e:=job.run();if e!=nil {t.Fatal(e)}
 var got []map[string]json.RawMessage
 raw,e:=os.ReadFile(filepath.Join(output,"cases.json"));if e!=nil {t.Fatal(e)}
 e=json.Unmarshal(raw,&got);if e!=nil {t.Fatal(e)}
 if len(got)!=2 {t.Fatal("wrong selected count")}
 for i,name:=range []string{"first","second"} {
  actual,e:=os.ReadFile(filepath.Join(output,name+"-event.bin"));if e!=nil {t.Fatal(e)}
  if !bytes.Equal(actual,[]byte{2,0,8,1,20,129,0}) {t.Fatalf("short bytes: %x",actual)}
  var got_name string;json.Unmarshal(got[i]["name"],&got_name);if got_name!=name {t.Fatal("selection changed catalog order")}
  expected:=records[i]
  for key,value:=range expected {
   if key=="event" || key=="event_sha256" || key=="event_operations" {continue}
   encoded,e:=json.Marshal(value);if e!=nil {t.Fatal(e)}
   if !same_short_json(got[i][key],encoded) {t.Fatalf("metadata lost: %s",key)}
  }
  for _,key:=range []string{"event","event_sha256","event_operations"} {
   encoded,e:=json.Marshal(expected[key]);if e!=nil {t.Fatal(e)}
   if !same_short_json(got[i]["original_"+key],encoded) {t.Fatalf("original provenance lost: %s",key)}
  }
  if string(got[i]["event_ends_immediately_after_last_write"])!="true" || string(got[i]["status_query_is_separate_after_capture"])!="true" {t.Fatal("status semantics lost")}
  var path,hash string;json.Unmarshal(got[i]["event"],&path);json.Unmarshal(got[i]["event_sha256"],&hash)
  if path!=filepath.Join(output,name+"-event.bin") || hash!=fmt.Sprintf("%x",sha256.Sum256(actual)) {t.Fatal("fresh path/hash differs")}
 }
 subset:=short_job{input:input,output:filepath.Join(t.TempDir(),"subset"),names:"second"}
 e=subset.run();if e!=nil {t.Fatal(e)}
 if len(subset.selected)!=1 || subset.selected[0].name!="second" {t.Fatal("subset selection differs")}
 if _,e=os.Stat(filepath.Join(subset.output,"first-event.bin"));!os.IsNotExist(e) {t.Fatal("unselected payload emitted")}
}
func TestShortRejectsMalformedInputBeforeOutput(t *testing.T) {
 tests:=[]struct{name string;change func([]map[string]interface{});selection string;invalid_json bool}{
  {name:"unknown-selection",selection:"missing"},
  {name:"duplicate-selection",selection:"one,one"},
  {name:"empty-selection",selection:"one,"},
  {name:"unsafe-name",change:func(r []map[string]interface{}){r[0]["name"]="../escape"}},
  {name:"missing-name",change:func(r []map[string]interface{}){delete(r[0],"name")}},
  {name:"missing-ops",change:func(r []map[string]interface{}){delete(r[0],"event_operations")}},
  {name:"hash-mismatch",change:func(r []map[string]interface{}){r[0]["event_sha256"]="bad"}},
  {name:"init-hash-mismatch",change:func(r []map[string]interface{}){r[0]["init_sha256"]="bad"}},
  {name:"model-hash-mismatch",change:func(r []map[string]interface{}){r[0]["model_init_sha256"]="bad"}},
  {name:"truncated-write",change:func(r []map[string]interface{}){replace_short_payload(r[0],"event",[]byte{2,0,8,1,20})}},
  {name:"unknown-opcode",change:func(r []map[string]interface{}){replace_short_payload(r[0],"event",[]byte{4,0})}},
  {name:"missing-end",change:func(r []map[string]interface{}){replace_short_payload(r[0],"event",[]byte{2,0,8,1,20,129,2,0,12,3})}},
  {name:"early-end",change:func(r []map[string]interface{}){replace_short_payload(r[0],"event",[]byte{0,2,0,8,1,20,129,2,0,12,3,0})}},
  {name:"status-in-init",change:func(r []map[string]interface{}){r[0]["init_operations"]=[]map[string]interface{}{{"kind":"status","value":0}};replace_short_payload(r[0],"init",[]byte{3,0})}},
  {name:"wrong-postdelay",change:func(r []map[string]interface{}){r[0]["event_operations"].([]map[string]interface{})[2]["delay_count"]=3071;replace_short_payload(r[0],"event",[]byte{2,0,8,1,20,129,2,255,11,3,0})}},
  {name:"wrong-last-write",change:func(r []map[string]interface{}){r[0]["event_operations"].([]map[string]interface{})[1]["value"]=130}},
  {name:"out-of-range-register",change:func(r []map[string]interface{}){r[0]["event_operations"].([]map[string]interface{})[1]["reg"]=256}},
  {name:"out-of-range-value",change:func(r []map[string]interface{}){r[0]["event_operations"].([]map[string]interface{})[1]["value"]=-1}},
  {name:"out-of-range-delay",change:func(r []map[string]interface{}){r[0]["event_operations"].([]map[string]interface{})[0]["delay_count"]=65536}},
  {name:"unknown-kind",change:func(r []map[string]interface{}){r[0]["event_operations"].([]map[string]interface{})[1]["kind"]="unknown"}},
  {name:"null-record",change:func(r []map[string]interface{}){r[0]=nil}},
  {name:"bad-json",invalid_json:true},
 }
 for _,tt:=range tests {
  t.Run(tt.name,func(t *testing.T){
   input,records:=make_short_catalog(t,[]string{"one"})
   if tt.change!=nil {tt.change(records)}
   data,e:=json.Marshal(records);if e!=nil {t.Fatal(e)}
   if tt.invalid_json {data=[]byte("[")}
   e=os.WriteFile(input,data,0600);if e!=nil {t.Fatal(e)}
   output:=filepath.Join(t.TempDir(),"must-not-exist")
   job:=short_job{input:input,output:output,names:tt.selection}
   if job.run()==nil {t.Fatal("malformed input accepted")}
   if _,e=os.Stat(output);!os.IsNotExist(e) {t.Fatal("output created before validation completed")}
  })
 }
 input,records:=make_short_catalog(t,[]string{"one","two"});records[1]["name"]="one";data,_:=json.Marshal(records);os.WriteFile(input,data,0600)
 job:=short_job{input:input,output:filepath.Join(t.TempDir(),"duplicates")};if job.run()==nil {t.Fatal("duplicate fixture accepted")}
 input=filepath.Join(t.TempDir(),"empty.json");os.WriteFile(input,[]byte("[]"),0600);job=short_job{input:input,output:filepath.Join(t.TempDir(),"empty")};if job.run()==nil {t.Fatal("empty catalog accepted")}
}
func TestShortExclusiveOutputs(t *testing.T) {
 input,_:=make_short_catalog(t,[]string{"one"});output:=t.TempDir();sentinel:=filepath.Join(output,"keep");os.WriteFile(sentinel,[]byte("unchanged"),0600)
 job:=short_job{input:input,output:output};if job.run()==nil {t.Fatal("existing output directory accepted")}
 data,e:=os.ReadFile(sentinel);if e!=nil || string(data)!="unchanged" {t.Fatal("existing output changed")}
 if write_short_file(sentinel,[]byte("overwrite"))==nil {t.Fatal("existing file accepted")}
 data,_=os.ReadFile(sentinel);if string(data)!="unchanged" {t.Fatal("file overwritten")}
}
func make_short_catalog(t *testing.T,names []string) (string,[]map[string]interface{}) {
 t.Helper();root:=t.TempDir();records:=[]map[string]interface{}{}
 for _,name:=range names {
  fields:=map[string]interface{}{"name":name,"attack_rate":31,"extra_metadata":map[string]interface{}{"kept":[]int{3,7},"note":"preserve unknown metadata"}}
  for _,prefix:=range []string{"init","model_init","event"} {
   raw:=[]byte{1,20,48,0};ops:=[]map[string]interface{}{{"kind":"write","reg":20,"value":48,"role":"stop"}}
   if prefix=="event" {raw=[]byte{2,0,8,1,20,129,2,0,12,3,0};ops=[]map[string]interface{}{{"kind":"delay","value":0,"delay_count":2048,"role":"prefix"},{"kind":"write","reg":20,"value":129,"role":"intervention"},{"kind":"delay","value":0,"delay_count":3072},{"kind":"status","value":0}}}
   path:=filepath.Join(root,name+"-"+prefix+".bin");e:=os.WriteFile(path,raw,0600);if e!=nil {t.Fatal(e)}
   fields[prefix]=path;fields[prefix+"_sha256"]=fmt.Sprintf("%x",sha256.Sum256(raw));fields[prefix+"_operations"]=ops
  }
  records=append(records,fields)
 }
 input:=filepath.Join(root,"cases.json");data,e:=json.Marshal(records);if e!=nil {t.Fatal(e)};e=os.WriteFile(input,data,0600);if e!=nil {t.Fatal(e)}
 return input,records
}
func replace_short_payload(fields map[string]interface{},prefix string,data []byte) {
 path:=fields[prefix].(string)
 if e:=os.WriteFile(path,data,0600);e!=nil {panic(e)}
 fields[prefix+"_sha256"]=fmt.Sprintf("%x",sha256.Sum256(data))
}
func same_short_json(a,b []byte) bool {
 var x,y interface{}
 if json.Unmarshal(a,&x)!=nil || json.Unmarshal(b,&y)!=nil {return false}
 return reflect.DeepEqual(x,y)
}
