// Compile an explicitly expanded monitor replay, retaining every source write.
package main

import (
 "crypto/sha256"
 "encoding/csv"
 "encoding/json"
 "flag"
 "fmt"
 "io"
 "math"
 "os"
 "path/filepath"
 "strconv"
)

type source_write struct { Row int; Time float64; Register, Value int }
type chunk_info struct { Path string `json:"path"`; SHA256 string `json:"sha256"`; FirstRow, LastRow, Writes, Bytes int }
func main() {
 input:=flag.String("bus","","complete bus.csv")
 output:=flag.String("output","","fresh output directory")
 prefix:=flag.Int("prefix",107500,"number of source data writes before capture event")
 end:=flag.Int("end",108700,"number of source data writes including event")
 flag.Parse()
 if e:=compile(*input,*output,*prefix,*end);e!=nil { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
}
func compile(input,output string,prefix,end int)error {
 if prefix<1 || end<=prefix {return fmt.Errorf("invalid source bounds")}
 f,e:=os.Open(input);if e!=nil{return e};defer f.Close()
 reader:=csv.NewReader(f);header,e:=reader.Read();if e!=nil{return e}
 if fmt.Sprint(header)!="[seconds attoseconds address value mask]" {return fmt.Errorf("unexpected bus schema")}
 writes:=[]source_write{};reg:=-1;last:=-1.0
 for { record,e:=reader.Read();if e==io.EOF{break};if e!=nil{return e}
  v:=[5]int64{};for i:=range v {v[i],e=strconv.ParseInt(record[i],10,64);if e!=nil{return e}}
  t:=float64(v[0])+float64(v[1])/1e18
  if t<last || v[4]!=255 {return fmt.Errorf("invalid bus timing/mask")};last=t
  if v[2]==0x9000 {reg=int(v[3]);continue}
  if v[2]!=0x9001 || reg<0 {return fmt.Errorf("invalid data transaction")}
  writes=append(writes,source_write{len(writes)+1,t,reg,int(v[3])});reg=-1
  if len(writes)==end {break}
 }
 if len(writes)!=end {return fmt.Errorf("source ends before requested event")}
 if e=os.Mkdir(output,0755);e!=nil{return e}
 output,e=filepath.Abs(output);if e!=nil{return e}
 chunks:=[]chunk_info{};data:=[]byte{};first:=1;count:=0;clamped:=0;previous:=0.0;delay_counts:=uint64(0)
 save:=func(name string,b []byte)error{return exclusive(filepath.Join(output,name),append(append([]byte{},b...),0))}
 flush:=func(last_row int)error {
  name:=fmt.Sprintf("history-%03d.bin",len(chunks));b:=append(append([]byte{},data...),0)
  p:=filepath.Join(output,name);if e:=exclusive(p,b);e!=nil{return e}
  chunks=append(chunks,chunk_info{p,fmt.Sprintf("%x",sha256.Sum256(b)),first,last_row,count,len(b)})
  data=nil;count=0;first=last_row+1;return nil
 }
 event:=[]byte{}
 for _,w:=range writes {
  cycles:=(w.Time-previous)*4000000;previous=w.Time
  n:=int(math.Round((cycles-80)/37.5));if n<0{n=0;clamped++};delay_counts+=uint64(n)
  op:=[]byte{};for n>0 {step:=n;if step>65535{step=65535};op=append(op,2,byte(step),byte(step>>8));n-=step}
  op=append(op,1,byte(w.Register),byte(w.Value))
  if w.Row<=prefix {
   if len(data)+len(op)+1>8192 {if e:=flush(w.Row-1);e!=nil{return e}}
   data=append(data,op...);count++
  }else{event=append(event,op...)}
 }
 if len(data)>0{if e:=flush(prefix);e!=nil{return e}}
 if len(event)+1>8192{return fmt.Errorf("event exceeds monitor bound: %d",len(event)+1)}
 if e=save("natural-event.bin",event);e!=nil{return e}
 if e=save("initialize.bin",initialization());e!=nil{return e}
 if e=save("quiet.bin",cleanup());e!=nil{return e}
 if e=save("positive.bin",positive());e!=nil{return e}
 // A fresh snapshot control for the first natural key-on in EVENT.
 registers:=[256]int{};var target source_write
 for _,w:=range writes {registers[w.Register]=w.Value;if w.Row>prefix && w.Register==8 && w.Value&120!=0 {target=w;break}}
 if target.Row==0{return fmt.Errorf("no selected natural key-on")}
 ch:=target.Value&7;fresh:=initialization()
 for r:=0x20+ch;r<256;r+=8 {fresh=append(fresh,1,byte(r),byte(registers[r]))}
 fresh=append(fresh,1,8,byte(ch))
 if e=save("natural-fresh-init.bin",fresh);e!=nil{return e}
 if e=save("natural-fresh-event.bin",[]byte{2,0,32,1,8,byte(target.Value)});e!=nil{return e}
 m:=map[string]any{"source_bus":input,"source_prefix_rows":prefix,"source_event_end_row":end,"chunks":chunks,
  "source_first_data_seconds":writes[0].Time,"source_event_start_seconds":writes[prefix].Time,"source_end_seconds":writes[end-1].Time,
  "first_natural_keyon":target,"short_intervals_stretched":clamped,"total_delay_counts":delay_counts,
  "source_master_clock_hz":4000000,"bench_nominal_master_clock_hz":3580000,"delay_count_master_clocks_approximate":37.5,
  "write_overhead_budget_master_clocks":80,"timing_policy":"Each source interval is mapped to source master cycles; delay counts round(max(0,(cycles-80)/37.5)). CPU and busy overhead plus measured host gaps expand timing. Neither source timestamp fidelity nor exact internal write phase is claimed.",
  "identity":"User-authorized replacement. Complete literal preceding register writes, including every duplicate 1B; not recovered original trace."}
 b,e:=json.MarshalIndent(m,"","  ");if e!=nil{return e};return exclusive(filepath.Join(output,"manifest.json"),append(b,'\n'))
}
func exclusive(path string,b []byte)error { f,e:=os.OpenFile(path,os.O_WRONLY|os.O_CREATE|os.O_EXCL,0600);if e!=nil{return e};_,e=f.Write(b);c:=f.Close();if e!=nil{return e};return c }
func initialization()[]byte {
 b:=cleanup();b=append(b,2,0,128)
 for _,w:=range [][2]int{{1,0},{0x14,0x30},{15,0},{24,0},{25,0},{25,128},{27,0}}{b=append(b,1,byte(w[0]),byte(w[1]))}
 for r:=32;r<256;r++ {v:=0;if r>=96&&r<128{v=127};b=append(b,1,byte(r),byte(v))};return b
}
func cleanup()[]byte {b:=[]byte{1,0x14,0x30,1,15,0};for r:=224;r<256;r++{b=append(b,1,byte(r),15)};for ch:=0;ch<8;ch++{b=append(b,1,8,byte(ch))};for r:=96;r<128;r++{b=append(b,1,byte(r),127)};for ch:=0;ch<8;ch++{b=append(b,1,byte(32+ch),0)};return b}
func positive()[]byte {b:=initialization();for _,w:=range [][2]int{{0x20,0xc7},{0x28,0x4a},{0x58,8},{0x78,0},{0x98,31},{0xf8,15}}{b=append(b,1,byte(w[0]),byte(w[1]))};return b}
