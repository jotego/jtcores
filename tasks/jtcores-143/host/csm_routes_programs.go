// Task-local CSM route proposal; public-register stimuli, no oracle logic.
package main

import (
    "crypto/sha256"
    "encoding/json"
    "flag"
    "fmt"
    "os"
    "path/filepath"
)

type route_operation struct {
    Kind string `json:"kind"`
    Reg int `json:"reg"`
    Value int `json:"value"`
    Count int `json:"delay_count,omitempty"`
    Role string `json:"role"`
}
type route_fixture struct {
    Name string `json:"name"`
    Profile string `json:"profile"`
    Channel int `json:"channel"`
    Slot int `json:"slot"`
    Operator string `json:"operator"`
    Offset int `json:"operator_register_offset"`
    Mask int `json:"selected_manual_key_mask"`
    Init string `json:"init"`
    ModelInit string `json:"model_init"`
    Event string `json:"event"`
    InitHash string `json:"init_sha256"`
    ModelHash string `json:"model_init_sha256"`
    EventHash string `json:"event_sha256"`
    InitOps []route_operation `json:"init_operations"`
    ModelOps []route_operation `json:"model_init_operations"`
    EventOps []route_operation `json:"event_operations"`
    ManualControl string `json:"matched_manual_control,omitempty"`
    BackgroundControl string `json:"matched_background_control"`
    Carrier int `json:"manual_carrier_increment_to_qualify"`
    Frames int `json:"recorded_frames"`
    Stride int `json:"stride"`
    Fs float64 `json:"recorded_sample_rate_hz"`
    Period int `json:"timer_a_period_native_samples"`
    MinimumPost int `json:"minimum_actual_post_guard_samples"`
    Guard int `json:"final_event_host_upper_guard_samples"`
    Prefix int `json:"guaranteed_early_prefix_samples"`
    Limits []string `json:"limits"`
}

func main() {
    output:=flag.String("output","","fresh artifact directory; generates fixed72-profile proposal")
    flag.Parse()
    if *output=="" || flag.NArg()!=0 { fmt.Fprintln(os.Stderr,"use -output NEW_DIRECTORY");os.Exit(1) }
    e:=generate_routes(*output);if e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}

func generate_routes(output string) error {
    e:=os.Mkdir(output,0755);if e!=nil { return e }
    var cases []route_fixture
    for _,profile:=range []string{"manual-positive","automatic-csm","background-null"} {
        for channel:=0;channel<8;channel++ {
            slots:=4;if profile=="background-null" { slots=1 }
            for slot:=0;slot<slots;slot++ {
                c:=make_route(profile,channel,slot)
                for _,item:=range []struct{suffix string;ops []route_operation;path,hash *string}{
                    {"init",c.InitOps,&c.Init,&c.InitHash},
                    {"model-init",c.ModelOps,&c.ModelInit,&c.ModelHash},
                    {"event",c.EventOps,&c.Event,&c.EventHash},
                } {
                    b:=encode_route(item.ops)
                    if len(b)>8192 { return fmt.Errorf("program exceeds monitor bound") }
                    *item.path=filepath.Join(output,c.Name+"-"+item.suffix+".bin")
                    *item.hash=fmt.Sprintf("%x",sha256.Sum256(b))
                    e=os.WriteFile(*item.path,b,0600);if e!=nil { return e }
                }
                cases=append(cases,c)
            }
        }
    }
    if len(cases)!=72 { return fmt.Errorf("unexpected route count") }
    data,e:=json.MarshalIndent(cases,"","  ");if e!=nil { return e }
    e=os.WriteFile(filepath.Join(output,"cases.json"),append(data,'\n'),0600);if e!=nil { return e }
    e=os.WriteFile(filepath.Join(output,"cleanup.bin"),encode_route(route_cleanup()),0600);if e!=nil { return e }
    return os.WriteFile(filepath.Join(output,"status.bin"),[]byte{3,0},0600)
}

