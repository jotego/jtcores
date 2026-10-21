// Measure a controlled sine's attack from a fixed windowed carrier projection.
package main

import (
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

func main() {
    column:=flag.String("column","linear","signal CSV column")
    increment:=flag.Float64("increment",0,"known phase increment per recorded sample")
    rate:=flag.Float64("sample-rate",55937.5,"calibrated recorded sample rate")
    window:=flag.Int("window",128,"fixed projection window, at least 1.5 carrier cycles")
    hop:=flag.Int("hop",8,"samples between window centers")
    output:=flag.String("csv","","optional new amplitude-curve CSV")
    curve_only:=flag.Bool("curve-only",false,"export level/curve statistics without scoring attack duration")
    flag.Parse()
    if flag.NArg()!=1 { fmt.Fprintln(os.Stderr,"Usage: envelope -increment STEP [options] SIGNAL.csv");os.Exit(2) }
    if e:=run_envelope(flag.Arg(0),*column,*increment,*rate,*window,*hop,*output,*curve_only);e!=nil {
        fmt.Fprintln(os.Stderr,e);os.Exit(1)
    }
}

func run_envelope(path,column string,increment,rate float64,window,hop int,output string,curve_only bool) error {
    raw,e:=os.ReadFile(path);if e!=nil { return e }
    values,e:=read_phase_csv(raw,column);if e!=nil { return e }
    result,e:=measure_envelope(values,increment,rate,window,hop);if e!=nil { return e }
    if curve_only {
        result.Attack=nil
        if result.State!="no_signal" { result.State="curve_only" }
    }
    if output!="" { e=write_envelope(output,result.points);if e!=nil { return e } }
    return json.NewEncoder(os.Stdout).Encode(struct{
        File string `json:"file"`
        SHA256 string `json:"sha256"`
        Column string `json:"column"`
        Envelope envelope_result `json:"envelope"`
    }{path,fmt.Sprintf("%x",sha256.Sum256(raw)),column,result})
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
