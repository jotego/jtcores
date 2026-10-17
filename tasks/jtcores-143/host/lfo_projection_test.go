package main

import (
    "encoding/csv"
    "math"
    "os"
    "path/filepath"
    "sort"
    "strings"
    "testing"
)

// Forward independent stimulus: integrate every native frame, interpolate the
// specified half-native-frame latch age, then retain every eighth sample.
func projection_fixture(am,pm,carrier_phase,lfo_phase,age float64) (projection_job,[]float64,[]float64,[]float64) {
    samples:=16384
    total:=samples*8+32
    native_phase,native_am,native_pm:=make([]float64,total),make([]float64,total),make([]float64,total)
    two_pi:=2*math.Pi
    radians:=two_pi*32992/(1<<20)
    phase:=carrier_phase
    for k:=0;k<total;k++ {
        t:=float64(k-8)/8
        q:=math.Mod(math.Floor((t/2048+lfo_phase)*256),256)
        if q<0 { q+=256 }
        triangle:=1-math.Abs(q/128-1)
        attenuation:=am*triangle
        cents:=pm*(2*triangle-1)
        phase+=radians/8*math.Exp2(cents/1200)
        native_phase[k]=phase;native_am[k]=attenuation;native_pm[k]=cents
    }
    interpolate:=func(values []float64,where float64)float64 {
        first:=int(math.Floor(where));fraction:=where-float64(first)
        return values[first]+fraction*(values[first+1]-values[first])
    }
    job:=projection_job{values:make([]float64,samples)}
    truth_am,truth_pm,truth_phase:=make([]float64,samples),make([]float64,samples),make([]float64,samples)
    for n:=0;n<samples;n++ {
        where:=float64(n*8+8)+age*8
        theta:=interpolate(native_phase,where)
        attenuation:=interpolate(native_am,where)
        truth_am[n]=attenuation;truth_pm[n]=interpolate(native_pm,where);truth_phase[n]=theta-radians*float64(n)
        signal:=8170*math.Pow(10,-attenuation/20)*math.Sin(theta)
        job.values[n]=16*math.RoundToEven(signal/16)
    }
    return job,truth_am,truth_pm,truth_phase
}

func projection_median(values []float64) float64 {
    sorted:=append([]float64(nil),values...);sort.Float64s(sorted)
    return (sorted[(len(sorted)-1)/2]+sorted[len(sorted)/2])/2
}

type projection_errors struct { am_rms,am_max,pm_rms,pm_max,phase_rms float64 }

func projection_measure(job *projection_job,truth_am,truth_pm,truth_phase []float64) projection_errors {
    var result projection_errors
    var phase_errors []float64
    am_count,pm_count:=0,0
    for _,point:=range job.points {
        if point.Attenuation!=nil {
            error:=*point.Attenuation-truth_am[point.Sample]
            result.am_rms+=error*error;result.am_max=math.Max(result.am_max,math.Abs(error));am_count++
        }
        if point.Cents!=nil {
            error:=*point.Cents-truth_pm[point.Sample]
            result.pm_rms+=error*error;result.pm_max=math.Max(result.pm_max,math.Abs(error));pm_count++
        }
        if point.Phase!=nil { phase_errors=append(phase_errors,*point.Phase-truth_phase[point.Sample]) }
    }
    origin:=projection_median(phase_errors)
    for _,error:=range phase_errors { result.phase_rms+=(error-origin)*(error-origin) }
    result.am_rms=math.Sqrt(result.am_rms/float64(am_count));result.pm_rms=math.Sqrt(result.pm_rms/float64(pm_count));result.phase_rms=math.Sqrt(result.phase_rms/float64(len(phase_errors)))
    return result
}

