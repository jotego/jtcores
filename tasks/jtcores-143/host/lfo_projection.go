// Fixed storage-fixture projection. Build with tone.go's strict CSV reader.
// pinv(X*h)*h is squared-Hann weighted least squares, not Hann WLS.
package main

import (
    "crypto/sha256"
    "encoding/csv"
    "encoding/json"
    "flag"
    "fmt"
    "math"
    "os"
    "strconv"
)

const projection_window=129
const projection_hop=8
const projection_lag=16
const projection_increment=32992
const projection_stride=8
const projection_rate=6992.1875
const projection_amplitude=8170
const projection_log_floor=64
const projection_phase_floor=512

type projection_job struct {
    input,column,output string
    values []float64
    points []projection_point
    dual [3][projection_window]float64
    radians float64
    result projection_result
}
type projection_point struct {
    Sample int `json:"sample_center"`
    Amplitude float64 `json:"amplitude"`
    Attenuation *float64 `json:"attenuation_db,omitempty"`
    Phase *float64 `json:"carrier_relative_phase_radians,omitempty"`
    Cents *float64 `json:"cents,omitempty"`
    Segment int `json:"phase_segment,omitempty"`
    Quality string `json:"quality"`
}
type projection_result struct {
    State string `json:"state"`
    Samples int `json:"samples"`
    Points int `json:"projection_points"`
    ValidLog int `json:"valid_log_points"`
    InvalidLog int `json:"invalid_log_points"`
    ValidPhase int `json:"valid_phase_points"`
    InvalidPhase int `json:"invalid_phase_points"`
    ValidCents int `json:"valid_cents_points"`
    InvalidCents int `json:"invalid_cents_points_with_full_support"`
    Segments int `json:"phase_segments"`
    Window int `json:"window_samples"`
    Hop int `json:"hop_samples"`
    Lag int `json:"phase_difference_half_span_samples"`
    Increment int `json:"recorded_increment_20bit"`
    Stride int `json:"native_stride"`
    SampleRate float64 `json:"recorded_sample_rate_hz"`
    ReferenceAmplitude float64 `json:"reference_amplitude"`
    LogFloor int `json:"log_amplitude_floor_pcm"`
    PhaseFloor int `json:"phase_amplitude_floor_pcm"`
    AMHalfSupport int `json:"am_phase_support_half_span_samples"`
    PMHalfSupport int `json:"pm_support_half_span_samples"`
    Weight string `json:"weight"`
    Assumptions []string `json:"assumptions"`
}

func main() {
    job:=projection_job{}
    flag.StringVar(&job.column,"column","linear","signal CSV column")
    flag.StringVar(&job.output,"csv","","fresh output curve CSV; existing files are rejected")
    flag.Parse()
    if flag.NArg()!=1 { fmt.Fprintln(os.Stderr,"Usage: lfo_projection [-column NAME] [-csv NEW.csv] INPUT.csv");os.Exit(2) }
    job.input=flag.Arg(0)
    if e:=job.run();e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}

func (job *projection_job) run() error {
    raw,e:=os.ReadFile(job.input);if e!=nil { return e }
    job.values,e=read_phase_csv(raw,job.column);if e!=nil { return e }
    if e=job.analyze();e!=nil { return e }
    curve_hash:=""
    if job.output!="" { curve_hash,e=job.write_curve();if e!=nil { return e } }
    return json.NewEncoder(os.Stdout).Encode(struct {
        File string `json:"file"`
        SHA256 string `json:"sha256"`
        Column string `json:"column"`
        Curve string `json:"curve_csv,omitempty"`
        CurveHash string `json:"curve_sha256,omitempty"`
        Projection projection_result `json:"projection"`
    }{job.input,fmt.Sprintf("%x",sha256.Sum256(raw)),job.column,job.output,curve_hash,job.result})
}

