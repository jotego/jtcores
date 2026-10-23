package main

import (
 "bytes"
 "crypto/sha256"
 "encoding/hex"
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
 if configured:=os.Getenv("JT143_COMPLEMENTS_REPORT_DIR");configured!="" {root,e:=filepath.Abs(configured);if e!=nil {fmt.Fprintln(os.Stderr,e);os.Exit(1)};if e=os.Setenv("JT143_COMPLEMENTS_REPORT_DIR",root);e!=nil {fmt.Fprintln(os.Stderr,e);os.Exit(1)};if e=os.Mkdir(root,0755);e!=nil {fmt.Fprintln(os.Stderr,e);os.Exit(1)}}
 os.Exit(m.Run())
}

type complements_promotion struct {t *testing.T;root,host,generator,noise,low string;commands []map[string]interface{};checks map[string]int}

func TestOriginalComplementsPromotion(t *testing.T) {
 root:=os.Getenv("JT143_COMPLEMENTS_REPORT_DIR");if root=="" {root=t.TempDir()}
 _,source,_,ok:=runtime.Caller(0);if !ok {t.Fatal("source path unavailable")}
 job:=complements_promotion{t:t,root:root,host:filepath.Dir(source),checks:map[string]int{}}
 job.build()
 job.catalog()
 job.cli()
 command:=exec.Command(os.Args[0],"-test.run","^TestOriginalComplementsPromotion$");command.Env=append(os.Environ(),"JT143_COMPLEMENTS_REPORT_DIR="+root)
 output,e:=command.CombinedOutput();if e==nil {t.Fatal("existing report root accepted")}
 job.commands=append(job.commands,map[string]interface{}{"kind":"existing-report-root-rejection-before-tests","exitcode":command.ProcessState.ExitCode(),"output":string(output)})
 job.report("wrapper-report.json",map[string]interface{}{"state":"focused_complements_payload_structural_and_CLI_checks_pass","checks":job.checks,"commands":job.commands,"no_generic_grid_no_model_no_hardware":true})
 t.Logf("complements report: %s",root)
}

func (job *complements_promotion) build() {
 dir:=filepath.Join(job.root,"bin");if e:=os.Mkdir(dir,0755);e!=nil {job.t.Fatal(e)}
 job.generator=filepath.Join(dir,"generator");job.noise=filepath.Join(dir,"noise-energy");job.low=filepath.Join(dir,"low-score")
 identities:=map[string]interface{}{}
 noise:=[]string{"complements_noise_energy.go","complements_energy.go","complements_noise.go","tone.go","complements_input.go"}
 low:=[]string{"complements_low_score.go","lfo_fast_observer.go","complements_partial.go","complements_low_fine.go","tone.go","sine_fit.go","complements_input.go"}
 for _,group:=range []struct{name,exe string;files,tests []string}{{"generator",job.generator,[]string{"complements_programs.go"},[]string{"complements_programs_test.go"}},{"noise",job.noise,noise,[]string{"complements_input_test.go"}},{"low",job.low,low,[]string{"complements_input_test.go","complements_low_test.go"}},{"phase",filepath.Join(dir,"phase"),[]string{"phase.go","tone.go"},nil},{"csm-energy",filepath.Join(dir,"csm-energy"),[]string{"csm_energy.go","tone.go"},nil}} {
  paths:=[]string{};sources:=map[string]string{};for _,name:=range group.files {p:=filepath.Join(job.host,name);paths=append(paths,p);sources[p]=complements_sha(job.t,p)}
  job.run("go",append([]string{"build","-trimpath","-o",group.exe},paths...),true)
  job.run("go",append([]string{"vet"},paths...),true)
  if len(group.tests)>0 {for _,name:=range group.tests {paths=append(paths,filepath.Join(job.host,name))};job.run("go",append([]string{"test","-count=1","-v"},paths...),true)}
  identities[group.name]=map[string]interface{}{"sources":sources,"executable":group.exe,"executable_sha256":complements_sha(job.t,group.exe)}
 }
 job.run("python3",[]string{"-m","py_compile",filepath.Join(job.host,"complements_csm_review.py")},true)
 job.report("build-identities.json",identities)
}

