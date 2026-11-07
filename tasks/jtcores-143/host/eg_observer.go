// EG observer: exact task-owned numeric bodies; standalone original CLIs remain unchanged.
package main
import("encoding/csv";"fmt";"math";"os";"strconv";"sort")
const amp=8169.5

type envelope_point struct { sample, amplitude, dc, rms float64 }

type attack_measurement struct {
    Ten float64 `json:"ten_percent_sample"`
    Ninety float64 `json:"ninety_percent_sample"`
    Duration float64 `json:"duration_ms"`
    Resolution float64 `json:"window_duration_ms"`
}

type envelope_result struct {
    State string `json:"state"`
    Samples int `json:"samples"`
    First int `json:"first_nonzero_sample"`
    Window int `json:"window_samples"`
    Hop int `json:"hop_samples"`
    Increment float64 `json:"phase_increment_20bit"`
    Rate float64 `json:"sample_rate_hz"`
    Plateau float64 `json:"plateau_amplitude"`
    PlateauSpan float64 `json:"plateau_relative_span"`
    CarrierRMS float64 `json:"plateau_relative_carrier_rms"`
    Attack *attack_measurement `json:"attack,omitempty"`
    points []envelope_point
}

func measure_envelope(values []float64,increment,rate float64,window,hop int) (envelope_result,error) {
    result:=envelope_result{Samples:len(values),First:-1,Window:window,Hop:hop,Increment:increment,Rate:rate}
    if !finite(increment) || !finite(rate) || rate<=0 || increment<=0 || increment>=1<<19 ||
       window<8 || window>len(values)/4 || hop<1 || hop>window || float64(window)*increment/(1<<20)<1.5 {
        return result,fmt.Errorf("invalid projection settings or insufficient data")
    }
    sine,cosine:=make([]float64,len(values)),make([]float64,len(values))
    for i,value:=range values {
        if !finite(value) { return result,fmt.Errorf("nonfinite input sample") }
        if value!=0 && result.First<0 { result.First=i }
        angle:=float64(i)*increment/(1<<20)*2*math.Pi
        sine[i],cosine[i]=math.Sin(angle),math.Cos(angle)
    }
    for start:=0;start+window<=len(values);start+=hop {
        end:=start+window
        point,e:=project_carrier(values[start:end],sine[start:end],cosine[start:end]);if e!=nil { return result,e }
        point.sample=float64(start)+float64(window-1)/2
        result.points=append(result.points,point)
    }
    if result.First<0 { result.State="no_signal";return result,nil }
    tail:=result.points[3*len(result.points)/4:]
    amplitudes:=make([]float64,len(tail))
    var rms float64
    for i,p:=range tail { amplitudes[i]=p.amplitude;rms+=p.rms*p.rms }
    sort.Float64s(amplitudes)
    result.Plateau=amplitudes[len(amplitudes)/2]
    if result.Plateau<32 { result.State="no_clean_plateau";return result,nil }
    result.PlateauSpan=(amplitudes[len(amplitudes)-1]-amplitudes[0])/result.Plateau
    result.CarrierRMS=math.Sqrt(rms/float64(len(tail)))/(result.Plateau/math.Sqrt2)
    if result.PlateauSpan>.01 || result.CarrierRMS>.02 { result.State="no_clean_plateau";return result,nil }
    if result.First<window { result.State="no_pretrigger";return result,nil }
    ten,ok:=envelope_crossing(result.points,.1*result.Plateau)
    ninety,ok90:=envelope_crossing(result.points,.9*result.Plateau)
    if !ok || !ok90 || ninety<ten { result.State="no_attack_crossings";return result,nil }
    result.State="measured"
    result.Attack=&attack_measurement{ten,ninety,(ninety-ten)/rate*1000,float64(window)/rate*1000}
    return result,nil
}

func finite(value float64) bool { return !math.IsNaN(value) && !math.IsInf(value,0) }

func project_carrier(values,sine,cosine []float64) (envelope_point,error) {
    var matrix [3][4]float64
    for i,value:=range values {
        row:=[3]float64{sine[i],cosine[i],1}
        for r:=0;r<3;r++ {
            for c:=0;c<3;c++ { matrix[r][c]+=row[r]*row[c] }
            matrix[r][3]+=row[r]*value
        }
    }
    coefficients,e:=solve_projection(matrix);if e!=nil { return envelope_point{},e }
    result:=envelope_point{amplitude:math.Hypot(coefficients[0],coefficients[1]),dc:coefficients[2]}
    for i,value:=range values {
        residual:=value-coefficients[0]*sine[i]-coefficients[1]*cosine[i]-coefficients[2]
        result.rms+=residual*residual
    }
    result.rms=math.Sqrt(result.rms/float64(len(values)))
    return result,nil
}