func (job *projection_job) analyze() error {
    if len(job.values)<projection_window+4*projection_hop { return fmt.Errorf("at least 161 consecutive samples are required for full phase-difference support") }
    for _,value:=range job.values {
        if math.IsNaN(value) || math.IsInf(value,0) { return fmt.Errorf("nonfinite PCM") }
        if value < -32768 || value>32767 { return fmt.Errorf("PCM outside signed 16-bit range") }
    }
    job.points=nil
    job.result=projection_result{State:"projection_features",Samples:len(job.values),Window:projection_window,Hop:projection_hop,Lag:projection_lag,
        Increment:projection_increment,Stride:projection_stride,SampleRate:projection_rate,ReferenceAmplitude:projection_amplitude,
        LogFloor:projection_log_floor,PhaseFloor:projection_phase_floor,AMHalfSupport:64,PMHalfSupport:80,Weight:"Hann squared: pinv(X*h)*h",
        Assumptions:[]string{"Fixed retained increment 32992, stride 8, nominal sample rate 6992.1875 Hz; known single carrier and storage-fixture moderate AM/PM scope.",
            "Centered 129-sample sine/cosine/DC basis with squared-Hann weights; centers 64,72,...; phase convention subtracts carrier phase before one unwrap per uninterrupted valid segment.",
            "Cents use fixed phase neighbors +/-16 samples; no period, gain, event or cycle alignment is fitted. AM/phase support 129 samples, cents support 161 samples.",
            "Reference amplitude 8170 and nominal sample rate are caller calibration assumptions; preexisting aliasing or arbitrary multiple carriers are not identified from PCM.",
            "Below 64 PCM no logarithm; below 512 PCM no phase. These floors do not qualify deep-modulation precision. Cents never cross an invalid phase segment.",
            "Retained AMD127 synthetic maximum AM corner error is about 0.374 dB and exceeds the predeclared 0.3 dB guard; precise AMD127 extrema remain unqualified."}}
    if e:=job.make_dual();e!=nil { return e }
    active:=false
    last_raw,correction:=0.0,0.0
    segment:=0
    two_pi:=2*math.Pi
    for center:=64;center<len(job.values)-64;center+=projection_hop {
        var coefficients [3]float64
        for j:=0;j<projection_window;j++ {
            for k:=0;k<3;k++ { coefficients[k]+=job.dual[k][j]*job.values[center-64+j] }
        }
        amplitude:=math.Hypot(coefficients[0],coefficients[1])
        if !projection_finite(amplitude) { return fmt.Errorf("nonfinite projection at sample %d",center) }
        point:=projection_point{Sample:center,Amplitude:amplitude,Quality:"quantization_limited"}
        if amplitude>=projection_log_floor {
            attenuation:=20*math.Log10(projection_amplitude/amplitude);point.Attenuation=&attenuation
            point.Quality="low_amplitude_phase_unqualified"
        }
        if amplitude>=projection_phase_floor {
            raw_phase:=math.Atan2(coefficients[1],coefficients[0])-job.radians*float64(center)
            if !active { correction=0;segment++;active=true } else {
                difference:=raw_phase-last_raw
                if math.Abs(difference)>=math.Pi {
                    wrapped:=math.Mod(difference+math.Pi,two_pi)
                    if wrapped<0 { wrapped+=two_pi }
                    wrapped-=math.Pi
                    if wrapped == -math.Pi && difference>0 { wrapped=math.Pi }
                    correction+=wrapped-difference
                }
            }
            unwrapped:=raw_phase+correction;point.Phase=&unwrapped;point.Segment=segment
            last_raw=raw_phase;point.Quality="phase_difference_support_unavailable"
        } else { active=false }
        job.points=append(job.points,point)
    }
    distance:=projection_lag/projection_hop
    for i:=distance;i<len(job.points)-distance;i++ {
        before,point,after:=&job.points[i-distance],&job.points[i],&job.points[i+distance]
        if point.Phase==nil || before.Phase==nil || after.Phase==nil || before.Segment!=point.Segment || after.Segment!=point.Segment { continue }
        ratio:=1+(*after.Phase-*before.Phase)/(32*job.radians)
        if ratio<=0 || !projection_finite(ratio) { point.Quality="nonpositive_or_invalid_frequency_ratio";continue }
        cents:=1200*math.Log2(ratio);point.Cents=&cents;point.Quality="valid_window_averaged"
    }
    job.result.Points=len(job.points);job.result.Segments=segment
    for i,point:=range job.points {
        if point.Attenuation==nil { job.result.InvalidLog++ } else { job.result.ValidLog++ }
        if point.Phase==nil { job.result.InvalidPhase++ } else { job.result.ValidPhase++ }
        if point.Cents!=nil { job.result.ValidCents++ } else if i>=distance && i<len(job.points)-distance { job.result.InvalidCents++ }
    }
    if job.result.InvalidLog>0 || job.result.InvalidPhase>0 || job.result.InvalidCents>0 { job.result.State="limited_projection_features" }
    return nil
}

