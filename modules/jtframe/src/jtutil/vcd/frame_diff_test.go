package vcd

import (
	"os"
	"path/filepath"
	"testing"
)

func Test_expandFrameDiffBraces(t *testing.T) {
	got := expandFrameDiffBraces("wr_{a,b}")
	if len(got) != 2 {
		t.Fatalf("expected 2 expansions, got %d", len(got))
	}
	if got[0] != "wr_a" || got[1] != "wr_b" {
		t.Fatalf("unexpected expansions: %#v", got)
	}
}

func Test_parseFrameDiffRanges(t *testing.T) {
	ranges, err := parseFrameDiffRanges("", 2)
	if err != nil {
		t.Fatal(err)
	}
	if len(ranges) != 1 || ranges[0].start != 3 || ranges[0].end != 3 || ranges[0].open {
		t.Fatalf("unexpected default range: %#v", ranges)
	}

	ranges, err = parseFrameDiffRanges("10-12,15,20-", 2)
	if err != nil {
		t.Fatal(err)
	}
	if len(ranges) != 3 {
		t.Fatalf("unexpected ranges: %#v", ranges)
	}
	if ranges[0].start != 10 || ranges[0].end != 12 || ranges[0].open {
		t.Fatalf("bad first range: %#v", ranges[0])
	}
	if ranges[1].start != 15 || ranges[1].end != 15 || ranges[1].open {
		t.Fatalf("bad second range: %#v", ranges[1])
	}
	if ranges[2].start != 20 || !ranges[2].open {
		t.Fatalf("bad third range: %#v", ranges[2])
	}
}

func Test_collectFrameDiffData(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sample.vcd")
	content := `$date
  today
$end
$version
  test
$end
$timescale
 1ns
$end
$scope module TOP $end
$scope module game_test $end
$scope module u_obj $end
$var wire 1 ! wr $end
$var wire 8 " data [7:0] $end
$upscope $end
$var wire 2 # frame_cnt [1:0] $end
$upscope $end
$upscope $end
$enddefinitions $end
$dumpvars
0!
b00000000 "
b00 #
$end
#5
b01 #
#10
1!
b00010010 "
#15
b10 #
#20
0!
b00010011 "
#25
b11 #
#30
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	ln, ss := LoadVCD(path)
	defer ln.Close()

	frameSig := findFrameCountSignal(ss)
	if frameSig == nil {
		t.Fatal("frame_cnt not found")
	}
	scopeRoot, err := resolveFrameDiffScope(ss, "u_obj")
	if err != nil {
		t.Fatal(err)
	}
	selected, err := selectFrameDiffSignals(ss, scopeRoot, "u_obj/*")
	if err != nil {
		t.Fatal(err)
	}
	if len(selected) != 2 {
		t.Fatalf("unexpected selected signals: %d", len(selected))
	}

	frames, err := collectFrameDiffData(ln, ss, frameSig, selected, nil)
	if err != nil {
		t.Fatal(err)
	}
	frame1, ok := frames[1]
	if !ok {
		t.Fatal("frame 1 should be complete")
	}
	if len(frame1.rows) != 2 {
		t.Fatalf("expected 2 rows, got %d", len(frame1.rows))
	}
	if frame1.rows[0].values[0] != 0 || frame1.rows[0].values[1] != 0 {
		t.Fatalf("bad frame 1 row 0: %#v", frame1.rows[0].values)
	}
	if frame1.rows[1].values[0] != 0x12 || frame1.rows[1].values[1] != 1 {
		t.Fatalf("bad frame 1 row 1: %#v", frame1.rows[1].values)
	}
	frame2, ok := frames[2]
	if !ok {
		t.Fatal("frame 2 should be complete")
	}
	if len(frame2.rows) != 2 {
		t.Fatalf("expected 2 rows in frame 2, got %d", len(frame2.rows))
	}
	if frame2.rows[1].values[0] != 0x13 || frame2.rows[1].values[1] != 0 {
		t.Fatalf("bad frame 2 row 1: %#v", frame2.rows[1].values)
	}
}

func Test_parseFrameDiffWhen(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "when.vcd")
	content := `$date
  today
$end
$version
  test
$end
$timescale
 1ns
$end
$scope module TOP $end
$scope module game_test $end
$scope module u_obj $end
$var wire 1 ! wr_en $end
$var wire 8 " data [7:0] $end
$var wire 2 # frame_cnt [1:0] $end
$upscope $end
$upscope $end
$upscope $end
$enddefinitions $end
$dumpvars
0!
b00000000 "
b00 #
$end
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	ln, ss := LoadVCD(path)
	defer ln.Close()

	scopeRoot, err := resolveFrameDiffScope(ss, "u_obj/data")
	if err != nil {
		t.Fatal(err)
	}
	when, err := parseFrameDiffWhen(ss, scopeRoot, "wr_en==1")
	if err != nil {
		t.Fatal(err)
	}
	if when.signal.FullName() != "TOP.game_test.u_obj.wr_en" {
		t.Fatalf("unexpected when signal: %s", when.signal.FullName())
	}
	if when.expected != 1 {
		t.Fatalf("unexpected when value: %d", when.expected)
	}
	when, err = parseFrameDiffWhen(ss, scopeRoot, "TOP.game_test.u_obj.wr_en==0")
	if err != nil {
		t.Fatal(err)
	}
	if when.signal.FullName() != "TOP.game_test.u_obj.wr_en" {
		t.Fatalf("unexpected explicit when signal: %s", when.signal.FullName())
	}
	if when.expected != 0 {
		t.Fatalf("unexpected explicit when value: %d", when.expected)
	}
	for _, expr := range []string{"wr_en", "wr_en==2", "wr_en!=1", "missing==1"} {
		if _, err := parseFrameDiffWhen(ss, scopeRoot, expr); err == nil {
			t.Fatalf("expected %q to fail", expr)
		}
	}
}

