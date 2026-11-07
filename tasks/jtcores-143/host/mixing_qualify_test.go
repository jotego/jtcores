package main

import (
 "bytes"
 "crypto/sha256"
 "encoding/json"
 "fmt"
 "os"
 "os/exec"
 "path/filepath"
 "runtime"
 "testing"
)

func TestMain(m *testing.M) {
 if root:=os.Getenv("JT143_MIXING_REPORT_DIR");root!="" {
  e:=os.Mkdir(root,0755);if e!=nil {fmt.Fprintln(os.Stderr,e);os.Exit(1)}
 }
 os.Exit(m.Run())
}
func TestOriginalMixingQualification(t *testing.T) {
 root:=os.Getenv("JT143_MIXING_REPORT_DIR");if root=="" {root=t.TempDir()}
 _,current,_,ok:=runtime.Caller(0);if !ok {t.Fatal("test source location unavailable")}
 source_root:=filepath.Dir(current)
 binaries:=filepath.Join(root,"bin")
 e:=os.Mkdir(binaries,0755);if e!=nil {t.Fatal(e)}
 tools:=map[string]string{}
 identities:=map[string]map[string]string{}
 for _,tool:=range []struct{name,source string}{{"generator","mixing_programs.go"},{"validator","mixing_validate.go"},{"describe","mixing_describe.go"},{"qualify","mixing_qualify.go"}} {
  source:=filepath.Join(source_root,tool.source)
  binary:=filepath.Join(binaries,tool.name)
  command:=exec.Command("go","build","-trimpath","-o",binary,source)
  output,e:=command.CombinedOutput();if e!=nil {t.Fatalf("build %s: %v\n%s",tool.name,e,output)}
  tools[tool.name]=binary
  identities[tool.name]=map[string]string{"source":source,"source_sha256":mixing_test_hash(t,source),"executable":binary,"executable_sha256":mixing_test_hash(t,binary)}
 }
 version,e:=exec.Command("go","version").CombinedOutput();if e!=nil {t.Fatal(e)}
 mixing_test_report(t,filepath.Join(root,"build-identities.json"),map[string]interface{}{"tools":identities,"toolchain":string(version),"build_flags":[]string{"-trimpath"},"no_models_or_hardware":true})
 output:=filepath.Join(root,"qualification")
 args:=[]string{"-output",output,"-generator",tools["generator"],"-validator",tools["validator"],"-describe",tools["describe"]}
 command:=exec.Command(tools["qualify"],args...)
 stdout,e:=command.CombinedOutput();if e!=nil {t.Fatalf("original qualification: %v\n%s",e,stdout)}
 raw,e:=os.ReadFile(filepath.Join(output,"report.json"));if e!=nil {t.Fatal(e)}
 var report struct {Complete bool `json:"complete"`;Trials []trial `json:"trials"`;Controls []map[string]interface{} `json:"controls"`}
 e=json.Unmarshal(raw,&report);if e!=nil {t.Fatal(e)}
 if !report.Complete || len(report.Trials)!=103 || len(report.Controls)!=21 {t.Fatal("original finite qualification shape changed")}
 found:=map[string]bool{}
 for _,test:=range report.Trials {if !test.Pass {t.Fatalf("original trial failed: %s",test.Name)};found[test.Name]=true}
 for _,name:=range []string{"reject-self-consistent-wrong-TL","reject-empty-digest","reject-duplicate-json-field","csv-reject-nonfinite-other","describe-reused-output","generator-reused-directory"} {
  if !found[name] {t.Fatalf("missing original guard: %s",name)}
 }
 first,second:=filepath.Join(output,"programs"),filepath.Join(output,"programs-reproduction")
 entries,e:=os.ReadDir(first);if e!=nil {t.Fatal(e)}
 if len(entries)!=130 {t.Fatal("expected130 original catalog files")}
 for _,entry:=range entries {
  a,e:=os.ReadFile(filepath.Join(first,entry.Name()));if e!=nil {t.Fatal(e)}
  b,e:=os.ReadFile(filepath.Join(second,entry.Name()));if e!=nil {t.Fatal(e)}
  if !bytes.Equal(a,b) {t.Fatalf("payload/manifest reproduction: %s",entry.Name())}
 }
 rejected:=[]map[string]interface{}{}
 cases:=[]struct{name string;args []string}{
  {"qualify-no-args",nil},
  {"qualify-unknown-flag",[]string{"-unknown"}},
  {"qualify-extra-arg",append(append([]string{},args...),"extra")},
  {"qualify-reused-directory",args},
 }
 before:=mixing_test_hash(t,filepath.Join(output,"report.json"))
 for _,test:=range cases {
  text,e:=exec.Command(tools["qualify"],test.args...).CombinedOutput()
  exit,ok:=e.(*exec.ExitError);if !ok || exit.ExitCode()<=0 {t.Fatalf("negative %s accepted: %v %s",test.name,e,text)}
  rejected=append(rejected,map[string]interface{}{"name":test.name,"argv":append([]string{tools["qualify"]},test.args...),"exitcode":exit.ExitCode(),"output":string(text)})
 }
 if mixing_test_hash(t,filepath.Join(output,"report.json"))!=before {t.Fatal("rejected qualifier changed existing report")}
 mixing_test_report(t,filepath.Join(root,"wrapper-report.json"),map[string]interface{}{"state":"original103trials21controls_pass","original_stdout":string(stdout),"original_report_sha256":before,"exact_reproduced_files":130,"qualifier_cli_negatives":rejected,"no_models_or_hardware":true})
 t.Logf("mixing qualification report: %s",root)
}
func mixing_test_hash(t *testing.T,path string) string {
 t.Helper()
 raw,e:=os.ReadFile(path);if e!=nil {t.Fatal(e)}
 return fmt.Sprintf("%x",sha256.Sum256(raw))
}
func mixing_test_report(t *testing.T,path string,value interface{}) {
 t.Helper()
 raw,e:=json.MarshalIndent(value,"","  ");if e!=nil {t.Fatal(e)}
 file,e:=os.OpenFile(path,os.O_WRONLY|os.O_CREATE|os.O_EXCL,0600);if e!=nil {t.Fatal(e)}
 _,e=file.Write(append(raw,'\n'));if e!=nil {file.Close();t.Fatal(e)}
 e=file.Close();if e!=nil {t.Fatal(e)}
}
