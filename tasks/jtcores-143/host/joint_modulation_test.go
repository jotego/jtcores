package main

import (
    "math"
    "os"
    "path/filepath"
    "strings"
    "testing"
)

// Independent forward stimulus integrates true instantaneous frequency, then
// applies an independently specified amplitude and DC before PCM quantization.
func joint_fixture(am_depth,pm_depth,carrier_phase,lfo_phase,dc,quantum float64,step bool) (joint_job,[]float64,[]float64) {
    job:=joint_job{increment:65984,sample_rate:27968.75,amplitude:8170,stride:2,
        window:128,hop:8,lag:16,start:4096,pre_end:512,values:make([]float64,16384)}
    amplitude_truth,cents_truth:=make([]float64,len(job.values)),make([]float64,len(job.values))
    phase:=carrier_phase
    for n:=range job.values {
        position:=lfo_phase
        if n>=4096 { position+=float64(n-4096)/2048 }
        fraction:=position-math.Floor(position)
        wave:=1-4*math.Abs(fraction-.5)
        if step { if fraction<.5 { wave=-1 } else { wave=1 } }
        am:=am_depth*(wave+1)/2
        cents:=pm_depth*wave
        amplitude_truth[n]=am;cents_truth[n]=cents
        value:=8170*math.Pow(10,-am/20)*math.Sin(phase)+dc
        if quantum>0 { value=math.Floor(value/quantum)*quantum }
        job.values[n]=value
        phase+=65984.0/(1<<20)*2*math.Pi*math.Exp2(cents/1200)
    }
    return job,amplitude_truth,cents_truth
}

func joint_truth(values []float64,at float64) float64 {
    i:=int(at);fraction:=at-float64(i)
    return values[i]+fraction*(values[i+1]-values[i])
}

func TestJointModerateTriangle(t *testing.T) {
    cases:=0
    max_am,max_pm,max_am_interior,max_pm_interior:=0.0,0.0,0.0,0.0
    false_pm,false_am:=0.0,0.0
    for _,depth:=range [][2]float64{{12,25},{12,0},{0,25},{0,0}} {
        for _,phase:=range []float64{0,.3,1.2,2.4} {
            for _,lfo_phase:=range []float64{0,.17,.61} {
                for _,dc:=range []float64{-8,0,137} {
                    job,am,pm:=joint_fixture(depth[0],depth[1],phase,lfo_phase,dc,16,false)
                    if e:=job.analyze();e!=nil { t.Fatal(e) }
                    if job.result.State!="window_averaged_features" || job.result.PreAM==nil || job.result.PrePM==nil { t.Fatalf("%+v",job.result) }
                    for _,point:=range job.points {
                        if point.Sample<4200 || point.Sample>16200 { continue }
                        if point.Attenuation==nil || point.Cents==nil { t.Fatal("missing moderate-depth feature") }
                        am_error:=math.Abs(*point.Attenuation-joint_truth(am,point.Sample))
                        pm_error:=math.Abs(*point.Cents-joint_truth(pm,point.Sample))
                        max_am=math.Max(max_am,am_error);max_pm=math.Max(max_pm,pm_error)
                        position:=lfo_phase+(point.Sample-4096)/2048
                        distance:=math.Abs(position*2-math.Round(position*2))*1024
                        if distance>96 {
                            max_am_interior=math.Max(max_am_interior,am_error)
                            max_pm_interior=math.Max(max_pm_interior,pm_error)
                        }
                        if am_error>.35 || pm_error>2 { t.Fatalf("full support errors am%g pm%g",am_error,pm_error) }
                        if depth[1]==0 { false_pm=math.Max(false_pm,math.Abs(*point.Cents)) }
                        if depth[0]==0 { false_am=math.Max(false_am,math.Abs(*point.Attenuation)) }
                        if depth[1]==0 && math.Abs(*point.Cents)>.25 { t.Fatalf("false PM from pure AM %g",*point.Cents) }
                        if depth[0]==0 && math.Abs(*point.Attenuation)>.12 { t.Fatalf("false AM from pure PM %g",*point.Attenuation) }
                    }
                    cases++
                }
            }
        }
    }
    if max_am_interior>.075 || max_pm_interior>.25 { t.Fatalf("interior errors am%g pm%g",max_am_interior,max_pm_interior) }
    t.Logf("%d integrated triangle/control cases: max errors full AM%.6fdB PM%.6fcents; interior AM%.6fdB PM%.6fcents",cases,max_am,max_pm,max_am_interior,max_pm_interior)
    t.Logf("Pure-control cross talk maxima: falsePM%.6fcents falseAM%.6fdB",false_pm,false_am)
}