func (job *complements_promotion) catalog() {
 t:=job.t;roots:=[]string{filepath.Join(job.root,"programs-default"),filepath.Join(job.root,"programs-spec")}
 for i,root:=range roots {
  args:=[]string{"-output",root};if i==1 {args=append(args,"-spec",filepath.Join(job.host,"testdata","audit-complements-method.json"))};job.run(job.generator,args,true)
  entries,e:=os.ReadDir(root);if e!=nil||len(entries)!=25 {t.Fatal("exact25 generated files",e)}
  for name,want:=range complements_payload_hashes {p:=filepath.Join(root,name);if complements_sha(t,p)!=want {t.Fatal("payload differs",name)}}
  var catalog map[string]interface{};complements_read(t,filepath.Join(root,"cases.json"),&catalog)
  cases:=catalog["cases"].([]interface{});if len(cases)!=11 {t.Fatal("eleven profiles")};rebase:=0
  for _,raw:=range cases {c:=raw.(map[string]interface{});for _,key:=range []string{"init","event"} {path:=c[key].(string);if filepath.Dir(path)!=root {t.Fatal("unexpected catalog path")};c[key]="$PROGRAMS/"+filepath.Base(path);rebase++}}
  a,e:=json.Marshal(catalog);if e!=nil {t.Fatal(e)};if fmt.Sprintf("%x",sha256.Sum256(a))!=complements_expected_catalog_sha256||rebase!=22 {t.Fatal("catalog differs beyond22 path rebases")}
  job.literal(root)
  job.checks["exact_binary_payloads"]+=24;job.checks["catalog_path_rebases"]+=rebase;job.checks["emitted_files"]+=25
 }
 for name:=range complements_payload_hashes {a,e:=os.ReadFile(filepath.Join(roots[0],name));if e!=nil {t.Fatal(e)};b,e:=os.ReadFile(filepath.Join(roots[1],name));if e!=nil||!bytes.Equal(a,b) {t.Fatal("default/explicit spec differs")}}
 before:=complements_sha(t,filepath.Join(roots[0],"cases.json"));job.run(job.generator,[]string{"-output",roots[0]},false);if before!=complements_sha(t,filepath.Join(roots[0],"cases.json")) {t.Fatal("exclusive catalog changed")}
 bad:=filepath.Join(job.root,"changed-spec.json");data,e:=os.ReadFile(filepath.Join(job.host,"testdata","audit-complements-method.json"));if e!=nil {t.Fatal(e)};if e=os.WriteFile(bad,append(data,'\n'),0600);e!=nil {t.Fatal(e)}
 rejects:=[][]string{{},{"-output",filepath.Join(job.root,"reject-changed"),"-spec",bad},{"-output",filepath.Join(job.root,"reject-missing"),"-spec",bad+"-absent"},{"-output",filepath.Join(job.root,"reject-extra"),"extra"},{"-unknown"},{"-output",filepath.Join(job.root,"missing-parent","output")}}
 for _,args:=range rejects {job.run(job.generator,args,false);job.checks["generator_CLI_rejections"]++}
}