func make_route(profile string,channel,slot int) route_fixture {
    operators:=[]string{"m1","m2","c1","c2"}
    offsets:=[]int{0,8,16,24}
    masks:=[]int{8,32,16,64}
    name:=fmt.Sprintf("%s-ch%d-%s",profile,channel,operators[slot])
    operator:=operators[slot];offset:=offsets[slot];mask:=masks[slot]
    if profile=="background-null" { name=fmt.Sprintf("background-null-ch%d",channel);slot=-1;operator="none";offset=-1;mask=0 }
    init:=[]route_operation{route_write(20,48,"FIRST disable CSM/stop timers/reset both flags")}
    for ch:=0;ch<8;ch++ { init=append(init,route_write(8,ch,"all manual keys off")) }
    for _,w:=range [][2]int{{1,0},{15,0},{24,0},{25,0},{25,128},{27,0},{16,128},{17,0},{18,255}} {
        init=append(init,route_write(w[0],w[1],"explicit globals; Timer A preload512; B remains stopped"))
    }
    for reg:=32;reg<256;reg++ {
        value:=0
        if reg==32+channel { value=199 }
        if reg==40+channel { value=74 }
        if reg>=96 && reg<128 { value=127 }
        if reg>=224 { value=15 }
        if slot>=0 {
            switch reg {
            case 64+offset+channel:value=8
            case 96+offset+channel:value=0
            case 128+offset+channel:value=31
            }
        }
        init=append(init,route_write(reg,value,"complete image; unused AR0/KS0/TL127/MUL0/RR15; only selected route differs"))
    }
    init=append(init,route_write(20,0,"timers and CSM remain stopped until EVENT"))
    event:=[]route_operation{{Kind:"delay",Count:2048,Role:"pretrigger, explicit model32 master/count; physical CPU timing differs"}}
    period:=512;minimum:=3136;carrier:=65984
    if profile=="manual-positive" {
        event=append(event,route_write(8,mask|channel,"only selected operator manual KEYON; CSM/timers stay stopped"));period=0;minimum=1024
    } else {
        event=append(event,route_write(20,129,"CSM and Timer A ON; timer flag enables remain OFF"))
    }
    if profile=="background-null" { carrier=0;minimum=1024 }
    model:=append([]route_operation{},route_cleanup()...)
    model=append(model,route_operation{Kind:"delay",Count:55938,Role:"explicit model-only cleanup dwell1790016master; no physical observed-wait claim"})
    model=append(model,init...)
    manual_control:=fmt.Sprintf("manual-positive-ch%d-%s",channel,operator)
    if profile=="background-null" { manual_control="" }
    return route_fixture{Name:name,Profile:profile,Channel:channel,Slot:slot,Operator:operator,Offset:offset,Mask:mask,InitOps:init,ModelOps:model,EventOps:event,ManualControl:manual_control,BackgroundControl:fmt.Sprintf("background-null-ch%d",channel),Carrier:carrier,Frames:16384,Stride:1,Fs:55937.5,Period:period,MinimumPost:minimum,Guard:128,Prefix:512,Limits:[]string{
        "Proposal only: no route model or physical execution before review",
        "Operator addresses M1/M2/C1/C2 offsets0/8/16/24 map KEYON masks08/20/10/40; primary printed5/PDF6 and printed16/PDF17",
        "Every channel/operator manual carrier must be measured independently; inherited65984 is a hypothesis until qualified",
        "Automatic selected-route output needs nonzero observation plus matched manual carrier and same-channel background control before all32-slot coverage",
        "Unused TL127 is not assumed mute; background exactzero/levels are measured, not manufactured",
        "AR31 envelope confound retained; no precise attackshape, pulsewidth, first-load,64-master phase or bus-latency claim",
        "Short EVENT ends after final write; status03/00 only after capture in separate logged command",
        "Actual final EVENT host upper+128 must leave required horizon; no planned bound substitutes",
        "Native energy classifier unchanged; finite period support does not recover hidden key pulses or clocks",
        "Physical IRQ unobserved; flag-enable behavior is separate from CSM audio",
        "Physical pilot and strong stop-first cleanup must qualify before any route batch",
    }}
}

func route_write(reg,value int,role string) route_operation {
    return route_operation{Kind:"write",Reg:reg,Value:value,Role:role}
}

func route_cleanup() []route_operation {
    ops:=[]route_operation{route_write(20,48,"FIRST disable CSM/stop timers/reset flags"),route_write(15,0,"noise off")}
    for reg:=224;reg<256;reg++ { ops=append(ops,route_write(reg,15,"all RR15 before keyoff")) }
    for ch:=0;ch<8;ch++ { ops=append(ops,route_write(8,ch,"all manual keys off")) }
    return ops
}

func encode_route(ops []route_operation) []byte {
    var b []byte
    for _,o:=range ops {
        if o.Kind=="write" { b=append(b,1,byte(o.Reg),byte(o.Value)) }
        if o.Kind=="delay" { b=append(b,2,byte(o.Count),byte(o.Count>>8)) }
    }
    return append(b,0)
}