func TestJointUnquantizedAndSteps(t *testing.T) {
    for _,phase:=range []float64{0,.3,1.2,2.4} {
        job,_,_:=joint_fixture(12,25,phase,.17,137,0,false)
        if e:=job.analyze();e!=nil || job.result.State!="window_averaged_features" { t.Fatalf("%v %+v",e,job.result) }
        job,_,_=joint_fixture(12,25,phase,.17,137,16,true)
        if e:=job.analyze();e!=nil { t.Fatal(e) }
        if job.result.Limited==0 || job.result.Limited>len(job.points)/2 || job.result.State!="window_limited_features" { t.Fatal("step transition was not marked limited") }
    }
}

func TestJointDeepAndCSV(t *testing.T) {
    job,_,_:=joint_fixture(12,25,.2,.17,-8,16,false)
    for i:=6000;i<len(job.values);i++ { job.values[i]=0 }
    if e:=job.analyze();e!=nil || job.result.Invalid==0 { t.Fatal(e,job.result) }
    for _,point:=range job.points {
        if point.Sample>6200 && (point.Attenuation!=nil || point.Phase!=nil || point.Cents!=nil) { t.Fatal("zero received log or phase") }
    }
    job.output=filepath.Join(t.TempDir(),"joint.csv")
    if e:=job.write_curve();e!=nil { t.Fatal(e) }
    raw,e:=os.ReadFile(job.output);if e!=nil { t.Fatal(e) }
    if strings.Contains(string(raw),"NaN") || strings.Contains(string(raw),"Inf") { t.Fatal("nonfinite CSV") }
    if e=job.write_curve();e==nil { t.Fatal("overwrote evidence") }
    job,_,_=joint_fixture(12,25,.2,.17,-8,16,false)
    for i:=6000;i<8000;i++ { job.values[i]*=.0001 }
    if e=job.analyze();e!=nil || job.result.Invalid==0 { t.Fatal(e,job.result) }
    for _,point:=range job.points {
        if point.Sample>6200 && point.Sample<7800 && point.Cents!=nil { t.Fatal("deep projection received phase slope") }
    }
    job,_,_=joint_fixture(12,25,.2,.17,-8,16,false)
    for i:=6000;i<len(job.values);i++ { job.values[i]=math.Floor(128*math.Sin(float64(i)*65984.0/(1<<20)*2*math.Pi)/16)*16 }
    if e=job.analyze();e!=nil { t.Fatal(e) }
    for _,point:=range job.points {
        if point.Sample>6200 && (point.Attenuation==nil || point.Phase!=nil || point.Cents!=nil || point.Quality!="low_amplitude_phase_unqualified") {
            t.Fatal("low-amplitude logarithm/phase qualification",point)
        }
    }
}

func TestJointBoundsAndInput(t *testing.T) {
    for _,kind:=range []string{"nan","overflow","carrier","pre","lag"} {
        job,_,_:=joint_fixture(12,25,.2,.17,-8,16,false)
        switch kind {
        case "nan":job.values[100]=math.NaN()
        case "overflow":job.values[100]=1e300
        case "carrier":job.increment=1000
        case "pre":job.pre_end=job.start+1
        case "lag":job.lag=17
        }
        if e:=job.analyze();e==nil { t.Fatal("accepted",kind) }
    }
    job,_,_:=joint_fixture(12,25,.2,.17,-8,16,false)
    job.pre_end=0
    if e:=job.analyze();e!=nil || job.result.PreAM!=nil || job.result.PrePM!=nil { t.Fatal("unprovided pre bound was scored",e) }
}
