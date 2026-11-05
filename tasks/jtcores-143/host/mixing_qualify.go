// Original finite method qualification only; never invokes chip models/hardware.
package main
import("bytes";"crypto/sha256";"encoding/csv";"encoding/json";"flag";"fmt";"math";"math/rand";"os";"os/exec";"path/filepath";"sort";"strconv";"strings";"time")
type trial struct{Name string `json:"name"`;Command []string `json:"command,omitempty"`;WantFailure bool `json:"want_failure,omitempty"`;ExitCode int `json:"exit_code"`;Stdout string `json:"stdout,omitempty"`;Stderr string `json:"stderr,omitempty"`;Pass bool `json:"pass"`}
type qualification struct{output,generator,validator,describe string;trials []trial;controls []map[string]interface{}}
func main(){
 var job qualification
 flag.StringVar(&job.output,"output","","fresh directory")
 flag.StringVar(&job.generator,"generator","","generator executable")
 flag.StringVar(&job.validator,"validator","","literal validator executable")
 flag.StringVar(&job.describe,"describe","","raw descriptor executable")
 flag.Parse();e:=job.run();if e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}
}
func(job *qualification)run()error{
 if job.output==""||job.generator==""||job.validator==""||job.describe==""||flag.NArg()!=0{return fmt.Errorf("use -output NEW -generator EXE -validator EXE -describe EXE")}
 for _,path:=range []string{job.generator,job.validator,job.describe}{if !filepath.IsAbs(path){return fmt.Errorf("absolute executable paths required")}}
 e:=os.Mkdir(job.output,0755);if e!=nil{return e}
 for _,name:=range []string{"controls","csv-negatives","mutations","sandbox"}{e=os.Mkdir(filepath.Join(job.output,name),0755);if e!=nil{return e}}
 e=job.programs();if e!=nil{return e}
 e=job.math_controls();if e!=nil{return e}
 e=job.csv_negatives();if e!=nil{return e}
 e=job.save(true);if e!=nil{return e}
 fmt.Printf("Finite method qualification passed: %d command trials, %d generic controls; no chip coverage\n",len(job.trials),len(job.controls))
 return nil
}
func(job *qualification)programs()error{
 first,second:=filepath.Join(job.output,"programs"),filepath.Join(job.output,"programs-reproduction")
 for i,path:=range []string{first,second}{
  e:=job.command(fmt.Sprintf("generate-%d",i),false,job.generator,"-output",path);if e!=nil{return e}
  e=job.command(fmt.Sprintf("validate-%d",i),false,job.validator,"-input",path);if e!=nil{return e}
 }
 files,e:=os.ReadDir(first);if e!=nil{return e}
 for _,file:=range files{
  a,e:=os.ReadFile(filepath.Join(first,file.Name()));if e!=nil{return e}
  b,e:=os.ReadFile(filepath.Join(second,file.Name()));if e!=nil{return e}
  if !bytes.Equal(a,b){return fmt.Errorf("reproduction mismatch %s",file.Name())}
 }
 job.controls=append(job.controls,map[string]interface{}{"name":"byte-exact-reproduction","files":len(files),"pass":len(files)==130})
 negatives:=[]struct{name string;exe string;args []string}{
  {"generator-no-args",job.generator,nil},{"generator-extra-arg",job.generator,[]string{"-output",filepath.Join(job.output,"must-not-exist"),"extra"}},
  {"generator-unknown-flag",job.generator,[]string{"-unknown"}},{"generator-reused-directory",job.generator,[]string{"-output",first}},
  {"generator-existing-file",job.generator,[]string{"-output",filepath.Join(first,"cases.json")}},
  {"validator-no-args",job.validator,nil},{"validator-extra-arg",job.validator,[]string{"-input",first,"extra"}},
  {"validator-unknown-flag",job.validator,[]string{"-unknown"}},{"validator-missing-directory",job.validator,[]string{"-input",filepath.Join(job.output,"absent")}},
 }
 for _,test:=range negatives{e=job.command(test.name,true,test.exe,test.args...);if e!=nil{return e}}
 sandbox:=filepath.Join(job.output,"sandbox")
 original:=map[string][]byte{}
 for _,file:=range files{
  raw,e:=os.ReadFile(filepath.Join(first,file.Name()));if e!=nil{return e};original[file.Name()]=raw
  e=os.WriteFile(filepath.Join(sandbox,file.Name()),raw,0600);if e!=nil{return e}
 }
 names:=[]string{"missing-profile","reordered-profiles","wrong-contributor","unknown-json-field","empty-digest","duplicate-json-field","wrong-pilot","unsafe-path","invalid-opcode","missing-terminator","trailing-bytecode","truncated-bytecode","zero-model-delay","self-consistent-wrong-TL","wrong-cleanup-order","extra-file"}
 for _,name:=range names{
  e=job.mutation(name,sandbox,original);if e!=nil{return e}
  e=job.command("restored-"+name,false,job.validator,"-input",sandbox);if e!=nil{return e}
 }
 return nil
}
func(job *qualification)mutation(name,sandbox string,original map[string][]byte)error{
 var cases []map[string]interface{}
 e:=json.Unmarshal(original["cases.json"],&cases);if e!=nil{return e}
 changed:=map[string][]byte{}
 first:=cases[0];init:=first["init"].(string);model:=first["model_init"].(string)
 switch name{
 case "missing-profile":cases=cases[:62]
 case "reordered-profiles":cases[0],cases[1]=cases[1],cases[0]
 case "wrong-contributor":first["contributors"]=2
 case "unknown-json-field":first["unsupported"]=true
 case "empty-digest":first["init_sha256"]=""
 case "duplicate-json-field":
 case "wrong-pilot":changed["pilot.json"]=[]byte("[]\n")
 case "unsafe-path":first["init"]="../outside.bin"
 case "invalid-opcode":data:=append([]byte(nil),original[init]...);data[0]=99;changed[init]=data;first["init_sha256"]=digest(data)
 case "missing-terminator":data:=append([]byte(nil),original[init][:len(original[init])-1]...);changed[init]=data;first["init_sha256"]=digest(data)
 case "trailing-bytecode":data:=append(append([]byte(nil),original[init]...),1);changed[init]=data;first["init_sha256"]=digest(data)
 case "truncated-bytecode":data:=[]byte{1,20};changed[init]=data;first["init_sha256"]=digest(data)
 case "zero-model-delay":
  data:=append([]byte(nil),original[model]...)
  for i:=0;i+2<len(data);i+=3{if data[i]==2{data[i+1]=0;data[i+2]=0;break}}
  changed[model]=data;first["model_init_sha256"]=digest(data)
 case "self-consistent-wrong-TL":
  for _,pair:=range [][3]string{{init,"init_sha256","init_operations"},{model,"model_init_sha256","model_init_operations"}}{
   data:=append([]byte(nil),original[pair[0]]...)
   for i:=0;i+2<len(data);i+=3{if data[i]==1&&data[i+1]==96{data[i+2]=17}}
   changed[pair[0]]=data;first[pair[1]]=digest(data)
   for _,entry:=range first[pair[2]].([]interface{}){op:=entry.(map[string]interface{});if op["kind"]=="write"&&op["reg"]==float64(96){op["value"]=17}}
  }
 case "wrong-cleanup-order":
  data:=append([]byte(nil),original["cleanup.bin"]...);data[0],data[3]=data[3],data[0];data[1],data[4]=data[4],data[1];data[2],data[5]=data[5],data[2];changed["cleanup.bin"]=data
 case "extra-file":changed["unexpected.bin"]=[]byte{0}
 default:return fmt.Errorf("unknown mutation")
 }
 if name!="wrong-pilot"&&name!="wrong-cleanup-order"&&name!="extra-file"{data,e:=json.MarshalIndent(cases,"","  ");if e!=nil{return e};if name=="duplicate-json-field"{data=bytes.Replace(data,[]byte("\"name\": \"sum-n01-tl00\""),[]byte("\"name\": \"sum-n01-tl00\", \"name\": \"sum-n01-tl00\""),1)};changed["cases.json"]=append(data,'\n')}
 saved:=filepath.Join(job.output,"mutations",name);e=os.Mkdir(saved,0755);if e!=nil{return e}
 keys:=[]string{};for key:=range changed{keys=append(keys,key)};sort.Strings(keys)
 for _,key:=range keys{
  e=os.WriteFile(filepath.Join(saved,key),changed[key],0600);if e!=nil{return e}
  e=os.WriteFile(filepath.Join(sandbox,key),changed[key],0600);if e!=nil{return e}
 }
 e=job.command("reject-"+name,true,job.validator,"-input",sandbox);if e!=nil{return e}
 for _,key:=range keys{
  if raw,ok:=original[key];ok{e=os.WriteFile(filepath.Join(sandbox,key),raw,0600)}else{e=os.Remove(filepath.Join(sandbox,key))}
  if e!=nil{return e}
 }
 return nil
}
func(job *qualification)math_controls()error{
 count:=4096
 waves:=map[string][]int{}
 make_wave:=func(name string,f func(int)float64){
  v:=make([]int,count);for i:=range v{v[i]=int(math.Round(f(i)))};waves[name]=v
 }
 angle:=func(i int,k float64)float64{return 2*math.Pi*k*float64(i)/float64(count)}
 make_wave("silence",func(i int)float64{return 0})
 make_wave("stuck-dc37",func(i int)float64{return 37})
 make_wave("weak-sine",func(i int)float64{return 3*math.Sin(angle(i,7))})
 make_wave("sine",func(i int)float64{return 93*math.Sin(angle(i,7))})
 make_wave("sine-arbitrary-dc",func(i int)float64{return 93*math.Sin(angle(i,7))+11})
 make_wave("constructive-three",func(i int)float64{return 3*93*math.Sin(angle(i,7))})
 make_wave("canceling-pair",func(i int)float64{x:=93*math.Sin(angle(i,7));return x-x})
 make_wave("multisine",func(i int)float64{return 71*math.Sin(angle(i,7))+39*math.Sin(angle(i,13)+.7)+17*math.Sin(angle(i,37)+2.1)-9})
 make_wave("drifting-wave",func(i int)float64{t:=float64(i)/float64(count);return (61+29*t)*math.Sin(2*math.Pi*(7*t+.35*t*t))})
 make_wave("changing-wave",func(i int)float64{if i<count/2{return 93*math.Sin(angle(i,7))};return -41*math.Sin(angle(i,7))+31})
 noise:=rand.New(rand.NewSource(54821))
 make_wave("mixed-noise",func(i int)float64{return 67*math.Sin(angle(i,7))+float64(noise.Intn(39)-19)})
 source:=waves["constructive-three"]
 for _,name:=range []string{"generic-clipped","generic-wrapped","uniform-grid7","floating-grid-like"}{
  v:=make([]int,count)
  for i,x:=range source{
   switch name{
   case "generic-clipped":v[i]=x;if x>47{v[i]=47};if x< -47{v[i]=-47}
   case "generic-wrapped":v[i]=((x+48)%96+96)%96-48
   case "uniform-grid7":v[i]=int(math.Round(float64(x)/7))*7
   case "floating-grid-like":step:=1;if x>37||x< -37{step=5};if x>109||x< -109{step=13};v[i]=int(math.Round(float64(x)/float64(step)))*step
   }
  }
  waves[name]=v
 }
 waves["dc-injection3"]=make([]int,count);waves["block-injection18"]=make([]int,count)
 for i,x:=range waves["sine"]{waves["dc-injection3"][i]=x+3;waves["block-injection18"][i]=x;if i>=count/2{waves["block-injection18"][i]+=18}}
 literal:=[]int{};for repeat:=0;repeat<16;repeat++{literal=append(literal,-5,-5,-2,0,3,3,3,7)};waves["literal-counts"]=literal
 rails:=[]int{};for i:=0;i<64;i++{rails=append(rails,-32768,32767)};waves["container-rails"]=rails
 names:=[]string{};for name:=range waves{names=append(names,name)};sort.Strings(names)
 results:=map[string]map[string]interface{}{}
 for _,name:=range names{
  path:=filepath.Join(job.output,"controls",name+".csv");e:=write_csv(path,waves[name]);if e!=nil{return e}
  output:=filepath.Join(job.output,"controls",name+".json")
  threshold:=16;if name=="literal-counts"{threshold=8}
  e=job.command("describe-"+name,false,job.describe,"-input",path,"-output",output,"-column","left","-jump-threshold",strconv.Itoa(threshold),"-lower-level","-47","-upper-level","47");if e!=nil{return e}
  result,e:=load_result(output);if e!=nil{return e};results[name]=result
  e=known_counts(waves[name],result);if e!=nil{return fmt.Errorf("%s: %w",name,e)}
  job.controls=append(job.controls,map[string]interface{}{"name":name,"samples":len(waves[name]),"csv_sha256":file_digest(path),"descriptor_sha256":file_digest(output),"independent_exact_count_check":"pass","mathematics":"generic sampled controls; no chip quantization, clipping order, or reference constants"})
 }
 literal_result:=results["literal-counts"]
 for key,want:=range map[string]float64{"difference_minimum":-12,"difference_maximum":4,"large_jump_count":15,"maximum_equal_run":3,"adjacent_opposite_signs":15,"nonzero_sign_changes":31}{
  if literal_result[key]!=want{return fmt.Errorf("literal descriptor %s: got%v want%v",key,literal_result[key],want)}
 }
 lower:=literal_result["observed_lower"].(map[string]interface{});upper:=literal_result["observed_upper"].(map[string]interface{})
 if lower["count"]!=float64(32)||lower["maximum_run"]!=float64(2)||upper["count"]!=float64(16)||upper["maximum_run"]!=float64(1){return fmt.Errorf("literal endpoint/run counts")}
 rail_result:=results["container-rails"]
 if rail_result["difference_minimum"]!=float64(-65535)||rail_result["difference_maximum"]!=float64(65535)||rail_result["large_jump_count"]!=float64(127){return fmt.Errorf("container full-difference preservation")}
 clipped:=results["generic-clipped"];wrapped:=results["generic-wrapped"]
 if clipped["observed_lower"].(map[string]interface{})["value"]!=float64(-47)||clipped["observed_upper"].(map[string]interface{})["value"]!=float64(47){return fmt.Errorf("generic saturation endpoints")}
 if clipped["observed_upper"].(map[string]interface{})["count"].(float64)<=1||clipped["observed_lower"].(map[string]interface{})["maximum_run"].(float64)<=1{return fmt.Errorf("generic saturation occupancy")}
 if wrapped["large_jump_count"].(float64)<=results["constructive-three"]["large_jump_count"].(float64){return fmt.Errorf("generic wrap jump descriptor lost")}
 if same_feature(clipped,results["uniform-grid7"],"level_population")||same_feature(clipped,results["floating-grid-like"],"difference_population")||same_feature(clipped,wrapped,"difference_population"){return fmt.Errorf("clipped/quantized/wrapped controls collapsed")}
 mean:=func(name string)float64{return results[name]["summary"].(map[string]interface{})["mean"].(float64)}
 if math.Abs(mean("dc-injection3")-mean("sine")-3)>1e-12{return fmt.Errorf("3PCM injected DC lost")}
 quarters:=results["block-injection18"]["quarters"].([]interface{});base_quarters:=results["sine"]["quarters"].([]interface{})
 for q:=0;q<4;q++{delta:=quarters[q].(map[string]interface{})["mean"].(float64)-base_quarters[q].(map[string]interface{})["mean"].(float64);want:=0.0;if q>=2{want=18};if math.Abs(delta-want)>1e-12{return fmt.Errorf("18PCM block change lost")}}
 if results["weak-sine"]["summary"].(map[string]interface{})["rms"].(float64)<=0||results["silence"]["unique_levels"]!=float64(1)||results["canceling-pair"]["summary"].(map[string]interface{})["zero_count"]!=float64(count){return fmt.Errorf("weak/silent/canceling control")}
 right_path:=filepath.Join(job.output,"controls","literal-counts-right.json")
 e:=job.command("describe-selected-right",false,job.describe,"-input",filepath.Join(job.output,"controls","literal-counts.csv"),"-output",right_path,"-column","right");if e!=nil{return e}
 right_result,e:=load_result(right_path);if e!=nil{return e}
 right_values:=make([]int,len(literal));for i,x:=range literal{right_values[i]=-x}
 e=known_counts(right_values,right_result);if e!=nil{return e}
 raw_path:=filepath.Join(job.output,"controls","literal-raw-linear.csv")
 raw_file,e:=os.OpenFile(raw_path,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600);if e!=nil{return e}
 raw_writer:=csv.NewWriter(raw_file);raw_writer.Write([]string{"sample","raw16_hex","linear"})
 for i,x:=range literal{raw_writer.Write([]string{strconv.Itoa(i),fmt.Sprintf("%04x",uint16(int16(x))),strconv.Itoa(x)})};raw_writer.Flush();write_error:=raw_writer.Error();close_error:=raw_file.Close();if write_error!=nil{return write_error};if close_error!=nil{return close_error}
 raw_output:=filepath.Join(job.output,"controls","literal-raw-linear.json")
 e=job.command("describe-raw-linear",false,job.describe,"-input",raw_path,"-output",raw_output,"-column","linear");if e!=nil{return e}
 raw_result,e:=load_result(raw_output);if e!=nil{return e};e=known_counts(literal,raw_result);if e!=nil{return e}
 if raw_result["raw16_hex_population"].(map[string]interface{})["fffb"]!=float64(32){return fmt.Errorf("raw word population lost")}
 job.controls=append(job.controls,map[string]interface{}{"name":"cross-control-separation-and-injections","pass":true,"guards":"3PCM DC and 18PCM block changes retained; no chip tolerance inferred"})
 return nil
}
func(job *qualification)csv_negatives()error{
 base:=[]string{"sample,left,right"};for i:=0;i<128;i++{base=append(base,fmt.Sprintf("%d,%d,%d",i,i%13-6,6-i%13))}
 cases:=map[string]string{"empty":"","header-only":"sample,left,right\n","short127":strings.Join(base[:128],"\n")+"\n","missing-column":"sample,value\n0,1\n","missing-sample":"left,right\n1,2\n","duplicate-header":"sample,left,left\n0,1,2\n","malformed-quote":"sample,left,right\n0,\"bad,0\n"}
 replace:=func(row int,text string)string{copy_rows:=append([]string(nil),base...);copy_rows[row+1]=text;return strings.Join(copy_rows,"\n")+"\n"}
 cases["gap"]=replace(64,"65,1,1");cases["duplicate-index"]=replace(64,"63,1,1")
 cases["negative-index"]=replace(0,"-1,1,1");cases["fractional-index"]=replace(64,"64.5,1,1")
 cases["nonfinite-selected"]=replace(64,"64,NaN,1");cases["infinite-selected"]=replace(64,"64,+Inf,1");cases["nonfinite-other"]=replace(64,"64,1,NaN")
 cases["positive-overflow"]=replace(64,"64,32768,0");cases["negative-overflow"]=replace(64,"64,-32769,0");cases["integer-overflow"]=replace(64,"64,99999999999999999999999999999999999999999999999999999999999999999999999999999999999,0")
 cases["fractional"]=replace(64,"64,0.5,0");cases["empty-value"]=replace(64,"64,,0");cases["ragged"]=replace(64,"64,1")
 cases["blank-line"]=strings.Join(base[:65],"\n")+"\n\n"+strings.Join(base[65:],"\n")+"\n"
 cases["unknown-header"]=strings.Replace(strings.Join(base,"\n")+"\n","sample,left,right","sample,left,unknown",1)
 clock:=[]string{"sample,clock,left,right"};for i:=0;i<128;i++{n:=i*64;if i>=64{n+=1};clock=append(clock,fmt.Sprintf("%d,%d,1,1",i,n))};cases["clock-gap"]=strings.Join(clock,"\n")+"\n"
 clock[65]="64,18446744073709551616,1,1";cases["clock-overflow"]=strings.Join(clock,"\n")+"\n"
 raw:=[]string{"sample,raw16_hex,linear"};for i:=0;i<128;i++{raw=append(raw,fmt.Sprintf("%d,xxxx,1",i))};cases["invalid-raw-word"]=strings.Join(raw,"\n")+"\n"
 names:=[]string{};for name:=range cases{names=append(names,name)};sort.Strings(names)
 for _,name:=range names{
  input:=filepath.Join(job.output,"csv-negatives",name+".csv");e:=os.WriteFile(input,[]byte(cases[name]),0600);if e!=nil{return e}
  column:="left";if name=="invalid-raw-word"{column="linear"}
  e=job.command("csv-reject-"+name,true,job.describe,"-input",input,"-output",filepath.Join(job.output,"csv-negatives",name+".json"),"-column",column);if e!=nil{return e}
 }
 valid:=filepath.Join(job.output,"controls","literal-counts.csv")
 args:=[]struct{name string;values []string}{
  {"describe-no-args",nil},{"describe-no-output",[]string{"-input",valid}},{"describe-extra-arg",[]string{"-input",valid,"-output",filepath.Join(job.output,"unused.json"),"extra"}},
  {"describe-unknown-flag",[]string{"-unknown"}},{"describe-bad-column",[]string{"-input",valid,"-output",filepath.Join(job.output,"unused.json"),"-column","hidden"}},
  {"describe-zero-jump",[]string{"-input",valid,"-output",filepath.Join(job.output,"unused.json"),"-jump-threshold","0"}},
  {"describe-overflow-jump",[]string{"-input",valid,"-output",filepath.Join(job.output,"unused.json"),"-jump-threshold","65536"}},
  {"describe-invalid-endpoint",[]string{"-input",valid,"-output",filepath.Join(job.output,"unused.json"),"-lower-level","1.5"}},
  {"describe-negative-start",[]string{"-input",valid,"-output",filepath.Join(job.output,"unused.json"),"-start","-1"}},
  {"describe-overrun-window",[]string{"-input",valid,"-output",filepath.Join(job.output,"unused.json"),"-end","129"}},
  {"describe-too-short-window",[]string{"-input",valid,"-output",filepath.Join(job.output,"unused.json"),"-end","127"}},
  {"describe-reused-output",[]string{"-input",valid,"-output",filepath.Join(job.output,"controls","literal-counts.json")}},
 }
 for _,test:=range args{e:=job.command(test.name,true,job.describe,test.values...);if e!=nil{return e}}
 if _,e:=os.Lstat(filepath.Join(job.output,"unused.json"));!os.IsNotExist(e){return fmt.Errorf("rejected CLI created output")}
 return nil
}
func(job *qualification)command(name string,want_failure bool,exe string,args ...string)error{
 cmd:=exec.Command(exe,args...);var stdout,stderr bytes.Buffer;cmd.Stdout=&stdout;cmd.Stderr=&stderr
 started:=time.Now();e:=cmd.Run();code:=0;if e!=nil{if exit,ok:=e.(*exec.ExitError);ok{code=exit.ExitCode()}else{code=-1}}
 pass:=(!want_failure&&code==0)||(want_failure&&code>0)
 job.trials=append(job.trials,trial{Name:name,Command:append([]string{exe},args...),WantFailure:want_failure,ExitCode:code,Stdout:stdout.String(),Stderr:stderr.String(),Pass:pass})
 save_error:=job.save(false);if save_error!=nil{return save_error}
 if !pass{return fmt.Errorf("trial %s failed after%s: %v stdout=%s stderr=%s",name,time.Since(started),e,stdout.String(),stderr.String())}
 return nil
}
func(job *qualification)save(complete bool)error{
 data,e:=json.MarshalIndent(map[string]interface{}{"scope":"finite original analytic method only; no models/hardware/chip conformance","complete":complete,"trials":job.trials,"controls":job.controls},"","  ");if e!=nil{return e}
 return os.WriteFile(filepath.Join(job.output,"report.json"),append(data,'\n'),0600)
}
func write_csv(path string,v []int)error{
 file,e:=os.OpenFile(path,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600);if e!=nil{return e}
 writer:=csv.NewWriter(file);e=writer.Write([]string{"sample","left","right"});if e!=nil{file.Close();return e}
 for i,x:=range v{right:=0;if x> -32768{right=-x};e=writer.Write([]string{strconv.Itoa(i),strconv.Itoa(x),strconv.Itoa(right)});if e!=nil{file.Close();return e}}
 writer.Flush();e=writer.Error();close_error:=file.Close();if e!=nil{return e};return close_error
}
func load_result(path string)(map[string]interface{},error){
 raw,e:=os.ReadFile(path);if e!=nil{return nil,e}
 var value map[string]interface{};e=json.Unmarshal(raw,&value);if e!=nil{return nil,e}
 return value["result"].(map[string]interface{}),nil
}
func known_counts(v []int,result map[string]interface{})error{
 sum,squares,zeros,negative,positive:=int64(0),int64(0),0,0,0
 counts:=map[int]int{};minimum,maximum:=v[0],v[0]
 for _,x:=range v{
  sum+=int64(x);squares+=int64(x)*int64(x);counts[x]++
  if x==0{zeros++};if x<0{negative++};if x>0{positive++};if x<minimum{minimum=x};if x>maximum{maximum=x}
 }
 stats:=result["summary"].(map[string]interface{})
 expected:=map[string]float64{"samples":float64(len(v)),"minimum":float64(minimum),"maximum":float64(maximum),"sum":float64(sum),"sum_squares":float64(squares),"zero_count":float64(zeros),"negative_count":float64(negative),"positive_count":float64(positive)}
 for key,want:=range expected{if stats[key]!=want{return fmt.Errorf("exact %s mismatch",key)}}
 if math.Abs(stats["mean"].(float64)-float64(sum)/float64(len(v)))>1e-12||math.Abs(stats["rms"].(float64)-math.Sqrt(float64(squares)/float64(len(v))))>1e-10{return fmt.Errorf("known mean/RMS mismatch")}
 population:=result["level_population"].([]interface{});if len(population)!=len(counts){return fmt.Errorf("level count")}
 previous:=-32769
 for _,entry:=range population{row:=entry.(map[string]interface{});x:=int(row["value"].(float64));if x<=previous||row["count"]!=float64(counts[x]){return fmt.Errorf("exact level population mismatch")};previous=x}
 return nil
}
func same_feature(a,b map[string]interface{},key string)bool{x,_:=json.Marshal(a[key]);y,_:=json.Marshal(b[key]);return bytes.Equal(x,y)}
func file_digest(path string)string{raw,e:=os.ReadFile(path);if e!=nil{panic(e)};return digest(raw)}
func digest(raw []byte)string{return fmt.Sprintf("%x",sha256.Sum256(raw))}

