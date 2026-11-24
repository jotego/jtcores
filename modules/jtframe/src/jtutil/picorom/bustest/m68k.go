/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package bustest

// MC68000 backend: GNU m68k-linux-gnu binutils and the fx68k core in jtsim

import (
	_ "embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
)

//go:embed m68k.s.tmpl
var m68k_template string

//go:embed m68k_hook.h.tmpl
var m68k_hook_template string

const (
	m68k_wait_cycles = 38 // cycles of one acknowledge-wait iteration
	m68k_wd_period   = 0.005
	m68k_cpu_path    = "game_test__DOT__u_game__DOT__u_game__DOT__u_main__DOT__u_cpu__DOT__u_cpu__DOT__"
)

var m68k_kernels = map[string]string{
	"none":    "move.w %d1,%d1",
	"read.w":  "move.w (%a0),%d1",
	"write.w": "move.w %d2,(%a0)",
	"read.b":  "move.b (%a0),%d1",
	"write.b": "move.b %d2,(%a0)",
}

type m68k struct{}

func init() { register(m68k{}) }

func (m68k) Name() string { return "m68k" }
func (m68k) Lanes() int   { return 2 }

func (m68k) Nominal() map[string]int {
	return map[string]int{"none": 26, "read.w": 42, "write.w": 42, "read.b": 42, "write.b": 42}
}

type m68k_rep struct {
	Comment         string
	Addr, Start, End int
}

type m68k_case struct {
	Kernel string
	Reps   []m68k_rep
}

type m68k_data struct {
	Stack, MarkStart, MarkEnd, MarkFatal, InSeq, Active, RxData int
	LastIter, WaitLoops int
	Watchdog         string
	Preamble, Init   []string
	Cases            []m68k_case
}

func (m m68k) Source(t *Test) (string, error) {
	d := m68k_data{Stack: t.Stack(), MarkStart: t.Mark(MarkStart), MarkEnd: t.Mark(MarkEnd),
		MarkFatal: t.Mark(MarkFatal), InSeq: t.InSeq(), Active: t.Active(), RxData: t.RxData(),
		LastIter: Iterations - 1, Watchdog: "nop", Preamble: t.Preamble}
	// Some watchdogs reset the board when kicked too often: kick once per
	// case and about every 5 ms while waiting for the host
	d.WaitLoops = max(1, min(0xffff, int(float64(t.CpuHz)*m68k_wd_period/m68k_wait_cycles)))
	if t.Watchdog != nil { d.Watchdog = m68k_access(*t.Watchdog) }
	for _, it := range t.Init { d.Init = append(d.Init, m68k_access(it)+"   | "+it.Why) }
	k := 0
	for _, c := range t.Cases {
		mc := m68k_case{Kernel: m68k_kernels[c.Access]}
		for r := 0; r < Reps; r++ {
			b := t.Brackets[k]
			mc.Reps = append(mc.Reps, m68k_rep{Addr: c.Addr, Start: t.Mark(b.start), End: t.Mark(b.end),
				Comment: fmt.Sprintf("%s %s 0x%x rep %d", c.Name, c.Access, c.Addr, r)})
			k++
		}
		d.Cases = append(d.Cases, mc)
	}
	return render(m68k_template, d)
}

func m68k_access(a Access) string {
	op, size, _ := strings.Cut(a.Access, ".")
	if op == "write" {
		mask := 0xffff
		if size == "b" { mask = 0xff }
		return fmt.Sprintf("move.%s #0x%x,(0x%x).l", size, a.Value&mask, a.Addr)
	}
	return fmt.Sprintf("tst.%s (0x%x).l", size, a.Addr)
}

func render(tmpl string, data any) (string, error) {
	t, e := template.New("").Funcs(template.FuncMap{"hex": func(v int) string { return fmt.Sprintf("%x", v) }}).Parse(tmpl)
	if e != nil { return "", e }
	var sb strings.Builder
	e = t.Execute(&sb, data)
	return sb.String(), e
}

func (m68k) Assemble(src string) ([]byte, string, error) {
	tmp, e := os.MkdirTemp("", "bustest"); if e != nil { return nil, "", e }
	defer os.RemoveAll(tmp)
	path := func(n string) string { return filepath.Join(tmp, n) }
	e = os.WriteFile(path("test.s"), []byte(src), 0o664); if e != nil { return nil, "", e }
	steps := [][]string{
		{"m68k-linux-gnu-as", "-m68000", "-o", path("t.o"), path("test.s")},
		{"m68k-linux-gnu-ld", "-Ttext=0", "-o", path("t.elf"), path("t.o")},
		{"m68k-linux-gnu-objcopy", "-O", "binary", path("t.elf"), path("t.bin")},
	}
	for _, s := range steps {
		out, e := exec.Command(s[0], s[1:]...).CombinedOutput()
		if e != nil { return nil, "", fmt.Errorf("%s: %w\n%s(install gcc-m68k-linux-gnu)", s[0], e, out) }
	}
	lst, e := exec.Command("m68k-linux-gnu-objdump", "-d", path("t.elf")).Output(); if e != nil { return nil, "", e }
	code, e := os.ReadFile(path("t.bin"))
	return code, strings.ReplaceAll(string(lst), tmp+"/", ""), e
}

func (m68k) SimHook(cpu_path string, lo, hi int) string {
	if cpu_path == "" { cpu_path = m68k_cpu_path }
	s, _ := render(m68k_hook_template, map[string]any{"P": cpu_path, "Lo": lo, "Hi": hi})
	return s
}
