package vcd

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func Test_MakeAlias_uses_csv_header(t *testing.T) {
	dir := t.TempDir()
	traceName := filepath.Join(dir, "debug.trace")
	if err := os.WriteFile(traceName, []byte(strings.Join([]string{
		"PC,A,B,frame_cnt",
		"1000,1,2,3",
	}, "\n")+"\n"), 0644); err != nil {
		t.Fatal(err)
	}
	trace := &TraceReader{}
	trace.Open(traceName)
	defer trace.Close()
	if _, ok := trace.Next(); !ok {
		t.Fatal("trace should have an initial row")
	}
	trace.RewindTo(1, 0)

	ss := VCDData{
		"pc": &VCDSignal{Name: "TRACE_PC", Scope: "TOP"},
		"a":  &VCDSignal{Name: "TRACE_A", Scope: "TOP"},
		"b":  &VCDSignal{Name: "TRACE_B", Scope: "TOP"},
		"fr": &VCDSignal{Name: "TRACE_FRAME_CNT", Scope: "TOP"},
	}
	alias := MakeAlias(trace, ss)
	if alias["PC"] == nil {
		t.Fatal("expected PC alias")
	}
	if alias["A"] == nil {
		t.Fatal("expected A alias")
	}
	if alias["B"] == nil {
		t.Fatal("expected B alias")
	}
	if alias["frame_cnt"] != nil {
		t.Fatal("frame_cnt should not be aliased")
	}
}
