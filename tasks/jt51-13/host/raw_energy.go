// Describe public output in fixed sample blocks, without alignment or fitting.
package main

import (
    "bytes"
    "crypto/sha256"
    "encoding/csv"
    "encoding/hex"
    "encoding/json"
    "flag"
    "fmt"
    "io"
    "math"
    "os"
    "sort"
    "strconv"
    "strings"
)

const energy_block_frames = 1024

type energy_options struct {
    input string
    output string
    column string
    kind string
    case_name string
    frames int
    stride int
    native_rate float64
}
type energy_population struct {
    Value int `json:"value"`
    Count int `json:"count"`
}
type energy_word_population struct {
    Word string `json:"raw16_hex"`
    Count int `json:"count"`
}
type energy_stats struct {
    Count int `json:"samples"`
    Nonzero int `json:"nonzero_samples"`
    Positive int `json:"positive_samples"`
    Negative int `json:"negative_samples"`
    Zero int `json:"zero_samples"`
    Minimum int `json:"minimum"`
    Maximum int `json:"maximum"`
    Peak int `json:"absolute_peak"`
    Sum int64 `json:"exact_sum"`
    Squares uint64 `json:"exact_sum_squares"`
    Mean float64 `json:"mean"`
    Energy float64 `json:"mean_square_energy"`
    RMS float64 `json:"RMS"`
    Bipolar bool `json:"bipolar"`
    Exact_zero bool `json:"entire_exactzero"`
    Unique int `json:"unique_linear_values"`
    Population []energy_population `json:"linear_population"`
}
type energy_block struct {
    Index int `json:"block_index_zero_based"`
    First int `json:"first_sample_inclusive"`
    End int `json:"end_sample_exclusive"`
    Full bool `json:"complete_1024_sample_block"`
    Start_seconds float64 `json:"start_seconds_relative_first_retained_sample"`
    Duration_seconds float64 `json:"sample_bin_duration_seconds"`
    Statistics energy_stats `json:"statistics"`
    Normalized_energy *float64 `json:"energy_over_own_whole_peak_squared"`
    Normalized_rms *float64 `json:"RMS_over_own_whole_peak"`
}
type energy_report struct {
    State string `json:"state"`
    Case string `json:"caller_case"`
    Kind string `json:"caller_kind"`
    Input string `json:"input"`
    Input_sha256 string `json:"input_sha256"`
    Format string `json:"CSV_format"`
    Column string `json:"column"`
    Frames int `json:"frames"`
    Stride int `json:"native_stride"`
    Native_rate float64 `json:"caller_native_sample_rate_hz"`
    Recorded_rate float64 `json:"caller_recorded_sample_rate_hz"`
    Duration float64 `json:"sample_bin_duration_seconds"`
    First_to_last float64 `json:"first_to_last_sample_span_seconds"`
    Whole energy_stats `json:"whole"`
    Raw_population []energy_word_population `json:"raw16_word_population_or_null"`
    First_clock *uint64 `json:"first_model_clock_or_null"`
    Last_clock *uint64 `json:"last_model_clock_or_null"`
    Cadence *uint64 `json:"model_clock_cadence_or_null"`
    Ignored []string `json:"unused_model_columns"`
    Blocks []energy_block `json:"fixed_1024_sample_blocks"`
    Block_summary map[string]any `json:"sixteen_block_summary"`
    Quiet_exactzero *bool `json:"quiet_exactzero_or_null"`
    Normalization string `json:"normalization_policy"`
    Limits []string `json:"limits"`
}

