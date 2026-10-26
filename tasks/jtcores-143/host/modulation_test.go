package main

import (
    "encoding/csv"
    "math"
    "os"
    "path/filepath"
    "strings"
    "testing"
)

// Independent stimulus: integrate the specified instantaneous frequency first,
// then quantize its sine. No inverse-phase estimator constructs the fixtures.
func modulation_fixture(mode,wave string,depth,carrier_phase,lfo_phase float64,samples,pre int) (modulation_job,[]float64) {
    job:=modulation_job{mode:mode,waveform:"periodic",increment:65984,sample_rate:27968.75,
        native_stride:2,amplitude:8170,offset:-8,window:32,hop:4,start:pre,pre_end:pre,expected_period:2048,
        values:make([]float64,samples)}
    if wave=="noise" { job.waveform="noise" }
    phases:=make([]float64,samples)
    phase:=carrier_phase
    random:=uint32(0x381799)
    noise:=.25
    for n:=range job.values {
        position:=lfo_phase
        if n>=pre { position+=float64(n-pre)/2048 }
        fraction:=position-math.Floor(position)
        var modulation float64
        switch wave {
        case "saw": modulation=2*fraction-1
        case "square": if fraction<.5 { modulation=1 } else { modulation=-1 }
        case "triangle": modulation=1-4*math.Abs(fraction-.5)
        case "noise":
            if n>=pre && (n-pre)%8==0 {
                random^=random<<13;random^=random>>17;random^=random<<5
                noise=float64(random&65535)/32767.5-1
            }
            modulation=noise
        }
        amplitude:=8170.0
        increment:=65984.0
        if mode=="am" { amplitude*=math.Pow(10,-depth*(modulation+1)/2/20) } else {
            increment*=math.Exp2(depth*modulation/1200)
        }
        phases[n]=phase
        job.values[n]=math.Floor(amplitude*math.Sin(phase)/16)*16
        phase+=increment/(1<<20)*2*math.Pi
    }
    return job,phases
}

func TestPMIntegratedPhase(t *testing.T) {
    measured,noise_cases:=0,0
    for _,depth:=range []float64{5,10,20,50,100,400,700,800} {
        for _,wave:=range []string{"saw","square","triangle","noise"} {
            for _,carrier_phase:=range []float64{0,.3,1.2,2.4} {
                for _,lfo_phase:=range []float64{0,.17,.61} {
                    job,truth:=modulation_fixture("pm",wave,depth,carrier_phase,lfo_phase,16384,4096)
                    phases,e:=job.phase_points();if e!=nil { t.Fatalf("phase depth%g %s carrier%g lfo%g: %v",depth,wave,carrier_phase,lfo_phase,e) }
                    offset:=phases[0].phase-truth[int(phases[0].sample)]
                    for _,point:=range phases {
                        error:=point.phase-truth[int(point.sample)]-offset
                        if math.Abs(error)>.005 { t.Fatalf("phase error %g for depth%g %s",error,depth,wave) }
                    }
                    e=job.analyze();if e!=nil { t.Fatalf("analyze depth%g %s: %v",depth,wave,e) }
                    if wave=="noise" {
                        noise_cases++
                        if job.result.Period!=nil && job.result.Period.Recorded!=0 { t.Fatal("assigned a noise period") }
                        if job.result.State!="noise_features_only" && job.result.State!="no_resolved_modulation" { t.Fatal(job.result.State) }
                        continue
                    }
                    if job.result.State!="periodic_measured" { t.Fatalf("depth%g %s carrier%g lfo%g: %s %+v",depth,wave,carrier_phase,lfo_phase,job.result.State,job.result.Period) }
                    measured++
                    if math.Abs(job.result.Period.Recorded-2048)>64 { t.Fatalf("wrong measured period %+v",job.result.Period) }
                    if job.result.Period.Native!=2*job.result.Period.Recorded { t.Fatal("native stride not retained") }
                    if job.result.Span.Minimum < -depth-2 || job.result.Span.Maximum>depth+2 { t.Fatalf("frequency overshoot depth%g %+v",depth,job.result.Span) }
                    if wave=="square" && (math.Abs(job.result.Span.P05+depth)>1 || math.Abs(job.result.Span.P95-depth)>1) {
                        t.Fatalf("square endpoints depth%g %+v",depth,job.result.Span)
                    }
                }
            }
        }
    }
    t.Logf("Qualified %d periodic PM and %d noise cases against integrated true phase, depths 5..800 cents",measured,noise_cases)
}

