// Original raw PCM descriptors; no synthesis/model arithmetic or fitted corrections.
package main
import("bytes";"crypto/sha256";"encoding/csv";"encoding/json";"flag";"fmt";"io";"math";"os";"sort";"strconv";"strings")
type job struct{input,output,column,lower,upper string;first,end,jump int}
type level struct{Value int `json:"value"`;Count int `json:"count"`}
type summary struct{
 Samples int `json:"samples"`;Minimum int `json:"minimum"`;Maximum int `json:"maximum"`
 Sum int64 `json:"sum"`;SumSquares int64 `json:"sum_squares"`
 Mean float64 `json:"mean"`;RMS float64 `json:"rms"`;ACRMS float64 `json:"ac_rms"`
 ZeroCount int `json:"zero_count"`;NegativeCount int `json:"negative_count"`;PositiveCount int `json:"positive_count"`
 ZeroFraction float64 `json:"zero_fraction"`;NegativeFraction float64 `json:"negative_fraction"`;PositiveFraction float64 `json:"positive_fraction"`
}
type endpoint struct{Value int `json:"value"`;Count int `json:"count"`;MaximumRun int `json:"maximum_run"`}
type descriptors struct{
 Summary summary `json:"summary"`;UniqueLevels int `json:"unique_levels"`;Levels []level `json:"level_population"`
 ObservedLower endpoint `json:"observed_lower"`;ObservedUpper endpoint `json:"observed_upper"`
 RequestedEndpoints []endpoint `json:"requested_endpoints"`
 MaximumEqualRun int `json:"maximum_equal_run"`
 AdjacentOppositeSigns int `json:"adjacent_opposite_signs"`;NonzeroSignChanges int `json:"nonzero_sign_changes"`
 DifferenceMinimum int `json:"difference_minimum"`;DifferenceMaximum int `json:"difference_maximum"`
 Differences []level `json:"difference_population"`;LargeJumpThreshold int `json:"large_jump_threshold"`;LargeJumpCount int `json:"large_jump_count"`
 Quarters []summary `json:"quarters"`;RawWords map[string]int `json:"raw16_hex_population,omitempty"`
}
func main(){
 var task job
 flag.StringVar(&task.input,"input","","PCM CSV")
 flag.StringVar(&task.output,"output","","fresh JSON file")
 flag.StringVar(&task.column,"column","left","left, right, or linear")
 flag.StringVar(&task.lower,"lower-level","","optional endpoint integer, not inferred as a clip rail")
 flag.StringVar(&task.upper,"upper-level","","optional endpoint integer, not inferred as a clip rail")
 flag.IntVar(&task.first,"start",0,"first native sample index")
 flag.IntVar(&task.end,"end",0,"exclusive end, zero means all")
 flag.IntVar(&task.jump,"jump-threshold",4096,"absolute first difference counted as large, inclusive")
 flag.Parse();e:=task.run();if e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}
}
func(task *job)run()error{
 if task.input==""||task.output==""||flag.NArg()!=0{return fmt.Errorf("use -input PCM.csv -output NEW.json [-column left|right|linear]")}
 if task.column!="left"&&task.column!="right"&&task.column!="linear"{return fmt.Errorf("unsupported PCM column")}
 if task.jump<1||task.jump>65535{return fmt.Errorf("jump threshold outside positive PCM difference range")}
 if _,e:=os.Lstat(task.output);e==nil{return fmt.Errorf("output already exists")}else if !os.IsNotExist(e){return e}
 info,e:=os.Stat(task.input);if e!=nil{return e};if !info.Mode().IsRegular()||info.Size()>64*1024*1024{return fmt.Errorf("input type/size limit")}
 raw,e:=os.ReadFile(task.input);if e!=nil{return e}
 values,words,e:=read_pcm(raw,task.column);if e!=nil{return e}
 end:=task.end;if end==0{end=len(values)}
 if task.first<0||end>len(values)||end<=task.first||end-task.first<128{return fmt.Errorf("invalid/too-short window: minimum128 samples")}
 points:=[]int{}
 for _,text:=range []string{task.lower,task.upper}{if text!=""{v,e:=strconv.Atoi(text);if e!=nil||v< -32768||v>32767{return fmt.Errorf("invalid endpoint")};points=append(points,v)}}
 selected:=values[task.first:end]
 result:=describe(selected,task.jump,points)
 if words!=nil{result.RawWords=map[string]int{};for _,w:=range words[task.first:end]{result.RawWords[w]++}}
 output:=map[string]interface{}{"method":"raw-pcm-descriptors-v1","classification":"descriptors_only_no_chip_conformance","input":task.input,"input_sha256":fmt.Sprintf("%x",sha256.Sum256(raw)),"column":task.column,"input_samples":len(values),"native_stride":1,"first_sample":task.first,"end_sample_exclusive":end,"minimum_window_samples":128,"result":result}
 data,e:=json.MarshalIndent(output,"","  ");if e!=nil{return e}
 file,e:=os.OpenFile(task.output,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600);if e!=nil{return e}
 _,e=file.Write(append(data,'\n'));close_error:=file.Close();if e!=nil{return e};return close_error
}
func read_pcm(raw []byte,column string)([]int,[]string,error){
 lines:=bytes.Split(raw,[]byte{'\n'})
 for i,line:=range lines{if len(bytes.TrimSpace(line))==0&&i<len(lines)-1{return nil,nil,fmt.Errorf("blank CSV line")}}
 reader:=csv.NewReader(bytes.NewReader(raw))
 header,e:=reader.Read();if e!=nil{return nil,nil,e}
 positions:=map[string]int{}
 for i,name:=range header{
  if name==""||strings.TrimSpace(name)!=name{return nil,nil,fmt.Errorf("empty/noncanonical header")}
  if _,ok:=positions[name];ok{return nil,nil,fmt.Errorf("duplicate header")}
  switch name{case "sample","clock","left","right","linear","raw16_hex":default:return nil,nil,fmt.Errorf("unknown CSV column %s",name)}
  positions[name]=i
 }
 si,sok:=positions["sample"];vi,vok:=positions[column]
 if !sok||!vok{return nil,nil,fmt.Errorf("missing sample/selected PCM column")}
 values:=[]int{};var words []string
 wi,has_words:=positions["raw16_hex"];if has_words{words=[]string{}}
 ci,has_clock:=positions["clock"];var previous_clock uint64
 for row_number:=0;;row_number++{
  row,e:=reader.Read();if e==io.EOF{break};if e!=nil{return nil,nil,e}
  if row_number>=1048576{return nil,nil,fmt.Errorf("sample-count limit")}
  sample,e:=strconv.ParseInt(row[si],10,64);if e!=nil||sample!=int64(row_number){return nil,nil,fmt.Errorf("nonconsecutive native sample at row%d",row_number)}
  for name,index:=range positions{
   if name=="left"||name=="right"||name=="linear"{
    x,e:=strconv.ParseFloat(row[index],64)
    if e!=nil||math.IsNaN(x)||math.IsInf(x,0)||x!=math.Trunc(x)||x< -32768||x>32767{return nil,nil,fmt.Errorf("nonfinite/nonintegral/out-of-range PCM %s row%d",name,row_number)}
   }
  }
  value,_:=strconv.ParseFloat(row[vi],64);values=append(values,int(value))
  if has_clock{
   clock,e:=strconv.ParseUint(row[ci],10,64);if e!=nil{return nil,nil,fmt.Errorf("invalid clock")}
   if row_number>0&&(clock<=previous_clock||clock-previous_clock!=64){return nil,nil,fmt.Errorf("nonconsecutive model native clocks")}
   previous_clock=clock
  }
  if has_words{
   text:=row[wi];_,e:=strconv.ParseUint(text,16,16)
   if e!=nil||len(text)!=4{return nil,nil,fmt.Errorf("invalid raw16_hex")}
   words=append(words,text)
  }
 }
 if len(values)<128{return nil,nil,fmt.Errorf("too-short CSV: minimum128 samples")}
 return values,words,nil
}
func describe(v []int,jump int,requested []int)descriptors{
 stats:=summarize(v)
 out:=descriptors{Summary:stats,ObservedLower:at_endpoint(v,stats.Minimum),ObservedUpper:at_endpoint(v,stats.Maximum),LargeJumpThreshold:jump,RequestedEndpoints:[]endpoint{},Quarters:[]summary{}}
 counts,deltas:=map[int]int{},map[int]int{}
 longest,run,prior_sign:=0,0,0
 for i,x:=range v{
  counts[x]++
  if i==0||x!=v[i-1]{run=1}else{run++};if run>longest{longest=run}
  sign:=0;if x>0{sign=1};if x<0{sign=-1}
  if sign!=0{if prior_sign!=0&&sign!=prior_sign{out.NonzeroSignChanges++};prior_sign=sign}
  if i==0{continue}
  d:=x-v[i-1];deltas[d]++
  if i==1||d<out.DifferenceMinimum{out.DifferenceMinimum=d}
  if i==1||d>out.DifferenceMaximum{out.DifferenceMaximum=d}
  if d>=jump||d<= -jump{out.LargeJumpCount++}
  if (x>0&&v[i-1]<0)||(x<0&&v[i-1]>0){out.AdjacentOppositeSigns++}
 }
 out.UniqueLevels=len(counts);out.Levels=population(counts);out.Differences=population(deltas);out.MaximumEqualRun=longest
 for _,x:=range requested{out.RequestedEndpoints=append(out.RequestedEndpoints,at_endpoint(v,x))}
 for q:=0;q<4;q++{out.Quarters=append(out.Quarters,summarize(v[q*len(v)/4:(q+1)*len(v)/4]))}
 return out
}
func summarize(v []int)summary{
 out:=summary{Samples:len(v),Minimum:v[0],Maximum:v[0]}
 for _,x:=range v{
  if x<out.Minimum{out.Minimum=x};if x>out.Maximum{out.Maximum=x}
  out.Sum+=int64(x);out.SumSquares+=int64(x)*int64(x)
  if x==0{out.ZeroCount++};if x<0{out.NegativeCount++};if x>0{out.PositiveCount++}
 }
 out.Mean=float64(out.Sum)/float64(len(v));out.RMS=math.Sqrt(float64(out.SumSquares)/float64(len(v)))
 energy:=0.0;for _,x:=range v{d:=float64(x)-out.Mean;energy+=d*d}
 out.ACRMS=math.Sqrt(energy/float64(len(v)))
 out.ZeroFraction=float64(out.ZeroCount)/float64(len(v));out.NegativeFraction=float64(out.NegativeCount)/float64(len(v));out.PositiveFraction=float64(out.PositiveCount)/float64(len(v))
 return out
}
func at_endpoint(v []int,x int)endpoint{
 out:=endpoint{Value:x};run:=0
 for _,value:=range v{if value==x{out.Count++;run++;if run>out.MaximumRun{out.MaximumRun=run}}else{run=0}}
 return out
}
func population(counts map[int]int)[]level{
 keys:=[]int{};for key:=range counts{keys=append(keys,key)};sort.Ints(keys)
 out:=[]level{};for _,key:=range keys{out=append(out,level{key,counts[key]})}
 return out
}

