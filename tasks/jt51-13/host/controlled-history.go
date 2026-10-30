// Public-register controlled probes after the complete replacement history.
package main
import("encoding/json";"flag";"fmt";"os";"path/filepath")
type probe_case struct {Name string `json:"name"`; Init string `json:"init"`; Event string `json:"event"`; Stride int `json:"stride"`; DelayCount int `json:"pretrigger_delay_count"`; Purpose string `json:"purpose"`}
func main(){base:=flag.String("replay","","compiled replay directory");out:=flag.String("output","","fresh output directory");flag.Parse();if e:=generate(*base,*out);e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}}
func generate(base,out string)error{
 b,e:=os.ReadFile(filepath.Join(base,"natural-fresh-init.bin"));if e!=nil{return e}
 // Recover the exact replay register image immediately before the natural target.
 registers:=[256]byte{};entries,e:=filepath.Glob(filepath.Join(base,"history-*.bin"));if e!=nil{return e}
 for _,path:=range entries {data,e:=os.ReadFile(path);if e!=nil{return e};for i:=0;i<len(data);{switch data[i]{case 0:i=len(data);case 1:registers[data[i+1]]=data[i+2];i+=3;case 2:i+=3;default:return fmt.Errorf("bad bytecode")}}}
 if e=os.Mkdir(out,0755);e!=nil{return e};out,e=filepath.Abs(out);if e!=nil{return e}
 write:=func(name string,data []byte)(string,error){p:=filepath.Join(out,name);f,e:=os.OpenFile(p,os.O_WRONLY|os.O_CREATE|os.O_EXCL,0600);if e!=nil{return "",e};_,e=f.Write(data);c:=f.Close();if e!=nil{return "",e};return p,c}
 if _,e=write("end.bin",[]byte{0});e!=nil{return e}
 cases:=[]probe_case{}
 // Literal two original jt51#1 distilled programs, already retained in History93.
 attack:=[][2]byte{{0x26,0xe8},{0x2e,0x1d},{0x36,0x1c},{0x3e,0},{0x46,1},{0x66,6},{0x86,12},{0xa6,0},{0xc6,8},{0xe6,0xf4},{0x4e,1},{0x6e,14},{0x8e,17},{0xae,16},{0xce,0x48},{0xee,0x34},{0x56,5},{0x76,13},{0x96,28},{0xb6,12},{0xd6,8},{0xf6,4},{0x5e,0},{0x7e,7},{0x9e,22},{0xbe,12},{0xde,0},{0xfe,0xf4}}
 release:=[][2]byte{{0x2e,8},{0x36,0x1c},{0x26,0xf9},{0x3e,0},{0x46,2},{0x66,0x75},{0x86,0x12},{0xa6,10},{0xc6,10},{0xe6,0x18},{0x4e,0x13},{0x6e,31},{0x8e,0x12},{0xae,8},{0xce,6},{0xee,0x17},{0x56,0},{0x76,10},{0x96,0x12},{0xb6,9},{0xd6,7},{0xf6,0x27},{0x5e,1},{0x7e,0},{0x9e,0x5a},{0xbe,10},{0xde,5},{0xfe,6}}
 for _,kind:=range []string{"original-attack","original-release","rr0-ks0-kc00","rr0-ks3-kc04","rr0-ks3-kc08","rr0-ks3-kc10"}{
  setup:=[]byte{}
  for ch:=0;ch<8;ch++{if ch!=6{setup=append(setup,1,byte(32+ch),registers[32+ch]&63)}}
  setup=append(setup,1,8,6)
  stride:=1;purpose:="Literal original AR12/ALG0 program appended as a controlled target after the new complete MAME prefix; not a natural replacement-trace event"
  if kind=="original-attack"||kind=="original-release" {program:=attack;if kind=="original-release"{program=release;stride=3;purpose="Literal original release-entry program after new full history; original missing trace remains distinct"};for _,w:=range program{setup=append(setup,1,w[0],w[1])}}else{
   kc,ks:=byte(0),byte(0);switch kind{case "rr0-ks3-kc04":kc=4;ks=3;case "rr0-ks3-kc08":kc=8;ks=3;case "rr0-ks3-kc10":kc=16;ks=3}
   for _,w:=range [][2]byte{{0x26,0xc7},{0x2e,kc},{0x36,0},{0x3e,0},{0x66,127},{0x6e,127},{0x76,127},{0x5e,8},{0x7e,0},{0x9e,ks<<6|31},{0xbe,0},{0xde,0},{0xfe,0}}{setup=append(setup,1,w[0],w[1])}
   stride=32;purpose="Controlled C2-only release, raw RR0; labels retain literal KS/KC to avoid ambiguous effective-rate numbering; low-rate public audio after full prefix"
  }
  ip,e:=write(kind+"-init.bin",append(setup,0));if e!=nil{return e}
  for repeat,phase:=range []int{0,7,19}{event:=[]byte{2,byte(8192+phase),byte((8192+phase)>>8),1,8,126}
   if kind!="original-attack" {event=append(event,2,168,40,1,8,6)}
   ep,e:=write(fmt.Sprintf("%s-event-%d.bin",kind,repeat),append(event,0));if e!=nil{return e}
   cases=append(cases,probe_case{fmt.Sprintf("%s-r%d",kind,repeat),ip,ep,stride,8192+phase,purpose})
  }
 }
 _=b // Validate the natural-fresh artifact's existence before making output.
 encoded,e:=json.MarshalIndent(cases,"","  ");if e!=nil{return e};_,e=write("cases.json",append(encoded,'\n'));return e
}
