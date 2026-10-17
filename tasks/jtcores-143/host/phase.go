// Estimate the effective phase increment of a controlled, unmodulated sine.
package main

import (
    "crypto/sha256"
    "encoding/json"
    "flag"
    "fmt"
    "math"
    "os"
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