func TestAMProjectionAndPeriod(t *testing.T) {
    cases:=0
    for _,depth:=range []float64{6,12,24} {
        for _,wave:=range []string{"saw","square","triangle","noise"} {
            for _,phase:=range []float64{0,.7,2.1} {
                job,_:=modulation_fixture("am",wave,depth,phase,.17,16384,4096)
                e:=job.analyze();if e!=nil { t.Fatal(e) }
                if job.result.Gate==nil || !job.result.Gate.Stable { t.Fatalf("AM held gate not stable: %s %+v",wave,job.result.Gate) }
                if wave=="noise" {
                    if job.result.State!="noise_features_only" { t.Fatal(job.result.State) }
                } else {
                    if job.result.State!="periodic_measured" || math.Abs(job.result.Period.Recorded-2048)>32 { t.Fatalf("AM depth%g %s: %s %+v",depth,wave,job.result.State,job.result.Period) }
                    if math.Abs(job.result.Span.Minimum)>.25 || math.Abs(job.result.Span.Maximum-depth)>.25 { t.Fatalf("AM endpoints %+v",job.result.Span) }
                }
                cases++
            }
        }
    }
    t.Logf("Qualified %d AM cases including attenuated reset-held gates and noise",cases)
}

func TestModulationRejectionsAndLimits(t *testing.T) {
    for _,mode:=range []string{"am","pm"} {
        job,_:=modulation_fixture(mode,"triangle",0,.2,0,16384,4096)
        e:=job.analyze();if e!=nil || job.result.State!="no_resolved_modulation" { t.Fatal(mode,job.result.State,e) }
        job,_=modulation_fixture(mode,"triangle",20,.2,0,16384,4096)
        for _,expected:=range []float64{1024,1900,4096} {
            job.expected_period=expected
            e=job.analyze();if e!=nil || job.result.State!="expected_rate_mismatch" || job.result.Period.Recorded<2000 { t.Fatal(mode,expected,job.result.State,e) }
        }
        job.expected_period=0;job.expected_lfo=2*job.sample_rate/2048
        e=job.analyze();if e!=nil || job.result.State!="expected_rate_mismatch" { t.Fatal(mode,job.result.State,e) }
        job,_=modulation_fixture(mode,"triangle",20,.2,0,4096,1024)
        e=job.analyze();if e!=nil || job.result.State=="periodic_measured" || job.result.Period.Recorded!=0 { t.Fatal(mode,job.result.State,e) }
        for i:=range job.values { job.values[i]=0 }
        job.points=nil
        e=job.analyze();if e!=nil || job.result.State!="no_signal" { t.Fatal(mode,job.result.State,e) }
    }
    for _,kind:=range []string{"wrong_amplitude","wrong_carrier","alias","combined","nan"} {
        job,_:=modulation_fixture("pm","triangle",100,.7,0,16384,4096)
        switch kind {
        case "wrong_amplitude": job.amplitude=10000
        case "wrong_carrier": job.increment/=2
        case "alias": for n:=range job.values { job.values[n]=math.Floor(8170*math.Sin(float64(n)*.3*2*math.Pi)/16)*16 }
        case "combined": for n:=range job.values { job.values[n]*=.7+.2*math.Sin(float64(n)/200) }
        case "nan": job.values[200]=math.NaN()
        }
        if e:=job.analyze();e==nil { t.Fatal("accepted unqualified",kind) }
    }
    job,_:=modulation_fixture("am","triangle",12,.7,0,16384,4096)
    job.increment=50000
    e:=job.analyze();if e!=nil || job.result.State!="unqualified_reset_held_carrier" { t.Fatal("wrong AM carrier",job.result.State,e) }
    if _,e:=read_phase_csv([]byte("sample,linear\n0,1\n2,2\n"),"linear");e==nil { t.Fatal("accepted nonconsecutive samples") }
}

