// Joint AM/PM output observation, qualified for the moderate-depth W2 pilot.
// Build with tone.go for its strict consecutive-sample CSV reader.
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

type joint_job struct {
    input,column,output string
    increment,sample_rate,amplitude float64
    stride,window,hop,lag,start,pre_end int
    values []float64
    points []joint_point
    result joint_result
}
type joint_point struct {
    Sample float64 `json:"sample_center"`
    Amplitude float64 `json:"amplitude"`
    Attenuation *float64 `json:"attenuation_db,omitempty"`
    Phase *float64 `json:"carrier_relative_phase_radians,omitempty"`
    Cents *float64 `json:"cents,omitempty"`
    Segment int `json:"phase_segment,omitempty"`
    Residual float64 `json:"relative_carrier_rms"`
    Quality string `json:"quality"`
}
type joint_span struct {
    Points int `json:"points"`
    Minimum float64 `json:"minimum"`
    Maximum float64 `json:"maximum"`
    P05 float64 `json:"p05"`
    P95 float64 `json:"p95"`
}
type joint_result struct {
    State string `json:"state"`
    Samples int `json:"samples"`
    Increment float64 `json:"increment_20bit"`
    SampleRate float64 `json:"recorded_sample_rate_hz"`
    Stride int `json:"native_stride"`
    Window int `json:"window_samples"`
    Hop int `json:"hop_samples"`
    Lag int `json:"phase_difference_half_span_samples"`
    Start int `json:"post_event_start_sample"`
    PreEnd int `json:"reset_held_end_sample_exclusive"`
    PreAM *joint_span `json:"reset_held_am_db,omitempty"`
    PrePM *joint_span `json:"reset_held_pm_cents,omitempty"`
    AM *joint_span `json:"post_event_am_db,omitempty"`
    PM *joint_span `json:"post_event_pm_cents,omitempty"`
    Invalid int `json:"invalid_post_event_points"`
    Limited int `json:"window_limited_post_event_points"`
    Assumptions []string `json:"assumptions"`
}

func main() {
    job:=joint_job{}
    flag.StringVar(&job.column,"column","linear","signal column")
    flag.StringVar(&job.output,"csv","","new unaligned local-feature CSV")
    flag.Float64Var(&job.increment,"increment",0,"known unmodulated increment per retained sample")
    flag.Float64Var(&job.sample_rate,"sample-rate",55937.5,"retained sample rate; Hz follows caller clock calibration")
    flag.Float64Var(&job.amplitude,"amplitude",8170,"reference full-level amplitude; caller calibration assumption")
    flag.IntVar(&job.stride,"native-stride",1,"native frames between retained frames")
    flag.IntVar(&job.window,"window",128,"Hann weighted sine/cosine/DC projection window")
    flag.IntVar(&job.hop,"hop",8,"recorded samples between projection centers")
    flag.IntVar(&job.lag,"phase-lag",16,"fixed central phase-difference half span, multiple of hop")
    flag.IntVar(&job.start,"start-sample",0,"conservative post-event lower bound")
    flag.IntVar(&job.pre_end,"pre-end-sample",0,"guaranteed reset-held upper bound; zero leaves it unevaluated")
    flag.Parse()
    if flag.NArg()!=1 { fmt.Fprintln(os.Stderr,"Usage: joint_modulation -increment STEP [options] INPUT.csv");os.Exit(2) }
    job.input=flag.Arg(0)
    if e:=job.run();e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}

func (job *joint_job) run() error {
    raw,e:=os.ReadFile(job.input);if e!=nil { return e }
    job.values,e=read_phase_csv(raw,job.column);if e!=nil { return e }
    if e=job.analyze();e!=nil { return e }
    if job.output!="" { if e=job.write_curve();e!=nil { return e } }
    return json.NewEncoder(os.Stdout).Encode(struct {
        File string `json:"file"`
        SHA256 string `json:"sha256"`
        Column string `json:"column"`
        Joint joint_result `json:"joint_modulation"`
    }{job.input,fmt.Sprintf("%x",sha256.Sum256(raw)),job.column,job.result})
}

func joint_finite(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v,0) }

