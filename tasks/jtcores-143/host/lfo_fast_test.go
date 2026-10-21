package main

import (
 "bytes"
 "crypto/sha256"
 "encoding/csv"
 "encoding/json"
 "fmt"
 "os"
 "os/exec"
 "path/filepath"
 "runtime"
 "strconv"
 "strings"
 "testing"
)

func TestMain(m *testing.M) {
 if configured:=os.Getenv("JT143_LFO_FAST_REPORT_DIR");configured!="" {root,e:=filepath.Abs(configured);if e!=nil {fmt.Fprintln(os.Stderr,e);os.Exit(1)};if e=os.Setenv("JT143_LFO_FAST_REPORT_DIR",root);e!=nil {fmt.Fprintln(os.Stderr,e);os.Exit(1)};if e=os.Mkdir(root,0755);e!=nil {fmt.Fprintln(os.Stderr,e);os.Exit(1)}}
 os.Exit(m.Run())
}

type fast_promotion struct {t *testing.T;root,host,generator,scorer,generic string;commands []map[string]interface{}}

func TestOriginalFast12Promotion(t *testing.T) {
 root:=os.Getenv("JT143_LFO_FAST_REPORT_DIR");if root=="" {root=t.TempDir()}
 _,source,_,ok:=runtime.Caller(0);if !ok {t.Fatal("source path unavailable")}
 job:=fast_promotion{t:t,root:root,host:filepath.Dir(source)}
 job.build()
 job.catalog()
 job.qualification()
 job.scorer_cli()
 before:=fast_test_sha(t,filepath.Join(root,"qualification","qualification.json"))
 command:=exec.Command(os.Args[0],"-test.run","^TestOriginalFast12Promotion$")
 command.Env=append(os.Environ(),"JT143_LFO_FAST_REPORT_DIR="+root)
 output,e:=command.CombinedOutput();if e==nil {t.Fatal("existing report root accepted")}
 if fast_test_sha(t,filepath.Join(root,"qualification","qualification.json"))!=before {t.Fatal("rejected report root modified existing data")}
 job.commands=append(job.commands,map[string]interface{}{"kind":"existing-report-root-rejected-before-tests","output":string(output),"exitcode":command.ProcessState.ExitCode()})
 fast_test_report(t,filepath.Join(root,"wrapper-report.json"),map[string]interface{}{"state":"original_FAST12_payloads_grid_and_CLI_pass","generic_grid":[]int{3456,48,48,8},"payload_files":26,"generator_negatives":20,"scorer_positives":6,"scorer_negatives":24,"commands":job.commands,"no_models_or_hardware":true,"report_relocation_not_whole_byteidentity":true})
 t.Logf("FAST12 report: %s",root)
}

func (job *fast_promotion) build() {
 t:=job.t;dir:=filepath.Join(job.root,"bin");if e:=os.Mkdir(dir,0755);e!=nil {t.Fatal(e)}
 job.generator=filepath.Join(dir,"generator");job.scorer=filepath.Join(dir,"score");job.generic=filepath.Join(dir,"generic-tests")
 core:=[]string{"lfo_fast_observer.go","tone.go","sine_fit.go","lfo_fast_fine.go"}
 identities:=map[string]interface{}{}
 for _,group:=range []struct{name,output string;files []string;test bool}{{"generator",job.generator,[]string{"lfo_fast_programs.go"},false},{"score",job.scorer,append(append([]string{},core...),"lfo_fast_score.go"),false},{"generic",job.generic,append(append([]string{},core...),"lfo_fast_generic_test.go"),true}} {
  args:=[]string{"build","-trimpath","-o",group.output};if group.test {args=[]string{"test","-c","-trimpath","-o",group.output}}
  sources:=map[string]string{};for _,name:=range group.files {p:=filepath.Join(job.host,name);sources[p]=fast_test_sha(t,p);args=append(args,p)}
  job.run("go",args,nil,true)
  identities[group.name]=map[string]interface{}{"sources":sources,"executable":group.output,"executable_sha256":fast_test_sha(t,group.output)}
 }
 version:=job.run("go",[]string{"version"},nil,true)
 fast_test_report(t,filepath.Join(job.root,"build-identities.json"),map[string]interface{}{"tools":identities,"toolchain":string(version),"flags":[]string{"-trimpath"},"no_models_or_hardware":true})
}

