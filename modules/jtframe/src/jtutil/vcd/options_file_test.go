package vcd

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func Test_load_options_file(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, ".jtutil.toml")
	data := `[trace.options]
retry = true
vcd-lookahead = 12
mame-lookahead = 3
merge-window = 4
table-width = 80
color = false
`
	e := os.WriteFile(path, []byte(data), 0644)
	if e != nil {
		t.Fatal(e)
	}
	cmp := NewComparator(VCDData{}, nil, nil)
	e = cmp.load_options(path)
	if e != nil {
		t.Fatal(e)
	}
	if !cmp.retry_step || cmp.kmax != 12 || cmp.mame_lookahead != 3 || cmp.merge_window != 4 || cmp.table_width != 80 || cmp.color {
		t.Fatalf("options not loaded: %+v", cmp)
	}
}

func Test_save_options_file_preserves_other_sections(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, ".jtutil.toml")
	data := `[other]
name = "kept"

[trace.options]
retry = true
vcd-lookahead = 8

[tail]
value = 1
`
	e := os.WriteFile(path, []byte(data), 0644)
	if e != nil {
		t.Fatal(e)
	}
	cmp := NewComparator(VCDData{}, nil, nil)
	cmp.kmax = 12
	cmp.mame_lookahead = 5
	cmp.merge_window = 3
	cmp.table_width = 90
	cmp.color = false
	e = cmp.save_options(path)
	if e != nil {
		t.Fatal(e)
	}
	updated, e := os.ReadFile(path)
	if e != nil {
		t.Fatal(e)
	}
	text := string(updated)
	for _, want := range []string{
		`[other]`,
		`name = "kept"`,
		`[tail]`,
		`vcd-lookahead = 12`,
		`mame-lookahead = 5`,
		`merge-window = 3`,
		`table-width = 90`,
		`color = false`,
	} {
		if !strings.Contains(text, want) {
			t.Fatalf("saved config missing %q:\n%s", want, text)
		}
	}
	if strings.Contains(text, "vcd-lookahead = 8") {
		t.Fatalf("old trace options were not replaced:\n%s", text)
	}
}

func Test_option_command_saves_options_to_cwd(t *testing.T) {
	wd, e := os.Getwd()
	if e != nil {
		t.Fatal(e)
	}
	e = os.Chdir(t.TempDir())
	if e != nil {
		t.Fatal(e)
	}
	defer os.Chdir(wd)
	p := &VCDPrompt{
		tokens: []string{"option", "vcd-lookahead=12"},
		cmp:    NewComparator(VCDData{}, nil, nil),
	}
	p.optionCmd()
	data, e := os.ReadFile(jtutil_config_name)
	if e != nil {
		t.Fatal(e)
	}
	if !strings.Contains(string(data), "vcd-lookahead = 12") {
		t.Fatalf("option was not saved:\n%s", string(data))
	}
}

func Test_save_trace_session_preserves_other_sections(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, ".jtutil.toml")
	data := `[trace.options]
retry = true

[trace.session]
vcd_file = "old.vcd"
csv_file = "old.csv"
vcd_line = 1
csv_line = 2
vcd_time = 1
csv_time = 2
vcd_mtime_ns = 3
csv_mtime_ns = 4

[notes]
value = 1
`
	if e := os.WriteFile(path, []byte(data), 0644); e != nil {
		t.Fatal(e)
	}
	e := save_trace_session(path, traceSessionState{
		SavedAt:    123456789,
		VcdFile:    "debug.vcd",
		CsvFile:    "debug.csv",
		VcdLine:    10,
		CsvLine:    20,
		VcdTime:    30,
		CsvTime:    40,
		VcdModTime: 111,
		CsvModTime: 222,
	})
	if e != nil {
		t.Fatal(e)
	}
	text, e := os.ReadFile(path)
	if e != nil {
		t.Fatal(e)
	}
	for _, want := range []string{
		`[trace.options]`,
		`retry = true`,
		`[trace.session]`,
		`vcd_file = "debug.vcd"`,
		`csv_file = "debug.csv"`,
		`vcd_line = 10`,
		`csv_line = 20`,
		`vcd_time = 30`,
		`csv_time = 40`,
		`vcd_mtime_ns = 111`,
		`csv_mtime_ns = 222`,
		`[notes]`,
		`value = 1`,
	} {
		if !strings.Contains(string(text), want) {
			t.Fatalf("session not stored correctly:\n%s", string(text))
		}
	}
}

func Test_load_trace_session_from_file(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, ".jtutil.toml")
	data := `[trace.session]
saved_at = 1234
vcd_file = "trace.vcd"
csv_file = "trace.csv"
vcd_line = 7
csv_line = 8
vcd_time = 90
csv_time = 91
vcd_mtime_ns = 500
csv_mtime_ns = 600
`
	if e := os.WriteFile(path, []byte(data), 0644); e != nil {
		t.Fatal(e)
	}
	state, found, e := load_trace_session(path)
	if e != nil {
		t.Fatal(e)
	}
	if !found {
		t.Fatal("expected session to be found")
	}
	want := traceSessionState{
		SavedAt:    1234,
		VcdFile:    "trace.vcd",
		CsvFile:    "trace.csv",
		VcdLine:    7,
		CsvLine:    8,
		VcdTime:    90,
		CsvTime:    91,
		VcdModTime: 500,
		CsvModTime: 600,
	}
	if state != want {
		t.Fatalf("unexpected session: %+v", state)
	}
}
