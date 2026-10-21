package main

import (
    "fmt"
    "strings"
    "testing"
)

func TestPhaseCSV(t *testing.T) {
    for _,kind:=range []string{"valid","gap","nan","short","missing"} {
        var input strings.Builder
        if kind=="missing" { input.WriteString("index,linear\n") } else { input.WriteString("sample,linear\n") }
        for i:=0;i<128;i++ {
            index:=i
            if kind=="gap" && i>32 { index++ }
            value:="100"
            if kind=="nan" && i==32 { value="NaN" }
            if kind=="short" && i==32 { fmt.Fprintf(&input,"%d\n",index) } else { fmt.Fprintf(&input,"%d,%s\n",index,value) }
        }
        values,e:=read_phase_csv([]byte(input.String()),"linear")
        if kind=="valid" {
            if e!=nil || len(values)!=128 { t.Fatalf("valid CSV: %v",e) }
        } else if e==nil { t.Fatal("accepted",kind) }
    }
}
