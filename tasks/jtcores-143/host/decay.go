// Measure a controlled sine's falling amplitude from envelope.go curve CSVs.
package main

import (
    "bytes"
    "crypto/sha256"
    "encoding/csv"
    "encoding/json"
    "flag"
    "fmt"
    "math"
    "os"
    "sort"
    "strconv"
)

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

func main() {
    rate:=flag.Float64("sample-rate",55937.5,"recorded sample rate")
    window:=flag.Int("window",32,"carrier projection window in recorded samples")
    initial:=flag.Float64("initial-level",8169.5,"independently qualified initial carrier amplitude")
    keyon:=flag.Bool("keyon",false,"configured-rate key-on complement; require silent pretrigger and a resolved peak")
    flag.Parse()
    if flag.NArg()!=1 { fmt.Fprintln(os.Stderr,"Usage: decay [options] AMPLITUDE.csv");os.Exit(2) }
    raw,e:=os.ReadFile(flag.Arg(0));if e!=nil { fail_decay(e) }
    points,e:=read_decay(raw);if e!=nil { fail_decay(e) }
    result,e:=measure_decay(points,*rate,*window,*initial,*keyon);if e!=nil { fail_decay(e) }
    e=json.NewEncoder(os.Stdout).Encode(struct{
        File string `json:"file"`
        SHA256 string `json:"sha256"`
        Decay decay_result `json:"decay"`
    }{flag.Arg(0),fmt.Sprintf("%x",sha256.Sum256(raw)),result});if e!=nil { fail_decay(e) }
}

func fail_decay(e error) { fmt.Fprintln(os.Stderr,e);os.Exit(1) }

func read_decay(raw []byte) ([]decay_point,error) {
    rows,e:=csv.NewReader(bytes.NewReader(raw)).ReadAll();if e!=nil { return nil,e }
    if len(rows)<17 || len(rows[0])!=4 { return nil,fmt.Errorf("insufficient amplitude curve") }
    for i,want:=range []string{"sample_center","amplitude","dc","carrier_rms"} {
        if rows[0][i]!=want { return nil,fmt.Errorf("unexpected amplitude CSV columns") }
    }
    var points []decay_point
    var spacing float64
    for i,row:=range rows[1:] {
        if len(row)!=4 { return nil,fmt.Errorf("invalid curve row") }
        var values [4]float64
        for j,s:=range row {
            values[j],e=strconv.ParseFloat(s,64)
            if e!=nil || !decay_finite(values[j]) { return nil,fmt.Errorf("nonfinite curve value") }
        }
        if values[0]<0 || values[1]<0 || values[3]<0 { return nil,fmt.Errorf("negative curve field") }
        if i>0 {
            step:=values[0]-points[i-1].at
            if i==1 { spacing=step }
            if spacing<=0 || math.Abs(step-spacing)>1e-6 { return nil,fmt.Errorf("nonconsecutive curve centers") }
        }
        points=append(points,decay_point{values[0],values[1],values[3]})
    }
    return points,nil
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
