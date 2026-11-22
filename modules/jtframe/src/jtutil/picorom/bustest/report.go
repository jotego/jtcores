/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package bustest

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Row compares one case on the PCB and in jtsim
type Row struct {
	Case        string    `json:"case"`
	Access      string    `json:"access"`
	Addr        string    `json:"addr"`
	Pcb         []float64 `json:"pcb"`
	PcbMedian   *float64  `json:"pcb_median"`
	Sim         *float64  `json:"sim"`
	WaitsAccess *float64  `json:"pcb_waits_per_access,omitempty"`
	Verdict     string    `json:"verdict"`
	Expect      string    `json:"expect,omitempty"`
}

type Report struct {
	Set      string `json:"set"`
	Board    string `json:"board"`
	PcbRun   string `json:"pcb_run"`
	Boots    int    `json:"boots"`
	Events   int    `json:"events"`
	Complete bool   `json:"complete"`
	Rows     []Row  `json:"rows"`
}

// NewReport compares the latest PCB run (or run, if given) with sim_result.json
func NewReport(t *Test, run string) (*Report, error) {
	dir := t.OutDir()
	if run == "" {
		runs, _ := filepath.Glob(filepath.Join(dir, "pcb_*"))
		if len(runs) == 0 { return nil, fmt.Errorf("no PCB run in %s", dir) }
		sort.Strings(runs)
		run = runs[len(runs)-1]
	}
	var pcb PcbResult
	e := read_json(filepath.Join(run, "pcb_result.json"), &pcb); if e != nil { return nil, e }
	var sim SimResult
	read_json(filepath.Join(dir, "sim_result.json"), &sim)
	rep := &Report{Set: t.Set, Board: t.Board, PcbRun: filepath.Base(run), Boots: pcb.Boots,
		Events: len(pcb.Events), Complete: pcb.Complete}
	nominal := t.Backend.Nominal()
	for _, c := range t.Cases {
		row := Row{Case: c.Name, Access: c.Access, Addr: fmt.Sprintf("0x%x", c.Addr), Expect: c.Expect}
		var sims []float64
		for _, b := range pcb.Brackets { if b.Case == c.Name && b.Cycles != nil { row.Pcb = append(row.Pcb, *b.Cycles) } }
		for _, b := range sim.Brackets { if b.Case == c.Name && b.Cycles != nil { sims = append(sims, *b.Cycles) } }
		if len(row.Pcb) > 0 { m := median(row.Pcb); row.PcbMedian = &m }
		if len(sims) > 0 { m := mean(sims); row.Sim = &m }
		if row.PcbMedian != nil && c.Access != "none" {
			w := (*row.PcbMedian - float64(nominal[c.Access])) / 4
			row.WaitsAccess = &w
		}
		row.Verdict = "-"
		if row.PcbMedian != nil && row.Sim != nil {
			row.Verdict = "core differs"
			if abs(*row.PcbMedian-*row.Sim) < 0.5 { row.Verdict = "match" }
		}
		rep.Rows = append(rep.Rows, row)
	}
	return rep, nil
}

func read_json(path string, v any) error {
	data, e := os.ReadFile(path); if e != nil { return e }
	return json.Unmarshal(data, v)
}

func median(v []float64) float64 {
	s := append([]float64{}, v...)
	sort.Float64s(s)
	if len(s)%2 == 1 { return s[len(s)/2] }
	return (s[len(s)/2-1] + s[len(s)/2]) / 2
}

func mean(v []float64) float64 {
	t := 0.0
	for _, x := range v { t += x }
	return t / float64(len(v))
}

func abs(v float64) float64 {
	if v < 0 { return -v }
	return v
}

// Markdown renders the comparison as a table for issues and READMEs
func (r *Report) Markdown() string {
	var b strings.Builder
	fmt.Fprintf(&b, "### %s (`%s`) - %s\n\n", r.Board, r.Set, strings.TrimPrefix(r.PcbRun, "pcb_"))
	fmt.Fprintf(&b, "Boots %d, %d events, complete: %v.\n\n", r.Boots, r.Events, r.Complete)
	fmt.Fprintln(&b, "| Case | Address | PCB (runs) | Core jtsim | PCB waits/access | Verdict |")
	fmt.Fprintln(&b, "|---|---|---|---|---|---|")
	for _, row := range r.Rows {
		var pcb []string
		for _, v := range row.Pcb { pcb = append(pcb, fmt.Sprintf("%.2f", v)) }
		if len(pcb) == 0 { pcb = []string{"n/a"} }
		fmt.Fprintf(&b, "| %s (%s) | %s | %s | %s | %s | %s |\n", row.Case, row.Access, row.Addr,
			strings.Join(pcb, " / "), fmtp(row.Sim, "%.2f"), fmtp(row.WaitsAccess, "%.2f"), row.Verdict)
	}
	return b.String()
}

func fmtp(v *float64, f string) string {
	if v == nil { return "-" }
	return fmt.Sprintf(f, *v)
}

// Show describes the test without touching hardware
func (t *Test) Show() string {
	var b strings.Builder
	fmt.Fprintf(&b, "%s (core %s): %s\n", t.Set, t.Core, t.Board)
	fmt.Fprintf(&b, "CPU %s at %.3f MHz; program at 0x%x; output %s\n", t.Cpu, float64(t.CpuHz)/1e6, t.Rom.CpuBase, t.OutDir())
	for k, lane := range t.LaneNames() {
		role := ""
		if k == t.Lane { role = " (serves the markers)" }
		fmt.Fprintf(&b, "  %s lane: socket %s%s\n", lane, t.LaneSockets()[k], role)
	}
	fmt.Fprintf(&b, "  chip %s, %d-pin socket\n", t.Rom.Chip, t.Rom.Pins)
	fmt.Fprintf(&b, "Work RAM 0x%x-0x%x\n", t.Ram.Base, t.Ram.Base+t.Ram.Size-1)
	if w := t.Watchdog; w != nil { fmt.Fprintf(&b, "Watchdog: %s 0x%x. %s\n", w.Access, w.Addr, w.Why) }
	for _, it := range t.Init { fmt.Fprintf(&b, "Setup: %s 0x%x = 0x%x. %s\n", it.Access, it.Addr, it.Value, it.Why) }
	fmt.Fprintln(&b, "Cases:")
	for _, c := range t.Cases[1:] { fmt.Fprintf(&b, "  %-10s %-8s 0x%-8x %s\n", c.Name, c.Access, c.Addr, c.Expect) }
	if len(t.Checklist) > 0 {
		fmt.Fprintln(&b, "Checklist:")
		for _, c := range t.Checklist { fmt.Fprintf(&b, "  - %s\n", c) }
	}
	return b.String()
}