func (job *fast_promotion) catalog() {
 t:=job.t;base:=fast_test_base();if fast_test_hash(base)!="d8f414e301521e4522739c7c845693e16dec01e4a265751f2352dbaab07e4c16" {t.Fatal("canonical base identity")}
 basepath:=filepath.Join(job.root,"tone.bin");if e:=os.WriteFile(basepath,base,0600);e!=nil {t.Fatal(e)}
 first,second:=filepath.Join(job.root,"programs-a"),filepath.Join(job.root,"programs-b")
 for _,p:=range []string{first,second} {job.run(job.generator,[]string{"-base",basepath,"-output",p},nil,true);job.check_catalog(p)}
 for name,expected:=range fast_test_payload_hashes {a,e:=os.ReadFile(filepath.Join(first,name));if e!=nil {t.Fatal(e)};b,e:=os.ReadFile(filepath.Join(second,name));if e!=nil {t.Fatal(e)};if !bytes.Equal(a,b)||fast_test_hash(a)!=expected {t.Fatal("payload byte reproduction:",name)}}
 append_write:=func(data []byte,reg,value byte)[]byte {p:=append([]byte(nil),data[:len(data)-4]...);return append(append(p,1,reg,value),data[len(data)-4:]...)}
 bad:=map[string][]byte{"empty":{},"missingEND":base[:len(base)-1],"trailing":append(append([]byte{},base...),0),"duplicateKEYON":append(append([]byte{},base[:len(base)-1]...),1,8,64,0),"secondvoiceKEYON":append_write(base,8,65),"delay":append([]byte{2,0,1},base...),"noise":append_write(base,15,128),"test":append_write(base,1,2),"modulation":append_write(base,25,64),"noncanonicalglobal":append_write(base,16,255),"secondvoiceAR":append_write(base,153,31),"secondvoicePAN":append_write(base,33,199),"duplicateclear":append_write(base,25,0),"duplicateTEST":append_write(base,1,0)}
 count:=0;for name,data:=range bad {p:=filepath.Join(job.root,"bad-"+name+".bin");if e:=os.WriteFile(p,data,0600);e!=nil {t.Fatal(e)};dest:=filepath.Join(job.root,"reject-generator-"+name);job.run(job.generator,[]string{"-base",p,"-output",dest},nil,false);fast_test_absent(t,dest);count++}
 for i,args:=range [][]string{nil,{"-base",basepath},{"-output",filepath.Join(job.root,"missing-base")},{"-base",basepath,"-output",filepath.Join(job.root,"extra"),"extra"},{"-base",basepath,"-output",filepath.Join(job.root,"unknown"),"-unknown"},{"-base",basepath,"-output",first}} {job.run(job.generator,args,nil,false);if i==2 {fast_test_absent(t,args[1])};if i==3||i==4 {fast_test_absent(t,args[3])};count++}
 if count!=20 {t.Fatal("original20 generator controls")}
 job.check_catalog(first)
 fast_test_report(t,filepath.Join(job.root,"catalog-report.json"),map[string]interface{}{"state":"13pairs26payloads_exact_literal_manifest_path_only_rebase","payload_sha256":fast_test_payload_hashes,"base_sha256":fast_test_hash(base),"negative_count":count})
}