func Test_collectFrameDiffDataWhen(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "when_collect.vcd")
	content := `$date
  today
$end
$version
  test
$end
$timescale
 1ns
$end
$scope module TOP $end
$scope module game_test $end
$scope module u_obj $end
$var wire 1 ! wr_en $end
$var wire 8 " data [7:0] $end
$var wire 2 # frame_cnt [1:0] $end
$upscope $end
$upscope $end
$upscope $end
$enddefinitions $end
$dumpvars
0!
b00000000 "
b00 #
$end
#5
b01 #
b00000001 "
#10
1!
b00000010 "
#15
b00000011 "
#20
b10 #
0!
b00000100 "
#25
1!
b00000101 "
#30
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	ln, ss := LoadVCD(path)
	defer ln.Close()

	frameSig := findFrameCountSignal(ss)
	if frameSig == nil {
		t.Fatal("frame_cnt not found")
	}
	scopeRoot, err := resolveFrameDiffScope(ss, "u_obj/data")
	if err != nil {
		t.Fatal(err)
	}
	selected, err := selectFrameDiffSignals(ss, scopeRoot, "u_obj/data")
	if err != nil {
		t.Fatal(err)
	}
	if len(selected) != 1 {
		t.Fatalf("unexpected selected signals: %d", len(selected))
	}
	when, err := parseFrameDiffWhen(ss, scopeRoot, "wr_en==1")
	if err != nil {
		t.Fatal(err)
	}
	frames, err := collectFrameDiffData(ln, ss, frameSig, selected, when)
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := frames[0]; ok {
		t.Fatal("frame 0 should be filtered out")
	}
	frame1, ok := frames[1]
	if !ok {
		t.Fatal("frame 1 should be present")
	}
	if len(frame1.rows) != 2 {
		t.Fatalf("expected 2 filtered rows in frame 1, got %d", len(frame1.rows))
	}
	if frame1.rows[0].values[0] != 0x02 {
		t.Fatalf("unexpected frame 1 row 0: %#v", frame1.rows[0].values)
	}
	if frame1.rows[1].values[0] != 0x03 {
		t.Fatalf("unexpected frame 1 row 1: %#v", frame1.rows[1].values)
	}
	frame2, ok := frames[2]
	if !ok {
		t.Fatal("frame 2 should be present")
	}
	if len(frame2.rows) != 1 {
		t.Fatalf("expected 1 filtered row in frame 2, got %d", len(frame2.rows))
	}
	if frame2.rows[0].values[0] != 0x05 {
		t.Fatalf("unexpected frame 2 row 0: %#v", frame2.rows[0].values)
	}
}

func Test_resolveFrameDiffScope(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "scope.vcd")
	content := `$date
  today
