package main

import (
    "math"
    "testing"
)

func TestWindowedAttack(t *testing.T) {
    for _,window:=range []int{32,128} {
        increment:=65984.0
        if window==128 { increment=16496 }
        for _,phase:=range []float64{0,.4,2} {
            values:=make([]float64,4096)
            for i:=range values {
                envelope:=math.Max(0,math.Min(1,float64(i-512)/1000))
                value:=8170*envelope*math.Sin(float64(i)*increment/(1<<20)*2*math.Pi+phase)
                values[i]=math.Floor(value/16)*16
            }
            result,e:=measure_envelope(values,increment,55937.5,window,8)
            if e!=nil || result.State!="measured" { t.Fatalf("window %d: %+v %v",window,result,e) }
            want:=800.0/55937.5*1000
            if math.Abs(result.Attack.Duration-want)>result.Attack.Resolution { t.Fatalf("duration outside window resolution: %+v",result.Attack) }
            if math.Abs(result.Plateau-8170)>8 { t.Fatalf("bad amplitude %f",result.Plateau) }
        }
    }
}

func TestEnvelopeQualification(t *testing.T) {
    for _,kind:=range []string{"silent","no_pretrigger","unfinished","wrong_carrier"} {
        values:=make([]float64,4096)
        for i:=range values {
            amplitude:=8170.0
            if kind=="silent" || (kind!="no_pretrigger" && i<512) { amplitude=0 }
            if kind=="unfinished" { amplitude*=float64(i)/float64(len(values)) }
            values[i]=amplitude*math.Sin(float64(i)*16496/(1<<20)*2*math.Pi)
        }
        increment:=16496.0
        if kind=="wrong_carrier" { increment=20784 }
        result,e:=measure_envelope(values,increment,55937.5,128,8)
        if e!=nil { t.Fatal(e) }
        if result.State=="measured" { t.Fatalf("accepted unqualified %s",kind) }
    }
}

func TestNonlinearAttack(t *testing.T) {
    for _,tau:=range []float64{30,1000} {
        for _,phase:=range []float64{.1,2.3,4.8} {
            values:=make([]float64,16384)
            for i:=range values {
                if i<512 { continue }
                amplitude:=8170*math.Exp(-11*math.Exp(-float64(i-512)/tau))
                values[i]=math.Floor(amplitude*math.Sin(float64(i)*65984/(1<<20)*2*math.Pi+phase)/16)*16
            }
            result,e:=measure_envelope(values,65984,55937.5,32,8)
            if e!=nil || result.Attack==nil { t.Fatalf("nonlinear attack: %s %v",result.State,e) }
            want:=tau*math.Log(math.Log(10)/(-math.Log(.9)))/55937.5*1000
            if math.Abs(result.Attack.Duration-want)>result.Attack.Resolution {
                t.Fatalf("nonlinear timing outside window resolution: got %f want %f",result.Attack.Duration,want)
            }
        }
    }
}
