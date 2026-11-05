package main

import (
    "math"
    "testing"
)

// Independent native-frame forward stimulus for the C0/stride8 route campaign.
// Sampling includes a half-native-frame serial-latch age, not aliased folding.
func route_fixture(mode string,depth,carrier_phase,lfo_phase,age float64,phase_steps int) modulation_job {
    const frames=16384
    const stride=8
    const native_step=4124.0
    const period=16384.0
    total:=frames*stride+32
    angles,attenuation:=make([]float64,total),make([]float64,total)
    phase:=carrier_phase
    for k:=0;k<total;k++ {
        relative:=float64(k-8)-4096
        am,pm:=0.0,0.0
        if relative<0 {
            if mode=="am" { am=depth }
        } else {
            q:=math.Mod(math.Floor((relative/period+lfo_phase)*256),256)
            if q<0 { q+=256 }
            triangle:=1-math.Abs(q/128-1)
            if mode=="am" { am=depth*triangle } else { pm=depth*(2*triangle-1) }
        }
        phase+=2*math.Pi*native_step/(1<<20)*math.Exp2(pm/1200)
        angles[k]=phase;attenuation[k]=am
    }
    interpolate:=func(values []float64,at float64)float64 {
        i:=int(math.Floor(at));fraction:=at-float64(i)
        return values[i]+fraction*(values[i+1]-values[i])
    }
    job:=modulation_job{mode:mode,waveform:"periodic",increment:32992,sample_rate:6992.1875,native_stride:8,
        amplitude:8170,offset:-8,window:64,hop:4,pre_end:512,start:3072,expected_period:2048,values:make([]float64,frames)}
    for n:=range job.values {
        at:=float64(n*stride+8)+age*stride
        angle:=interpolate(angles,at);am:=interpolate(attenuation,at)
        if phase_steps>0 { quantum:=2*math.Pi/float64(phase_steps);angle=quantum*math.Floor(angle/quantum) }
        signal:=8170*math.Pow(10,-am/20)*math.Sin(angle)
        job.values[n]=16*math.Floor(signal/16)
    }
    return job
}

func TestRouteNativeCarrierQualification(t *testing.T) {
    cases:=0
    maximum_period_error:=0.0
    for _,mode:=range []string{"am","pm"} {
        depth:=12.0
        if mode=="pm" { depth=25 }
        for _,carrier_phase:=range []float64{0,.3,1.2,2.4} {
            for _,lfo_phase:=range []float64{0,.17,.61} {
                for _,age:=range []float64{-.0625,.0625} {
                  for _,phase_steps:=range []int{0,1024} {
                    job:=route_fixture(mode,depth,carrier_phase,lfo_phase,age,phase_steps)
                    if e:=job.analyze();e!=nil { t.Fatal(mode,carrier_phase,lfo_phase,age,e) }
                    if job.result.Gate==nil || !job.result.Gate.Stable { t.Fatal("held carrier not stable",mode,job.result.Gate) }
                    if job.result.State!="periodic_measured" || job.result.Period==nil { t.Fatal(mode,job.result.State) }
                    p:=job.result.Period
                    if p.Bounds==nil || p.Bounds[0]>2048 || p.Bounds[1]<2048 || p.Native!=8*p.Recorded { t.Fatal("wrong independently measured period",mode,p) }
                    maximum_period_error=math.Max(maximum_period_error,math.Abs(p.Recorded-2048))
                    span:=job.result.Span
                    if mode=="am" && (math.Abs(span.Minimum)>.3 || math.Abs(span.Maximum-depth)>.3) { t.Fatal("AM finite endpoint guard",span) }
                    if mode=="pm" && (math.Abs(span.Minimum+depth)>2 || math.Abs(span.Maximum-depth)>2) { t.Fatal("PM finite endpoint guard",span) }
                    cases++
                  }
                }
            }
        }
    }
    t.Logf("%d independent C0 native-integrated AM/PM fixtures with ideal/generic1024-step phase; retained increment32992/window64; maximum measured-period error%.6f samples",cases,maximum_period_error)
}

func TestRouteZeroAndWrongRate(t *testing.T) {
    for _,mode:=range []string{"am","pm"} {
        job:=route_fixture(mode,0,.7,.17,.0625,0)
        if e:=job.analyze();e!=nil || job.result.State!="no_resolved_modulation" { t.Fatal(mode,job.result.State,e) }
        depth:=12.0
        if mode=="pm" { depth=25 }
        job=route_fixture(mode,depth,.7,.17,.0625,0)
        for _,wrong:=range []float64{1900,4096} {
            job.expected_period=wrong
            if e:=job.analyze();e!=nil { t.Fatal(e) }
            if job.result.State!="expected_rate_mismatch" || math.Abs(job.result.Period.Recorded-2048)>64 { t.Fatal("wrong expected rate became a measurement",mode,wrong,job.result) }
        }
    }
}