func TestAMZeroLogAndExclusiveCSV(t *testing.T) {
    job,_:=modulation_fixture("am","square",12,.2,0,16384,4096)
    for i:=5000;i<len(job.values);i++ { job.values[i]=0 }
    e:=job.analyze();if e!=nil || job.result.State!="quantization_limited" { t.Fatal(job.result.State,e) }
    job.output=filepath.Join(t.TempDir(),"curve.csv")
    e=job.write_curve();if e!=nil { t.Fatal(e) }
    raw,e:=os.ReadFile(job.output);if e!=nil { t.Fatal(e) }
    if strings.Contains(string(raw),"Inf") || strings.Contains(string(raw),"NaN") { t.Fatal("nonfinite logarithm exported") }
    rows,e:=csv.NewReader(strings.NewReader(string(raw))).ReadAll();if e!=nil { t.Fatal(e) }
    invalid:=0
    for _,row:=range rows[1:] {
        if row[10]=="false" { invalid++;if row[6]!="" { t.Fatal("zero amplitude received a logarithm") } }
    }
    if invalid==0 { t.Fatal("no explicit invalid log fields") }
    if e=job.write_curve();e==nil { t.Fatal("overwrote existing evidence") }
}

func TestExplicitResetHeldBoundary(t *testing.T) {
    job,_:=modulation_fixture("am","triangle",12,.2,0,16384,2048)
    job.start=4096
    job.pre_end=512
    e:=job.analyze();if e!=nil || job.result.Gate==nil || !job.result.Gate.Stable { t.Fatal(job.result.Gate,e) }
    if job.result.Gate.Points>=128 { t.Fatal("reset-held gate included the event-uncertainty region") }
    job.pre_end=0
    e=job.analyze();if e!=nil || job.result.Gate!=nil { t.Fatal("unevaluated pretrigger was labelled qualified",job.result.Gate,e) }
    job.pre_end=job.start+1
    if e=job.analyze();e==nil { t.Fatal("accepted pretrigger bound after the post-event bound") }
}

func TestNoiseDoesNotAcquireExpectedPeriod(t *testing.T) {
    for _,mode:=range []string{"am","pm"} {
        job,_:=modulation_fixture(mode,"noise",20,.7,0,16384,4096)
        job.waveform="periodic"
        e:=job.analyze();if e!=nil { t.Fatal(e) }
        if job.result.State=="periodic_measured" || job.result.Period!=nil && job.result.Period.Recorded!=0 {
            t.Fatal("noise acquired the expected period",mode,job.result.State)
        }
    }
}

// These finite synthetic cases establish unresolved observations, not an exact
// zero-leakage assertion for physical captures or every sub-cent waveform.
func TestPMWeakResolution(t *testing.T) {
    cases:=0
    for _,depth:=range []float64{0,.02,.1} {
        for _,wave:=range []string{"saw","square","triangle","noise"} {
            for _,phase:=range []float64{0,.7,2.1} {
                job,_:=modulation_fixture("pm",wave,depth,phase,.17,16384,4096)
                if e:=job.analyze();e!=nil { t.Fatal(e) }
                if job.result.State!="no_resolved_modulation" || job.result.Period!=nil && job.result.Period.Recorded!=0 {
                    t.Fatalf("weak depth%g %s phase%g: %s",depth,wave,phase,job.result.State)
                }
                cases++
            }
        }
    }
    t.Logf("%d finite weak/no-modulation controls remain unresolved; no zero-leakage claim",cases)
}
