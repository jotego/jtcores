package main
import("bytes";"os";"path/filepath";"testing")
func TestFrozenSpecRejectsContamination(t *testing.T){cases:=[][]byte{append(append([]byte{},literal_spec...), '\n'),bytes.Replace(literal_spec,[]byte(`"name": "N0"`),[]byte(`"name": "X0"`),1),[]byte(`{}`)};for i,b:=range cases{if _,e:=read_complement_spec(b);e==nil{t.Fatalf("contamination%d accepted",i)}}}
func TestBytecodeRejectsMalformed(t *testing.T){for _,b:=range [][]byte{nil,{1,8},{2,0,0,0},{3,0},{1,8,0},{0,0},{2,1,0}}{if _,e:=decode_complement(b);e==nil{t.Fatalf("malformed%v accepted",b)}}}
func TestGeneratorExclusive(t *testing.T){path:=filepath.Join(t.TempDir(),"occupied");if e:=os.Mkdir(path,0700);e!=nil{t.Fatal(e)};marker:=filepath.Join(path,"marker");if e:=os.WriteFile(marker,[]byte("untouched"),0600);e!=nil{t.Fatal(e)};j:=complement_generation{output:path};if e:=j.run();e==nil{t.Fatal("occupied output accepted")};raw,e:=os.ReadFile(marker);if e!=nil||string(raw)!="untouched"{t.Fatal("existing output mutated")}}