func (job *complements_promotion) literal(root string) {
 t:=job.t;var spec struct{Profiles []struct{Name string `json:"name"`;Overrides map[string]string `json:"register_image_overrides_hex"`;Globals map[string]string `json:"global_overrides_hex"`;Noise string `json:"initial_NE_NFRQ_hex"`;Keys [][]string `json:"profile_keyons_hex"`;Event string `json:"event_hex"`}}
 complements_read(t,filepath.Join(job.host,"testdata","audit-complements-method.json"),&spec)
 value:=func(s string)byte {x,e:=strconv.ParseUint(s,16,8);if e!=nil {t.Fatal(e)};return byte(x)}
 for _,p:=range spec.Profiles {
  want:=[]byte{};write:=func(reg,v byte){want=append(want,1,reg,v)}
  write(20,48);write(15,0);for channel:=byte(0);channel<8;channel++ {write(8,channel)}
  for _,key:=range []string{"01","10","11","12","18","19:AMD","19:PMD","1B"} {v:="00";if key=="19:PMD" {v="80"};if override,ok:=p.Globals[key];ok {v=override};write(value(key[:2]),value(v))}
  for reg:=32;reg<=255;reg++ {v:=byte(0);if reg>=96&&reg<=127 {v=127};if reg>=224 {v=15};if override,ok:=p.Overrides[fmt.Sprintf("%02X",reg)];ok {v=value(override)};write(byte(reg),v)}
  write(15,value(p.Noise));write(20,0);for _,key:=range p.Keys {if len(key)!=2||key[0]!="08" {t.Fatal("literal key selector")};write(8,value(key[1]))};want=append(want,2,0,32,0)
  got,e:=os.ReadFile(filepath.Join(root,p.Name+"-init.bin"));if e!=nil||!bytes.Equal(got,want) {t.Fatal("independent literal INIT",p.Name)}
  want,e=hex.DecodeString(strings.ReplaceAll(p.Event," ",""));if e!=nil {t.Fatal(e)};got,e=os.ReadFile(filepath.Join(root,p.Name+"-event.bin"));if e!=nil||!bytes.Equal(got,want) {t.Fatal("independent literal EVENT",p.Name)}
  if p.Name[0]=='L' {if len(got)!=19||!bytes.Equal(got[:15],[]byte{2,255,255,2,255,255,2,255,255,2,255,255,2,4,0}) {t.Fatal("five literal low delay chunks")}}
  job.checks["independent_literal_profiles"]++
 }
 clean:=[]byte{1,20,48,1,15,0};for reg:=224;reg<=255;reg++ {clean=append(clean,1,byte(reg),15)};for ch:=0;ch<8;ch++ {clean=append(clean,1,8,byte(ch))};clean=append(clean,0)
 got,e:=os.ReadFile(filepath.Join(root,"cleanup.bin"));if e!=nil||!bytes.Equal(got,clean) {t.Fatal("stop-first cleanup")};got,e=os.ReadFile(filepath.Join(root,"status.bin"));if e!=nil||!bytes.Equal(got,[]byte{3,0}) {t.Fatal("separate status")}
}

