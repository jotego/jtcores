// Independent free-frequency sine/cosine/DC fit; no expected rate is supplied.
package main

import("fmt";"math")

type free_sine_job struct{values []float64;first,end int}

func fit_free_sine(values []float64,first,end int)(map[string]interface{},error){
 job:=free_sine_job{values,first,end};return job.run()
}
func(job *free_sine_job)run()(map[string]interface{},error){
 if job.first<0||job.end>len(job.values)||job.end<=job.first{return nil,fmt.Errorf("invalid sine fit bounds")}
 result:=map[string]interface{}{"state":"unresolved_low_or_short","measured_increment_20bit":nil}
 low,high:=job.values[job.first],job.values[job.first];for _,v:=range job.values[job.first:job.end]{if math.IsNaN(v)||math.IsInf(v,0){return nil,fmt.Errorf("nonfinite sine input")};low=math.Min(low,v);high=math.Max(high,v)}
 if job.end-job.first<256||high-low<32{return result,nil}
 mid:=(low+high)/2;crossings:=[]float64{}
 for n:=job.first;n<job.end-1;n++{a,b:=job.values[n],job.values[n+1];if a<=mid&&b>mid{crossings=append(crossings,float64(n)+(mid-a)/(b-a))}}
 if len(crossings)<8{result["state"]="unresolved_insufficient_crossings";result["crossings"]=len(crossings);return result,nil}
 mean_cross:=0.;for _,x:=range crossings{mean_cross+=x};mean_cross/=float64(len(crossings));mean_index:=float64(len(crossings)-1)/2;numerator,denominator:=0.,0.
 for i,x:=range crossings{k:=float64(i)-mean_index;numerator+=k*(x-mean_cross);denominator+=k*k}
 period:=numerator/denominator;if !(period>0){return nil,fmt.Errorf("invalid crossing period")};initial:=2*math.Pi/period;first,last:=initial*.98,initial*1.02;step:=(last-first)/64;best:=-1;best_cost:=math.Inf(1)
 for i:=0;i<=64;i++{cost,_,ok:=job.solve(first+float64(i)*step);if ok&&cost<best_cost{best,best_cost=i,cost}}
 if best<=0||best>=64{result["state"]="unresolved_frequency_search_boundary";result["crossings"]=len(crossings);return result,nil}
 lo,hi:=first+float64(best-1)*step,first+float64(best+1)*step
 for i:=0;i<44;i++{a,b:=lo+(hi-lo)*.3819660112501051,lo+(hi-lo)*.6180339887498949;left,_,left_ok:=job.solve(a);right,_,right_ok:=job.solve(b);if !left_ok||!right_ok{return nil,fmt.Errorf("singular sine basis")};if left<right{hi=b}else{lo=a}}
 w:=(lo+hi)/2;cost,beta,ok:=job.solve(w);if !ok{return nil,fmt.Errorf("singular sine basis")};amplitude:=math.Hypot(beta[0],beta[1]);if !(amplitude>0){return nil,fmt.Errorf("zero fitted sine amplitude")};rms:=math.Sqrt(cost/float64(job.end-job.first))
 return map[string]interface{}{"state":"free_frequency_sine_fit_observed_not_automatic_pass","first":job.first,"end_exclusive":job.end,"samples":job.end-job.first,"crossings":len(crossings),"measured_increment_20bit":w/(2*math.Pi)*(1<<20),"measured_period_recorded_samples":2*math.Pi/w,"peak_amplitude_pcm":amplitude,"dc_pcm":beta[2],"sine_rms_pcm":rms,"relative_sine_rms":rms/amplitude,"phase_radians":math.Atan2(beta[1],beta[0]),"search":"zero-crossing-derived +/-2%;no expectedincrement supplied"},nil
}
func(job *free_sine_job)solve(w float64)(float64,[3]float64,bool){
 var matrix [3][4]float64
 for n:=job.first;n<job.end;n++{s,c:=math.Sincos(w*float64(n));basis:=[3]float64{s,c,1};for i:=0;i<3;i++{for j:=0;j<3;j++{matrix[i][j]+=basis[i]*basis[j]};matrix[i][3]+=basis[i]*job.values[n]}}
 for k:=0;k<3;k++{pivot:=k;for i:=k+1;i<3;i++{if math.Abs(matrix[i][k])>math.Abs(matrix[pivot][k]){pivot=i}};if math.Abs(matrix[pivot][k])<1e-10{return 0,[3]float64{},false};matrix[k],matrix[pivot]=matrix[pivot],matrix[k];scale:=matrix[k][k];for j:=k;j<4;j++{matrix[k][j]/=scale};for i:=0;i<3;i++{if i==k{continue};scale=matrix[i][k];for j:=k;j<4;j++{matrix[i][j]-=scale*matrix[k][j]}}}
 beta:=[3]float64{matrix[0][3],matrix[1][3],matrix[2][3]};cost:=0.
 for n:=job.first;n<job.end;n++{s,c:=math.Sincos(w*float64(n));residual:=job.values[n]-(beta[0]*s+beta[1]*c+beta[2]);cost+=residual*residual}
 return cost,beta,true
}
