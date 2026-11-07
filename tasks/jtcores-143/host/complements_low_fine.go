// New finite fast12 diagnostics; published AM observer functions/states unchanged.
package main
import("math";"fmt")
var fast_rates=[]int{0xc0,0xcf,0xd0,0xdf,0xe0,0xe1,0xe7,0xe8,0xee,0xef,0xf0,0xff}
type fast_fine_result struct {
 State string `json:"state"`; Crossings []float64 `json:"independent_crossings_recorded_samples"`; Median float64 `json:"published_median_period"`; Span float64 `json:"endpoint_span_period"`; Bound float64 `json:"endpoint_span_period_bound"`; RelativeBound float64 `json:"relative_propagated_bound"`; Expected float64 `json:"nominal_hypothesis_period"`; RelativeError float64 `json:"span_relative_error"`; MedianRelativeError float64 `json:"median_relative_error"`; Eligible bool `json:"eligible"`; Match bool `json:"finite_one_percent_and_propagated_bound_match"`; Reasons []string `json:"unqualified_reasons,omitempty"`; Limits []string `json:"limits"`
}
func fast_nominal(rate int)float64{return float64(int64(1)<<30)/float64((int64(16+(rate&15))<<uint(rate>>4))*4)}
func fast_valid_rate(rate int)bool{for _,r:=range fast_rates{if rate==r{return true}};return false}
func fast_job(values []float64,period float64)modulation_job{return modulation_job{mode:"am",waveform:"periodic",increment:263936,sample_rate:13984.375,native_stride:4,amplitude:8170,offset:-8,window:16,hop:4,start:3072,end:len(values),pre_end:512,expected_period:period,values:values}}
func fast_fine(job *modulation_job,expected float64)fast_fine_result{
 r:=fast_fine_result{State:"finite_precision_unqualified",Expected:expected,Limits:[]string{"New scoped predata diagnostic; published median/recurrence/bands/states unchanged","No expectedperiod selects crossings or fits phase; endpoint-span estimate precedes hypothesis check","Endpoint timing allowance W+2H each; propagated span-period bound 2*(W+2H)/(crossings-1), finite-grid qualification required","1% is a scoped generic precision screen, not universal chip/estimator tolerance; failed/unresolvedcases must remain","Qualification report and ROOTreview required before physical acceptance"}}
 if expected<=0||!mod_finite(expected){r.Reasons=append(r.Reasons,"invalid_nominal_hypothesis");return r}
 if len(job.values)-job.start<int(math.Ceil(3*expected))+2*job.window+2*job.hop{r.Reasons=append(r.Reasons,"insufficient_actual_horizon")}
 peak:=0.;for _,v:=range job.values{peak=math.Max(peak,math.Abs(v))};if peak>=32767{r.Reasons=append(r.Reasons,"raw_clipped")}
 if job.result.Gate==nil||!job.result.Gate.Stable{r.Reasons=append(r.Reasons,"resetheld_unqualified")}
 if job.result.State!="periodic_measured"&&job.result.State!="expected_rate_mismatch"{r.Reasons=append(r.Reasons,"published_period_unresolved");return r}
 half:=float64(job.window)/2;post:=[]modulation_point{};for _,p:=range job.points{if p.sample>=float64(job.start)+half&&p.sample<float64(job.end)-half&&p.valid{post=append(post,p)}}
 if len(post)<16{r.Reasons=append(r.Reasons,"insufficient_projection_points");return r};stats:=mod_span(post);mid:=(stats.P05+stats.P95)/2;low:=mid-.2*stats.Span;armed:=post[0].value<low
 for i:=1;i<len(post);i++{a,b:=post[i-1],post[i];if b.value<low{armed=true};if armed&&a.value<mid&&b.value>=mid{r.Crossings=append(r.Crossings,a.sample+(mid-a.value)/(b.value-a.value)*(b.sample-a.sample));armed=false}}
 if len(r.Crossings)<3{r.Reasons=append(r.Reasons,"insufficient_independent_crossings");return r}
 intervals:=[]float64{};for i:=1;i<len(r.Crossings);i++{intervals=append(intervals,r.Crossings[i]-r.Crossings[i-1])};r.Median=mod_quantile(intervals,.5)
 if job.result.Period==nil||math.Abs(job.result.Period.Recorded-r.Median)>1e-8{r.Reasons=append(r.Reasons,"published_median_wiring_mismatch");return r}
 r.Span=(r.Crossings[len(r.Crossings)-1]-r.Crossings[0])/float64(len(r.Crossings)-1);r.Bound=2*float64(job.window+2*job.hop)/float64(len(r.Crossings)-1);r.RelativeBound=r.Bound/r.Span;r.RelativeError=(r.Span-expected)/expected;r.MedianRelativeError=(r.Median-expected)/expected;r.Eligible=len(r.Reasons)==0;r.Match=r.Eligible&&math.Abs(r.RelativeError)<=.01&&math.Abs(r.Span-expected)<=r.Bound&&r.RelativeBound<=.01
 if r.Match{r.State="finite_precision_matches_hypothesis"}else if r.Eligible{r.State="finite_precision_mismatch_or_bound_unqualified"};return r
}
func fast_carrier(values []float64,first int)(map[string]interface{},error){
 fit,e:=fit_free_sine(values,first,len(values));if e!=nil{return nil,e};inc,ok:=fit["measured_increment_20bit"].(float64);rms,rms_ok:=fit["relative_sine_rms"].(float64);low,high:=math.Inf(1),math.Inf(-1);for _,v:=range values[first:]{low=math.Min(low,v);high=math.Max(high,v)};cross:=[]float64{};brackets:=[][2]int{};mid:=(low+high)/2
 for i:=first+1;i<len(values);i++{a,b:=values[i-1],values[i];if a<mid&&b>=mid{cross=append(cross,float64(i-1)+(mid-a)/(b-a));brackets=append(brackets,[2]int{i-1,i})}};cross_inc:=0.;interval:=[]float64{};if len(cross)>8{cross_inc=(1<<20)*float64(len(cross)-1)/(cross[len(cross)-1]-cross[0]);a,b:=brackets[0],brackets[len(brackets)-1];short,long:=b[0]-a[1],b[1]-a[0];if short>0&&long>0{interval=[]float64{(1<<20)*float64(len(cross)-1)/float64(long),(1<<20)*float64(len(cross)-1)/float64(short)}}}
 free_guard:=ok&&rms_ok&&math.Abs(inc-165888)<.1&&int(math.Round(inc))==165888&&rms<.003&&low<0&&high>0;cross_guard:=len(cross)>8&&len(interval)==2&&interval[0]<=165888&&165888<=interval[1]
 return map[string]interface{}{"free_fit":fit,"free_fit_guard":free_guard,"independent_midpoint_crossings":len(cross),"interpolated_crossing_increment_diagnostic_only":cross_inc,"integer_sign_crossing_brackets":brackets,"independent_crossing_increment_interval":interval,"crossing_interval_guard":cross_guard,"qualified":free_guard&&cross_guard,"limits":"Retained165888 independently scoped generic guard; original inverse-sine phase.go is inapplicable above131072; freefrequency fit has no expectedinc; first/last integer sign-crossing bounds supply independent coverage; interpolated crossing point is not an acceptance guard"},nil
}
func fast_rate_error(text string)error{return fmt.Errorf("%s: exact fast12 rates C0,CF,D0,DF,E0,E1,E7,E8,EE,EF,F0,FF required",text)}
