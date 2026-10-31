package main

import (
    "fmt"
    "math/big"
    "os"
    "path/filepath"
    "strings"
    "testing"
)

func TestExactTraceAndPrefix(t *testing.T) {
    root:=t.TempDir();run:=filepath.Join(root,"capture");out:=filepath.Join(root,"out")
    fixture(t,run)
    input:=trace_input{run:run,out:out,maximum_delta_rounding:new(big.Int)}
    if e:=input.run_inventory();e!=nil {t.Fatal(e)}
    if len(input.writes)!=2||input.writes[0].Clock!=3999999||input.writes[1].Clock!=4000001 {t.Fatal(input.writes)}
    raw,e:=os.ReadFile(filepath.Join(out,"canonical-writes.csv"));if e!=nil {t.Fatal(e)}
    if !strings.Contains(string(raw),"0,0,1,0,999999750000000000,3999999,3999999,20,07") || !strings.Contains(string(raw),"1,2,3,1,250000000000,4000001,2,08,78") {t.Fatal(string(raw))}
    if e:=input.run_inventory();e==nil {t.Fatal("existing output overwritten")}
}
func TestInputRejection(t *testing.T) {
    cases:=[]struct{name,file,old,new string}{
        {"missing address","bus.csv","36864,32","36865,32"},
        {"repeated address","bus.csv","36865,7","36864,7"},
        {"unmatched final address","bus.csv","1,250000000000,36865,120,255\n",""},
        {"mask","bus.csv",",255\n",",127\n"},
        {"off source clock","bus.csv","999999500000000000","999999500000000001"},
        {"nonmonotonic","bus.csv","1,0,36864","0,0,36864"},
        {"bad atto range","bus.csv","999999500000000000","1000000000000000000"},
        {"wrong derived register","registers.csv",",32,7",",33,7"},
        {"wrong derived delta","registers.csv","0.000000500000000000","0.000000750000000000"},
        {"extra derived row","registers.csv","0.000000500000000000,8,120\n","0.000000500000000000,8,120\n0.000000000000000000,8,0\n"},
        {"NaN","registers.csv","0.000000500000000000","NaN"},
        {"failed terminal","exit-status.txt","0","124"},
        {"clock metadata","capture.txt","4000000","3580000"},
        {"count metadata","capture.txt","writes=2","writes=3"},
        {"incomplete reason","capture.txt","emulated_time_limit","wrapper_cleanup"},
    }
    for _,c:=range cases {t.Run(c.name,func(t *testing.T){
        root:=t.TempDir();run:=filepath.Join(root,"capture");fixture(t,run);p:=filepath.Join(run,c.file)
        data,e:=os.ReadFile(p);if e!=nil{t.Fatal(e)};if !strings.Contains(string(data),c.old){t.Fatal("fixture edit missing")};e=os.WriteFile(p,[]byte(strings.Replace(string(data),c.old,c.new,1)),0644);if e!=nil{t.Fatal(e)}
        input:=trace_input{run:run,out:filepath.Join(root,"out"),maximum_delta_rounding:new(big.Int)}
        if e:=input.run_inventory();e==nil{t.Fatal("malformed input accepted")};if _,e:=os.Stat(input.out);!os.IsNotExist(e){t.Fatal("invalid capture published output")}
    })}
}
func TestOperatorMappingsAndRates(t *testing.T) {
    var regs [256]uint8;var known [256]bool
    for _,a:=range []int{0x20,0x28,0x80,0x88,0x90,0x98,0xe0,0xe8,0xf0,0xf8}{known[a]=true}
    regs[0x20]=3;regs[0x28]=0x4a
    for slot:=0;slot<4;slot++ {regs[0x80+8*slot]=uint8(12+64*slot);regs[0xe0+8*slot]=uint8(slot)}
    p:=snapshot(0,2,regs,known)
    if p.Algorithm!=3||!p.Algorithm_known{t.Fatal(p)}
    for i,op:=range p.Operators {
        want_term:=[]int{2,4,9,18}[i]
        if op.AR!=12||op.KS_term!=want_term||op.AR_effective!=24+want_term||op.RR_mapped!=2*i+1||op.RR_effective!=2*(2*i+1)+want_term{t.Fatal(op)}
        if op.Command_on!=(i==2){t.Fatalf("mask02 is C1, not M2: %+v",op)}
    }
    regs[0x28]=0
    p=snapshot(0,15,regs,known);if p.Operators[0].AR_effective!=24||p.Operators[0].RR_effective!=2{t.Fatal(p)}
    known[0x80]=false;if snapshot(0,15,regs,known).Operators[0].Known{t.Fatal("unknown AR treated as known")}
}
func TestPublicFloatSerialization(t *testing.T) {
    // Source conversion multiplies, rather than divides, by 1e-18. This is
    // the independently observed decimal edge that the first check exposed.
    fraction:=float64(3913000000000000)*1e-18
    got:=fmt.Sprintf("%.18f",fraction)
    if got!="0.003913000000000001"{t.Fatal(got)}
    tm,e:=parse_time("1200","999999999999999999");if e!=nil{t.Fatal(e)}
    if total_attoseconds(tm).String()!="1200999999999999999999"{t.Fatal(total_attoseconds(tm))}
    if _,e:=source_clock(tm);e==nil{t.Fatal("nonlattice timestamp accepted")}
}
func fixture(t *testing.T,run string) {
    t.Helper();if e:=os.Mkdir(run,0755);e!=nil{t.Fatal(e)}
    files:=map[string]string{
        "bus.csv":"seconds,attoseconds,address,value,mask\n0,999999500000000000,36864,32,255\n0,999999750000000000,36865,7,255\n1,0,36864,8,255\n1,250000000000,36865,120,255\n",
        "registers.csv":"0.000000000000000000,32,7\n0.000000500000000000,8,120\n",
        "capture.txt":"start_seconds=0\nstart_attoseconds=0\nsource_clock_hz=4000000\nreason=emulated_time_limit\ntransactions=4\nwrites=2\nframes=120\nend_seconds=2\nend_attoseconds=0\n",
        "exit-status.txt":"0\n",
    }
    for n,data:=range files {if e:=os.WriteFile(filepath.Join(run,n),[]byte(data),0644);e!=nil{t.Fatal(e)}}
}
