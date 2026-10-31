package main

import (
    "fmt"
    "math"
    "strings"
    "testing"
)

func decay_fixture(curve func(float64) float64) []decay_point {
    var points []decay_point
    for i:=0;i<300;i++ {
        at:=15.5+float64(i)*8
        points=append(points,decay_point{at,curve(at),.2})
    }
    return points
}

func TestDecayFeatures(t *testing.T) {
    for _,v:=range []struct{name string;curve func(float64) float64;state string}{
        {"held",func(x float64) float64{return 1000},"held_in_window"},
        {"silent",func(x float64) float64{return 0},"no_initial_signal"},
        {"wrong_level",func(x float64) float64{return 500},"no_clean_initial_plateau"},
        {"unfinished",func(x float64) float64{if x<600{return 1000};return 1000-(x-600)*.2},"incomplete_decay"},
        {"step",func(x float64) float64{if x<600{return 1000};return 0},"window_limited"},
        {"exponential",func(x float64) float64{if x<600{return 1000};return 1000*math.Exp(-(x-600)/400)},"measured"},
    } {
        t.Run(v.name,func(t *testing.T){
            result,e:=measure_decay(decay_fixture(v.curve),1000,32,1000,false)
            if e!=nil || result.State!=v.state { t.Fatalf("state %s: %v",result.State,e) }
            if v.name=="exponential" && math.Abs(result.Feature.Duration-math.Ln2*400)>.1 {
                t.Fatal(result.Feature)
            }
            if v.state!="measured" && v.state!="window_limited" && result.Feature!=nil {
                t.Fatal("assigned a fall duration to an unqualified curve")
            }
        })
    }
    points:=decay_fixture(func(x float64)float64{return 1000})
    if _,e:=measure_decay(points,1000,64,1000,false);e==nil { t.Fatal("accepted wrong projection window") }
    points[0].rms=100
    result,e:=measure_decay(points,1000,32,1000,false)
    if e!=nil || result.State!="no_clean_initial_plateau" { t.Fatal(result,e) }
}

func TestConfiguredKeyonDecay(t *testing.T) {
    points:=decay_fixture(func(x float64)float64{if x<600{return 0};return 1000*math.Exp(-(x-600)/400)})
    for i:=0;i<4;i++ { points[i].rms=0 }
    result,e:=measure_decay(points,1000,32,1000,true)
    if e!=nil || result.State!="measured" || result.InitialQuality || math.Abs(result.Feature.Duration-math.Ln2*400)>.1 {
        t.Fatal(result,e)
    }
    points[0].amplitude=1
    result,e=measure_decay(points,1000,32,1000,true)
    if e!=nil || result.State!="no_silent_pretrigger" { t.Fatal(result,e) }
    points[0].amplitude=0
    for i:=range points { points[i].amplitude*=.5 }
    result,e=measure_decay(points,1000,32,1000,true)
    if e!=nil || result.State!="no_resolved_peak" || result.Feature!=nil { t.Fatal(result,e) }
}

func TestDecayCurveParsing(t *testing.T) {
    var b strings.Builder
    b.WriteString("sample_center,amplitude,dc,carrier_rms\n")
    for i:=0;i<20;i++ { fmt.Fprintf(&b,"%.1f,1000,0,0.2\n",15.5+float64(i)*8) }
    good:=b.String()
    if _,e:=read_decay([]byte(good));e!=nil { t.Fatal(e) }
    for _,bad:=range []string{
        strings.Replace(good,",1000,",",NaN,",1),
        strings.Replace(good,",1000,",",-1,",1),
        strings.Replace(good,"23.5,","25.5,",1),
        strings.Replace(good,"carrier_rms","wrong_column",1),
        good+"1,2\n",
    } {
        if _,e:=read_decay([]byte(bad));e==nil { t.Fatal("accepted malformed curve") }
    }
}
