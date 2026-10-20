package main

import (
    "fmt"
    "math"
    "os"
    "path/filepath"
    "strings"
    "testing"
)

func TestFixedSixteenBlocks(t *testing.T) {
    o:=energy_fixture(t,16384,3,false,func(i int)int{a:=i/1024+1;if i%2!=0{return -a};return a})
    report,e:=o.analyze();if e!=nil{t.Fatal(e)}
    if len(report.Blocks)!=16||report.Block_summary["state"]!="sixteen_complete_fixed_blocks"||!report.Whole.Bipolar||report.Whole.Nonzero!=16384||report.Whole.Mean!=0 {t.Fatal(report.Whole)}
    for i,b:=range report.Blocks {
        a:=i+1
        if b.Index!=i||b.First!=i*1024||b.End!=(i+1)*1024||!b.Full||b.Statistics.Squares!=uint64(1024*a*a)||b.Statistics.RMS!=float64(a){t.Fatal(b)}
        if b.Normalized_energy==nil||*b.Normalized_energy!=float64(a*a)/256||*b.Normalized_rms!=float64(a)/16{t.Fatal(b)}
    }
    want_duration:=float64(16384*3)/55937.5;want_span:=float64(16383*3)/55937.5
    if math.Abs(report.Duration-want_duration)>4*(math.Nextafter(want_duration,math.Inf(1))-want_duration)||math.Abs(report.First_to_last-want_span)>4*(math.Nextafter(want_span,math.Inf(1))-want_span){t.Fatal(report.Duration,report.First_to_last)}
    if e=o.publish(report);e!=nil{t.Fatal(e)};if e=o.publish(report);e==nil{t.Fatal("existing report overwritten")}
}
func TestQuietAndSilentTarget(t *testing.T) {
    o:=energy_fixture(t,4096,32,false,func(i int)int{return 0});o.kind="quiet"
    report,e:=o.analyze();if e!=nil{t.Fatal(e)}
    if report.State!="QUIET_EXACTZERO_RETAINED"||report.Quiet_exactzero==nil||!*report.Quiet_exactzero||!report.Whole.Exact_zero||report.Whole.RMS!=0||report.Whole.Unique!=1{t.Fatal(report)}
    if len(report.Blocks)!=4||report.Block_summary["state"]!="not_exactly_sixteen_complete_blocks"{t.Fatal(report.Block_summary)}
    for _,b:=range report.Blocks{if b.Normalized_energy!=nil||b.Normalized_rms!=nil{t.Fatal("silent stream normalized to invented value")}}
    o.kind="target";report,e=o.analyze();if e!=nil{t.Fatal(e)}
    if report.State!="DESCRIPTIVE_PUBLIC_STREAM_RETAINED_NO_CONFORMANCE_SCORE"||report.Quiet_exactzero!=nil||!report.Whole.Exact_zero {t.Fatal(report)}
    o=energy_fixture(t,1024,1,false,func(i int)int{return 1});o.kind="quiet";report,e=o.analyze();if e!=nil{t.Fatal(e)}
    if report.State!="QUIET_NONZERO_OBSERVATION_RETAINED"||*report.Quiet_exactzero||report.Whole.Bipolar||report.Whole.RMS!=1||report.Whole.Mean!=1{t.Fatal(report)}
}
func TestModelCadenceAndCallerDuration(t *testing.T) {
    for _,stride:=range []int{1,3,32}{
        o:=energy_fixture(t,2049,stride,true,func(i int)int{if i%2==0{return -32768};return 32767})
        report,e:=o.analyze();if e!=nil{t.Fatal(e)}
        if report.First_clock==nil||*report.First_clock!=900||*report.Last_clock!=900+uint64(2048*64*stride)||*report.Cadence!=uint64(64*stride){t.Fatal(report)}
        if report.Whole.Minimum!=-32768||report.Whole.Maximum!=32767||report.Whole.Peak!=32768||report.Blocks[2].Full||report.Blocks[2].Statistics.Count!=1 {t.Fatal(report.Whole)}
        want:=float64(2049*stride)/55937.5
        if math.Abs(report.Duration-want)>1e-15{t.Fatal(report.Duration,want)}
        if len(report.Ignored)!=1||report.Ignored[0]!="auxiliary"{t.Fatal(report.Ignored)}
        // Independent hand calculation for1025 negative and1024 positive values.
        want_squares:=uint64(1025)*32768*32768+uint64(1024)*32767*32767
        if report.Whole.Squares!=want_squares||report.Whole.Sum!=-33792{t.Fatal(report.Whole)}
    }
}
func TestInvalidRawEnergyInputs(t *testing.T) {
    cases:=[]struct{name string;model bool;replace_old,replace_new string}{
        {"index gap",false,"1,7c01,-2","2,7c01,-2"},
        {"invalid raw hex",false,"7c00","zz00"},
        {"short raw hex",false,"7c00","000"},
        {"nonfinite PCM",false,",2\n",",NaN\n"},
        {"fractional PCM",false,",2\n",",2.0\n"},
        {"PCM above signed range",false,",2\n",",32768\n"},
        {"duplicate physical column",false,"sample,raw16_hex,linear","sample,sample,linear"},
        {"short CSV",false,"3,7c01,-2\n",""},
        {"clock cadence",true,"1,-2,2,1092,0","1,-2,2,1093,0"},
        {"unselected channel invalid",true,"0,2,-2,900,0","0,2,NaN,900,0"},
        {"missing model clock",true,"clock","ticks"},
    }
    for _,c:=range cases{t.Run(c.name,func(t *testing.T){
        o:=energy_fixture(t,4,3,c.model,func(i int)int{if i%2==0{return 2};return -2})
        data,e:=os.ReadFile(o.input);if e!=nil{t.Fatal(e)};if !strings.Contains(string(data),c.replace_old){t.Fatal("missing fixture edit",string(data))}
        if e=os.WriteFile(o.input,[]byte(strings.Replace(string(data),c.replace_old,c.replace_new,1)),0644);e!=nil{t.Fatal(e)}
        if _,e=o.analyze();e==nil{t.Fatal("malformed source accepted")}
        if _,e=os.Stat(o.output);!os.IsNotExist(e){t.Fatal("invalid source published")}
    })}
    for _,change:=range []func(*energy_options){func(o *energy_options){o.native_rate=0},func(o *energy_options){o.native_rate=math.NaN()},func(o *energy_options){o.native_rate=math.Inf(1)},func(o *energy_options){o.stride=2},func(o *energy_options){o.frames=0},func(o *energy_options){o.kind="pass"}}{
        o:=energy_fixture(t,4,1,false,func(i int)int{return 0});change(&o);if _,e:=o.analyze();e==nil{t.Fatal("invalid caller metadata accepted")}
    }
}
func energy_fixture(t *testing.T,frames,stride int,model bool,value func(int)int)energy_options {
    t.Helper();root:=t.TempDir();o:=energy_options{input:filepath.Join(root,"source.csv"),output:filepath.Join(root,"report.json"),column:"linear",kind:"target",case_name:"independent_integer_fixture",frames:frames,stride:stride,native_rate:55937.5}
    var text strings.Builder
    if model{o.column="left";text.WriteString("sample,left,right,clock,auxiliary\n")}else{text.WriteString("sample,raw16_hex,linear\n")}
    for i:=0;i<frames;i++{v:=value(i);if model{fmt.Fprintf(&text,"%d,%d,%d,%d,0\n",i,v,-v,900+i*64*stride)}else{fmt.Fprintf(&text,"%d,7c0%d,%d\n",i,i%2,v)}}
    // At the signed minimum the independent other channel uses a valid value.
    if model{text2:=strings.ReplaceAll(text.String(),",32768,",",32767,");text.Reset();text.WriteString(text2)}
    if e:=os.WriteFile(o.input,[]byte(text.String()),0644);e!=nil{t.Fatal(e)};return o
}
