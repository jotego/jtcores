/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package bustest

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"jtutil/picorom"
)

// The golden files are the programs that the Python generator built for the
// #230 PCB runs; the Go generator must reproduce them byte for byte.
func use_repo(t *testing.T) {
	root, e := filepath.Abs("../../../../../..")
	if e != nil { t.Fatal(e) }
	t.Setenv("JTROOT", root)
}

func TestGoldenSources(t *testing.T) {
	use_repo(t)
	for _, c := range []struct{ core, set string }{
		{"riders", "glfgreat"}, {"riders", "ssriders"}, {"tmnt", "punkshot"}} {
		spec, e := LoadSpec(c.core, c.set)
		if e != nil { t.Fatal(e) }
		test, e := NewTest(spec)
		if e != nil { t.Fatal(e) }
		got, e := test.Backend.Source(test)
		if e != nil { t.Fatal(e) }
		want, e := os.ReadFile(filepath.Join("testdata", c.set+".s"))
		if e != nil { t.Fatal(e) }
		if got != string(want) { t.Errorf("%s: generated program differs from testdata/%s.s", c.set, c.set) }
	}
}

func TestCommsLane(t *testing.T) {
	use_repo(t)
	spec, e := LoadSpec("riders", "ssriders")
	if e != nil { t.Fatal(e) }
	test, _ := NewTest(spec)
	if test.Lane != 1 { t.Fatalf("ssriders markers are on the odd lane, got lane %d", test.Lane) }
	if test.Mark(MarkStart) != 2*(PicoBase+tx_offset+MarkStart)+1 { t.Errorf("odd-lane marker address 0x%x", test.Mark(MarkStart)) }
	lo, hi := test.MarkWindow()
	if hi-lo != 2*0x1ff { t.Errorf("marker window 0x%x-0x%x", lo, hi) }
	if len(test.Brackets) != Reps*(len(spec.Cases)+1) { t.Errorf("%d brackets", len(test.Brackets)) }
	if test.Brackets[0].Case != "baseline" || test.Brackets[0].Start != "0x020" { t.Errorf("first bracket %+v", test.Brackets[0]) }
}

func TestSpecErrors(t *testing.T) {
	use_repo(t)
	if _, e := LoadSpec("riders", "nosuchset"); e == nil || !strings.Contains(e.Error(), "glfgreat") {
		t.Errorf("an unknown set should list the available ones, got %v", e)
	}
	s := &Spec{Core: "riders", Set: "x", Cpu: "z80", CpuHz: 1, Cases: []Access{{Access: "read.w"}}}
	if e := s.validate(); e == nil || !strings.Contains(e.Error(), "m68k") { t.Errorf("unknown cpu: %v", e) }
	s = &Spec{Core: "riders", Set: "x", CpuHz: 1, Cases: []Access{{Name: "a", Access: "read.l"}}}
	if e := s.validate(); e == nil { t.Error("read.l must be rejected") }
}

func TestRenderedHook(t *testing.T) {
	h := m68k{}.SimHook("", 0x1b800, 0x1bbfe)
	for _, want := range []string{"sim_hook(UUT& game", "a >= 0x1b800u && a <= 0x1bbfeu", m68k_cpu_path + "busControl__DOT__rAS"} {
		if !strings.Contains(h, want) { t.Errorf("hook lacks %q", want) }
	}
}

// A reboot in the middle of a run must not pair a start marker of one boot
// with an end marker of another
func TestComputeLastBoot(t *testing.T) {
	use_repo(t)
	spec, _ := LoadSpec("riders", "glfgreat")
	test, _ := NewTest(spec)
	r := &Runner{t: test}
	ev := func(seq, addr int, us uint32) picorom.Event { return picorom.Event{Sequence: seq, Address: addr, TimeUs: us} }
	r.res.Events = []picorom.Event{
		ev(0, MarkStart, 100), ev(1, 0x020, 1000), ev(2, 0x021, 1600), // first boot, bracket 0
		ev(3, MarkStart, 5000), ev(4, 0x020, 6000), // reboot: bracket 0 starts again, no end
	}
	r.compute()
	if r.res.Brackets[0].Cycles != nil { t.Errorf("bracket 0 paired across boots: %v", *r.res.Brackets[0].Cycles) }
	r.res = PcbResult{Events: r.res.Events[:3]}
	r.compute()
	if c := r.res.Brackets[0].Cycles; c == nil || *c != round3(600e-6*16e6/Iterations) { t.Errorf("bracket 0 within one boot: %v", c) }
	if r.res.Complete { t.Error("no end marker: the run cannot be complete") }
}