func (job *fast_promotion) check_catalog(root string) {
 t:=job.t;entries,e:=os.ReadDir(root);if e!=nil||len(entries)!=27 {t.Fatal("exact27 catalog files",e)}
 raw,e:=os.ReadFile(filepath.Join(root,"cases.json"));if e!=nil {t.Fatal(e)}
 var rows []map[string]interface{};d:=json.NewDecoder(bytes.NewReader(raw));d.UseNumber();if e=d.Decode(&rows);e!=nil {t.Fatal(e)}
 names:=[]string{"carrier-amoff-c0","rate-c0","rate-cf","rate-d0","rate-df","rate-e0","rate-e1","rate-e7","rate-e8","rate-ee","rate-ef","rate-f0","rate-ff"}
 if len(rows)!=13 {t.Fatal("13 profiles")}
 for i,row:=range rows {
  name:=row["name"].(string);if name!=names[i] {t.Fatal("literal profile order")}
  amd:=0;if i>0 {amd=64}
  for _,key:=range []string{"init","event"} {path:=row[key].(string);want:=filepath.Join(root,name+"-"+key+".bin");if path!=want||!filepath.IsAbs(path) {t.Fatal("manifest path ownership")};row[key]="$PROGRAM_OUTPUT/"+filepath.Base(path)}
  init,e:=os.ReadFile(filepath.Join(root,name+"-init.bin"));if e!=nil {t.Fatal(e)};event,e:=os.ReadFile(filepath.Join(root,name+"-event.bin"));if e!=nil {t.Fatal(e)}
  rate,e:=strconv.Atoi(string(row["rate"].(json.Number)));if e!=nil {t.Fatal(e)}
  if e=fast_test_literal(init,event,rate,amd);e!=nil {t.Fatal(name,e)}
  mutated:=append([]byte{},init...);for n:=0;n<len(mutated)-1;n+=3 {if mutated[n+1]==120 {mutated[n+2]=1}}
  if fast_test_literal(mutated,event,rate,amd)==nil {t.Fatal("literal validator accepted wrong audible TL")}
 }
 data,e:=json.Marshal(rows);if e!=nil {t.Fatal(e)};if fast_test_hash(data)!="b641e9deaca313202d5c7b9d5b674d6e1b43a82ab827bdc48ba9cd14d0305e7d" {t.Fatal("strict full manifest differs beyond INIT/EVENT output-root paths")}
}

func (job *fast_promotion) qualification() {
 t:=job.t;dir:=filepath.Join(job.root,"qualification")
 job.run(job.generic,[]string{"-test.run","^TestFast12ScopedQualification$","-test.v","-test.timeout","20m"},[]string{"FAST12_QUAL_OUTPUT="+dir},true)
 raw,e:=os.ReadFile(filepath.Join(dir,"qualification.json"));if e!=nil {t.Fatal(e)}
 var report map[string]interface{};decoder:=json.NewDecoder(bytes.NewReader(raw));decoder.UseNumber();if e=decoder.Decode(&report);e!=nil {t.Fatal(e)}
 for key,want:=range map[string]string{"positive_count":"3456","wrong_rate_count":"48","carrier_null_count":"48","negative_count":"8","coarse_failures":"0","fine_failures":"0","carrier_null_failures":"0","wrong_rate_failures":"0","negative_failures":"0"} {if string(report[key].(json.Number))!=want {t.Fatal("original grid result:",key)}}
 substitutions:=fast_test_rebase(t,report,dir+string(os.PathSeparator));canonical,e:=json.Marshal(report);if e!=nil {t.Fatal(e)}
 digest:=fast_test_hash(canonical);if substitutions!=48||digest!="6fde566f1ec671c8338796036c3dc3023713b8c46c8320775f3a6868a72ff811" {t.Fatalf("scientific report differs: substitutions%d SHA%s",substitutions,digest)}
 inputs:=filepath.Join(job.root,"cli-inputs");job.run(job.generic,[]string{"-test.run","^TestExportFrozenCLIInputs$","-test.v"},[]string{"FAST12_CLI_INPUTS="+inputs,"FAST12_QUAL_REPORT="+filepath.Join(dir,"qualification.json")},true)
 fast_test_report(t,filepath.Join(job.root,"scientific-report-reproduction.json"),map[string]interface{}{"scientific_digest":digest,"only_signal_csv_outputroot_substitutions":substitutions,"raw_report_sha256":fast_test_hash(raw),"raw_relocated_report_byteidentity_claimed":false,"full_grid_runs":1})
}