func (job *joint_job) analyze() error {
    if !joint_finite(job.increment) || job.increment<=0 || job.increment>=1<<19 ||
       !joint_finite(job.sample_rate) || job.sample_rate<=0 || !joint_finite(job.amplitude) || job.amplitude<64 ||
       job.stride<1 || job.stride>1024 || job.window<32 || job.window>len(job.values)/4 ||
       job.hop<1 || job.hop>job.window/4 || job.lag<job.hop || job.lag%job.hop!=0 || job.lag>job.window/2 ||
       job.start<0 || job.pre_end<0 || job.pre_end>job.start || len(job.values)-job.start<2*job.window ||
       float64(job.window)*job.increment/(1<<20)<4 {
        return fmt.Errorf("invalid joint settings or insufficient carrier/data support")
    }
    for _,v:=range job.values { if !joint_finite(v) { return fmt.Errorf("nonfinite PCM") } }
    job.points=nil
    job.result=joint_result{Samples:len(job.values),Increment:job.increment,SampleRate:job.sample_rate,Stride:job.stride,
        Window:job.window,Hop:job.hop,Lag:job.lag,Start:job.start,PreEnd:job.pre_end,
        Assumptions:[]string{"Original output-domain Hann weighted sine/cosine/DC least-squares projection; carrier-relative complex phase is unwrapped once, then differenced across fixed neighbor windows.",
            "Qualified scope: isolated carrier, W2 triangle E0 period2048 retained frames, AM0..12dB and PM within+/-25cents at recorded increment65984, window128/hop8/phase-lag16.",
            "Other settings produce exploratory observations, not an extension of that qualification. No forced period, cycle alignment, per-cycle warp, gain fitting or external chip-state observation.",
            "All features are window averaged. AM support is window; PM support is window+2*phase-lag. Steps/turning points incur fixed-window bias; high carrier residual is marked window_limited.",
            "Amplitude reference and supplied rate are caller calibration assumptions, not inferred from CSV provenance; existing aliasing cannot be identified from samples alone.",
            "Projections below64PCM have no logarithm; below512PCM have no phase. These conservative floors do not extend precision qualification below the moderate-depth pilot. Invalid gaps break the phase segment and PM differences never cross them."}}
    radians:=job.increment/(1<<20)*2*math.Pi
    segment:=0
    segments:=[]int{}
    projection_limited:=[]bool{}
    var last,phase float64
    active:=false
    for first:=0;first+job.window<=len(job.values);first+=job.hop {
        coefficients,residual,e:=job.project(first,radians);if e!=nil { return e }
        point:=joint_point{Sample:float64(first)+float64(job.window-1)/2,Amplitude:math.Hypot(coefficients[0],coefficients[1]),Quality:"quantization_limited"}
        if point.Amplitude>=64 {
            attenuation:=-20*math.Log10(point.Amplitude/job.amplitude)
            point.Attenuation=&attenuation
            point.Residual=residual/(point.Amplitude/math.Sqrt2)
        }
        if point.Amplitude>=512 {
            angle:=math.Atan2(coefficients[1],coefficients[0])
            if !active { phase=angle;segment++;active=true } else {
                advance:=math.Remainder(angle-last,2*math.Pi)
                if math.Abs(advance)>=math.Pi/2 { segment++;phase=angle } else { phase+=advance }
            }
            last=angle
            unwrapped:=phase;point.Phase=&unwrapped;point.Segment=segment
            point.Quality="valid_window_averaged"
            if point.Residual>.25 { point.Quality="window_limited" }
        } else {
            active=false
            if point.Attenuation!=nil { point.Quality="low_amplitude_phase_unqualified" }
        }
        segments=append(segments,segment)
        projection_limited=append(projection_limited,point.Quality=="window_limited")
        job.points=append(job.points,point)
    }
    distance:=job.lag/job.hop
    for i:=distance;i+distance<len(job.points);i++ {
        before,point,after:=&job.points[i-distance],&job.points[i],&job.points[i+distance]
        if point.Phase==nil || before.Phase==nil || after.Phase==nil || segments[i-distance]!=segments[i] || segments[i+distance]!=segments[i] { continue }
        residual_slope:=(*after.Phase-*before.Phase)/(after.Sample-before.Sample)
        increment:=job.increment+residual_slope/(2*math.Pi)*(1<<20)
        if increment<=0 || !joint_finite(increment) { point.Quality="ambiguous_phase_advance";continue }
        cents:=1200*math.Log2(increment/job.increment);point.Cents=&cents
        if projection_limited[i-distance] || projection_limited[i] || projection_limited[i+distance] { point.Quality="window_limited" }
    }
    for i:=range job.points {
        if job.points[i].Phase!=nil && job.points[i].Cents==nil && job.points[i].Quality=="valid_window_averaged" { job.points[i].Quality="phase_difference_unavailable" }
    }
    job.summarize()
    return nil
}