func solve_projection(matrix [3][4]float64) ([3]float64,error) {
    for col:=0;col<3;col++ {
        pivot:=col
        for row:=col+1;row<3;row++ { if math.Abs(matrix[row][col])>math.Abs(matrix[pivot][col]) { pivot=row } }
        if math.Abs(matrix[pivot][col])<1e-9 { return [3]float64{},fmt.Errorf("singular carrier projection") }
        matrix[col],matrix[pivot]=matrix[pivot],matrix[col]
        divisor:=matrix[col][col]
        for i:=col;i<4;i++ { matrix[col][i]/=divisor }
        for row:=0;row<3;row++ {
            if row==col { continue }
            factor:=matrix[row][col]
            for i:=col;i<4;i++ { matrix[row][i]-=factor*matrix[col][i] }
        }
    }
    return [3]float64{matrix[0][3],matrix[1][3],matrix[2][3]},nil
}

func envelope_crossing(points []envelope_point,threshold float64) (float64,bool) {
    for i:=1;i<len(points);i++ {
        before,after:=points[i-1],points[i]
        if before.amplitude<threshold && after.amplitude>=threshold {
            fraction:=(threshold-before.amplitude)/(after.amplitude-before.amplitude)
            return before.sample+fraction*(after.sample-before.sample),true
        }
    }
    return 0,false
}

func write_envelope(path string,points []envelope_point) error {
    file,e:=os.OpenFile(path,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600);if e!=nil { return e }
    defer file.Close()
    out:=csv.NewWriter(file)
    e=out.Write([]string{"sample_center","amplitude","dc","carrier_rms"});if e!=nil { return e }
    for _,p:=range points {
        row:=[]string{}
        for _,v:=range []float64{p.sample,p.amplitude,p.dc,p.rms} { row=append(row,strconv.FormatFloat(v,'g',12,64)) }
        e=out.Write(row);if e!=nil { return e }
    }
    out.Flush()
    return out.Error()
}

type decay_point struct { at, amplitude, rms float64 }

type decay_feature struct {
    High float64 `json:"eighty_percent_sample"`
    Low float64 `json:"forty_percent_sample"`
    Duration float64 `json:"duration_ms"`
    CarrierRMS float64 `json:"maximum_relative_carrier_rms"`
}

type decay_result struct {
    State string `json:"state"`
    Points int `json:"points"`
    Initial float64 `json:"initial_amplitude"`
    InitialSpan float64 `json:"initial_relative_span"`
    InitialRMS float64 `json:"initial_relative_carrier_rms"`
    Final float64 `json:"final_amplitude"`
    Window float64 `json:"window_duration_ms"`
    Keyon bool `json:"configured_keyon,omitempty"`
    InitialQuality bool `json:"initial_plateau_quality_evaluated"`
    Peak float64 `json:"projected_peak,omitempty"`
    Feature *decay_feature `json:"fall,omitempty"`
}

func decay_finite(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v,0) }

func measure_decay(points []decay_point,rate float64,window int,expected float64,keyon bool) (decay_result,error) {
    result:=decay_result{Points:len(points),Window:float64(window)/rate*1000,Keyon:keyon}
    if len(points)<16 || !decay_finite(rate) || rate<=0 || window<8 ||
       !decay_finite(expected) || expected<32 { return result,fmt.Errorf("invalid decay settings") }
    if math.Abs(points[0].at-float64(window-1)/2)>1e-6 {
        return result,fmt.Errorf("projection window differs from curve centers")
    }
    start:=1
    if keyon {
        for _,p:=range points[:4] {
            if p.amplitude!=0 || p.rms!=0 { result.State="no_silent_pretrigger";return result,nil }
        }
        for i,p:=range points {
            if p.amplitude>result.Peak { result.Peak=p.amplitude;start=i }
        }
        result.Initial=expected
        if result.Peak<.8*expected { result.State="no_resolved_peak";return result,nil }
    } else {
        initial:=make([]float64,4)
        var sum_rms float64
        for i,p:=range points[:4] { initial[i]=p.amplitude;sum_rms+=p.rms*p.rms }
        sort.Float64s(initial)
        result.Initial=(initial[1]+initial[2])/2
        if result.Initial<32 { result.State="no_initial_signal";return result,nil }
        result.InitialSpan=(initial[3]-initial[0])/result.Initial
        result.InitialRMS=math.Sqrt(sum_rms/4)/(result.Initial/math.Sqrt2)
        result.InitialQuality=true
        if math.Abs(result.Initial/expected-1)>.01 || result.InitialSpan>.01 || result.InitialRMS>.02 {
            result.State="no_clean_initial_plateau";return result,nil
        }
    }
    tail:=make([]float64,4)
    for i,p:=range points[len(points)-4:] { tail[i]=p.amplitude }
    sort.Float64s(tail);result.Final=(tail[1]+tail[2])/2
    high,low:=.8*result.Initial,.4*result.Initial
    high_at,high_index,found_high:=falling_crossing(points,high,start)
    low_at,_,found_low:=falling_crossing(points,low,high_index)
    if !found_high || !found_low {
        result.State="held_in_window"
        if keyon { result.State="incomplete_decay";return result,nil }
        for _,p:=range points[4:] {
            if math.Abs(p.amplitude/result.Initial-1)>.01 { result.State="incomplete_decay";break }
        }
        return result,nil
    }
    feature:=&decay_feature{High:high_at,Low:low_at,Duration:(low_at-high_at)/rate*1000}
    for _,p:=range points {
        if p.at<high_at || p.at>low_at || p.amplitude==0 { continue }
        feature.CarrierRMS=math.Max(feature.CarrierRMS,p.rms/(p.amplitude/math.Sqrt2))
    }
    result.Feature=feature
    result.State="measured"
    if feature.Duration<2*result.Window { result.State="window_limited" }
    return result,nil
}