func (job *fast_promotion) scorer_cli() {
 t:=job.t;dir:=filepath.Join(job.root,"cli-checks");if e:=os.Mkdir(dir,0755);e!=nil {t.Fatal(e)}
 input:=filepath.Join(job.root,"qualification","c0-db_saw.csv")
 score:=func(name,profile,rate,path string,extra []string)map[string]interface{} {args:=[]string{"-profile",profile,"-rate",rate,"-output",filepath.Join(dir,name+".json")};args=append(args,extra...);args=append(args,path);job.run(job.scorer,args,nil,true);raw,e:=os.ReadFile(filepath.Join(dir,name+".json"));if e!=nil {t.Fatal(e)};var d map[string]interface{};if e=json.Unmarshal(raw,&d);e!=nil {t.Fatal(e)};if d["input_sha256"]!=fast_test_sha(t,path)||d["native_stride"]!=float64(4)||d["recorded_increment_hypothesis"]!=float64(263936)||d["frames"]!=float64(16384)||d["window"]!=float64(16)||d["hop"]!=float64(4) {t.Fatal("scorer geometry/input")};return d}
 for _,rate:=range []string{"c0","ff"} {curve:=filepath.Join(dir,rate+"-curve.csv");d:=score("am-"+rate,"am",rate,filepath.Join(job.root,"qualification",rate+"-db_saw.csv"),[]string{"-curve",curve});if d["published_observer"].(map[string]interface{})["state"]!="periodic_measured"||d["fine_diagnostic"].(map[string]interface{})["finite_one_percent_and_propagated_bound_match"]!=true {t.Fatal("original AM executable positive")};fast_test_curve(t,curve)}
 d:=score("carrier","carrier","c0",filepath.Join(job.root,"cli-inputs","carrier.csv"),nil);if d["minimum_remaining"]!=float64(1024)||d["carrier_diagnostic"].(map[string]interface{})["qualified"]!=true||d["whole_carrier_descriptive"].(map[string]interface{})["qualified_as_acceptance_gate"]!=false||d["published_observer"].(map[string]interface{})["state"]!="no_resolved_modulation" {t.Fatal("carrier executable control")}
 d=score("quiet","am","c0",filepath.Join(job.root,"cli-inputs","quiet.csv"),nil);if d["published_observer"].(map[string]interface{})["state"]!="no_signal"||d["fine_diagnostic"].(map[string]interface{})["finite_one_percent_and_propagated_bound_match"]!=false {t.Fatal("quiet control")}
 d=score("clipped","am","c0",filepath.Join(job.root,"cli-inputs","clipped.csv"),nil);if d["published_observer"].(map[string]interface{})["state"]!="periodic_measured"||!fast_test_reason(d,"raw_clipped")||d["fine_diagnostic"].(map[string]interface{})["eligible"]!=false {t.Fatal("clipped control")}
 d=score("short-post","am","c0",input,[]string{"-start-sample","16000"});if !fast_test_reason(d,"insufficient_actual_horizon")||d["fine_diagnostic"].(map[string]interface{})["eligible"]!=false {t.Fatal("short post control")}
 flags:=[][]string{{"-rate","fe"},{"-rate","100"},{"-rate","-1"},{"-rate","no"},{"-profile","other"},{"-start-sample","-1"},{"-start-sample","16384"},{"-pre-end-sample","4000"},{"-pre-end-sample","0"},{"-profile","carrier","-rate","ff"},{"-profile","carrier","-start-sample","16000"},{"-column","absent"},{"-unknown"},{"-start-sample","oops"}}
 negatives:=0;for i,flags:=range flags {dest:=filepath.Join(dir,fmt.Sprintf("reject-flags-%d.json",i));args:=append([]string{"-output",dest},flags...);job.run(job.scorer,append(args,input),nil,false);fast_test_absent(t,dest);negatives++}
 for _,kind:=range []string{"short","badheader","nonconsecutive","nan","range"} {var b strings.Builder;if kind=="badheader" {b.WriteString("bad,linear\n")}else {b.WriteString("sample,linear\n")};count:=16384;if kind=="short"||kind=="badheader" {count=1};for n:=0;n<count;n++ {index:=n;if kind=="nonconsecutive" {index++};value:="0";if n==100&&kind=="nan" {value="NaN"};if n==100&&kind=="range" {value="40000"};fmt.Fprintf(&b,"%d,%s\n",index,value)};p:=filepath.Join(dir,kind+".csv");if e:=os.WriteFile(p,[]byte(b.String()),0600);e!=nil {t.Fatal(e)};dest:=filepath.Join(dir,"reject-"+kind+".json");job.run(job.scorer,[]string{"-output",dest,p},nil,false);fast_test_absent(t,dest);negatives++}
 for _,test:=range []struct{existing string;args []string;absent string}{{filepath.Join(dir,"am-c0.json"),[]string{"-output",filepath.Join(dir,"am-c0.json"),input},""},{filepath.Join(dir,"c0-curve.csv"),[]string{"-output",filepath.Join(dir,"reject-curve.json"),"-curve",filepath.Join(dir,"c0-curve.csv"),input},filepath.Join(dir,"reject-curve.json")},{"",[]string{"-output",filepath.Join(dir,"same"),"-curve",filepath.Join(dir,"same"),input},filepath.Join(dir,"same")}} {before:="";if test.existing!="" {before=fast_test_sha(t,test.existing)};job.run(job.scorer,test.args,nil,false);if test.existing!=""&&fast_test_sha(t,test.existing)!=before {t.Fatal("exclusive output changed")};if test.absent!="" {fast_test_absent(t,test.absent)};negatives++}
 job.run(job.scorer,nil,nil,false);job.run(job.scorer,[]string{"-output",filepath.Join(dir,"reject-extra.json"),input,"extra"},nil,false);fast_test_absent(t,filepath.Join(dir,"reject-extra.json"));negatives+=2
 if negatives!=24 {t.Fatal("original24 scorer negatives")}
 fast_test_report(t,filepath.Join(job.root,"CLI-report.json"),map[string]interface{}{"original_positives":6,"original_negatives":negatives,"states_preserved":true})
}

