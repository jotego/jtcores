// Generate complete, independent register programs for the PG measurement matrix.
package main

import (
    "crypto/sha256"
    "encoding/json"
    "flag"
    "fmt"
    "os"
    "path/filepath"
)

type program_case struct {
    Name string `json:"name"`
    Group string `json:"group"`
    Value int `json:"value"`
    Program string `json:"program"`
    SHA256 string `json:"program_sha256"`
}

func main() {
    base:=flag.String("base","","canonical tone bytecode from monitor.py emit tone")
    output:=flag.String("output","","new output directory")
    flag.Parse()
    if *base=="" || *output=="" || flag.NArg()!=0 {
        fmt.Fprintln(os.Stderr,"Usage: programs -base TONE.bin -output NEW_DIRECTORY")
        os.Exit(2)
    }
    if e:=generate_programs(*base,*output);e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}

func generate_programs(base,output string) error {
    data,e:=os.ReadFile(base);if e!=nil { return e }
    registers,e:=register_positions(data);if e!=nil { return e }
    for reg,want:=range map[byte]byte{0x20:0xc7,0x28:0x4a,0x30:0,0x38:0,0x58:1,0x78:0,0x98:31,0xb8:0,0xd8:0,0xf8:15,8:0x40} {
        pos,ok:=registers[reg]
        if !ok || data[pos]!=want { return fmt.Errorf("base is not the controlled tone: register %02x",reg) }
    }
    e=os.Mkdir(output,0755);if e!=nil { return e }
    var cases []program_case
    groups:=[]struct{name string; count int; kc byte}{
        {"kc",128,0x4a},{"kf",64,0x4a},{"dt1",8,0x4a},
        {"dt2",4,0x40},{"mul",16,0x40},
        {"mul-kc4a",11,0x4a},{"mul-kc50",8,0x50},{"mul-kc60",4,0x60},
    }
    for _,group:=range groups {
        for value:=0;value<group.count;value++ {
            name:=fmt.Sprintf("%s-%02x",group.name,value)
            program:=append([]byte(nil),data...)
            updates:=map[byte]byte{0x28:group.kc,0x30:0,0x58:1,0xd8:0}
            switch group.name {
            case "kc": updates[0x28]=byte(value)
            case "kf": updates[0x30]=byte(value<<2)
            case "dt1": updates[0x58]=byte(value<<4)|1
            case "dt2": updates[0xd8]=byte(value<<6)
            case "mul","mul-kc4a","mul-kc50","mul-kc60": updates[0x58]=byte(value)
            }
            for reg,value:=range updates { program[registers[reg]]=value }
            path:=filepath.Join(output,name+".bin")
            e=os.WriteFile(path,program,0600);if e!=nil { return e }
            cases=append(cases,program_case{name,group.name,value,path,fmt.Sprintf("%x",sha256.Sum256(program))})
        }
    }
    manifest,e:=json.MarshalIndent(cases,"","  ");if e!=nil { return e }
    e=os.WriteFile(filepath.Join(output,"cases.json"),append(manifest,'\n'),0600)
    if e!=nil { return e }
    fmt.Printf("Generated %d independent register programs\n",len(cases))
    return nil
}

func register_positions(data []byte) (map[byte]int,error) {
    positions:=make(map[byte]int)
    if len(data)==0 || len(data)>8192 { return nil,fmt.Errorf("invalid program size") }
    for pos:=0;pos<len(data); {
        op:=data[pos];pos++
        switch op {
        case 0:
            if pos!=len(data) { return nil,fmt.Errorf("trailing program bytes") }
            return positions,nil
        case 1,2:
            if pos+2>len(data) { return nil,fmt.Errorf("truncated instruction") }
            if op==1 { positions[data[pos]]=pos+1 }
            pos+=2
        case 3:
        default: return nil,fmt.Errorf("invalid opcode %02x",op)
        }
    }
    return nil,fmt.Errorf("missing completion opcode")
}