func TestProjectionNativeIntegratedQualification(t *testing.T) {
    profiles:=[]struct{name string;am,pm float64}{ {"gate",0,0},{"am64",12,0},{"am127",23.8125,0},{"pm64",0,25},{"pm127",0,49.609375},{"combined64",12,25} }
    failures,cases:=0,0
    deep_max:=0.0
    for _,profile:=range profiles {
        worst:=projection_errors{}
        for _,phase:=range []float64{0,.7,2.2} {
            for _,age:=range []float64{-.0625,.0625} {
                job,am,pm,truth:=projection_fixture(profile.am,profile.pm,phase,.173+phase/10,age)
                if e:=job.analyze();e!=nil { t.Fatal(e) }
                if job.result.State!="projection_features" || job.result.Points!=2032 || job.result.ValidCents!=2028 { t.Fatal(job.result) }
                error:=projection_measure(&job,am,pm,truth)
                worst.am_rms=math.Max(worst.am_rms,error.am_rms);worst.am_max=math.Max(worst.am_max,error.am_max)
                worst.pm_rms=math.Max(worst.pm_rms,error.pm_rms);worst.pm_max=math.Max(worst.pm_max,error.pm_max);worst.phase_rms=math.Max(worst.phase_rms,error.phase_rms)
                if error.am_rms>.08 || error.pm_rms>1 || error.pm_max>3 || error.phase_rms>.005 { t.Fatalf("%s guard: %+v",profile.name,error) }
                if error.am_max>.3 {
                    if profile.name!="am127" { t.Fatalf("unexpected corner failure %s %+v",profile.name,error) }
                    failures++;deep_max=math.Max(deep_max,error.am_max)
                }
                cases++
            }
        }
        t.Logf("%s worst AMrms/max %.8f/%.8fdB PMrms/max %.8f/%.8fcents phaseRMS%.8frad",profile.name,worst.am_rms,worst.am_max,worst.pm_rms,worst.pm_max,worst.phase_rms)
    }
    if failures!=6 || deep_max<.35 || deep_max>.4 { t.Fatalf("AMD127 corner limitation was hidden: failures%d max%g",failures,deep_max) }
    t.Logf("%d native-integrated fixtures: retained %d AMD127 corner failures, max%.8fdB exceeds unchanged.3dB guard",cases,failures,deep_max)
}

func TestProjectionQuietLowAmplitudeAndGaps(t *testing.T) {
    job:=projection_job{values:make([]float64,16384)}
    if e:=job.analyze();e!=nil { t.Fatal(e) }
    if job.result.ValidLog!=0 || job.result.ValidPhase!=0 || job.result.ValidCents!=0 || job.result.State!="limited_projection_features" { t.Fatal(job.result) }
    two_pi:=2*math.Pi;radians:=two_pi*32992/(1<<20)
    for n:=range job.values { job.values[n]=128*math.Sin(float64(n)*radians) }
    if e:=job.analyze();e!=nil { t.Fatal(e) }
    if job.result.ValidLog!=job.result.Points || job.result.ValidPhase!=0 || job.result.ValidCents!=0 { t.Fatal(job.result) }
    job,_,_,_=projection_fixture(12,25,.7,.173,.0625)
    for n:=6000;n<8000;n++ { job.values[n]=0 }
    if e:=job.analyze();e!=nil { t.Fatal(e) }
    segments:=map[int]bool{}
    for _,point:=range job.points {
        if point.Phase!=nil { segments[point.Segment]=true }
        if point.Sample>6080 && point.Sample<7920 && (point.Attenuation!=nil || point.Phase!=nil || point.Cents!=nil) { t.Fatal("quiet gap assigned phase or logarithm") }
        if point.Cents!=nil {
            i:=(point.Sample-64)/8
            if job.points[i-2].Segment!=point.Segment || job.points[i+2].Segment!=point.Segment { t.Fatal("phase difference crosses gap") }
        }
    }
    if len(segments)!=2 { t.Fatal("phase gap not segmented",segments) }
}

func TestProjectionMalformedAndExclusiveCSV(t *testing.T) {
    for _,size:=range []int{0,128,160} {
        job:=projection_job{values:make([]float64,size)}
        if e:=job.analyze();e==nil { t.Fatal("accepted insufficient support",size) }
    }
    for _,bad:=range []float64{math.NaN(),math.Inf(1),1e308} {
        job,_,_,_:=projection_fixture(0,0,0,0,0);job.values[100]=bad
        if e:=job.analyze();e==nil { t.Fatal("accepted nonfinite/overflow projection",bad) }
    }
    for _,raw:=range []string{"sample,linear\n0,1\n2,2\n","sample,linear\n0,nan\n","linear\n1\n"} {
        if _,e:=read_phase_csv([]byte(raw),"linear");e==nil { t.Fatal("accepted malformed CSV") }
    }
    job:=projection_job{values:make([]float64,161),output:filepath.Join(t.TempDir(),"curve.csv")}
    if e:=job.analyze();e!=nil { t.Fatal(e) }
    if job.result.Points!=5 || job.result.InvalidCents!=1 { t.Fatal("incorrect support boundary",job.result) }
    hash,e:=job.write_curve();if e!=nil || len(hash)!=64 { t.Fatal(hash,e) }
    raw,e:=os.ReadFile(job.output);if e!=nil { t.Fatal(e) }
    if strings.Contains(string(raw),"NaN") || strings.Contains(string(raw),"Inf") { t.Fatal("nonfinite CSV value") }
    rows,e:=csv.NewReader(strings.NewReader(string(raw))).ReadAll();if e!=nil { t.Fatal(e) }
    for _,row:=range rows[1:] { if row[2]!="" || row[3]!="" || row[4]!="" { t.Fatal("quiet curve received log/phase/cents") } }
    if _,e=job.write_curve();e==nil { t.Fatal("overwrote evidence file") }
}
