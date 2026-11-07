package main

import (
    "bytes"
    "encoding/csv"
    "strconv"
    "fmt"
    "math"
)

type phase_fit struct {
    Samples int `json:"samples"`
    Used int `json:"used_samples"`
    Increment float64 `json:"phase_increment_20bit"`
    Rounded int `json:"rounded_increment"`
    RMS float64 `json:"phase_rms_radians"`
}

// Fit phase versus native sample number, independent of the capture's clock
// calibration and initial phase. This assumes an unmodulated single sine with
// known amplitude, frequency below one eighth of the native sample rate, and
// positive phase advance. The residual rejects signals that do not fit.
func fit_phase(values []float64,amplitude,offset float64) (phase_fit,error) {
    result:=phase_fit{Samples:len(values)}
    if len(values)<128 || amplitude<=0 || math.IsInf(amplitude,0) || math.IsNaN(amplitude) {
        return result,fmt.Errorf("invalid sine fit input")
    }
    previous:=make([]int,len(values))
    following:=make([]int,len(values))
    previous[0]=-1
    for i:=1;i<len(values);i++ {
        previous[i]=previous[i-1]
        if values[i-1]!=values[i] { previous[i]=i-1 }
    }
    following[len(values)-1]=-1
    for i:=len(values)-2;i>=0;i-- {
        following[i]=following[i+1]
        if values[i+1]!=values[i] { following[i]=i+1 }
    }
    type point struct {x,y float64}
    var points []point
    var old,phase,sum_x,sum_y float64
    for i,v:=range values {
        normalized:=(v-offset)/amplitude
        if math.IsNaN(normalized) || math.IsInf(normalized,0) { return result,fmt.Errorf("nonfinite sine sample") }
        // Avoid the flat peaks, where quantization makes inverse sine unstable.
        if math.Abs(normalized)>.8 || previous[i]<0 || following[i]<0 { continue }
        delta:=values[following[i]]-values[previous[i]]
        if delta==0 { continue }
        angle:=math.Asin(normalized)
        if delta<0 { angle=math.Pi-angle }
        if angle<0 { angle+=2*math.Pi }
        if len(points)==0 { phase=angle } else {
            difference:=angle-old
            for difference>math.Pi { difference-=2*math.Pi }
            for difference < -math.Pi { difference+=2*math.Pi }
            phase+=difference
        }
        old=angle
        points=append(points,point{float64(i),phase})
        sum_x+=float64(i);sum_y+=phase
    }
    result.Used=len(points)
    if len(points)<64 { return result,fmt.Errorf("not enough changing samples away from sine peaks") }
    mean_x,mean_y:=sum_x/float64(len(points)),sum_y/float64(len(points))
    var numerator,denominator float64
    for _,p:=range points {
        numerator+=(p.x-mean_x)*(p.y-mean_y)
        denominator+=(p.x-mean_x)*(p.x-mean_x)
    }
    slope:=numerator/denominator
    var square_error float64
    for _,p:=range points {
        residual:=p.y-(mean_y+slope*(p.x-mean_x))
        square_error+=residual*residual
    }
    result.RMS=math.Sqrt(square_error/float64(len(points)))
    result.Increment=slope/(2*math.Pi)*(1<<20)
    result.Rounded=int(math.Round(result.Increment))
    if result.RMS>.01 || result.Increment<=0 || result.Increment>=1<<17 {
        return result,fmt.Errorf("signal does not fit the controlled-sine assumptions: %+v",result)
    }
    return result,nil
}

func read_phase_csv(raw []byte,column string) ([]float64,error) {
    rows,e:=csv.NewReader(bytes.NewReader(raw)).ReadAll()
    if e!=nil { return nil,e }
    if len(rows)<129 { return nil,fmt.Errorf("not enough CSV samples") }
    index,sample_index:=-1,-1
    for i,name:=range rows[0] {
        if name==column { index=i }
        if name=="sample" { sample_index=i }
    }
    if index<0 || sample_index<0 { return nil,fmt.Errorf("missing signal or sample column") }
    values:=make([]float64,len(rows)-1)
    for i,row:=range rows[1:] {
        if len(row)<=index || len(row)<=sample_index { return nil,fmt.Errorf("short CSV row %d",i+2) }
        sample,e:=strconv.Atoi(row[sample_index])
        if e!=nil || sample!=i { return nil,fmt.Errorf("nonconsecutive sample at row %d",i+2) }
        value,e:=strconv.ParseFloat(row[index],64)
        if e!=nil || math.IsNaN(value) || value < -32768 || value > 32767 {
            return nil,fmt.Errorf("invalid sample at row %d",i+2)
        }
        values[i]=value
    }
    return values,nil
}
