// Output-domain LFO features. Uses tone.go's consecutive-sample CSV reader.
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

type modulation_job struct {
    mode, column, waveform, input, output string
    increment, sample_rate, amplitude, offset, expected_lfo, expected_period float64
    window, hop, start, end, pre_end, native_stride int
    values []float64
    points []modulation_point
    result modulation_result
}
type modulation_point struct {
    sample, value, amplitude, phase, increment, frequency, carrier_rms, phase_rms float64
    used int
    valid bool
}
type modulation_gate struct {
    Points int `json:"points"`
    Median float64 `json:"median"`
    Span float64 `json:"p95_minus_p05"`
    Stable bool `json:"stable"`
    Tolerance float64 `json:"span_tolerance"`
}
type modulation_span struct {
    Points int `json:"points"`
    Invalid int `json:"invalid_points"`
    Minimum float64 `json:"observed_minimum"`
    Maximum float64 `json:"observed_maximum"`
    P05 float64 `json:"p05"`
    P95 float64 `json:"p95"`
    Span float64 `json:"p95_minus_p05"`
    Median float64 `json:"median"`
}
type modulation_period struct {
    State string `json:"state"`
    Crossings int `json:"rising_crossings"`
    Cycles int `json:"complete_cycles"`
    Recorded float64 `json:"period_recorded_samples,omitempty"`
    Native float64 `json:"period_native_samples,omitempty"`
    Frequency float64 `json:"frequency_hz,omitempty"`
    Bounds *[2]float64 `json:"period_recorded_sample_bounds,omitempty"`
    Spread float64 `json:"relative_interval_spread,omitempty"`
    Recurrence float64 `json:"cycle_recurrence_rms_over_span,omitempty"`
    Origin float64 `json:"cycle_origin_sample,omitempty"`
    Shape []float64 `json:"cycle_bins,omitempty"`
}
type modulation_result struct {
    State string `json:"state"`
    Mode string `json:"mode"`
    Units string `json:"feature_units"`
    Samples int `json:"samples"`
    SampleRate float64 `json:"recorded_sample_rate_hz"`
    NativeStride int `json:"native_stride"`
    Increment float64 `json:"unmodulated_increment_20bit"`
    Window int `json:"window_samples"`
    Hop int `json:"hop_samples"`
    Start int `json:"start_sample"`
    PreEnd int `json:"pre_end_sample_exclusive"`
    End int `json:"end_sample_exclusive"`
    Gate *modulation_gate `json:"reset_held_gate,omitempty"`
    Span *modulation_span `json:"post_event,omitempty"`
    Period *modulation_period `json:"period,omitempty"`
    ActivityFloor float64 `json:"activity_floor"`
    Assumptions []string `json:"assumptions"`
}

func original_modulation_cli_main() {
    var job modulation_job
    flag.StringVar(&job.mode,"mode","","am or pm; combined modulation is not qualified")
    flag.StringVar(&job.column,"column","linear","signal CSV column")
    flag.StringVar(&job.waveform,"waveform","periodic","periodic or noise; noise has no period score")
    flag.Float64Var(&job.increment,"increment",0,"qualified unmodulated increment per recorded sample")
    flag.Float64Var(&job.sample_rate,"sample-rate",55937.5,"recorded rate; Hz follows this supplied clock calibration")
    flag.IntVar(&job.native_stride,"native-stride",1,"native stereo frames between retained samples")
    flag.Float64Var(&job.amplitude,"amplitude",8170,"known unmodulated peak amplitude")
    flag.Float64Var(&job.offset,"offset",-8,"known PM PCM quantization offset")
    flag.IntVar(&job.window,"window",32,"fixed local projection/phase-regression window")
    flag.IntVar(&job.hop,"hop",4,"recorded samples between window centers")
    flag.IntVar(&job.start,"start-sample",0,"post-event lower bound; complete crossing windows are excluded")
    flag.IntVar(&job.pre_end,"pre-end-sample",0,"guaranteed reset-held upper bound; zero leaves pretrigger quality unevaluated")
    flag.IntVar(&job.end,"end-sample",0,"exclusive upper bound; zero uses all samples")
    flag.Float64Var(&job.expected_lfo,"expected-lfo",0,"optional expected Hz, used only after independent period measurement")
    flag.Float64Var(&job.expected_period,"expected-period",0,"optional expected recorded-sample period, validation only")
    flag.StringVar(&job.output,"csv","","new unaligned curve CSV")
    flag.Parse()
    if flag.NArg()!=1 { fmt.Fprintln(os.Stderr,"Usage: modulation -mode am|pm -increment STEP [options] SIGNAL.csv");os.Exit(2) }
    job.input=flag.Arg(0)
    e:=job.run();if e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}

