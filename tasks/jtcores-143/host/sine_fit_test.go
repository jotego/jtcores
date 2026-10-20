package main

import("math";"testing")

func TestIndependentFreeSineFrequency(t *testing.T){
 maximum:=0.;records:=0
 for _,increment:=range []float64{31000,32992,65984}{for _,amplitude:=range []float64{2048,8170}{for _,phase:=range []float64{0,.37,2.4}{for _,quantum:=range []float64{1,16}{
  values:=make([]float64,4096);for n:=range values{values[n]=-8+quantum*math.RoundToEven(amplitude*math.Sin(2*math.Pi*increment*float64(n)/(1<<20)+phase)/quantum)};r,e:=fit_free_sine(values,128,2048);if e!=nil{t.Fatal(e)};measured,ok:=r["measured_increment_20bit"].(float64);if !ok{t.Fatal("known tone unresolved",r)};difference:=math.Abs(measured-increment);maximum=math.Max(maximum,difference);if difference>.1||r["relative_sine_rms"].(float64)>.003{t.Fatalf("independent tone increment%g got%v",increment,r)};records++
 }}}};t.Logf("%d independent tones,maximum increment error %g",records,maximum)
}
func TestFreeSineUnresolvedAndInvalid(t *testing.T){
 for _,value:=range []float64{0,10}{v:=make([]float64,1024);for i:=range v{v[i]=value};r,e:=fit_free_sine(v,0,len(v));if e!=nil||r["measured_increment_20bit"]!=nil{t.Fatal("quiet/stuck assigned frequency",r,e)}}
 v:=make([]float64,1024);for n:=range v{v[n]=1000*math.Sin(2*math.Pi*float64(n)/1024)};r,e:=fit_free_sine(v,0,len(v));if e!=nil||r["state"]!="unresolved_insufficient_crossings"{t.Fatal("insufficient cycles accepted",r,e)}
 for _,bounds:=range [][2]int{{-1,1024},{0,1025},{10,10}}{if _,e:=fit_free_sine(v,bounds[0],bounds[1]);e==nil{t.Fatal("invalid bounds accepted",bounds)}}
 for _,value:=range []float64{math.NaN(),math.Inf(1),math.Inf(-1)}{copy_v:=append([]float64(nil),v...);copy_v[512]=value;if _,e:=fit_free_sine(copy_v,0,len(copy_v));e==nil{t.Fatal("nonfinite accepted")}}
}
