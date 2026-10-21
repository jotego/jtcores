// Partial-only adapter: original analyze body and summarize prefix; period dispatch is absent.
package main
import("math")
func (job *modulation_job) analyze_partial() error {
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
    return job.summarize_partial()
}

func (job *modulation_job) summarize_partial() error {
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
    job.result.State="partial_features_only"
    return nil
}
