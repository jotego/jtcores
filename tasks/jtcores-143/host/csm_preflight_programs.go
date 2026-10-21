// Task-local adverse CSM cleanup preparation; no implementation oracle.
package main

import (
    "crypto/sha256"
    "encoding/json"
    "flag"
    "fmt"
    "os"
    "path/filepath"
)

type operation struct {
    Reg int `json:"reg"`
    Value int `json:"value"`
    Role string `json:"role"`
}
type fixture struct {
    Name string `json:"name"`
    Init string `json:"init"`
    InitHash string `json:"init_sha256"`
    Operations []operation `json:"init_ordered_writes"`
    ManualMasks []int `json:"final_manual_masks_by_channel"`
    PositiveFrames int `json:"positive_native_frames"`
    QuietFrames int `json:"quiet_native_frames"`
    Repetitions int `json:"repetitions"`
    Carrier int `json:"individual_native_carrier_increment"`
    Limits []string `json:"limits"`
}
func encode(ops []operation) []byte {
    var b []byte
    for _,o:=range ops { b=append(b,1,byte(o.Reg),byte(o.Value)) }
    return append(b,0)
}
func main() {
    output:=flag.String("output","","fresh artifact directory")
    flag.Parse()
    if *output=="" || flag.NArg()!=0 { fmt.Fprintln(os.Stderr,"use -output NEW_DIRECTORY");os.Exit(1) }
    if e:=os.Mkdir(*output,0755);e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
    var cases []fixture
    for _,manual:=range []bool{false,true} {
        name:="all32-auto-csm-rr0"
        if manual { name="all32-manual-held-csm-rr0" }
        ops:=[]operation{{20,48,"FIRST stop CSM and both timers, clear flags"}}
        for ch:=0;ch<8;ch++ { ops=append(ops,operation{8,ch,"manual all operators OFF"}) }
        for _,w:=range [][2]int{{1,0},{15,0},{24,0},{25,0},{25,128},{27,0},{16,128},{17,0},{18,255}} {
            ops=append(ops,operation{w[0],w[1],"explicit globals, Timer A period512; Timer B remains stopped"})
        }
        for reg:=32;reg<256;reg++ {
            value:=0
            switch {
            case reg<40:value=199 // Both outputs, FB0, ALG7.
            case reg<48:value=74 // KC4A for all eight channels.
            case reg>=128 && reg<160:value=31 // AR31, KS0 for all 32 operators.
            }
            ops=append(ops,operation{reg,value,"complete 224-register image: MUL0 TL0 D1R0 D2R0 D1L0 RR0, no AM/PM"})
        }
        masks:=make([]int,8)
        if manual {
            for ch:=0;ch<8;ch++ { masks[ch]=120;ops=append(ops,operation{8,120|ch,"all four manual key bits held on this channel"}) }
        }
        ops=append(ops,operation{20,133,"start Timer A with CSM and A flag enable, Timer B stopped"})
        b:=encode(ops);path:=filepath.Join(*output,name+"-init.bin")
        if e:=os.WriteFile(path,b,0600);e!=nil { panic(e) }
        cases=append(cases,fixture{Name:name,Init:path,InitHash:fmt.Sprintf("%x",sha256.Sum256(b)),Operations:ops,ManualMasks:masks,PositiveFrames:16384,QuietFrames:4096,Repetitions:3,Carrier:4124,Limits:[]string{"Proposed physical preflight only; no hardware/model execution authorized by generator","Positive is raw nonzero/bipolar evidence, not a carrier fit: 32 coherent voices can clip","AR31 CSM-only model silence cannot qualify an adverse positive; physical positive must be observed","After positive, use frozen cleanup FIRST14=30, observed host wait>=0.5 seconds, then quiet capture with exact zero BOTH and status0","Twelve total captures: two histories times three repetitions times positive and quiet"}})
    }
    b,e:=json.MarshalIndent(cases,"","  ");if e!=nil { panic(e) }
    if e=os.WriteFile(filepath.Join(*output,"cases.json"),append(b,'\n'),0600);e!=nil { panic(e) }
    // Status is a separate observation and adds no register writes.
    if e=os.WriteFile(filepath.Join(*output,"status-only.bin"),[]byte{3,0},0600);e!=nil { panic(e) }
}
