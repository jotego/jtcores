package vcd

import (
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func Test_set_option(t *testing.T) {
	var cmp Comparator
	e := cmp.set_option("kmax")
	if e == nil {
		t.Error("Expecting error on setting kmax")
	}
	e = cmp.set_option("retry")
	if e != nil {
		t.Error(e.Error())
	}
	if !cmp.retry_step {
		t.Error("retry_step should be true")
	}
	e = cmp.set_option("retry=false")
	if cmp.retry_step {
		t.Error("retry_step should be false")
	}
	e = cmp.set_option("retry=true")
	if !cmp.retry_step {
		t.Error("retry_step should be true")
	}
	e = cmp.set_option("mame-lookahead=3")
	if e != nil {
		t.Error(e.Error())
	}
	if cmp.mame_lookahead != 3 {
		t.Error("mame_lookahead should be 3")
	}
	e = cmp.set_option("vcd-lookahead=5")
	if e != nil {
		t.Error(e.Error())
	}
	if cmp.kmax != 5 {
		t.Error("kmax should be 5")
	}
	e = cmp.set_option("merge-window=4")
	if e != nil {
		t.Error(e.Error())
	}
	if cmp.merge_window != 4 {
		t.Error("merge_window should be 4")
	}
	e = cmp.set_option("merge-window=0")
	if e == nil {
		t.Error("Expecting error on invalid merge-window")
	}
}

func Test_nxTraceChange(t *testing.T) {
	var cmp Comparator
	cmp.trace = &TraceReader{}
	test_content := `PC,SP,X,Y,A,P,IR,frame_cnt
C189,FF,1,80,0,33,0,C
C189,FF,1,80,0,33,0,C
C189,FF,1,80,0,33,0,C

   (interrupted at C189, IRQ 0)

C19D,FC,1,80,1,37,48,D
C19E,FB,1,80,2,37,DA,E
`
	tmp := filepath.Join(t.TempDir(), "debug.trace")
	if e := os.WriteFile(tmp, []byte(test_content+"\n"), 0644); e != nil {
		t.Fatal(e)
	}
	cmp.trace.Open(tmp)
	defer cmp.trace.Close()
	if _, ok := cmp.trace.Next(); !ok {
		t.Fatal("first trace row missing")
	}
	var mame_st MAMEState
	mame_st.data = cmp.trace.previous
	mame_st.alias = mameAlias{
		"PC": nil, "SP": nil, "X": nil, "Y": nil, "A": nil,
		"P": nil, "IR": nil, "frame_cnt": nil,
	}
	if mame_st.data["PC"] != 0xC189 {
		t.Error("Did not read first line well")
	}
	_, found := cmp.nxTraceChange(&mame_st)
	if !found {
		t.Log(mame_st.data)
		t.Error("Did not found new data!")
	}
	if mame_st.asm == "" || mame_st.data["PC"] != 0xC189 {
		t.Fatalf("Expected first advance to capture interrupt row, got PC=%X asm=%q", mame_st.data["PC"], mame_st.asm)
	}
	_, found = cmp.nxTraceChange(&mame_st)
	if !found {
		t.Fatal("Expected second advance")
	}
	if mame_st.data["PC"] != 0xc19d {
		t.Error("Did not found the right line to stop at")
	}
}

func Test_nxVCDChange_prefers_trace_sequence_event(t *testing.T) {
	dir := t.TempDir()
	vcd_name := filepath.Join(dir, "debug.vcd")
	e := os.WriteFile(vcd_name, []byte("#10\nb1 !\n#20\nb10 #\n#30\n"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	vcd := &LnFile{}
	vcd.Open(vcd_name)
	defer vcd.Close()
	a := &VCDSignal{Name: "TRACE_A", alias: "!"}
	seq := &VCDSignal{Name: "TRACE_SEQ", alias: "#"}
	sim_st := &SimState{data: VCDData{"!": a, "#": seq}}
	cmp := Comparator{vcd: vcd, trace_seq: seq}
	lines, found := cmp.nxVCDChange(sim_st, mameAlias{"A": a})
	if !found {
		t.Fatal("expected TRACE_SEQ event")
	}
	if lines != 5 || a.Value != 1 || seq.Value != 2 {
		t.Fatalf("wrong VCD step: lines=%d A=%d SEQ=%d", lines, a.Value, seq.Value)
	}
}

func Test_nxVCDChange_prefers_trace_valid_event(t *testing.T) {
	dir := t.TempDir()
	vcd_name := filepath.Join(dir, "debug.vcd")
	e := os.WriteFile(vcd_name, []byte("#10\nb1 !\n#20\n1$\n#30\n0$\n#40\n"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	vcd := &LnFile{}
	vcd.Open(vcd_name)
	defer vcd.Close()
	a := &VCDSignal{Name: "TRACE_A", alias: "!"}
	valid := &VCDSignal{Name: "TRACE_VALID", alias: "$"}
	sim_st := &SimState{data: VCDData{"!": a, "$": valid}}
	cmp := Comparator{vcd: vcd, trace_valid: valid}
	lines, found := cmp.nxVCDChange(sim_st, mameAlias{"A": a})
	if !found {
		t.Fatal("expected TRACE_VALID event")
	}
	if lines != 5 || a.Value != 1 || valid.Value != 1 {
		t.Fatalf("wrong VCD step: lines=%d A=%d VALID=%d", lines, a.Value, valid.Value)
	}
}

func Test_select_candidate_exact_after_mame_and_vcd_advance(t *testing.T) {
	cmp, mame_st := make_test_cmp()
	mames := []mameSnapshot{
		{line: 1, data: NameValue{"A": 1, "B": 1}},
		{line: 2, data: NameValue{"A": 2, "B": 3}},
	}
	vcds := []vcdSnapshot{
		{line: 1, alias: NameValue{"A": 0, "B": 1}},
		{line: 2, alias: NameValue{"A": 2, "B": 3}},
	}
	cand, found := cmp.select_candidate(mame_st, mames, vcds)
	if !found {
		t.Fatal("expected candidate")
	}
	if cand.mame_index != 1 || cand.vcd_index != 1 || cand.merged {
		t.Fatalf("wrong candidate: %+v", cand)
	}
}

func Test_select_candidate_prefers_exact_over_merged(t *testing.T) {
	cmp, mame_st := make_test_cmp()
	mames := []mameSnapshot{{line: 1, data: NameValue{"A": 2, "B": 3}}}
	vcds := []vcdSnapshot{
		{line: 1, alias: NameValue{"A": 2, "B": 0}},
		{line: 2, alias: NameValue{"A": 2, "B": 3}},
	}
	cand, found := cmp.select_candidate(mame_st, mames, vcds)
	if !found {
		t.Fatal("expected candidate")
	}
	if cand.vcd_index != 1 || cand.vcd_end != 1 || cand.merged {
		t.Fatalf("exact match should win: %+v", cand)
	}
}

func Test_select_candidate_merged_within_window(t *testing.T) {
	cmp, mame_st := make_test_cmp()
	mames := []mameSnapshot{{line: 1, data: NameValue{"A": 2, "B": 3}}}
	vcds := []vcdSnapshot{
		{line: 1, alias: NameValue{"A": 2, "B": 0}},
		{line: 2, alias: NameValue{"A": 0, "B": 3}},
	}
	cmp.merge_window = 2
	cand, found := cmp.select_candidate(mame_st, mames, vcds)
	if !found {
		t.Fatal("expected merged candidate")
	}
	if !cand.merged || cand.vcd_index != 0 || cand.vcd_end != 1 {
		t.Fatalf("wrong merged candidate: %+v", cand)
	}
	cmp.merge_window = 1
	_, found = cmp.select_candidate(mame_st, mames, vcds)
	if found {
		t.Fatal("merged candidate should exceed window")
	}
}

func Test_find_missing_value_is_asymmetric(t *testing.T) {
	cmp, mame_st := make_test_cmp()
	mames := []mameSnapshot{
		{line: 10, data: NameValue{"A": 2, "B": 3}},
		{line: 11, data: NameValue{"A": 4, "B": 5}},
	}
	vcds := []vcdSnapshot{
		{line: 1, alias: NameValue{"A": 1, "B": 3}},
		{line: 2, alias: NameValue{"A": 4, "B": 5}},
	}
	missing := cmp.find_missing_value(mame_st, mames, vcds)
	if missing == nil {
		t.Fatal("expected missing value")
	}
	if missing.name != "A" || missing.value != 2 || missing.line != 10 {
		t.Fatalf("wrong missing value: %+v", missing)
	}
}

func Test_snapshot_diff_honors_mask_and_ignore(t *testing.T) {
	cmp, mame_st := make_test_cmp()
	mame_st.mask = NameValue{"A": 0xf}
	cmp.ignore = *newBoolSet(mame_st)
	cmp.ignore.Update("B")
	data := NameValue{"A": 0x12, "B": 0x44}
	alias_values := NameValue{"A": 0x10, "B": 0x99}
	if cmp.snapshot_diff(mame_st, data, alias_values) != 0 {
		t.Fatal("mask and ignore should hide differences")
	}
}

func Test_findSyncCandidate_restores_selected_stream_positions(t *testing.T) {
	dir := t.TempDir()
	trace_name := filepath.Join(dir, "debug.trace")
	vcd_name := filepath.Join(dir, "debug.vcd")
	e := os.WriteFile(trace_name, []byte("A,B\n1,0\n2,0\n"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	e = os.WriteFile(vcd_name, []byte("#10\nb10 !\n#20\n"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	trace := &TraceReader{}
	trace.Open(trace_name)
	defer trace.Close()
	vcd := &LnFile{}
	vcd.Open(vcd_name)
	defer vcd.Close()
	sig := &VCDSignal{Name: "A", alias: "!"}
	sim_st := &SimState{data: VCDData{"!": sig}}
	mame_st := &MAMEState{
		data:  NameValue{"A": 1},
		mask:  NameValue{},
		alias: mameAlias{"A": sig},
	}
	if _, ok := trace.Next(); !ok {
		t.Fatal("first trace row missing")
	}
	var cmp Comparator
	cmp.trace = trace
	cmp.vcd = vcd
	cmp.kmax = 2
	cmp.mame_lookahead = 1
	cmp.merge_window = 2
	if !cmp.findSyncCandidate(sim_st, mame_st) {
		t.Fatal("expected recovery")
	}
	if mame_st.data["A"] != 2 || trace.line != 3 {
		t.Fatalf("wrong trace state: line=%d data=%v", trace.line, mame_st.data)
	}
	if sig.Value != 2 || vcd.line != 3 || vcd.time != 20 {
		t.Fatalf("wrong VCD state: line=%d time=%d value=%d", vcd.line, vcd.time, sig.Value)
	}
}

func Test_findSyncCandidate_failure_restores_start_and_reports_missing(t *testing.T) {
	dir := t.TempDir()
	trace_name := filepath.Join(dir, "debug.trace")
	vcd_name := filepath.Join(dir, "debug.vcd")
	e := os.WriteFile(trace_name, []byte("A,B\n1,0\n2,0\n"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	e = os.WriteFile(vcd_name, []byte("#10\nb11 !\n#20\n"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	trace := &TraceReader{}
	trace.Open(trace_name)
	defer trace.Close()
	vcd := &LnFile{}
	vcd.Open(vcd_name)
	defer vcd.Close()
	sig := &VCDSignal{Name: "A", alias: "!"}
	sim_st := &SimState{data: VCDData{"!": sig}}
	mame_st := &MAMEState{
		data:  NameValue{"A": 1},
		mask:  NameValue{},
		alias: mameAlias{"A": sig},
	}
	if _, ok := trace.Next(); !ok {
		t.Fatal("first trace row missing")
	}
	var cmp Comparator
	cmp.trace = trace
	cmp.vcd = vcd
	cmp.kmax = 1
	cmp.mame_lookahead = 1
	cmp.merge_window = 2
	if cmp.findSyncCandidate(sim_st, mame_st) {
		t.Fatal("unexpected recovery")
	}
	if mame_st.data["A"] != 1 || trace.line != 2 {
		t.Fatalf("trace state not restored: line=%d data=%v", trace.line, mame_st.data)
	}
	if sig.Value != 0 || vcd.line != 0 || vcd.time != 0 {
		t.Fatalf("VCD state not restored: line=%d time=%d value=%d", vcd.line, vcd.time, sig.Value)
	}
	if cmp.last_missing == nil || cmp.last_missing.name != "A" || cmp.last_missing.value != 1 {
		t.Fatalf("wrong missing diagnostic: %+v", cmp.last_missing)
	}
}

func Test_print_recovery_only_in_verbose_mode(t *testing.T) {
	old_verbose := Verbose
	defer func() { Verbose = old_verbose }()
	cmp := Comparator{
		last_recovery: recoveryResult{
			found:       true,
			trace_line0: 1,
			trace_line1: 2,
			vcd_line0:   3,
			vcd_line1:   4,
			vcd_time0:   10,
			vcd_time1:   20,
		},
	}
	Verbose = false
	if got := capture_stdout(func() { cmp.print_recovery() }); got != "" {
		t.Fatalf("recovery output should be quiet without verbose: %q", got)
	}
	Verbose = true
	got := capture_stdout(func() { cmp.print_recovery() })
	if !strings.Contains(got, "Trace recovered by exact match:") {
		t.Fatalf("missing verbose recovery output: %q", got)
	}
}

func make_test_cmp() (*Comparator, *MAMEState) {
	a := &VCDSignal{Name: "A"}
	b := &VCDSignal{Name: "B"}
	mame_st := &MAMEState{
		data:  NameValue{"A": 0, "B": 0},
		mask:  NameValue{},
		alias: mameAlias{"A": a, "B": b},
	}
	cmp := &Comparator{merge_window: 2}
	return cmp, mame_st
}

func capture_stdout(fn func()) string {
	old := os.Stdout
	r, w, _ := os.Pipe()
	os.Stdout = w
	fn()
	w.Close()
	os.Stdout = old
	out, _ := io.ReadAll(r)
	r.Close()
	return string(out)
}
