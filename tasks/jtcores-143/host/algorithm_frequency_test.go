package main

import("encoding/json";"math";"os";"path/filepath";"testing")

func TestNativeIntegratedExposureFrequency(t *testing.T){
 runs:=[]zero_run{{2000,2064},{4000,4064},{6000,6064},{8000,8064}};records,fits_count:=0,0;maximum_frequency,maximum_residual:=0.,0.;rows:=[]map[string]interface{}{}
 for _,reverse:=range []bool{false,true}{for _,global:=range []float64{0,.37,2.4}{for _,age:=range []float64{-.5,.5}{for _,amplitude:=range []float64{2048,8170}{for _,steps:=range []int{0,1024}{for _,quantum:=range []float64{1,16}{
  order:=[]string{"M1","M2","C1","C2","M1"};if reverse{order=[]string{"M1","C2","C1","M2","M1"}};values:=native_exposures(order,runs,global,age,amplitude,steps,quantum,0);bounds,e:=observe_phase(values,runs,order,128,1000);if e!=nil{t.Fatal(e)}
  for _,bound:=range bounds{fit,e:=fit_free_sine(values,bound.First,bound.End);if e!=nil{t.Fatal(e)};frequency,ok:=fit["measured_increment_20bit"].(float64);if !ok{t.Fatal("known independent carrier unresolved",fit)};error:=math.Abs(frequency-32992);residual:=fit["relative_sine_rms"].(float64);maximum_frequency=math.Max(maximum_frequency,error);maximum_residual=math.Max(maximum_residual,residual);if error>.1||residual>.003{t.Fatal("original finite frequency/residual guard",fit)};fit["operator"]=bound.Operator;fit["source_record"]=records;rows=append(rows,fit);fits_count++};records++
 }}}}}};evidence:=map[string]interface{}{"state":"independent_native_integrated_free_frequency_qualification","records":records,"exposure_fits":fits_count,"maximum_frequency_deviation_20bit":maximum_frequency,"maximum_relative_residual":maximum_residual,"fixed_frequency_guard_20bit":.1,"fixed_relative_residual_guard":.003,"source":"Original generic native-phase integration and quantization controls; no expected frequency passed to fitter, no chip algorithm","observations":rows};write_frequency_evidence(t,evidence);t.Logf("%d records/%d free fits,max increment error%g,relative RMS%g",records,fits_count,maximum_frequency,maximum_residual)
}
func write_frequency_evidence(t *testing.T,value interface{}){
 t.Helper();data,e:=json.MarshalIndent(value,"","  ");if e!=nil{t.Fatal(e)};dir:=os.Getenv("JT143_PHASE_QUALIFICATION_DIR");if dir==""{dir=t.TempDir()};file,e:=os.OpenFile(filepath.Join(dir,"algorithm-frequency-qualification.json"),os.O_WRONLY|os.O_CREATE|os.O_EXCL,0600);if e!=nil{t.Fatal(e)};_,e=file.Write(append(data,'\n'));close_error:=file.Close();if e!=nil{t.Fatal(e)};if close_error!=nil{t.Fatal(close_error)}
}
