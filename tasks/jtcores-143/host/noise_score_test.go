package main
import("encoding/json";"fmt";"math";"math/rand";"os";"testing";"path/filepath")
func TestIndependentBinaryHeldSource(t *testing.T){
 type observation struct{D int `json:"candidate_divisor"`;Phase int `json:"phase"`;Seed int64 `json:"seed"`;Amplitude float64 `json:"amplitude"`;State string `json:"state"`;Compatible []int `json:"compatible_divisors"`;Coarsest int `json:"coarsest"`;Changes int `json:"changes"`}
 rows:=[]observation{};ambiguous:=0
 for d:=1;d<=32;d++{for _,phase:=range []int{0,d/4,d/2,d-1}{for seed:=int64(1);seed<=3;seed++{for _,amplitude:=range []float64{8176,1024,32}{v:=independent_binary(d,phase,seed,amplitude,-8,.5);r:=score_noise(v);if r.State!="steady_two_level"{t.Fatalf("D%d phase%d seed%d amp%g state%s",d,phase,seed,amplitude,r.State)};found:=false;for _,c:=range r.Compatible{if c==d{found=true}};if !found{t.Fatalf("true candidate missing D%d compatible%v",d,r.Compatible)};if d>=3&&r.Coarsest!=d{t.Fatalf("unexpected coarsest%d forD%d",r.Coarsest,d)};if d<=2{ambiguous++;if r.RateState!="unresolved_one_or_more_updates_per_native_sample"{t.Fatal("high update rate incorrectly resolved")}};rows=append(rows,observation{d,phase,seed,amplitude,r.State,r.Compatible,r.Coarsest,r.Changes})}}}}
 out:=map[string]interface{}{"state":"independent_generic_binary_source_qualification_pass","records":len(rows),"native_frames_each":16384,"high_rate_ambiguities_retained":ambiguous,"generation":"math/rand generic Bernoulli bits held forD half-native frames; no chip polynomial/taps/seed identity","scope":"Finite listed seeds/phases/amplitudes; coarsest-compatible lattice is descriptive and does not identify a unique internal clock","observations":rows};data,e:=json.MarshalIndent(out,"","  ");if e!=nil{t.Fatal(e)};e=write_noise_qualification(t,"synthetic-lattice-qualification.json",append(data,'\n'));if e!=nil{t.Fatal(e)}
}
func independent_binary(d,phase int,seed int64,amplitude,dc,probability float64)[]float64{rng:=rand.New(rand.NewSource(seed));v:=make([]float64,16384);old:=-1;positive:=false;for n:=range v{current:=(2*n+phase)/d;for old<current{positive=rng.Float64()<probability;old++};sign:=-1.;if positive{sign=1};v[n]=math.Round(dc+amplitude*sign)+float64(rng.Intn(3)-1)};return v}
func TestControls(t *testing.T){
 cases:=map[string][]float64{};zero:=make([]float64,16384);stuck:=make([]float64,16384);sine:=make([]float64,16384);mixture:=independent_binary(16,3,9,8176,-8,.5);vary:=independent_binary(16,3,9,8176,-8,.5);irregular:=independent_binary(2,0,19,8176,-8,.5)
 for n:=range stuck{stuck[n]=16;sine[n]=math.Round(-8+8170*math.Sin(2*math.Pi*4124*float64(n)/(1<<20)));mixture[n]+=math.Round(500*math.Sin(float64(n)*.1));vary[n]=math.Round(vary[n]*(.8+.2*float64(n)/16384))};cases["quiet"]=zero;cases["stuck"]=stuck;cases["sine"]=sine;cases["sine_noise"]=mixture;cases["varying_gain"]=vary;cases["low_level"]=independent_binary(16,3,9,7,-8,.5);cases["dense_unresolved"]=irregular;results:=map[string]noise_result{}
 for name,v:=range cases{r:=score_noise(v);results[name]=r;expected:=map[string]string{"quiet":"quiet_exact_zero","stuck":"stuck_nonzero","sine":"not_stationary_two_level","sine_noise":"not_stationary_two_level","varying_gain":"not_stationary_two_level","low_level":"low_level_unresolved","dense_unresolved":"steady_two_level"}[name];if r.State!=expected{t.Fatalf("%s got%s expected%s",name,r.State,expected)}}
 for _,d:=range []int{3,16,32}{for _,p:=range []float64{.02,.1,.9,.98}{r:=score_noise(independent_binary(d,d-1,69,1024,100,p));if r.State!="steady_two_level"&&r.State!="finite_transition_coverage_insufficient"{t.Fatal(r.State)};results[fmt.Sprintf("bias_D%d_p%g",d,p)]=r}}
 data,e:=json.MarshalIndent(map[string]interface{}{"controls":results,"interpretation":"Biased finite records may be unresolved; no IID requirement imposed"},"","  ");if e!=nil{t.Fatal(e)};e=write_noise_qualification(t,"synthetic-controls.json",append(data,'\n'));if e!=nil{t.Fatal(e)}
}

// Ordinary tests use temporary files; explicit evidence output must be fresh.
func write_noise_qualification(t *testing.T,name string,data []byte)error {
 dir:=os.Getenv("JT143_NOISE_QUALIFICATION_DIR")
 if dir=="" { dir=t.TempDir() }
 f,e:=os.OpenFile(filepath.Join(dir,name),os.O_WRONLY|os.O_CREATE|os.O_EXCL,0600);if e!=nil { return e }
 _,e=f.Write(data);close_error:=f.Close();if e!=nil { return e };return close_error
}