func main() {
    o:=energy_options{}
    flag.StringVar(&o.input,"input","","Completed public CSV")
    flag.StringVar(&o.output,"output","","Exclusive new JSON report")
    flag.StringVar(&o.column,"column","","linear for physical; left or right for model")
    flag.StringVar(&o.kind,"kind","target","target or quiet; nonzero quiet report is retained with exit1")
    flag.StringVar(&o.case_name,"case","","Caller profile/repetition label; no inference")
    flag.IntVar(&o.frames,"frames",0,"Exact expected frame count,1..16384")
    flag.IntVar(&o.stride,"stride",0,"Declared native stride,1,3 or32")
    flag.Float64Var(&o.native_rate,"native-rate",0,"Caller native sample rate in Hz; required, not estimated")
    flag.Parse()
    if flag.NArg()!=0 {fmt.Fprintln(os.Stderr,"unexpected positional arguments");os.Exit(2)}
    report,e:=o.analyze();if e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}
    e=o.publish(report);if e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}
    if report.Quiet_exactzero!=nil && !*report.Quiet_exactzero {fmt.Fprintln(os.Stderr,"nonzero quiet retained in report");os.Exit(1)}
}
func (o energy_options) analyze()(energy_report,error) {
    if o.input==""||o.output==""||o.frames<1||o.frames>16384 || (o.stride!=1&&o.stride!=3&&o.stride!=32) || math.IsNaN(o.native_rate)||math.IsInf(o.native_rate,0)||o.native_rate<=0 || (o.kind!="target"&&o.kind!="quiet") {
        return energy_report{},fmt.Errorf("require input/output,frames1..16384,stride1|3|32,finite positive native-rate,kindtarget|quiet")
    }
    data,e:=os.ReadFile(o.input);if e!=nil{return energy_report{},e}
    checksum:=sha256.Sum256(data)
    r:=csv.NewReader(bytes.NewReader(data));header,e:=r.Read();if e!=nil{return energy_report{},e}
    indices:=map[string]int{}
    for i,name:=range header {if _,ok:=indices[name];ok||name==""{return energy_report{},fmt.Errorf("duplicate/empty CSV column")};indices[name]=i}
    for _,name:=range []string{"sample",o.column}{if _,ok:=indices[name];!ok{return energy_report{},fmt.Errorf("missing CSV column %q",name)}}
    report:=energy_report{State:"DESCRIPTIVE_PUBLIC_STREAM_RETAINED_NO_CONFORMANCE_SCORE",Case:o.case_name,Kind:o.kind,Input:o.input,Input_sha256:hex.EncodeToString(checksum[:]),Column:o.column,Frames:o.frames,Stride:o.stride,Native_rate:o.native_rate,Recorded_rate:o.native_rate/float64(o.stride),Normalization:"Each block uses its own stream's single whole-record absolute peak. Zero peak produces null. This hides absolute gain, so raw energies/PCM remain primary; no per-block normalization or alignment."}
    physical:=o.column=="linear"
    if physical {
        if strings.Join(header,",")!="sample,raw16_hex,linear"{return report,fmt.Errorf("physical CSV requires exact sample,raw16_hex,linear header")};report.Format="physical_public_linear_and_raw16"
    } else {
        if o.column!="left"&&o.column!="right"{return report,fmt.Errorf("model column must be left or right")}
        for _,name:=range []string{"left","right","clock"}{if _,ok:=indices[name];!ok{return report,fmt.Errorf("model CSV missing %s",name)}}
        report.Format="model_public_left_right_masterclock"
        for _,name:=range header {if name!="sample"&&name!="left"&&name!="right"&&name!="clock"{report.Ignored=append(report.Ignored,name)}}
    }
    r.FieldsPerRecord=len(header)
    samples:=make([]int,0,o.frames);raw_counts:=map[uint16]int{};var previous_clock uint64
    for {
        row,e:=r.Read();if e==io.EOF{break};if e!=nil{return report,e}
        if len(samples)>=o.frames{return report,fmt.Errorf("CSV contains more than declared frames")}
        index,e:=energy_uint(row[indices["sample"]]);if e!=nil||index!=uint64(len(samples)){return report,fmt.Errorf("nonconsecutive CSV sample index at row%d",len(samples))}
        if physical {
            word:=row[indices["raw16_hex"]];if len(word)!=4||strings.Trim(word,"0123456789abcdefABCDEF")!=""{return report,fmt.Errorf("raw16_hex must have exactly4 hex digits")}
            value,e:=strconv.ParseUint(word,16,16);if e!=nil{return report,e};raw_counts[uint16(value)]++
        } else {
            for _,name:=range []string{"left","right"}{if _,e:=energy_pcm(row[indices[name]]);e!=nil{return report,e}}
            clock,e:=energy_uint(row[indices["clock"]]);if e!=nil{return report,e}
            if len(samples)==0 {first:=clock;report.First_clock=&first} else if clock<previous_clock||clock-previous_clock!=uint64(64*o.stride){return report,fmt.Errorf("model clock cadence differs from64*stride at sample%d",len(samples))}
            previous_clock=clock
        }
        value,e:=energy_pcm(row[indices[o.column]]);if e!=nil{return report,e};samples=append(samples,value)
    }
    if len(samples)!=o.frames{return report,fmt.Errorf("CSV frame count%d differs from declared%d",len(samples),o.frames)}
    if !physical {last:=previous_clock;report.Last_clock=&last;if o.frames>1{cadence:=uint64(64*o.stride);report.Cadence=&cadence}}
    for word,count:=range raw_counts {report.Raw_population=append(report.Raw_population,energy_word_population{fmt.Sprintf("%04x",word),count})}
    sort.Slice(report.Raw_population,func(i,j int)bool{return report.Raw_population[i].Word<report.Raw_population[j].Word})
    report.Whole=energy_summarize(samples)
    report.Duration=float64(o.frames)/report.Recorded_rate;report.First_to_last=float64(o.frames-1)/report.Recorded_rate
    energies:=[]float64{};rms_values:=[]float64{};peak:=float64(report.Whole.Peak)
    for first:=0;first<len(samples);first+=energy_block_frames {
        end:=min(first+energy_block_frames,len(samples));s:=energy_summarize(samples[first:end])
        b:=energy_block{Index:len(report.Blocks),First:first,End:end,Full:end-first==energy_block_frames,Start_seconds:float64(first)/report.Recorded_rate,Duration_seconds:float64(end-first)/report.Recorded_rate,Statistics:s}
        if peak>0 {en:=s.Energy/(peak*peak);rm:=s.RMS/peak;b.Normalized_energy=&en;b.Normalized_rms=&rm}
        report.Blocks=append(report.Blocks,b);energies=append(energies,s.Energy);rms_values=append(rms_values,s.RMS)
    }
    summary_state:="not_exactly_sixteen_complete_blocks"
    if o.frames==16*energy_block_frames{summary_state="sixteen_complete_fixed_blocks"}
    report.Block_summary=map[string]any{"state":summary_state,"complete_blocks":o.frames/energy_block_frames,"partial_tail_samples":o.frames%energy_block_frames,"block_energy_sequence":energies,"block_RMS_sequence":rms_values,"first_to_last_no_alignment":true}
    if o.kind=="quiet" {quiet:=report.Whole.Exact_zero;report.Quiet_exactzero=&quiet;if quiet{report.State="QUIET_EXACTZERO_RETAINED"}else{report.State="QUIET_NONZERO_OBSERVATION_RETAINED"}}
    report.Limits=[]string{"Only completed, externally bound captures/models may be supplied; this CSV utility does not establish capture/manifest completion or raw transport qualification.","Source sample0 is the only origin; no event alignment, phase fit, gain/DC correction, resampling or conformance tolerance.","Fixed1024-sample windows have stride-dependent physical duration. Cross-stride windows are not equivalent transient features.","Zero/silent/nonbipolar targets retain descriptors; process success does not imply a resolved envelope or chip agreement.","Raw16 words are counted, not decoded again; supplied linear PCM and existing independent decode audit remain separate.","Caller rate/stride are provenance, not measured frequency; all signed samples including DC and quantized zeros contribute to energy.","A quiet check applies to the selected column only; both physical latches need separate bound reports."}
    return report,nil
}
func (o energy_options) publish(report energy_report)error {
    data,e:=json.MarshalIndent(report,"","  ");if e!=nil{return e}
    f,e:=os.OpenFile(o.output,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0644);if e!=nil{return e}
    _,e=f.Write(append(data,'\n'));close_e:=f.Close();if e!=nil{return e};return close_e
}
func energy_summarize(values []int)energy_stats {
    s:=energy_stats{Count:len(values),Minimum:values[0],Maximum:values[0]};population:=map[int]int{}
    for _,v:=range values {
        s.Minimum=min(s.Minimum,v);s.Maximum=max(s.Maximum,v);s.Peak=max(s.Peak,energy_abs(v));s.Sum+=int64(v);s.Squares+=uint64(int64(v)*int64(v));population[v]++
        if v>0{s.Positive++}else if v<0{s.Negative++}else{s.Zero++}
    }
    s.Nonzero=s.Positive+s.Negative;s.Bipolar=s.Positive>0&&s.Negative>0;s.Exact_zero=s.Nonzero==0;s.Unique=len(population)
    s.Mean=float64(s.Sum)/float64(s.Count);s.Energy=float64(s.Squares)/float64(s.Count);s.RMS=math.Sqrt(s.Energy)
    for value,count:=range population{s.Population=append(s.Population,energy_population{value,count})};sort.Slice(s.Population,func(i,j int)bool{return s.Population[i].Value<s.Population[j].Value})
    return s
}
func energy_uint(s string)(uint64,error){if s==""||strings.Trim(s,"0123456789")!=""{return 0,fmt.Errorf("invalid nonnegative integer %q",s)};return strconv.ParseUint(s,10,64)}
func energy_pcm(s string)(int,error){if s==""||strings.Trim(strings.TrimPrefix(s,"-"),"0123456789")!=""{return 0,fmt.Errorf("invalid signed PCM %q",s)};v,e:=strconv.ParseInt(s,10,16);return int(v),e}
func energy_abs(v int)int{if v<0{return -v};return v}
