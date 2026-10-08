package vcd

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

func hexToBits(t *testing.T, hex string) string {
	t.Helper()
	var b strings.Builder
	b.Grow(len(hex) * 4)
	for _, ch := range hex {
		v, err := strconv.ParseUint(string(ch), 16, 4)
		if err != nil {
			t.Fatalf("bad hex %q: %v", hex, err)
		}
		for bit := 3; bit >= 0; bit-- {
			if v&(1<<bit) != 0 {
				b.WriteByte('1')
			} else {
				b.WriteByte('0')
			}
		}
	}
	return b.String()
}

func TestLoadVCD128AndIgnoreReal(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "wide.vcd")
	const hex0 = "0123456789ABCDEFFEDCBA9876543210"
	const hex1 = "89ABCDEF012345670123456789ABCDEF"

	content := `
$date
  today
$end
$version
  test
$end
$timescale
 1ns
$end
$scope module TOP $end
$var wire 128 ! tiles_data [127:0] $end
$var real 64 " ext_total_read_kb $end
$upscope $end
$enddefinitions $end
$dumpvars
b` + hexToBits(t, hex0) + ` !
r0 "
$end
#10
b` + hexToBits(t, hex1) + ` !
r0.25 "
#20
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	ln, ss := LoadVCD(path)
	defer ln.Close()

	sig := ss.Get("TOP.tiles_data")
	if sig == nil {
		t.Fatal("tiles_data not found")
	}
	if sig.RawWidth() != 128 {
		t.Fatalf("expected width 128, got %d", sig.RawWidth())
	}
	if got := sig.RawHexValue(); got != hex0 {
		t.Fatalf("unexpected initial value: got %s want %s", got, hex0)
	}
	if !ln.NextVCD(ss) {
		t.Fatal("expected one timestamp change")
	}
	if ln.time != 10 {
		t.Fatalf("expected time 10, got %d", ln.time)
	}
	if got := sig.RawHexValue(); got != hex0 {
		t.Fatalf("unexpected value at time 10 boundary: got %s want %s", got, hex0)
	}
	if !ln.NextVCD(ss) {
		t.Fatal("expected second timestamp change")
	}
	if ln.time != 20 {
		t.Fatalf("expected time 20, got %d", ln.time)
	}
	if got := sig.RawHexValue(); got != hex1 {
		t.Fatalf("unexpected updated value: got %s want %s", got, hex1)
	}
}

func TestLoadVCDRecordsOffsetsForFastRewind(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "rewind.vcd")
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
$var wire 1 ! flag $end
$upscope $end
$enddefinitions $end
$dumpvars
0!
$end
#10
1!
#20
0!
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	ln, ss := LoadVCD(path)
	defer ln.Close()
	if !ln.NextVCD(ss) {
		t.Fatal("expected first timestamp")
	}
	line10 := ln.line
	offset10, ok := ln.line_offset[line10]
	if !ok || offset10 == 0 {
		t.Fatalf("missing recorded offset for line %d", line10)
	}
	if !ln.NextVCD(ss) {
		t.Fatal("expected second timestamp")
	}
	if ln.time != 20 {
		t.Fatalf("expected time 20, got %d", ln.time)
	}
	if !ln.RewindTo(line10, 10) {
		t.Fatalf("could not rewind to line %d", line10)
	}
	if ln.line != line10 || ln.time != 10 {
		t.Fatalf("wrong rewind state: line=%d time=%d", ln.line, ln.time)
	}
	if !ln.NextVCD(ss) || ln.time != 20 {
		t.Fatalf("scan did not resume after rewind: line=%d time=%d", ln.line, ln.time)
	}
}

func TestParseValue128(t *testing.T) {
	const hex = "FEDCBA98765432100123456789ABCDEF"
	parsed := parseValue("b" + hexToBits(t, hex) + " !")
	if !parsed.ok {
		t.Fatal("expected parsed value")
	}
	sig := &VCDSignal{Name: "tiles_data", MSB: 127, LSB: 0}
	assign(parsedVCDValue{alias: "!", hi: parsed.hi, lo: parsed.lo, ok: true}, VCDData{"!": sig})
	if got := sig.RawHexValue(); got != hex {
		t.Fatalf("unexpected parsed hex: got %s want %s", got, hex)
	}
}