func (job *modulation_job) run() error {
    raw,e:=os.ReadFile(job.input);if e!=nil { return e }
    job.values,e=read_phase_csv(raw,job.column);if e!=nil { return e }
    e=job.analyze();if e!=nil { return e }
    if job.output!="" { e=job.write_curve();if e!=nil { return e } }
    return json.NewEncoder(os.Stdout).Encode(struct {
        File string `json:"file"`
        SHA256 string `json:"sha256"`
        Column string `json:"column"`
        Modulation modulation_result `json:"modulation"`
    }{job.input,fmt.Sprintf("%x",sha256.Sum256(raw)),job.column,job.result})
}

func (job *modulation_job) analyze() error {
    e:=job.validate();if e!=nil { return e }
    job.points=nil
    job.result=modulation_result{Mode:job.mode,Samples:len(job.values),SampleRate:job.sample_rate,
        NativeStride:job.native_stride,Increment:job.increment,Window:job.window,Hop:job.hop,Start:job.start,End:job.end,PreEnd:job.pre_end,
        Assumptions:[]string{"Known single carrier and isolated AM or PM; no combined-mode qualification.",
            "Retained samples must already satisfy the qualified carrier/Nyquist conditions; preexisting aliasing is not identifiable from PCM alone.",
            "Hz depends on the caller's clock calibration; recorded/native sample periods are the clock-independent measurements.",
            "Raw curve is unaligned. Period shape uses one measured crossing origin and one fixed period, without per-cycle time warps."}}
    maximum:=0.0
    for _,value:=range job.values { maximum=math.Max(maximum,math.Abs(value)) }
    if job.pre_end==0 { job.result.Assumptions=append(job.result.Assumptions,"Reset-held quality is unevaluated: no explicit guaranteed pre-event bound was supplied.") }
    job.result.Assumptions=append(job.result.Assumptions,"Amplitude/DC defaults are caller assumptions, not calibration provenance inferred from the input CSV.")
    if maximum==0 { job.result.State="no_signal";return nil }
    if job.mode=="am" { job.result.Units="attenuation_db";e=job.am_curve() } else {
        job.result.Units="cents_relative_to_qualified_carrier"
        job.result.Assumptions=append(job.result.Assumptions,"PM requires calibrated constant amplitude/DC and positive phase advance within +/-800 cents; local frequency is window averaged, not instantaneous.")
        e=job.pm_curve()
    }
    if e!=nil { return e }
    return job.summarize()
}

func (job *modulation_job) validate() error {
    if job.mode!="am" && job.mode!="pm" { return fmt.Errorf("mode must be am or pm") }
    if job.waveform!="periodic" && job.waveform!="noise" { return fmt.Errorf("waveform must be periodic or noise") }
    if job.end==0 { job.end=len(job.values) }
    if !mod_finite(job.increment) || job.increment<=0 || job.increment>=1<<19 ||
       !mod_finite(job.sample_rate) || job.sample_rate<=0 || !mod_finite(job.amplitude) || job.amplitude<32 ||
       !mod_finite(job.offset) || job.window<8 || job.window>len(job.values)/4 || job.hop<1 || job.hop>job.window ||
       job.start<0 || job.pre_end<0 || job.pre_end>job.start || job.end>len(job.values) || job.end-job.start<4*job.window || job.native_stride<1 || job.native_stride>1024 ||
       !mod_finite(job.expected_lfo) || job.expected_lfo<0 || !mod_finite(job.expected_period) || job.expected_period<0 {
        return fmt.Errorf("invalid modulation settings or insufficient bounded data")
    }
    if job.expected_lfo>0 && job.expected_period>0 && math.Abs(job.sample_rate/job.expected_period/job.expected_lfo-1)>1e-8 {
        return fmt.Errorf("expected frequency and sample period disagree")
    }
    for _,value:=range job.values { if !mod_finite(value) { return fmt.Errorf("nonfinite PCM") } }
    if job.mode=="am" && float64(job.window)*job.increment/(1<<20)<1.5 {
        return fmt.Errorf("AM projection requires at least 1.5 carrier cycles")
    }
    return nil
}

func mod_finite(value float64) bool { return !math.IsNaN(value) && !math.IsInf(value,0) }

