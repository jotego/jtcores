package vcd

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func Test_reset_command_restores_streams_without_changing_options(t *testing.T) {
	dir := t.TempDir()
	trace_name := filepath.Join(dir, "debug.trace")
	vcd_name := filepath.Join(dir, "debug.vcd")
	e := os.WriteFile(trace_name, []byte("A,B\n1,2\n3,4\n"), 0644)
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
	if _, ok := trace.Next(); !ok {
		t.Fatal("trace should have an initial line")
	}
	sig := &VCDSignal{Name: "A", alias: "!"}
	ss := VCDData{"!": sig}
	alias := mameAlias{"A": sig}
	cmp := NewComparator(ss, vcd, trace)
	cmp.kmax = 12
	cmp.mame_lookahead = 5
	cmp.merge_window = 3
	cmp.retry_step = true
	cmp.color = false
	cmp.table_width = 80
	p := &VCDPrompt{
		vcd:       vcd,
		trace:     trace,
		ss:        ss,
		mameAlias: alias,
		cmp:       cmp,
		simState:  &SimState{data: ss},
		mame_st:   &MAMEState{data: NameValue{"A": 1}, alias: alias, mask: NameValue{}},
	}
	p.set_reset_point()
	if _, ok := trace.Next(); !ok {
		t.Fatal("trace should have a second line")
	}
	p.mame_st.data = NameValue{"A": 2}
	sig.Value = 2
	vcd.Scan()
	vcd.time = 10
	p.cmp.last_missing = &missingValue{name: "A", value: 3, line: 2}
	p.cmp.last_recovery = recoveryResult{found: true}
	capture_stdout(func() { p.resetCmd() })
	if trace.line != 2 || trace.Text() != "1,2" {
		t.Fatalf("trace did not reset: line=%d text=%q", trace.line, trace.Text())
	}
	if vcd.line != 0 || vcd.time != 0 || sig.Value != 0 {
		t.Fatalf("VCD did not reset: line=%d time=%d value=%d", vcd.line, vcd.time, sig.Value)
	}
	if p.mame_st.data != nil {
		t.Fatalf("MAME state should be cleared: %v", p.mame_st.data)
	}
	if p.cmp.kmax != 12 || p.cmp.mame_lookahead != 5 || p.cmp.merge_window != 3 || !p.cmp.retry_step || p.cmp.color || p.cmp.table_width != 80 {
		t.Fatalf("options changed during reset: %+v", p.cmp)
	}
	if p.cmp.last_missing != nil || p.cmp.last_recovery.found {
		t.Fatalf("transient recovery state was not cleared")
	}
}

func Test_save_session_command_stores_state_in_jtutil_toml(t *testing.T) {
	dir := t.TempDir()
	trace_name := "debug.trace"
	vcd_name := "debug.vcd"
	if e := os.WriteFile(filepath.Join(dir, trace_name), []byte("A,B\n1,2\n2,3\n"), 0644); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(filepath.Join(dir, vcd_name), []byte("#10\nb1 !\n#20\nb10 !\n"), 0644); e != nil {
		t.Fatal(e)
	}
	wd, e := os.Getwd()
	if e != nil {
		t.Fatal(e)
	}
	e = os.Chdir(dir)
	if e != nil {
		t.Fatal(e)
	}
	defer os.Chdir(wd)
	trace := &TraceReader{}
	trace.Open(trace_name)
	defer trace.Close()
	vcd := &LnFile{}
	vcd.Open(vcd_name)
	defer vcd.Close()
	if _, ok := trace.Next(); !ok {
		t.Fatal("trace should have initial data")
	}
	if !trace.RewindTo(3, 90) {
		t.Fatal("cannot move trace")
	}
	if !vcd.RewindTo(4, 20) {
		t.Fatal("cannot move vcd")
	}
	sig := &VCDSignal{Name: "A", alias: "!"}
	ss := VCDData{"!": sig}
	alias := mameAlias{"A": sig}
	cmp := NewComparator(ss, vcd, trace)
	p := &VCDPrompt{
		vcd:       vcd,
		trace:     trace,
		ss:        ss,
		mameAlias: alias,
		cmp:       cmp,
		simState:  &SimState{data: ss},
		mame_st:   &MAMEState{alias: alias, data: NameValue{"A": 2}, mask: NameValue{}},
	}
	if !p.saveSession() {
		t.Fatal("saveSession returned false")
	}
	data, e := os.ReadFile(jtutil_config_name)
	if e != nil {
		t.Fatal(e)
	}
	text := string(data)
	for _, want := range []string{
		"[trace.session]",
		"vcd_file = \"debug.vcd\"",
		"csv_file = \"debug.trace\"",
		"vcd_line = 4",
		"csv_line = 3",
		"vcd_time = 20",
		"csv_time = 90",
	} {
		if !strings.Contains(text, want) {
			t.Fatalf("session file missing %q:\n%s", want, text)
		}
	}
}

