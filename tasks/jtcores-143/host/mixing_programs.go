// Artifact-only stimuli from the root-approved primary-register scope.
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
    Kind string `json:"kind"`
    Reg int `json:"reg"`
    Value int `json:"value"`
    Count int `json:"count"`
}
type profile struct {
    Name string `json:"name"`
    Group string `json:"group"`
    Contributors int `json:"contributors"`
    TL int `json:"tl"`
    Pans []int `json:"pans"`
    ManualMasks []int `json:"manual_masks"`
    Pilot bool `json:"pilot"`
    Init string `json:"init"`
    InitHash string `json:"init_sha256"`
    ModelInit string `json:"model_init"`
    ModelInitHash string `json:"model_init_sha256"`
    Event string `json:"event"`
    EventHash string `json:"event_sha256"`
    InitOperations []operation `json:"init_operations"`
    ModelInitOperations []operation `json:"model_init_operations"`
    Stride int `json:"stride"`
    Frames int `json:"recorded_frames"`
    ModelWait int `json:"model_conditioning_master_clocks"`
    ModelPreheat int `json:"model_preheat_master_clocks"`
    PhysicalPreheat string `json:"physical_preheat"`
}
type generation struct { output string; cases []profile }

func main() {
    var job generation
    flag.StringVar(&job.output,"output","","fresh output directory")
    flag.Parse()
    e:=job.run();if e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}
func(job *generation)run()error {
    if job.output=="" || flag.NArg()!=0 { return fmt.Errorf("use -output NEW_DIRECTORY") }
    e:=os.Mkdir(job.output,0755);if e!=nil { return e }
    for _,n:=range []int{1,2,3,4,5,8,16,32} {
        for _,tl:=range []int{0,8,16,24,32,48} {
            e=job.add(fmt.Sprintf("sum-n%02d-tl%02d",n,tl),"sum",n,tl,192,false)
            if e!=nil { return e }
        }
    }
    for _,n:=range []int{4,8,32} {
        for _,pan:=range []int{0,64,128} {
            e=job.add(fmt.Sprintf("pan-n%02d-tl32-p%02x",n,pan),"pan",n,32,pan,false)
            if e!=nil { return e }
        }
    }
    for _,tl:=range []int{0,24,32} {
        for _,reverse:=range []bool{false,true} {
            name:="normal";if reverse { name="reversed" }
            e=job.add(fmt.Sprintf("split-tl%02d-%s",tl,name),"split",32,tl,64,reverse)
            if e!=nil { return e }
        }
    }
    if len(job.cases)!=63 { return fmt.Errorf("profile count") }
    e=job.json("cases.json",job.cases);if e!=nil { return e }
    pilot:=[]profile{}
    for _,c:=range job.cases { if c.Pilot { pilot=append(pilot,c) } }
    if len(pilot)!=9 { return fmt.Errorf("pilot count") }
    e=job.json("pilot.json",pilot);if e!=nil { return e }
    e=job.bytes("cleanup.bin",encode(cleanup()));if e!=nil { return e }
    e=job.bytes("event.bin",[]byte{0});if e!=nil { return e }
    fmt.Println("Generated 63 profiles and 9 proposed pilot profiles; no execution coverage")
    return nil
}
func(job *generation)add(name,group string,n,tl,pan int,reverse bool)error {
    c:=profile{Name:name,Group:group,Contributors:n,TL:tl,Pans:make([]int,8),ManualMasks:make([]int,8),Stride:1,Frames:16384,ModelWait:1790016,ModelPreheat:262144,PhysicalPreheat:"unqualified: root owns physical wait; target INIT has no delay opcode"}
    selected:=make(map[int]bool)
    for rank:=0;rank<n;rank++ {
        ch,logical:=rank/4,rank%4
        off:=[]int{0,16,8,24}[logical]
        mask:=[]int{8,16,32,64}[logical]
        selected[96+off+ch]=true
        c.ManualMasks[ch]|=mask
    }
    for ch:=0;ch<8;ch++ {
        c.Pans[ch]=pan
        if group=="split" {
            left:=ch<4;if reverse { left=!left }
            c.Pans[ch]=128;if left { c.Pans[ch]=64 }
        }
    }
    ops:=[]operation{write(20,48),write(15,0),write(1,0),write(16,0),write(17,0),write(18,0),write(24,0),write(25,0),write(25,128),write(27,0)}
    for ch:=0;ch<8;ch++ { ops=append(ops,write(8,ch)) }
    for reg:=32;reg<256;reg++ {
        value:=0
        switch {
        case reg<40:value=c.Pans[reg-32]|7
        case reg<48:value=74
        case reg>=96 && reg<128:value=127;if selected[reg] { value=tl }
        case reg>=128 && reg<160:value=31
        case reg>=224:value=15
        }
        ops=append(ops,write(reg,value))
    }
    for ch:=0;ch<8;ch++ { ops=append(ops,write(8,c.ManualMasks[ch]|ch)) }
    c.InitOperations=ops
    model:=append(cleanup(),delay(55938))
    model=append(model,ops...)
    model=append(model,delay(8192))
    c.ModelInitOperations=model
    c.Init=name+"-init.bin";c.ModelInit=name+"-model-init.bin";c.Event="event.bin"
    a,b:=encode(ops),encode(model)
    c.InitHash=hash(a);c.ModelInitHash=hash(b);c.EventHash=hash([]byte{0})
    switch name {
    case "sum-n01-tl00","sum-n04-tl00","sum-n05-tl00","sum-n08-tl00","sum-n32-tl00","sum-n32-tl32","pan-n32-tl32-p40","pan-n32-tl32-p00","split-tl32-normal":c.Pilot=true
    }
    e:=job.bytes(c.Init,a);if e!=nil { return e }
    e=job.bytes(c.ModelInit,b);if e!=nil { return e }
    job.cases=append(job.cases,c)
    return nil
}
func(job *generation)json(name string,value interface{})error {
    raw,e:=json.MarshalIndent(value,"","  ");if e!=nil { return e }
    return job.bytes(name,append(raw,'\n'))
}
func(job *generation)bytes(name string,data []byte)error {
    file,e:=os.OpenFile(filepath.Join(job.output,name),os.O_WRONLY|os.O_CREATE|os.O_EXCL,0600);if e!=nil { return e }
    _,e=file.Write(data);close_error:=file.Close();if e!=nil { return e };return close_error
}
func cleanup()[]operation {
    out:=[]operation{write(20,48),write(15,0)}
    for reg:=224;reg<256;reg++ { out=append(out,write(reg,15)) }
    for ch:=0;ch<8;ch++ { out=append(out,write(8,ch)) }
    return out
}
func write(reg,value int)operation { return operation{Kind:"write",Reg:reg,Value:value} }
func delay(count int)operation { return operation{Kind:"delay",Count:count} }
func encode(ops []operation)[]byte {
    out:=[]byte{}
    for _,op:=range ops {
        if op.Kind=="write" { out=append(out,1,byte(op.Reg),byte(op.Value)) } else { out=append(out,2,byte(op.Count),byte(op.Count>>8)) }
    }
    return append(out,0)
}
func hash(data []byte)string { return fmt.Sprintf("%x",sha256.Sum256(data)) }