func (job *modulation_job) am_curve() error {
    radians:=job.increment/(1<<20)*2*math.Pi
    for start:=0;start+job.window<=len(job.values);start+=job.hop {
        var matrix [3][4]float64
        for i:=start;i<start+job.window;i++ {
            basis:=[3]float64{math.Sin(float64(i)*radians),math.Cos(float64(i)*radians),1}
            for r:=0;r<3;r++ {
                for c:=0;c<3;c++ { matrix[r][c]+=basis[r]*basis[c] }
                matrix[r][3]+=basis[r]*job.values[i]
            }
        }
        coefficients,e:=mod_solve(matrix);if e!=nil { return e }
        point:=modulation_point{sample:float64(start)+float64(job.window-1)/2,
            amplitude:math.Hypot(coefficients[0],coefficients[1]),used:job.window}
        for i:=start;i<start+job.window;i++ {
            predicted:=coefficients[0]*math.Sin(float64(i)*radians)+coefficients[1]*math.Cos(float64(i)*radians)+coefficients[2]
            point.carrier_rms+=(job.values[i]-predicted)*(job.values[i]-predicted)
        }
        point.carrier_rms=math.Sqrt(point.carrier_rms/float64(job.window))
        // A zero/near-quantization-floor projection has no logarithmic value.
        if point.amplitude>=32 {
            point.valid=true
            point.value=-20*math.Log10(point.amplitude/job.amplitude)
        }
        job.points=append(job.points,point)
    }
    return nil
}

func mod_solve(matrix [3][4]float64) ([3]float64,error) {
    for column:=0;column<3;column++ {
        pivot:=column
        for row:=column+1;row<3;row++ { if math.Abs(matrix[row][column])>math.Abs(matrix[pivot][column]) { pivot=row } }
        if math.Abs(matrix[pivot][column])<1e-9 { return [3]float64{},fmt.Errorf("singular carrier projection") }
        matrix[column],matrix[pivot]=matrix[pivot],matrix[column]
        divisor:=matrix[column][column]
        for i:=column;i<4;i++ { matrix[column][i]/=divisor }
        for row:=0;row<3;row++ {
            if row==column { continue }
            factor:=matrix[row][column]
            for i:=column;i<4;i++ { matrix[row][i]-=factor*matrix[column][i] }
        }
    }
    return [3]float64{matrix[0][3],matrix[1][3],matrix[2][3]},nil
}

type modulation_phase struct { sample, phase float64 }

func (job *modulation_job) pm_curve() error {
    phases,e:=job.phase_points();if e!=nil { return e }
    left,right:=0,0
    for start:=0;start+job.window<=len(job.values);start+=job.hop {
        for left<len(phases) && phases[left].sample<float64(start) { left++ }
        if right<left { right=left }
        for right<len(phases) && phases[right].sample<float64(start+job.window) { right++ }
        point:=modulation_point{sample:float64(start)+float64(job.window-1)/2,used:right-left}
        if point.used>=4 {
            var mean_x,mean_y float64
            for _,p:=range phases[left:right] { mean_x+=p.sample;mean_y+=p.phase }
            mean_x/=float64(point.used);mean_y/=float64(point.used)
            var numerator,denominator float64
            for _,p:=range phases[left:right] { numerator+=(p.sample-mean_x)*(p.phase-mean_y);denominator+=(p.sample-mean_x)*(p.sample-mean_x) }
            slope:=numerator/denominator
            point.phase=mean_y+slope*(point.sample-mean_x)
            point.increment=slope/(2*math.Pi)*(1<<20)
            if point.increment<=0 { return fmt.Errorf("nonpositive local phase advance") }
            point.frequency=point.increment/(1<<20)*job.sample_rate
            point.value=1200*math.Log2(point.increment/job.increment)
            for _,p:=range phases[left:right] {
                error:=p.phase-(mean_y+slope*(p.sample-mean_x))
                point.phase_rms+=error*error
            }
            point.phase_rms=math.Sqrt(point.phase_rms/float64(point.used))
            point.valid=true
        }
        job.points=append(job.points,point)
    }
    return nil
}

