/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package bustest

// Runs the test on the PCB: checks power is off, loads every lane with full
// readback, arms the recorder, powers the board, acknowledges each case,
// switches the board off and computes cycles per iteration.

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"jtutil/picorom"
)

type RunOptions struct {
	Ctx        context.Context   // cancelled on Ctrl-C: the run stops and switches the PCB off
	Units      map[string]string // lane -> unit name overrides
	Timeout    time.Duration
	StallProbe time.Duration // 0: off
	DryRun     bool
	Confirm    func(plan string) error // asks the operator to confirm the setup
	Out        io.Writer
}

// Placement assigns a connected unit to each ROM lane
type Placement struct {
	Lane   string       `json:"lane"`
	Socket string       `json:"socket"`
	Unit   picorom.Unit `json:"unit"`
	Image  string       `json:"image"`
	Comms  bool         `json:"comms"`
}

type PcbResult struct {
	Set          string                 `json:"set"`
	ManifestSha  map[string]string      `json:"manifest_sha256"`
	Start        string                 `json:"start_utc"`
	Placement    []Placement            `json:"placement"`
	Load         *picorom.LoadReport    `json:"load,omitempty"`
	PowerBefore  picorom.PowerState     `json:"power_before"`
	PowerOn      *picorom.PowerState    `json:"power_on,omitempty"`
	PowerOff     *picorom.PowerState    `json:"power_off,omitempty"`
	Acks         []map[string]any       `json:"acks"`
	Boots        int                    `json:"boots"`
	Warnings     []string               `json:"warnings"`
	Events       []picorom.Event        `json:"events"`
	Gaps         []int                  `json:"sequence_gaps"`
	StallPins    []string               `json:"stall_bus_state,omitempty"`
	Brackets     []BracketResult        `json:"brackets"`
	Complete     bool                   `json:"complete"`
	Dir          string                 `json:"dir"`
}

type Runner struct {
	t     *Test
	lab   *picorom.Lab
	power picorom.Power
	opt   RunOptions
	man   *Manifest
	res   PcbResult
	dir   string
}

func NewRunner(t *Test, lab *picorom.Lab, power picorom.Power, opt RunOptions) *Runner {
	if opt.Out == nil { opt.Out = os.Stderr }
	if opt.Timeout == 0 { opt.Timeout = 30 * time.Second }
	if opt.Ctx == nil { opt.Ctx = context.Background() }
	return &Runner{t: t, lab: lab, power: power, opt: opt}
}

func (r *Runner) Run() (*PcbResult, error) {
	var e error
	r.man, e = r.t.Generate(r.t.OutDir()); if e != nil { return nil, e }
	r.res = PcbResult{Set: r.t.Set, ManifestSha: r.man.Sha256, Start: time.Now().UTC().Format("20060102T150405Z")}
	r.res.Placement, e = r.place()
	if e != nil && r.opt.DryRun {
		fmt.Fprint(r.opt.Out, r.t.Show())
		fmt.Fprintf(r.opt.Out, "Units: %v\nDry run: nothing loaded, power not touched.\n", e)
		return nil, nil
	}
	if e != nil { return nil, e }
	plan := r.plan()
	if r.opt.DryRun {
		fmt.Fprint(r.opt.Out, plan)
		fmt.Fprintln(r.opt.Out, "Dry run: nothing loaded, power not touched.")
		return nil, nil
	}
	e = r.opt.Confirm(plan); if e != nil { return nil, e }
	if e := r.opt.Ctx.Err(); e != nil { return nil, e }
	r.res.PowerBefore, e = r.require_off(); if e != nil { return nil, e }
	r.dir = filepath.Join(r.t.OutDir(), "pcb_"+r.res.Start)
	r.res.Dir = r.dir
	e = os.MkdirAll(r.dir, 0o775); if e != nil { return nil, e }
	var jobs []picorom.LoadJob
	for _, p := range r.res.Placement { jobs = append(jobs, picorom.LoadJob{Name: p.Unit.Name, Path: p.Image}) }
	r.res.Load, e = picorom.LoadImages(r.lab, jobs, LoadSize, filepath.Join(r.dir, "load"), false)
	if e == nil && !r.res.Load.Ok { e = errors.New("PicoROM readback mismatch: see load/report.json") }
	if e != nil { return nil, e }
	e = r.capture()
	r.compute()
	js, _ := json.MarshalIndent(r.res, "", "  ")
	if we := os.WriteFile(filepath.Join(r.dir, "pcb_result.json"), append(js, '\n'), 0o664); we != nil && e == nil { e = we }
	return &r.res, e
}