func (job *joint_job) project(first int,radians float64) ([3]float64,float64,error) {
    var matrix [3][4]float64
    weight_sum:=0.0
    for j:=0;j<job.window;j++ {
        weight:=.5-.5*math.Cos(2*math.Pi*float64(j)/float64(job.window-1))
        basis:=[3]float64{math.Sin(float64(first+j)*radians),math.Cos(float64(first+j)*radians),1}
        for r:=0;r<3;r++ {
            for c:=0;c<3;c++ { matrix[r][c]+=weight*basis[r]*basis[c] }
            matrix[r][3]+=weight*basis[r]*job.values[first+j]
        }
        weight_sum+=weight
    }
    for column:=0;column<3;column++ {
        pivot:=column
        for row:=column+1;row<3;row++ { if math.Abs(matrix[row][column])>math.Abs(matrix[pivot][column]) { pivot=row } }
        if math.Abs(matrix[pivot][column])<1e-9 { return [3]float64{},0,fmt.Errorf("singular joint projection") }
        matrix[column],matrix[pivot]=matrix[pivot],matrix[column]
        divisor:=matrix[column][column]
        for k:=column;k<4;k++ { matrix[column][k]/=divisor }
        for row:=0;row<3;row++ {
            if row==column { continue }
            factor:=matrix[row][column]
            for k:=column;k<4;k++ { matrix[row][k]-=factor*matrix[column][k] }
        }
    }
    coefficients:=[3]float64{matrix[0][3],matrix[1][3],matrix[2][3]}
    residual:=0.0
    for j:=0;j<job.window;j++ {
        weight:=.5-.5*math.Cos(2*math.Pi*float64(j)/float64(job.window-1))
        predicted:=coefficients[0]*math.Sin(float64(first+j)*radians)+coefficients[1]*math.Cos(float64(first+j)*radians)+coefficients[2]
        error:=job.values[first+j]-predicted
        residual+=weight*error*error
    }
    if !joint_finite(residual) { return [3]float64{},0,fmt.Errorf("nonfinite joint projection") }
    for _,value:=range coefficients { if !joint_finite(value) { return [3]float64{},0,fmt.Errorf("nonfinite joint coefficient") } }
    return coefficients,math.Sqrt(residual/weight_sum),nil
}

func joint_stats(values []float64) *joint_span {
    if len(values)<8 { return nil }
    sort.Float64s(values)
    quantile:=func(p float64)float64 {
        pos:=p*float64(len(values)-1);i:=int(pos)
        if i==len(values)-1 { return values[i] }
        return values[i]+(pos-float64(i))*(values[i+1]-values[i])
    }
    return &joint_span{Points:len(values),Minimum:values[0],Maximum:values[len(values)-1],P05:quantile(.05),P95:quantile(.95)}
}

func (job *joint_job) summarize() {
    var pre_am,pre_pm,post_am,post_pm []float64
    support:=float64(job.window)/2+float64(job.lag)
    for _,p:=range job.points {
        if job.pre_end>0 && p.Sample+support<float64(job.pre_end) {
            if p.Attenuation!=nil { pre_am=append(pre_am,*p.Attenuation) }
            if p.Cents!=nil { pre_pm=append(pre_pm,*p.Cents) }
        }
        if p.Sample<float64(job.start)+support || p.Sample>=float64(len(job.values))-support { continue }
        if p.Attenuation!=nil { post_am=append(post_am,*p.Attenuation) }
        if p.Cents!=nil { post_pm=append(post_pm,*p.Cents) }
        if p.Attenuation==nil || p.Cents==nil { job.result.Invalid++ }
        if p.Quality=="window_limited" { job.result.Limited++ }
    }
    job.result.PreAM=joint_stats(pre_am);job.result.PrePM=joint_stats(pre_pm)
    job.result.AM=joint_stats(post_am);job.result.PM=joint_stats(post_pm)
    job.result.State="window_averaged_features"
    if job.result.AM==nil || job.result.PM==nil || job.result.Invalid>0 { job.result.State="quantization_or_phase_limited" }
    if job.result.Limited>0 { job.result.State="window_limited_features" }
}

func (job *joint_job) write_curve() error {
    f,e:=os.OpenFile(job.output,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600);if e!=nil { return e }
    writer:=csv.NewWriter(f)
    if e=writer.Write([]string{"sample_center","amplitude","attenuation_db","carrier_relative_phase_radians","cents","relative_carrier_rms","quality","phase_segment"});e!=nil { f.Close();return e }
    format:=func(v float64)string{return strconv.FormatFloat(v,'g',15,64)}
    optional:=func(v *float64)string{if v==nil { return "" };return format(*v)}
    for _,p:=range job.points {
        e=writer.Write([]string{format(p.Sample),format(p.Amplitude),optional(p.Attenuation),optional(p.Phase),optional(p.Cents),format(p.Residual),p.Quality,strconv.Itoa(p.Segment)})
        if e!=nil { f.Close();return e }
    }
    writer.Flush();e=writer.Error();close_error:=f.Close();if e!=nil { return e };return close_error
}