func falling_crossing(points []decay_point,level float64,start int) (float64,int,bool) {
    if start<1 { start=1 }
    for i:=start;i<len(points);i++ {
        before,after:=points[i-1],points[i]
        if before.amplitude>=level && after.amplitude<level {
            fraction:=(before.amplitude-level)/(before.amplitude-after.amplitude)
            return before.at+fraction*(after.at-before.at),i,true
        }
    }
    return 0,1,false
}

type geometry struct{Name string `json:"name"`;KC int `json:"kc"`;Mul int `json:"mul"`;Native float64 `json:"native_increment"`;Stride int `json:"stride"`;Frames int `json:"frames"`;Window int `json:"window"`;Hop int `json:"hop"`;Fs float64 `json:"sample_rate_hz"`;Recorded float64 `json:"recorded_increment"`}

type fixture struct{Values []float64;NativeHash string;RecordedHash string;NativeFrames int;Low,High float64}

func crossing(values []float64,expected float64)map[string]interface{}{
 lo,hi:=math.Inf(1),math.Inf(-1);for _,v:=range values{lo=math.Min(lo,v);hi=math.Max(hi,v)};mid:=(lo+hi)/2;var spans [][2]int
 for i:=1;i<len(values);i++{if values[i-1]<mid&&values[i]>=mid{spans=append(spans,[2]int{i-1,i})}}
 d:=map[string]interface{}{"rising_crossings":len(spans),"qualified":false,"integer_bracket_method":"firstlastinterval; no expectedfrequency crossingselection"};if len(spans)<9{return d};a,b:=spans[0],spans[len(spans)-1];short,long:=b[0]-a[1],b[1]-a[0];if short<=0||long<=0{return d};lower:=float64(len(spans)-1)*(1<<20)/float64(long);upper:=float64(len(spans)-1)*(1<<20)/float64(short);d["first_bracket"]=a;d["last_bracket"]=b;d["increment_interval"]=[]float64{lower,upper};d["qualified"]=lower<=expected&&expected<=upper;return d
}

func carrier(f fixture,g geometry)(map[string]interface{},bool){
 cross:=crossing(f.Values,g.Recorded);d:=map[string]interface{}{"crossing":cross,"bipolar":f.Low<0&&f.High>0};ok:=false
 if g.Recorded<1<<17{fit,e:=fit_phase(f.Values,8170,-8);d["phase_fit"]=fit;if e!=nil{d["phase_error"]=e.Error()};ok=e==nil&&fit.Rounded==int(g.Recorded)&&fit.RMS<.01
 }else{fit,e:=fit_free_sine(f.Values,0,len(f.Values));d["free_fit"]=fit;if e!=nil{d["free_error"]=e.Error()};inc,has:=fit["measured_increment_20bit"].(float64);rms,has_rms:=fit["relative_sine_rms"].(float64);ok=e==nil&&has&&has_rms&&math.Abs(inc-g.Recorded)<.1&&int(math.Round(inc))==int(g.Recorded)&&rms<.003}
 clipped:=f.Low<=-32768||f.High>=32767;d["raw_clipped"]=clipped;ok=ok&&cross["qualified"]==true&&f.Low<0&&f.High>0&&!clipped;d["qualified"]=ok;return d,ok
}

func decay_points(e envelope_result)[]decay_point{p:=make([]decay_point,len(e.points));for i,v:=range e.points{p[i]=decay_point{v.sample,v.amplitude,v.rms}};return p}