func Test_restore_session_command_restores_offsets_and_warns_if_files_changed(t *testing.T) {
	dir := t.TempDir()
	trace_name := "debug.trace"
	vcd_name := "debug.vcd"
	if e := os.WriteFile(filepath.Join(dir, trace_name), []byte("A,B\n1,2\n2,3\n3,4\n"), 0644); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(filepath.Join(dir, vcd_name), []byte("#10\nb1 !\n#20\nb10 !\n#30\nb11 !\n"), 0644); e != nil {
		t.Fatal(e)
	}
	wd, e := os.Getwd()
	if e != nil {
		t.Fatal(e)
	}
	e = os.Chdir(dir)
	if e != nil {
		t.Fatal(e)
	}
	defer os.Chdir(wd)
	trace := &TraceReader{}
	trace.Open(trace_name)
	defer trace.Close()
	vcd := &LnFile{}
	vcd.Open(vcd_name)
	defer vcd.Close()
	if _, ok := trace.Next(); !ok {
		t.Fatal("trace should have initial data")
	}
	state := traceSessionState{
		SavedAt:    111,
		VcdFile:    vcd_name,
		CsvFile:    trace_name,
		VcdLine:    4,
		CsvLine:    3,
		VcdTime:    20,
		CsvTime:    70,
		VcdModTime: 1,
		CsvModTime: 2,
	}
	if e := save_trace_session(jtutil_config_name, state); e != nil {
		t.Fatal(e)
	}
	fv, e := os.OpenFile(filepath.Join(dir, vcd_name), os.O_APPEND|os.O_WRONLY, 0644)
	if e != nil {
		t.Fatal(e)
	}
	if _, e := fv.WriteString("#40\nb4 !\n"); e != nil {
		fv.Close()
		t.Fatal(e)
	}
	if e := fv.Close(); e != nil {
		t.Fatal(e)
	}
	ft, e := os.OpenFile(filepath.Join(dir, trace_name), os.O_APPEND|os.O_WRONLY, 0644)
	if e != nil {
		t.Fatal(e)
	}
	if _, e := ft.WriteString("4,5\n"); e != nil {
		ft.Close()
		t.Fatal(e)
	}
	if e := ft.Close(); e != nil {
		t.Fatal(e)
	}
	sig := &VCDSignal{Name: "A", alias: "!"}
	ss := VCDData{"!": sig}
	alias := mameAlias{"A": sig}
	cmp := NewComparator(ss, vcd, trace)
	p := &VCDPrompt{
		vcd:       vcd,
		trace:     trace,
		ss:        ss,
		mameAlias: alias,
		cmp:       cmp,
		simState:  &SimState{data: ss},
		mame_st:   &MAMEState{alias: alias, data: NameValue{"A": 0}, mask: NameValue{}},
	}
	if !vcd.RewindTo(6, 30) {
		t.Fatal("cannot move vcd forward")
	}
	if !trace.RewindTo(4, 0) {
		t.Fatal("cannot move trace forward")
	}
	out := capture_stdout(func() {
		if !p.restoreSession() {
			t.Fatal("restoreSession returned false")
		}
	})
	if !strings.Contains(out, "WARNING: VCD file changed since session save") {
		t.Fatalf("expected VCD change warning:\n%s", out)
	}
	if !strings.Contains(out, "WARNING: CSV file changed since session save") {
		t.Fatalf("expected CSV change warning:\n%s", out)
	}
	if p.vcd.line != 4 || p.vcd.time != 20 {
		t.Fatalf("vcd session was not restored: line=%d time=%d", p.vcd.line, p.vcd.time)
	}
	if sig.Value != 2 {
		t.Fatalf("VCD value not restored: %d", sig.Value)
	}
	if p.trace.line != 3 || p.trace.time != 70 {
		t.Fatalf("trace session not restored: line=%d time=%d", p.trace.line, p.trace.time)
	}
	if p.mame_st.data["A"] != 2 {
		t.Fatalf("trace data not restored: %v", p.mame_st.data)
	}
}