$end
$version
  test
$end
$timescale
 1ns
$end
$scope module TOP $end
$scope module game_test $end
$scope module u_obj $end
$var wire 1 ! wr_en $end
$var wire 1 " pxl_data $end
$upscope $end
$var wire 2 # frame_cnt [1:0] $end
$upscope $end
$upscope $end
$enddefinitions $end
$dumpvars
0!
0"
b00 #
$end
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	ln, ss := LoadVCD(path)
	defer ln.Close()

	scopeRoot, err := resolveFrameDiffScope(ss, "u_obj/wr_*")
	if err != nil {
		t.Fatal(err)
	}
	if scopeRoot != "TOP.game_test.u_obj" {
		t.Fatalf("unexpected scope root: %q", scopeRoot)
	}

	selected, err := selectFrameDiffSignals(ss, scopeRoot, "u_obj/wr_*")
	if err != nil {
		t.Fatal(err)
	}
	if len(selected) != 1 {
		t.Fatalf("expected one selected signal, got %d", len(selected))
	}
	if selected[0].Name != "wr_en" {
		t.Fatalf("expected wr_en, got %s", selected[0].Name)
	}
}

func Test_splitFrameDiffPattern(t *testing.T) {
	scope, glob, err := splitFrameDiffPattern("u_video.u_obj/wr_*")
	if err != nil {
		t.Fatal(err)
	}
	if scope != "u_video.u_obj" {
		t.Fatalf("unexpected scope: %q", scope)
	}
	if glob != "wr_*" {
		t.Fatalf("unexpected glob: %q", glob)
	}
}

func Test_splitFrameDiffPatternRejectsMultipleSlashes(t *testing.T) {
	_, _, err := splitFrameDiffPattern("u_video/u_obj/wr_*")
	if err == nil {
		t.Fatal("expected an error for multiple / separators")
	}
}

func Test_resolveFrameDiffScopeNestedHierarchy(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "nested.vcd")
	content := `$date
  today
$end
$version
  test
$end
$timescale
 1ns
$end
$scope module TOP $end
$scope module game_test $end
$scope module u_video $end
$scope module u_obj $end
$var wire 1 ! wr_en $end
$var wire 1 " pxl_data $end
$upscope $end
$upscope $end
$var wire 2 # frame_cnt [1:0] $end
$upscope $end
$upscope $end
$enddefinitions $end
$dumpvars
0!
0"
b00 #
$end
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	ln, ss := LoadVCD(path)
	defer ln.Close()

	scopeRoot, err := resolveFrameDiffScope(ss, "u_video.u_obj/wr_*")
	if err != nil {
		t.Fatal(err)
	}
	if scopeRoot != "TOP.game_test.u_video.u_obj" {
		t.Fatalf("unexpected scope root: %q", scopeRoot)
	}

	selected, err := selectFrameDiffSignals(ss, scopeRoot, "u_video.u_obj/wr_*")
	if err != nil {
		t.Fatal(err)
	}
	if len(selected) != 1 {
		t.Fatalf("expected one selected signal, got %d", len(selected))
	}
	if selected[0].FullName() != "TOP.game_test.u_video.u_obj.wr_en" {
		t.Fatalf("unexpected selected signal: %s", selected[0].FullName())
	}
}
