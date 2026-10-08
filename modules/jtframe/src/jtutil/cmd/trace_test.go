package cmd

import (
	"os"
	"path/filepath"
	"testing"
)

func Test_is_vcd_file(t *testing.T) {
	dir := t.TempDir()
	vcd_name := filepath.Join(dir, "debug.vcd")
	csv_name := filepath.Join(dir, "debug.csv")
	if e := os.WriteFile(vcd_name, []byte("\n$date\n$end\n"), 0o644); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(csv_name, []byte("PC,A\n0001,02\n"), 0o644); e != nil {
		t.Fatal(e)
	}
	if !is_vcd_file(vcd_name) {
		t.Fatal("expected VCD file to be detected")
	}
	if is_vcd_file(csv_name) {
		t.Fatal("expected CSV file not to be detected as VCD")
	}
}