func (job *modulation_job) phase_points() ([]modulation_phase,error) {
    nominal:=job.increment/(1<<20)*2*math.Pi
    maximum,minimum:=nominal*math.Exp2(800.0/1200),nominal/math.Exp2(800.0/1200)
    // Away from |sin|>.8, neither neighbor can cross a turning point under
    // this bound. Known positive advance selects the quadrant uniquely.
    if maximum>=math.Acos(.8) { return nil,fmt.Errorf("configured PM carrier/modulation range exceeds qualified phase-tracking bandwidth") }
    previous,following:=make([]int,len(job.values)),make([]int,len(job.values))
    previous[0]=-1
    for i:=1;i<len(job.values);i++ { previous[i]=previous[i-1];if job.values[i-1]!=job.values[i] { previous[i]=i-1 } }
    following[len(job.values)-1]=-1
    for i:=len(job.values)-2;i>=0;i-- { following[i]=following[i+1];if job.values[i+1]!=job.values[i] { following[i]=i+1 } }
    var points []modulation_phase
    var old,unwrapped,peak float64
    for i,value:=range job.values {
        normalized:=(value-job.offset)/job.amplitude
        peak=math.Max(peak,math.Abs(normalized))
        if math.Abs(normalized)>1.02 { return nil,fmt.Errorf("PCM exceeds calibrated constant PM amplitude") }
        if math.Abs(normalized)>.8 || previous[i]<0 || following[i]<0 { continue }
        difference:=job.values[following[i]]-job.values[previous[i]]
        if difference==0 { continue }
        angle:=math.Asin(normalized)
        if difference<0 { angle=math.Pi-angle }
        if angle<0 { angle+=2*math.Pi }
        if len(points)==0 { unwrapped=angle } else {
            advance:=angle-old
            if advance==0 { continue }
            if advance<0 { advance+=2*math.Pi }
            gap:=float64(i)-points[len(points)-1].sample
            if maximum*gap>=2*math.Pi-.03 || advance>maximum*gap+.03 || advance<minimum*gap-.03 {
                return nil,fmt.Errorf("ambiguous phase gap or unqualified amplitude/advance at sample %d",i)
            }
            unwrapped+=advance
        }
        old=angle
        points=append(points,modulation_phase{float64(i),unwrapped})
    }
    if peak<.97 { return nil,fmt.Errorf("PCM does not reach calibrated PM amplitude; constant-amplitude assumption is unqualified") }
    if len(points)<64 { return nil,fmt.Errorf("not enough unambiguous phase samples") }
    return points,nil
}

func (job *modulation_job) summarize() error {
    var pre,post []modulation_point
    half:=float64(job.window)/2
    invalid:=0
    for _,point:=range job.points {
        if job.pre_end>0 && point.sample+half<float64(job.pre_end) && point.valid { pre=append(pre,point) }
        if point.sample>=float64(job.start)+half && point.sample<float64(job.end)-half {
            if point.valid { post=append(post,point) } else { invalid++ }
        }
    }
    if len(pre)>=8 {
        stats:=mod_span(pre)
        tolerance:=.05
        if job.mode=="pm" { tolerance=1 } else {
            amplitude:=job.amplitude*math.Pow(10,-stats.Median/20)
            // Conservative amplitude error bound for the largest decoded PCM
            // quantum; retain the measured span instead of hiding it.
            tolerance=math.Max(tolerance,20*math.Log10((amplitude+16)/(amplitude-16)))
        }
        job.result.Gate=&modulation_gate{Points:len(pre),Median:stats.Median,Span:stats.Span,Stable:stats.Span<tolerance,Tolerance:tolerance}
    }
    if len(post)<16 { job.result.State="quantization_limited";return nil }
    stats:=mod_span(post);stats.Invalid=invalid;job.result.Span=&stats
    if job.mode=="am" {
        var residuals []float64
        for _,point:=range pre { residuals=append(residuals,point.carrier_rms/(point.amplitude/math.Sqrt2)) }
        if len(residuals)>=8 && mod_quantile(residuals,.5)>.02 { job.result.State="unqualified_reset_held_carrier";return nil }
    }
    threshold:=.05
    if job.mode=="pm" { threshold=1 }
    if job.result.Gate!=nil && job.result.Gate.Stable { threshold=math.Max(threshold,3*job.result.Gate.Span) }
    job.result.ActivityFloor=threshold
    if invalid>0 { job.result.State="quantization_limited";return nil }
    if stats.Span<threshold { job.result.State="no_resolved_modulation";return nil }
    if job.waveform=="noise" {
        job.result.State="noise_features_only"
        job.result.Period=&modulation_period{State:"unscored_noise"}
        return nil
    }
    period:=job.measure_period(post,stats)
    job.result.Period=&period
    job.result.State=period.State
    return nil
}

func mod_span(points []modulation_point) modulation_span {
    values:=make([]float64,len(points))
    for i,point:=range points { values[i]=point.value }
    sort.Float64s(values)
    low,high:=mod_quantile(values,.05),mod_quantile(values,.95)
    return modulation_span{Points:len(points),Minimum:values[0],Maximum:values[len(values)-1],P05:low,P95:high,Span:high-low,Median:mod_quantile(values,.5)}
}