// place gives the comms lane to a unit with the event recorder and the
// other lanes to the remaining usable units, unless overridden
func (r *Runner) place() ([]Placement, error) {
	units, e := picorom.Units(r.lab); if e != nil { return nil, e }
	if len(units) == 0 { return nil, errors.New("no PicoROM connected") }
	names, sockets := r.t.LaneNames(), r.t.LaneSockets()
	out := make([]Placement, len(names))
	used := map[string]bool{}
	for lane, name := range r.opt.Units {
		if !contains_str(names, lane) { return nil, fmt.Errorf("--unit %s=%s: the lanes are %s", lane, name, strings.Join(names, ", ")) }
		if used[name] { return nil, fmt.Errorf("--unit gives %s to two lanes", name) }
		used[name] = true // reserved: automatic picks skip it
	}
	order := []int{r.t.Lane}
	for k := range names { if k != r.t.Lane { order = append(order, k) } }
	for _, k := range order {
		lane := names[k]
		p := Placement{Lane: lane, Socket: sockets[k], Comms: k == r.t.Lane, Image: filepath.Join(r.t.OutDir(), lane+"_lane.bin")}
		u, e := r.pick(units, used, lane, p.Comms); if e != nil { return nil, e }
		if e := u.Usable(); e != nil { return nil, e }
		if p.Comms && !u.Recorder { return nil, fmt.Errorf("%s serves the markers but has no event recorder (diagnostic firmware)", u.Name) }
		p.Unit = u
		used[u.Name] = true
		out[k] = p
	}
	return out, nil
}

// pick prefers units without the recorder for the other lanes
func (r *Runner) pick(units []picorom.Unit, used map[string]bool, lane string, comms bool) (picorom.Unit, error) {
	if name, ok := r.opt.Units[lane]; ok {
		for _, u := range units { if u.Name == name { return u, nil } }
		return picorom.Unit{}, fmt.Errorf("unit %q for lane %s is not connected", name, lane)
	}
	for pass := 0; pass < 2; pass++ {
		for _, u := range units {
			if used[u.Name] || u.Usable() != nil { continue }
			if comms && !u.Recorder { continue }
			if !comms && pass == 0 && u.Recorder { continue }
			return u, nil
		}
	}
	return picorom.Unit{}, r.no_unit(lane, comms, units)
}

func (r *Runner) no_unit(lane string, comms bool, units []picorom.Unit) error {
	var have []string
	for _, u := range units {
		s := u.Name
		if u.Recorder { s += " (recorder)" }
		if u.Usable() != nil { s += " (disabled)" }
		have = append(have, s)
	}
	need := "a usable PicoROM"
	if comms { need = "a usable PicoROM with the event recorder" }
	return fmt.Errorf("lane %s needs %s. Connected: %s", lane, need, strings.Join(have, ", "))
}

func (r *Runner) plan() string {
	var b strings.Builder
	fmt.Fprintf(&b, "%s: %s\n", r.t.Set, r.t.Board)
	fmt.Fprintf(&b, "Core %s, %s at %.3f MHz, %d cases\n", r.t.Core, r.t.Cpu, float64(r.t.CpuHz)/1e6, len(r.t.Cases))
	fmt.Fprintf(&b, "Power: %s\n", r.power.Describe())
	fmt.Fprintln(&b, "Fit with the PCB off, pin 1 as the original ROM:")
	for _, p := range r.res.Placement {
		role := ""
		if p.Comms { role = ", records markers" }
		fmt.Fprintf(&b, "  %-6s socket %-6s <- %s (%s%s)\n", p.Lane, p.Socket, p.Unit.Name, p.Unit.Serial, role)
		if lp := p.Unit.Lab; lp != nil && lp.Pins != 0 && r.t.Rom.Pins != 0 && lp.Pins != r.t.Rom.Pins {
			fmt.Fprintf(&b, "         the socket is %d-pin and the unit %d-pin: an adapter is needed\n", r.t.Rom.Pins, lp.Pins)
		}
	}
	if len(r.t.Checklist) > 0 {
		fmt.Fprintln(&b, "Checklist:")
		for _, c := range r.t.Checklist { fmt.Fprintf(&b, "  - %s\n", c) }
	}
	return b.String()
}

func (r *Runner) require_off() (picorom.PowerState, error) {
	st, e := r.power.Status(); if e != nil { return st, e }
	if st.On != nil && *st.On { return st, fmt.Errorf("PCB power is on (%s); switch it off first", r.power.Describe()) }
	return st, nil
}

