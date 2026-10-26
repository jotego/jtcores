// Generate independent timer flag controls and guarded period measurements.
package main

import (
    "crypto/sha256"
    "encoding/json"
    "flag"
    "fmt"
    "os"
    "path/filepath"
)

type timer_case struct {
    Name string `json:"name"`
    Program string `json:"program"`
    SHA256 string `json:"program_sha256"`
    Timer string `json:"timer,omitempty"`
    Preload int `json:"preload,omitempty"`
    Mode int `json:"mode"`
    Delay int `json:"delay"`
    Expected int `json:"expected_status"`
}

func main() {
    output:=flag.String("output","","new output directory")
    flag.Parse()
    if *output=="" || flag.NArg()!=0 {
        fmt.Fprintln(os.Stderr,"Usage: timer_programs -output NEW_DIRECTORY")
        os.Exit(2)
    }
    if e:=generate_timers(*output);e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}

func generate_timers(output string) error {
    e:=os.Mkdir(output,0755);if e!=nil { return e }
    var cases []timer_case
    for mode:=0;mode<16;mode++ {
        expected:=0
        if mode&5==5 { expected|=1 }
        if mode&10==10 { expected|=2 }
        data:=[]byte{1,0x14,0x30,1,0x10,255,1,0x11,3,1,0x12,255}
        data=append(data,timer_finish(mode,255)...)
        cases=append(cases,timer_case{Name:fmt.Sprintf("control-%02x",mode),Mode:mode,Delay:255,Expected:expected})
        e=save_timer(output,&cases[len(cases)-1],data);if e!=nil { return e }
    }
    for _,timer:=range []string{"a","b"} {
        preloads:=[]int{0,256,512,768,900}
        if timer=="b" { preloads=[]int{0,64,128,192,224} }
        for _,preload:=range preloads {
            period,span,mode,expected:=(1024-preload)*64,128,5,1
            data:=[]byte{1,0x14,0x30,1,0x10,byte(preload>>2),1,0x11,byte(preload&3)}
            if timer=="b" {
                period,span,mode,expected=(256-preload)*1024,1100,10,2
                data=[]byte{1,0x14,0x30,1,0x12,byte(preload)}
            }
            low,high:=0,0
            for n:=0;n<=16384;n++ {
                if timer_elapsed(n)<float64(period-span) { low=n }
                if high==0 && timer_elapsed(n)>float64(period+200) { high=n }
            }
            for _,point:=range []struct{name string;delay,status int}{{"clear",low,0},{"overflow",high,expected}} {
                name:=fmt.Sprintf("period-%s-%04d-%s",timer,preload,point.name)
                cases=append(cases,timer_case{Name:name,Timer:timer,Preload:preload,Mode:mode,Delay:point.delay,Expected:point.status})
                program:=append(append([]byte(nil),data...),timer_finish(mode,point.delay)...)
                e=save_timer(output,&cases[len(cases)-1],program);if e!=nil { return e }
            }
        }
    }
    manifest,e:=json.MarshalIndent(cases,"","  ");if e!=nil { return e }
    e=os.WriteFile(filepath.Join(output,"cases.json"),append(manifest,'\n'),0600)
    if e!=nil { return e }
    fmt.Printf("Generated %d independent timer programs\n",len(cases))
    return nil
}

func timer_finish(mode,delay int) []byte {
    // Read status before stopping/clearing; monitor retains that read in its reply.
    return []byte{1,0x14,byte(mode),2,byte(delay),byte(delay>>8),3,1,0x14,0x30,0}
}

func save_timer(output string,c *timer_case,data []byte) error {
    c.Program=filepath.Join(output,c.Name+".bin")
    c.SHA256=fmt.Sprintf("%x",sha256.Sum256(data))
    return os.WriteFile(c.Program,data,0600)
}

func timer_elapsed(delay int) float64 {
    // Monitor high-speed CPU cycles, converted by YM/CPU=4/3. The fixed
    // start-write to status-read overhead was independently measured in MAME
    // executing the assembled monitor, not fitted to physical overflow flags.
    return float64(28*delay+4*(delay/256))*4/3+246.66666666666666
}
