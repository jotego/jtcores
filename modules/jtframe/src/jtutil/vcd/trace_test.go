package vcd

import (
	"os"
	"path/filepath"
	"testing"
)

func Test_trace_reader_with_csv_header(t *testing.T) {
	dir := t.TempDir()
	traceName := filepath.Join(dir, "debug.trace")
	content := "PC,A,B\nC189,1,2,\nC18A,3,4,00000402: MOV.L   @($0008,PC),R14 [0000040C]\n"
	if err := os.WriteFile(traceName, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	trace := &TraceReader{}
	trace.Open(traceName)
	defer trace.Close()

	row, ok := trace.Next()
	if !ok {
		t.Fatal("expected first data row")
	}
	if row.Data["PC"] != 0xC189 || row.Data["A"] != 0x1 || row.Data["B"] != 0x2 {
		t.Fatalf("wrong first row parse: %+v", row.Data)
	}
	if row.Asm != "" {
		t.Fatalf("first row should have empty assembler text, got %q", row.Asm)
	}
	row, ok = trace.Next()
	if !ok {
		t.Fatal("expected second data row")
	}
	if row.Data["PC"] != 0xC18A || row.Data["A"] != 0x3 || row.Data["B"] != 0x4 {
		t.Fatalf("wrong second row parse: %+v", row.Data)
	}
	if row.Asm != "MOV.L   @($0008,PC),R14 [0000040C]" {
		t.Fatalf("wrong assembler text: %q", row.Asm)
	}
}

func Test_trace_reader_converts_interrupt_lines_to_rows(t *testing.T) {
	dir := t.TempDir()
	traceName := filepath.Join(dir, "debug.trace")
	content := "PC,A\nC189,1\n(interrupted at 0000C189, IRQ 12)\nC18A,2\n"
	trace := &TraceReader{}
	if err := os.WriteFile(traceName, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	trace.Open(traceName)
	defer trace.Close()

	if _, ok := trace.Next(); !ok {
		t.Fatal("expected data row")
	}
	interruptRow, ok := trace.Next()
	if !ok || interruptRow.Asm == "" || interruptRow.Asm != "IRQ 12" {
		t.Fatalf("expected interrupt synthetic row, got %v, %q", ok, interruptRow.Asm)
	}
	dataRow, ok := trace.Next()
	if !ok {
		t.Fatal("expected trailing row")
	}
	if dataRow.Data["PC"] != 0xC18A {
		t.Fatalf("wrong trailing row: %+v", dataRow.Data)
	}
}