func (job *complements_promotion) cli() {
 t:=job.t;dir:=filepath.Join(job.root,"CLI");if e:=os.Mkdir(dir,0755);e!=nil {t.Fatal(e)}
 make_csv:=func(n int,name string)string {var b strings.Builder;b.WriteString("sample,linear\n");for i:=0;i<n;i++ {fmt.Fprintf(&b,"%d,0\n",i)};p:=filepath.Join(dir,name);if e:=os.WriteFile(p,[]byte(b.String()),0600);e!=nil {t.Fatal(e)};return p}
 native:=make_csv(16384,"native-zero-structural.csv");low:=make_csv(4096,"low-zero-structural.csv")
 for _,p:=range []string{"N0","N1","N2","N3"} {dest:=filepath.Join(dir,"check-"+p);job.run(job.noise,[]string{"-check-only","-profile",p,"-start-sample","2048","-output",dest,native},true);complements_absent(t,dest);job.checks["noise_structural_CLI_positives"]++}
 for _,p:=range []string{"L0","L1","L2","L3"} {dest:=filepath.Join(dir,"check-"+p);job.run(job.low,[]string{"-check-only","-profile",p,"-start-sample","256","-pre-end-sample","128","-output",dest,low},true);complements_absent(t,dest);job.checks["low_structural_CLI_positives"]++}
 for i,flags:=range [][]string{{"-profile","N4"},{"-native-stride","4"},{"-start-sample","511"},{"-start-sample","16384"},{"-column","absent"},{"-unknown"}} {dest:=filepath.Join(dir,fmt.Sprintf("reject-noise-%d",i));args:=[]string{"-check-only","-profile","N3","-start-sample","2048","-output",dest};args=append(args,flags...);job.run(job.noise,append(args,native),false);complements_absent(t,dest);job.checks["noise_CLI_rejections"]++}
 for i,flags:=range [][]string{{"-profile","L4"},{"-native-stride","512"},{"-native-increment","1186"},{"-pre-end-sample","0"},{"-window","32"},{"-hop","8"},{"-sample-rate","NaN"},{"-column","absent"},{"-unknown"}} {dest:=filepath.Join(dir,fmt.Sprintf("reject-low-%d",i));args:=[]string{"-check-only","-profile","L0","-start-sample","256","-pre-end-sample","128","-output",dest};args=append(args,flags...);job.run(job.low,append(args,low),false);complements_absent(t,dest);job.checks["low_CLI_rejections"]++}
 guard:=filepath.Join(job.host,"complements_csm_review.py");dest:=filepath.Join(dir,"check-CSM");args:=[]string{guard,native,"--check-only","--profile","C2","--latch","1","--start-sample","2048","--energy-exe",filepath.Join(job.root,"bin","csm-energy"),"--phase-exe",filepath.Join(job.root,"bin","phase"),"--output",dest};job.run("python3",args,true);complements_absent(t,dest);job.checks["CSM_structural_CLI_positives"]++
 data,e:=os.ReadFile(native);if e!=nil {t.Fatal(e)}
 for name,bad:=range map[string][]byte{"range":bytes.Replace(data,[]byte("0,0\n"),[]byte("0,32768\n"),1),"nan":bytes.Replace(data,[]byte("0,0\n"),[]byte("0,NaN\n"),1),"gap":bytes.Replace(data,[]byte("1,0\n"),[]byte("2,0\n"),1),"duplicate-header":bytes.Replace(data,[]byte("sample,linear"),[]byte("sample,sample"),1),"fraction":bytes.Replace(data,[]byte("0,0\n"),[]byte("0,0.5\n"),1)} {p:=filepath.Join(dir,name+".csv");if e=os.WriteFile(p,bad,0600);e!=nil {t.Fatal(e)};a:=append([]string{},args...);a[1]=p;job.run("python3",a,false);complements_absent(t,dest);nd:=filepath.Join(dir,"noise-parser-"+name);job.run(job.noise,[]string{"-check-only","-profile","N3","-start-sample","2048","-output",nd,p},false);complements_absent(t,nd);job.checks["CSM_parser_rejections"]++;job.checks["noise_parser_rejections"]++}
 for _,exe:=range []string{job.noise,job.low} {job.run(exe,nil,false);job.checks["scorer_missing_arguments_rejections"]++}
 occupied:=filepath.Join(dir,"occupied");if e=os.Mkdir(occupied,0755);e!=nil {t.Fatal(e)};for _,exe:=range []string{job.noise,job.low} {input:=native;flags:=[]string{"-check-only","-profile","N3","-start-sample","2048","-output",occupied};if exe==job.low {input=low;flags=[]string{"-check-only","-profile","L0","-start-sample","256","-pre-end-sample","128","-output",occupied}};job.run(exe,append(flags,input),false);job.checks["scorer_existing_output_rejections"]++}
}

func (job *complements_promotion) run(exe string,args []string,pass bool) []byte {
 job.t.Helper();cmd:=exec.Command(exe,args...);output,e:=cmd.CombinedOutput();code:=0;if e!=nil {exit,ok:=e.(*exec.ExitError);if !ok {job.t.Fatal(e)};code=exit.ExitCode()}
 job.commands=append(job.commands,map[string]interface{}{"argv":append([]string{exe},args...),"exitcode":code,"output":string(output)})
 if (e==nil)!=pass {job.report(fmt.Sprintf("FAILED-%d.json",len(job.commands)),job.commands);job.t.Fatalf("command expectation failed %v: %v\n%s",cmd.Args,e,output)}
 return output
}
func (job *complements_promotion) report(name string,x interface{}) {job.t.Helper();data,e:=json.MarshalIndent(x,"","  ");if e!=nil {job.t.Fatal(e)};f,e:=os.OpenFile(filepath.Join(job.root,name),os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600);if e!=nil {job.t.Fatal(e)};if _,e=f.Write(append(data,'\n'));e!=nil {job.t.Fatal(e)};if e=f.Close();e!=nil {job.t.Fatal(e)}}
func complements_sha(t *testing.T,path string) string {t.Helper();data,e:=os.ReadFile(path);if e!=nil {t.Fatal(e)};return fmt.Sprintf("%x",sha256.Sum256(data))}
func complements_read(t *testing.T,path string,x interface{}) {t.Helper();data,e:=os.ReadFile(path);if e!=nil {t.Fatal(e)};if e=json.Unmarshal(data,x);e!=nil {t.Fatal(e)}}
func complements_absent(t *testing.T,path string) {t.Helper();if _,e:=os.Stat(path);!os.IsNotExist(e) {t.Fatal("structural/rejected command produced output",path)}}