func projection_finite(value float64) bool { return !math.IsNaN(value) && !math.IsInf(value,0) }

func (job *projection_job) make_dual() error {
    two_pi:=2*math.Pi
    job.radians=two_pi*float64(projection_increment)/(1<<20)
    var basis [projection_window][3]float64
    var weights [projection_window]float64
    var matrix [3][6]float64
    for j:=0;j<projection_window;j++ {
        angle:=job.radians*float64(j-64)
        basis[j]=[3]float64{math.Sin(angle),math.Cos(angle),1}
        hann:=.5-.5*math.Cos(two_pi*float64(j)/128)
        weights[j]=hann*hann
        for r:=0;r<3;r++ {
            for c:=0;c<3;c++ { matrix[r][c]+=weights[j]*basis[j][r]*basis[j][c] }
        }
    }
    for r:=0;r<3;r++ { matrix[r][r+3]=1 }
    for c:=0;c<3;c++ {
        pivot:=c
        for r:=c+1;r<3;r++ { if math.Abs(matrix[r][c])>math.Abs(matrix[pivot][c]) { pivot=r } }
        if math.Abs(matrix[pivot][c])<1e-12 { return fmt.Errorf("singular squared-Hann projection") }
        matrix[c],matrix[pivot]=matrix[pivot],matrix[c]
        divisor:=matrix[c][c]
        for k:=0;k<6;k++ { matrix[c][k]/=divisor }
        for r:=0;r<3;r++ {
            if r==c { continue }
            factor:=matrix[r][c]
            for k:=0;k<6;k++ { matrix[r][k]-=factor*matrix[c][k] }
        }
    }
    for r:=0;r<3;r++ {
        for j:=0;j<projection_window;j++ {
            job.dual[r][j]=0
            for k:=0;k<3;k++ { job.dual[r][j]+=matrix[r][k+3]*basis[j][k]*weights[j] }
        }
    }
    return nil
}

func (job *projection_job) write_curve() (string,error) {
    file,e:=os.OpenFile(job.output,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600);if e!=nil { return "",e }
    writer:=csv.NewWriter(file)
    e=writer.Write([]string{"sample_center","amplitude","attenuation_db","carrier_relative_phase_radians","cents","phase_segment","quality"})
    if e!=nil { file.Close();return "",e }
    format:=func(value float64)string{return strconv.FormatFloat(value,'g',17,64)}
    optional:=func(value *float64)string{if value==nil { return "" };return format(*value)}
    for _,point:=range job.points {
        e=writer.Write([]string{strconv.Itoa(point.Sample),format(point.Amplitude),optional(point.Attenuation),optional(point.Phase),optional(point.Cents),strconv.Itoa(point.Segment),point.Quality})
        if e!=nil { file.Close();return "",e }
    }
    writer.Flush();e=writer.Error();close_error:=file.Close();if e!=nil { return "",e };if close_error!=nil { return "",close_error }
    raw,e:=os.ReadFile(job.output);if e!=nil { return "",e }
    return fmt.Sprintf("%x",sha256.Sum256(raw)),nil
}
