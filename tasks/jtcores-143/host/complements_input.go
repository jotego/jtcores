// Strict public-output adapter. No expected waveform or signal reconstruction.
package main
import("bytes";"crypto/sha256";"encoding/csv";"fmt";"math";"os";"path/filepath")
func strict_public_csv(raw []byte,column string,frames int)([]float64,error){
 rows,e:=csv.NewReader(bytes.NewReader(raw)).ReadAll();if e!=nil{return nil,e};if len(rows)!=frames+1{return nil,fmt.Errorf("exact%d rows required",frames)};names:=map[string]bool{};for _,name:=range rows[0]{if name==""||names[name]{return nil,fmt.Errorf("empty/duplicate header")};names[name]=true};if !names["sample"]||!names[column]{return nil,fmt.Errorf("missing requested column")};v,e:=read_phase_csv(raw,column);if e!=nil{return nil,e};for _,x:=range v{if math.IsNaN(x)||math.IsInf(x,0)||x!=math.Trunc(x)||x< -32768||x>32767{return nil,fmt.Errorf("invalid signed integral PCM")}};return v,nil
}
func public_digest(raw []byte)string{return fmt.Sprintf("%x",sha256.Sum256(raw))}
func fresh_output(path string)error{if path==""{return fmt.Errorf("fresh -output directory required")};_,e:=os.Lstat(path);if e==nil{return fmt.Errorf("output already exists")};if !os.IsNotExist(e){return e};return nil}
func write_exclusive(path string,raw []byte)error{f,e:=os.OpenFile(path,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600);if e!=nil{return e};_,e=f.Write(raw);close_error:=f.Close();if e!=nil{return e};return close_error}
func absolute_path(path string)(string,error){if path==""{return "",fmt.Errorf("missing path")};return filepath.Abs(path)}
