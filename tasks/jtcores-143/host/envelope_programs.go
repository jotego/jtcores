// Generate isolated single-operator attack stimuli for the native recorder.
package main

import (
    "crypto/sha256"
    "encoding/json"
    "flag"
    "fmt"
    "os"
    "path/filepath"
)

type envelope_case struct {
    Name string `json:"name"`
    Rate int `json:"attack_rate"`
    KeyScale int `json:"key_scale"`
    Profile string `json:"profile"`
    Init string `json:"init"`
    Event string `json:"event"`
    InitHash string `json:"init_sha256"`
    EventHash string `json:"event_sha256"`
    Increment int `json:"phase_increment_20bit"`
    Window int `json:"projection_window_samples"`
}

func main() {
    base:=flag.String("base","","canonical tone bytecode")
    output:=flag.String("output","","new output directory")
    first:=flag.Int("first",12,"first AR value; slower attacks need longer acquisition")
    last:=flag.Int("last",31,"last AR value")
    ks:=flag.Int("ks",0,"key scale, 0..3")
    profile:=flag.String("profile","attack","attack, hold-d1 or hold-d2")
    flag.Parse()
    if *base=="" || *output=="" || *first<0 || *last>31 || *first>*last || *ks<0 || *ks>3 ||
       (*profile!="attack" && *profile!="hold-d1" && *profile!="hold-d2") || flag.NArg()!=0 {
        fmt.Fprintln(os.Stderr,"Usage: envelope_programs -base TONE.bin -output NEW_DIRECTORY [-first AR -last AR -ks KS -profile NAME]")
        os.Exit(2)
    }
    if *profile!="attack" { *first=31;*last=31 }
    if e:=generate_envelopes(*base,*output,*first,*last,*ks,*profile);e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}

func generate_envelopes(base,output string,first,last,ks int,profile string) error {
    data,e:=os.ReadFile(base);if e!=nil { return e }
    if len(data)<4 || len(data)>8192 || string(data[len(data)-4:])!=string([]byte{1,8,0x40,0}) {
        return fmt.Errorf("base must be canonical tone ending with C2 key-on")
    }
    data=append(append([]byte(nil),data[:len(data)-4]...),0)
    registers,e:=envelope_registers(data);if e!=nil { return e }
    for reg,want:=range map[byte]byte{0x20:0xc7,0x28:0x4a,0x30:0,0x38:0,0x58:1,0x78:0,0x98:31,0xb8:0,0xd8:0,0xf8:15} {
        pos,ok:=registers[reg]
        if !ok || data[pos]!=want { return fmt.Errorf("base differs from controlled tone at %02x",reg) }
    }
    e=os.Mkdir(output,0755);if e!=nil { return e }
    event:=[]byte{2,0,1,1,8,0x40,0}
    event_path:=filepath.Join(output,"keyon.bin")
    e=os.WriteFile(event_path,event,0600);if e!=nil { return e }
    var cases []envelope_case
    for rate:=first;rate<=last;rate++ {
        init:=append([]byte(nil),data...)
        init[registers[0x58]]=8 // High carrier, even multiplier: qualified physical pitch.
        init[registers[0x98]]=byte(ks<<6|rate) // Set AR/KS before profile-specific decay conditioning.
        name:=fmt.Sprintf("ar%02d",rate)
        if profile=="hold-d1" { init[registers[0xf8]]=0xff;name=profile }
        if profile=="hold-d2" { init[registers[0xb8]]=31;init[registers[0xf8]]=0x4f;name=profile }
        path:=filepath.Join(output,name+"-init.bin")
        e=os.WriteFile(path,init,0600);if e!=nil { return e }
        cases=append(cases,envelope_case{name,rate,ks,profile,path,event_path,
            fmt.Sprintf("%x",sha256.Sum256(init)),fmt.Sprintf("%x",sha256.Sum256(event)),65984,32})
    }
    manifest,e:=json.MarshalIndent(cases,"","  ");if e!=nil { return e }
    e=os.WriteFile(filepath.Join(output,"cases.json"),append(manifest,'\n'),0600)
    if e!=nil { return e }
    fmt.Printf("Generated %d complete initialization and key-on stimuli\n",len(cases))
    return nil
}

func envelope_registers(data []byte) (map[byte]int,error) {
    registers:=make(map[byte]int)
    for pos:=0;pos<len(data)-1;pos+=3 {
        if pos+2>=len(data)-1 || data[pos]!=1 { return nil,fmt.Errorf("base contains non-register initialization") }
        registers[data[pos+1]]=pos+2
    }
    return registers,nil
}
