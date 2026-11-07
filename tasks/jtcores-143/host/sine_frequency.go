// Measure an observed sine frequency independently of a proposed YM2151 rate.
package main

import("crypto/sha256";"encoding/json";"flag";"fmt";"os")

func main(){
 column:=flag.String("column","linear","PCM column");first:=flag.Int("first",0,"first included recorded sample");end:=flag.Int("end",0,"exclusive end, zero means all samples");flag.Parse();e:=measure_sine(*column,*first,*end);if e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)}
}
func measure_sine(column string,first,end int)error{
 if flag.NArg()!=1{return fmt.Errorf("one CSV input required")};raw,e:=os.ReadFile(flag.Arg(0));if e!=nil{return e};values,e:=read_phase_csv(raw,column);if e!=nil{return e};if end==0{end=len(values)};result,e:=fit_free_sine(values,first,end);if e!=nil{return e};return json.NewEncoder(os.Stdout).Encode(map[string]interface{}{"input":flag.Arg(0),"input_sha256":fmt.Sprintf("%x",sha256.Sum256(raw)),"result":result})
}
