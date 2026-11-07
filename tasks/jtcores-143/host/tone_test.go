package main

import (
    "math"
    "testing"
)

func TestPhaseIncrement(t *testing.T) {
    for _,increment:=range []int{56,324,649,5196,8248,16496,20784,33376,69920} {
        values:=make([]float64,16384)
        for i:=range values {
            phase:=(uint64(i)*uint64(increment)+123456)&((1<<20)-1)
            // Independent 10-bit phase LUT and PCM quantization model.
            angle:=(float64(phase>>10)+.5)*2*math.Pi/1024
            values[i]=math.Floor(8170*math.Sin(angle)/16)*16
        }
        fit,e:=fit_phase(values,8170,-8)
        if e!=nil { t.Fatal(increment,e) }
        if fit.Rounded!=increment { t.Fatalf("increment %d: %+v",increment,fit) }
    }
}

func TestRejectOtherSignals(t *testing.T) {
    for _,kind:=range []string{"silent","square","variable_frequency"} {
        values:=make([]float64,16384)
        for i:=range values {
            switch kind {
            case "square": if i%128<64 { values[i]=4000 } else { values[i]=-4000 }
            case "variable_frequency": values[i]=8170*math.Sin(float64(i*i)*.000001)
            }
        }
        if _,e:=fit_phase(values,8170,-8);e==nil { t.Fatal("accepted",kind) }
    }
}
