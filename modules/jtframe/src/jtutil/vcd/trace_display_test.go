package vcd

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func Test_trace_display_window_and_restore(t *testing.T) {
	trace := open_test_trace(t, []string{
		"PC,R4,frame_cnt",
		"1000,00000000,1",
		"1002,00000000,1",
		"1004,00000001,1",
		"1006,00000001,1",
		"1008,00000001,1",
		"100A,00000001,1",
	})
	defer trace.Close()
	for trace.line < 4 {
		if _, ok := trace.Next(); !ok {
			break
		}
	}
	trace.time = 77
	got := new_trace_display(trace, false, trace_table_width_default).render()
	for _, want := range []string{"Trace", "-2", "-1", "Current", "+1", "+2"} {
		if !strings.Contains(got, want) {
			t.Fatalf("trace table missing %q:\n%s", want, got)
		}
	}
	for _, want := range []string{"1000", "1002", "1004", "1006", "1008"} {
		if !strings.Contains(got, want) {
			t.Fatalf("missing expected trace value %q:\n%s", want, got)
		}
	}
	if trace.line != 4 || trace.time != 77 {
		t.Fatalf("trace position not restored: line=%d time=%d", trace.line, trace.time)
	}
	assert_table_rows_same_width(t, got)
}

func Test_trace_display_boundaries(t *testing.T) {
	trace := open_test_trace(t, []string{
		"PC,R0",
		"1,0",
		"2,1",
		"3,2",
	})
	defer trace.Close()
	_, _ = trace.Next()
	got := new_trace_display(trace, false, trace_table_width_default).render()
	if strings.Contains(got, "-1") || !strings.Contains(got, "Current") || !strings.Contains(got, "+2") {
		t.Fatalf("bad start boundary table:\n%s", got)
	}
	for trace.line < 4 {
		if _, ok := trace.Next(); !ok {
			break
		}
	}
	got = new_trace_display(trace, false, trace_table_width_default).render()
	if !strings.Contains(got, "-2") || !strings.Contains(got, "-1") || strings.Contains(got, "+1") {
		t.Fatalf("bad end boundary table:\n%s", got)
	}
	assert_table_rows_same_width(t, got)
}

func Test_trace_display_shifted_window(t *testing.T) {
	trace := open_test_trace(t, []string{
		"PC,R0",
		"1,0",
		"2,1",
		"3,2",
		"4,3",
		"5,4",
		"6,5",
		"7,6",
	})
	defer trace.Close()
	for trace.line < 4 {
		if _, ok := trace.Next(); !ok {
			break
		}
	}
	got := new_trace_display(trace, false, trace_table_width_default).render_at(-1)
	for _, want := range []string{"-2", "-1", "Current", "+1"} {
		if !strings.Contains(got, want) {
			t.Fatalf("shifted trace table missing %q:\n%s", want, got)
		}
	}
	if trace.line != 4 {
		t.Fatalf("trace position not restored: line=%d", trace.line)
	}
	assert_table_rows_same_width(t, got)
}

func Test_trace_display_truncates_to_table_width(t *testing.T) {
	trace := open_test_trace(t, []string{
		"R0,R1,R2,R3,R4,R5,R6,R7,R8,R9",
		"FFFFFFFFFFFFFFFF,FFFFFFFFFFFFFFFF,FFFFFFFFFFFFFFFF,FFFFFFFFFFFFFFFF,FFFFFFFFFFFFFFFF,FFFFFFFFFFFFFFFF,FFFFFFFFFFFFFFFF,FFFFFFFFFFFFFFFF,FFFFFFFFFFFFFFFF,FFFFFFFFFFFFFFFF",
		"0000000000000001,0000000000000001,0000000000000001,0000000000000001,0000000000000001,0000000000000001,0000000000000001,0000000000000001,0000000000000001,0000000000000001",
	})
	defer trace.Close()
	trace.Next()
	got := new_trace_display(trace, false, 40).render()
	if strings.Contains(got, "FFFFFFFFFFFFFFFF") {
		t.Fatalf("long values were not truncated:\n%s", got)
	}
	if !strings.Contains(got, "...") {
		t.Fatalf("truncated table should include ellipsis:\n%s", got)
	}
	assert_table_rows_fit_width(t, got, 80)
}

func Test_trace_display_colors_changed_values(t *testing.T) {
	trace := open_test_trace(t, []string{
		"PC,R4",
		"1,0",
		"1,1",
		"1,1",
	})
	defer trace.Close()
	for trace.line < 2 {
		if _, ok := trace.Next(); !ok {
			break
		}
	}
	got := new_trace_display(trace, true, trace_table_width_default).render()
	if !strings.Contains(got, trace_display_red+"0x1") {
		t.Fatalf("changed value was not highlighted:\n%s", got)
	}
	got = new_trace_display(trace, false, trace_table_width_default).render()
	if strings.Contains(got, trace_display_red) || strings.Contains(got, trace_display_reset) {
		t.Fatalf("color=false still emitted ANSI color:\n%s", got)
	}
}