func (job *fast_promotion) run(executable string,args,env []string,pass bool) []byte {
 job.t.Helper();command:=exec.Command(executable,args...);command.Env=append(os.Environ(),env...);output,e:=command.CombinedOutput();code:=0;if e!=nil {exit,ok:=e.(*exec.ExitError);if !ok {job.t.Fatal(e)};code=exit.ExitCode()}
 job.commands=append(job.commands,map[string]interface{}{"argv":append([]string{executable},args...),"environment_overrides":env,"exitcode":code,"output":string(output)})
 if (e==nil)!=pass {job.t.Fatalf("unexpected command result %v: %v\n%s",command.Args,e,output)}
 return output
}

func fast_test_base() []byte {
 data:=[]byte{};write:=func(reg,value int){data=append(data,1,byte(reg),byte(value))}
 for ch:=0;ch<8;ch++ {write(8,ch)};for reg:=32;reg<256;reg++ {write(reg,0)};for reg:=96;reg<128;reg++ {write(reg,127)}
 for _,pair:=range [][2]int{{1,0},{20,48},{15,0},{24,0},{25,0},{25,128},{27,0},{32,199},{40,74},{48,0},{88,1},{120,0},{152,31},{184,0},{216,0},{248,15},{8,64}} {write(pair[0],pair[1])}
 return append(data,0)
}

func fast_test_literal(init,event []byte,rate,amd int) error {
 if len(init)!=859||len(event)!=7||!bytes.Equal(event,[]byte{2,0,32,1,1,0,0})||init[len(init)-1]!=0 {return fmt.Errorf("literal INIT/EVENT length/opcode")}
 registers:=map[int]int{};keys:=[]int{};for p:=0;p<len(init)-1;p+=3 {if init[p]!=1 {return fmt.Errorf("INIT nonwrite")};reg,value:=int(init[p+1]),int(init[p+2]);registers[reg]=value;if reg==8 {keys=append(keys,value)}}
 if fmt.Sprint(keys)!="[0 1 2 3 4 5 6 7 64]" {return fmt.Errorf("literal key order")}
 special:=map[int]int{32:199,40:74,56:1,88:8,120:0,152:31,184:128,248:15};for reg:=32;reg<=255;reg++ {want:=0;if reg>=96&&reg<128 {want=127};if x,ok:=special[reg];ok {want=x};if registers[reg]!=want {return fmt.Errorf("literal register %02x",reg)}}
 if registers[1]!=2||registers[15]!=0||registers[20]!=48||registers[24]!=rate||registers[27]!=0 {return fmt.Errorf("literal globals")}
 tail:=[]byte{1,1,2,1,24,byte(rate),1,25,byte(amd),1,25,128,1,27,0,1,8,64,0};if !bytes.HasSuffix(init,tail) {return fmt.Errorf("literal appended LFO/key sequence")};return nil
}

func fast_test_rebase(t *testing.T,value interface{},root string) int {
 t.Helper();count:=0;switch x:=value.(type) {case map[string]interface{}:for key,v:=range x {if key=="signal_csv" {s,ok:=v.(string);if !ok||!strings.HasPrefix(s,root) {t.Fatal("unexpected generated signal path")};x[key]="$QUAL_OUTPUT/"+strings.TrimPrefix(s,root);count++}else {count+=fast_test_rebase(t,v,root)}};case []interface{}:for _,v:=range x {count+=fast_test_rebase(t,v,root)}};return count
}