var complements_payload_hashes=map[string]string{
"C2-event.bin":"f5fdb77c8a0d24b9870c9945ccf3607f74fa7dec23cb027db7d2792fd7c24717",
"C2-init.bin":"c2acbff77d78d90acded6343199cd51f3a9664d7956fb8acc6b656d7119e691d",
"C3-event.bin":"d1bd24a30a9b7e72910e08c8758dfa0899d148f928c9c4d25e3918cc85c62355",
"C3-init.bin":"c2acbff77d78d90acded6343199cd51f3a9664d7956fb8acc6b656d7119e691d",
"C4-event.bin":"d1bd24a30a9b7e72910e08c8758dfa0899d148f928c9c4d25e3918cc85c62355",
"C4-init.bin":"9b8eb94c9efe95a7d13793bdb556f4288fdf5ba84b3cd510e7cf437162a5da12",
"L0-event.bin":"e9770a8414be615881018d3c6a56e3f0e412f4407f50bf950f873209d27b55ff",
"L0-init.bin":"454debfd010a40f3e35b940702484d623dbb4ab054ec3c759595f5f0b9c6e7b9",
"L1-event.bin":"e9770a8414be615881018d3c6a56e3f0e412f4407f50bf950f873209d27b55ff",
"L1-init.bin":"f567608d8a6a4782fe28658d877989f3f09ba2c330ed3fb6827e877cec6a95dd",
"L2-event.bin":"e9770a8414be615881018d3c6a56e3f0e412f4407f50bf950f873209d27b55ff",
"L2-init.bin":"381c812b2d74283032797cea5262f2118cd619ab951aed056246c302280a809c",
"L3-event.bin":"3b0fe09242ac217df3449d9e953f206983bbe46e5067b07ccc6a7bac5c88c041",
"L3-init.bin":"f567608d8a6a4782fe28658d877989f3f09ba2c330ed3fb6827e877cec6a95dd",
"N0-event.bin":"886ae21a2bcdf48e08ade36c636d7b31cec494048f31d63a2855176458b00804",
"N0-init.bin":"4e47471b9190b0477b0719e679e4f594db20253a7f13bf3f5aa4e87dd7bb185b",
"N1-event.bin":"886ae21a2bcdf48e08ade36c636d7b31cec494048f31d63a2855176458b00804",
"N1-init.bin":"ddb7dcf819474a58b720d0d419b7d6920a598deab6c646a62ae278c94effcbfe",
"N2-event.bin":"15db0878dda1981236e1c507238b1a59d6c35880cf40c2467694a8e5904cfb69",
"N2-init.bin":"026227fb954654f1e41f6f0ddefa2f89f808aeb7728b39d71c2fd23fdf168d34",
"N3-event.bin":"15db0878dda1981236e1c507238b1a59d6c35880cf40c2467694a8e5904cfb69",
"N3-init.bin":"b929bd7d34d8f0fa416948054c0d938e1dead600abb50e3751bf18c29615e9d3",
"cleanup.bin":"024e6a9a81173c068190eb78346e3e6c16d893da0eb19674209af9c51a5359ea",
"status.bin":"9b4fb24edd6d1d8830e272398263cdbf026b97392cc35387b991dc0248a628f9",
}

const complements_expected_catalog_sha256="364463e233e829b818df6c23af7ca7da278d1cc3da0f90c7f4064cc7e8465f35"