func Test_trace_display_does_not_color_assembler_row(t *testing.T) {
	trace := open_test_trace(t, []string{
		"PC,R4",
		"1,0",
		"1,0",
		"1,0",
	})
	defer trace.Close()
	for trace.line < 2 {
		if _, ok := trace.Next(); !ok {
			break
		}
	}
	got := new_trace_display(trace, true, trace_table_width_default).render()
	for _, line := range strings.Split(got, "\n") {
		if strings.HasPrefix(line, "ASM COD") && strings.Contains(line, trace_display_red) {
			t.Fatalf("assembler row should not be colored:\n%s", got)
		}
	}
}

func Test_trace_display_collapses_assembler_spacing(t *testing.T) {
	trace := open_test_trace(t, []string{
		"PC,R4",
		"1,0,00000402: MOV.L   @($0008,PC),R14 [0000040C]",
	})
	defer trace.Close()
	row, ok := trace.Next()
	if !ok {
		t.Fatal("expected trace row")
	}
	if row.Asm != "MOV.L   @($0008,PC),R14 [0000040C]" {
		t.Fatalf("reader should keep assembler spacing, got %q", row.Asm)
	}
	got := new_trace_display(trace, false, trace_table_width_default).render()
	if !strings.Contains(got, "MOV.L @($0008,PC),R14 [0000040C]") {
		t.Fatalf("display should collapse assembler spacing:\n%s", got)
	}
	if strings.Contains(got, "MOV.L   @($0008,PC),R14") {
		t.Fatalf("display kept duplicated assembler spaces:\n%s", got)
	}
}

func Test_trace_display_places_pc_after_assembler_row(t *testing.T) {
	trace := open_test_trace(t, []string{
		"GBR,pc,R0",
		"00000000,1,00000000",
	})
	defer trace.Close()
	trace.Next()
	got := new_trace_display(trace, false, trace_table_width_default).render()
	asm_at := strings.Index(got, "\nASM COD")
	pc_at := strings.Index(got, "\npc")
	gbr_at := strings.Index(got, "\nGBR")
	if asm_at == -1 || pc_at == -1 || gbr_at == -1 {
		t.Fatalf("missing expected rows:\n%s", got)
	}
	if !(pc_at < gbr_at) {
		t.Fatalf("PC should be present before GBR:\n%s", got)
	}
}

func Test_trace_display_sorting_numeric_suffixes(t *testing.T) {
	trace := open_test_trace(t, []string{
		"PC,R1,R3,R10,R2,R9,R11",
		"1,1,3,10,2,9,11",
	})
	defer trace.Close()
	trace.Next()

	got := new_trace_display(trace, false, trace_table_width_default).render()
	rows := make([]string, 0, 8)
	for _, line := range strings.Split(got, "\n") {
		if !strings.Contains(line, "|") {
			continue
		}
		label := strings.TrimSpace(strings.SplitN(line, "|", 2)[0])
		if label == "Trace" || label == "ASM COD" || label == "" {
			continue
		}
		rows = append(rows, label)
	}

	want := []string{"PC", "R1", "R2", "R3", "R9", "R10", "R11"}
	if !reflect.DeepEqual(rows, want) {
		t.Fatalf("register order mismatch: got=%v want=%v\n%s", rows, want, got)
	}
}

func open_test_trace(t *testing.T, lines []string) *TraceReader {
	t.Helper()
	path := filepath.Join(t.TempDir(), "debug.trace")
	e := os.WriteFile(path, []byte(strings.Join(lines, "\n")+"\n"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	trace := &TraceReader{}
	trace.Open(path)
	return trace
}

func assert_table_rows_same_width(t *testing.T, text string) {
	t.Helper()
	width := -1
	for _, line := range strings.Split(text, "\n") {
		if !strings.Contains(line, "|") {
			continue
		}
		clean := strip_trace_display_ansi(line)
		if width == -1 {
			width = len(clean)
			continue
		}
		if len(clean) != width {
			t.Fatalf("table row widths differ: got %d want %d\n%s", len(clean), width, text)
		}
	}
}

func strip_trace_display_ansi(text string) string {
	text = strings.ReplaceAll(text, trace_display_red, "")
	return strings.ReplaceAll(text, trace_display_reset, "")
}

func assert_table_rows_fit_width(t *testing.T, text string, width int) {
	t.Helper()
	for _, line := range strings.Split(text, "\n") {
		if !strings.Contains(line, "|") {
			continue
		}
		clean := strip_trace_display_ansi(line)
		if len(clean) > width {
			t.Fatalf("table row width got %d want <= %d\n%s", len(clean), width, text)
		}
	}
}