func fast_test_reason(d map[string]interface{},want string) bool {for _,reason:=range d["fine_diagnostic"].(map[string]interface{})["unqualified_reasons"].([]interface{}) {if reason==want {return true}};return false}

func fast_test_curve(t *testing.T,path string) {
 t.Helper();f,e:=os.Open(path);if e!=nil {t.Fatal(e)};defer f.Close();rows,e:=csv.NewReader(f).ReadAll();if e!=nil||len(rows)!=4094 {t.Fatal("curve rows",e)};if rows[1][0]!="7.5"||rows[len(rows)-1][0]!="16375.5" {t.Fatal("curve endpoints")};valid:=-1;for i,name:=range rows[0] {if name=="valid" {valid=i}};if valid<0 {t.Fatal("missing curve valid column")};for _,row:=range rows[1:] {if row[valid]!="true" {t.Fatal("curve invalid point")}}
}

func fast_test_absent(t *testing.T,path string) {t.Helper();if _,e:=os.Stat(path);!os.IsNotExist(e) {t.Fatal("rejected command created output:",path)}}
func fast_test_hash(raw []byte) string {return fmt.Sprintf("%x",sha256.Sum256(raw))}
func fast_test_sha(t *testing.T,path string) string {t.Helper();raw,e:=os.ReadFile(path);if e!=nil {t.Fatal(e)};return fast_test_hash(raw)}
func fast_test_report(t *testing.T,path string,value interface{}) {t.Helper();raw,e:=json.MarshalIndent(value,"","  ");if e!=nil {t.Fatal(e)};f,e:=os.OpenFile(path,os.O_WRONLY|os.O_CREATE|os.O_EXCL,0600);if e!=nil {t.Fatal(e)};if _,e=f.Write(append(raw,'\n'));e!=nil {f.Close();t.Fatal(e)};if e=f.Close();e!=nil {t.Fatal(e)}}

var fast_test_payload_hashes=map[string]string{
 "carrier-amoff-c0-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "carrier-amoff-c0-init.bin":"e27992639bee705e2d71c9ec9d4998132840100d543f11f295eeda4ad52f0742",
 "rate-c0-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-c0-init.bin":"bbbbc3074ebfa0b72a8b6c3db645c710f06914f43c6886410b8b914f59cc0399",
 "rate-cf-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-cf-init.bin":"f349456ae7800c7ba27e4570ae897f9178c89d7365ec2faa5f76264a4566e6d6",
 "rate-d0-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-d0-init.bin":"3e298d40e7f95f19e2258769ab8a74752266e4b2a8a3669c321c739b2d16a975",
 "rate-df-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-df-init.bin":"ca6ecd798d508c31ef041dc796d7883de25fafc6215f715c63883a5bea664693",
 "rate-e0-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-e0-init.bin":"eac18b51bae0d8cecfe5fdf765c8ef8f9c46a492da9878ff0372e36966bb0855",
 "rate-e1-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-e1-init.bin":"b7e2c94f6c9a2e23be813cca99eef51258b4a2857caa844c5588b5a7bc293f25",
 "rate-e7-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-e7-init.bin":"f8b0cb950040c69a6d762a1304850f3452b296940df4c80b12b206cfdb67ea03",
 "rate-e8-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-e8-init.bin":"33f8fc2dca6337168ff82c49cb26b17c327dc2ed2adc79a2ee17f05b4e90f1e9",
 "rate-ee-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-ee-init.bin":"33e3731a2dfb9953503cb84322e5c7bdc06622af9830952f00184e8d7dcfd389",
 "rate-ef-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-ef-init.bin":"5d29622fa78cc8edf7dbf1c810149ddeaa2dde2daa42879e6dafc12b36fa99bb",
 "rate-f0-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-f0-init.bin":"c43c3a761a56eaa2efe41f8a8741ae8826c38d0ad2cdafb6e132ba3e6e72e4d4",
 "rate-ff-event.bin":"55e868473c20ec894d3e70870be93ebc3aea8b1cb9b0bff955ab56b2e02cf249",
 "rate-ff-init.bin":"22f79e03cfd720f82a93c8db5a5b6dafeb6f138fd9e921892c4a0d282c7f5aa2",
}
