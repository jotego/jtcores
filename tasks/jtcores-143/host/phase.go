// Estimate the effective phase increment of a controlled, unmodulated sine.
package main

import (
    "bytes"
    "crypto/sha256"
    "encoding/csv"
    "encoding/json"
    "flag"
    "fmt"
    "math"
    "os"
    "strconv"
)

func main() {
    column:=flag.String("column","linear","CSV signal column: linear, left or right")
    amplitude:=flag.Float64("amplitude",8170,"known peak amplitude of the controlled sine")
    offset:=flag.Float64("offset",-8,"known PCM quantization DC offset")
    sample_rate:=flag.Float64("sample-rate",0,"calibrated native sample rate in Hz; zero omits frequency")
    flag.Parse()
    if flag.NArg()!=1 { fmt.Fprintln(os.Stderr,"Usage: phase -column NAME CSV");os.Exit(2) }
    if e:=run_phase(flag.Arg(0),*column,*amplitude,*offset,*sample_rate);e!=nil {
        fmt.Fprintln(os.Stderr,e);os.Exit(1)
    }
}

func run_phase(path,column string,amplitude,offset,sample_rate float64) error {
    if sample_rate<0 || math.IsNaN(sample_rate) || math.IsInf(sample_rate,0) {
        return fmt.Errorf("invalid sample rate")
    }
    raw,e:=os.ReadFile(path)
    if e!=nil { return e }
    values,e:=read_phase_csv(raw,column)
    if e!=nil { return e }
    fit,e:=fit_phase(values,amplitude,offset)
    if e!=nil { return e }
    return json.NewEncoder(os.Stdout).Encode(struct{
        File string `json:"file"`
        SHA256 string `json:"sha256"`
        Column string `json:"column"`
        Fit phase_fit `json:"fit"`
        SampleRate float64 `json:"sample_rate_hz,omitempty"`
        Frequency float64 `json:"frequency_hz,omitempty"`
    }{path,fmt.Sprintf("%x",sha256.Sum256(raw)),column,fit,sample_rate,fit.Increment*sample_rate/(1<<20)})
}

func read_phase_csv(raw []byte,column string) ([]float64,error) {
    rows,e:=csv.NewReader(bytes.NewReader(raw)).ReadAll()
    if e!=nil { return nil,e }
    if len(rows)<129 { return nil,fmt.Errorf("not enough CSV samples") }
    index,sample_index:=-1,-1
    for i,name:=range rows[0] {
        if name==column { index=i }
        if name=="sample" { sample_index=i }
    }
    if index<0 || sample_index<0 { return nil,fmt.Errorf("missing signal or sample column") }
    values:=make([]float64,len(rows)-1)
    for i,row:=range rows[1:] {
        if len(row)<=index || len(row)<=sample_index { return nil,fmt.Errorf("short CSV row %d",i+2) }
        sample,e:=strconv.Atoi(row[sample_index])
        if e!=nil || sample!=i { return nil,fmt.Errorf("nonconsecutive sample at row %d",i+2) }
        value,e:=strconv.ParseFloat(row[index],64)
        if e!=nil || math.IsNaN(value) || value < -32768 || value > 32767 {
            return nil,fmt.Errorf("invalid sample at row %d",i+2)
        }
        values[i]=value
    }
    return values,nil
}