// capture powers the PCB only after the recorder session is armed, and
// switches it off on every exit path. A failed power-off is the error returned.
func (r *Runner) capture() (err error) {
	rec := r.res.Placement[r.t.Lane].Unit
	link, e := picorom.Open(rec.Name); if e != nil { return e }
	powered := false
	defer func() {
		if powered {
			st, e := r.power.Set(false)
			if e != nil {
				r.warn("power off failed: " + e.Error())
				err = fmt.Errorf("THE PCB MAY STILL BE POWERED: %w", e)
			} else { r.res.PowerOff = &st }
		}
		link.CommsEnd()
		link.Close()
	}()
	e = link.CommsStart(PicoBase); if e != nil { return e }
	snap, e := link.Events(PicoBase); if e != nil { return e }
	if !snap.Session { return fmt.Errorf("no communications session at 0x%x on %s", PicoBase, rec.Name) }
	if snap.Count != 0 { return fmt.Errorf("a fresh capture should be empty, it has %d events", snap.Count) }
	if e := r.opt.Ctx.Err(); e != nil { return e }
	powered = true // set first: Set(true) may switch the plug and still fail
	st, e := r.power.Set(true); if e != nil { return e }
	r.res.PowerOn = &st
	return r.collect(link)
}

func (r *Runner) collect(link *picorom.Link) error {
	events := map[int]picorom.Event{}
	defer func() { // keep what arrived, also when returning early
		for _, s := range sorted_keys(events) { r.res.Events = append(r.res.Events, events[s]) }
	}()
	per_case := 2 * Reps
	ncases := len(r.t.Cases)
	acks, boot := 0, -1
	start := time.Now()
	last_new := start
	for time.Since(start) < r.opt.Timeout {
		if e := r.opt.Ctx.Err(); e != nil { r.warn("interrupted"); return e }
		_, e := link.Poll(); if e != nil { return e }
		snap, e := link.Events(PicoBase); if e != nil { return e }
		if !snap.Session { return errors.New("the recorder session was lost") }
		if snap.CaptureStopped { return errors.New("the recorder stopped capturing") }
		if snap.DroppedBytes > 0 && len(r.res.Warnings) == 0 { r.warn("outgoing FIFO bytes dropped (markers carry no data; harmless)") }
		for _, ev := range snap.Events {
			if _, seen := events[ev.Sequence]; !seen { events[ev.Sequence] = ev; last_new = time.Now() }
		}
		seqs := sorted_keys(events)
		boots := 0
		for _, s := range seqs {
			if events[s].Address == MarkStart { boots++; if s > boot { boot, acks = s, 0 } }
		}
		r.res.Boots = boots
		var cur []int
		for _, s := range seqs { if boot >= 0 && s > boot { cur = append(cur, events[s].Address) } }
		if contains(cur, MarkFatal) { r.warn("fatal marker: the CPU took an exception"); break }
		done := 0
		for _, c := range cur { if c >= MarkCase0 && c < 0x100 { done++ } }
		if done/per_case > acks && acks < ncases {
			e = link.Send([]byte("A")); if e != nil { return e }
			acks++
			r.res.Acks = append(r.res.Acks, map[string]any{"boot_seq": boot, "case": acks, "host_s": time.Since(start).Seconds()})
		}
		if contains(cur, MarkEnd) { break }
		if r.opt.StallProbe > 0 && len(events) > 0 && time.Since(last_new) > r.opt.StallProbe {
			for k := 0; k < 40; k++ {
				p, e := link.Get("bus_state"); if e != nil { break }
				r.res.StallPins = append(r.res.StallPins, p)
				time.Sleep(20 * time.Millisecond)
			}
			r.warn(fmt.Sprintf("no new marker for %v: pins sampled", r.opt.StallProbe))
			break
		}
		time.Sleep(2 * time.Millisecond)
	}
	return nil
}

func (r *Runner) warn(s string) { r.res.Warnings = append(r.res.Warnings, s) }

// compute pairs markers from the last boot only
func (r *Runner) compute() {
	t := map[int]uint32{}
	prev, boot := -1, -1
	for _, ev := range r.res.Events {
		if prev >= 0 && ev.Sequence != prev+1 { r.res.Gaps = append(r.res.Gaps, ev.Sequence) }
		prev = ev.Sequence
		if ev.Address == MarkStart { boot = ev.Sequence }
	}
	for _, ev := range r.res.Events {
		if ev.Sequence >= boot { t[ev.Address] = ev.TimeUs }
	}
	hz := float64(r.t.CpuHz)
	for _, b := range r.t.Brackets {
		br := BracketResult{Bracket: b}
		ts, ok1 := t[b.start]
		te, ok2 := t[b.end]
		if ok1 && ok2 {
			d := float64(te - ts) // modulo 2^32 microseconds
			c := round3(d * 1e-6 * hz / Iterations)
			br.DurationUs, br.Cycles = &d, &c
		}
		r.res.Brackets = append(r.res.Brackets, br)
	}
	_, end := t[MarkEnd]
	r.res.Complete = end && len(r.res.Gaps) == 0
}

func sorted_keys(m map[int]picorom.Event) []int {
	var k []int
	for s := range m { k = append(k, s) }
	sort.Ints(k)
	return k
}

func contains(list []int, v int) bool {
	for _, x := range list { if x == v { return true } }
	return false
}

func contains_str(list []string, v string) bool {
	for _, x := range list { if x == v { return true } }
	return false
}