func mod_quantile(values []float64,fraction float64) float64 {
    sorted:=append([]float64(nil),values...)
    sort.Float64s(sorted)
    position:=fraction*float64(len(sorted)-1)
    first:=int(position)
    if first==len(sorted)-1 { return sorted[first] }
    return sorted[first]+(position-float64(first))*(sorted[first+1]-sorted[first])
}

func (job *modulation_job) measure_period(points []modulation_point,stats modulation_span) modulation_period {
    result:=modulation_period{State:"insufficient_cycles"}
    middle:=(stats.P05+stats.P95)/2
    low:=middle-.2*stats.Span
    armed:=points[0].value<low
    var crossings []float64
    for i:=1;i<len(points);i++ {
        before,after:=points[i-1],points[i]
        if after.value<low { armed=true }
        if armed && before.value<middle && after.value>=middle {
            fraction:=(middle-before.value)/(after.value-before.value)
            crossings=append(crossings,before.sample+fraction*(after.sample-before.sample))
            armed=false
        }
    }
    result.Crossings=len(crossings)
    if len(crossings)<3 { return result }
    intervals:=make([]float64,len(crossings)-1)
    for i:=range intervals { intervals[i]=crossings[i+1]-crossings[i] }
    period:=mod_quantile(intervals,.5)
    result.Spread=(mod_quantile(intervals,1)-mod_quantile(intervals,0))/period
    if result.Spread>.08 { result.State="aperiodic_or_unresolved";return result }
    cycles:=int((points[len(points)-1].sample-crossings[0])/period)
    if cycles<2 { return result }
    result.Cycles=cycles
    result.Origin=crossings[0]
    result.Shape=make([]float64,64)
    waveforms:=make([][]float64,cycles)
    for cycle:=0;cycle<cycles;cycle++ {
        waveforms[cycle]=make([]float64,64)
        for bin:=0;bin<64;bin++ {
            at:=crossings[0]+(float64(cycle)+float64(bin)/64)*period
            value:=mod_interpolate(points,at)
            waveforms[cycle][bin]=value
            result.Shape[bin]+=value/float64(cycles)
        }
    }
    var square_error float64
    for _,waveform:=range waveforms {
        for bin,value:=range waveform { square_error+=(value-result.Shape[bin])*(value-result.Shape[bin]) }
    }
    result.Recurrence=math.Sqrt(square_error/float64(cycles*64))/stats.Span
    if result.Recurrence>.12 { result.State="aperiodic_or_unresolved";return result }
    result.Recorded=period
    result.Native=period*float64(job.native_stride)
    result.Frequency=job.sample_rate/period
    uncertainty:=float64(job.window)+(mod_quantile(intervals,1)-mod_quantile(intervals,0))/2
    result.Bounds=&[2]float64{math.Max(0,period-uncertainty),period+uncertainty}
    expected:=job.expected_period
    if expected==0 && job.expected_lfo>0 { expected=job.sample_rate/job.expected_lfo }
    result.State="periodic_measured"
    if expected>0 && (expected<result.Bounds[0] || expected>result.Bounds[1]) { result.State="expected_rate_mismatch" }
    return result
}

func mod_interpolate(points []modulation_point,at float64) float64 {
    index:=sort.Search(len(points),func(i int)bool{return points[i].sample>=at})
    if index==0 { return points[0].value }
    if index==len(points) { return points[index-1].value }
    before,after:=points[index-1],points[index]
    return before.value+(after.value-before.value)*(at-before.sample)/(after.sample-before.sample)
}

func (job *modulation_job) write_curve() error {
    file,e:=os.OpenFile(job.output,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600);if e!=nil { return e }
    out:=csv.NewWriter(file)
    e=out.Write([]string{"sample_center","phase_radians","phase_increment_20bit","frequency_hz","cents","amplitude","attenuation_db","carrier_rms","phase_rms_radians","used_samples","valid"})
    if e!=nil { file.Close();return e }
    format:=func(value float64)string{return strconv.FormatFloat(value,'g',15,64)}
    for _,point:=range job.points {
        row:=make([]string,11)
        row[0]=format(point.sample);row[9]=strconv.Itoa(point.used);row[10]=strconv.FormatBool(point.valid)
        if job.mode=="am" {
            row[5]=format(point.amplitude);row[7]=format(point.carrier_rms)
            if point.valid { row[6]=format(point.value) }
        } else if point.valid {
            row[1]=format(point.phase);row[2]=format(point.increment);row[3]=format(point.frequency)
            row[4]=format(point.value);row[8]=format(point.phase_rms)
        }
        e=out.Write(row);if e!=nil { file.Close();return e }
    }
    out.Flush()
    e=out.Error();if e!=nil { file.Close();return e }
    return file.Close()
}
