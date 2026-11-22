/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package picorom

import (
	"context"
	"fmt"
	"sort"
	"time"
)

type ProbeSample struct {
	T     float64 `json:"t"`
	State string  `json:"bus_state"`
}

type ProbeCount struct {
	Address string `json:"address"`
	Count   int    `json:"count"`
}

type ProbeResult struct {
	Unit      string        `json:"unit"`
	PowerOn   *PowerState   `json:"power_on,omitempty"`
	PowerOff  *PowerState   `json:"power_off,omitempty"`
	Off       []string      `json:"off_samples"`
	Samples   []ProbeSample `json:"samples"`
	Pins      int           `json:"pin_samples"`
	Selected  int           `json:"selected_reads"`
	Distinct  int           `json:"distinct_addresses"`
	Top       []ProbeCount  `json:"top_addresses"`
	TopRead   []ProbeCount  `json:"top_selected_addresses"`
	Verdict   string        `json:"verdict"`
}

// Probe powers the PCB for a bounded time and samples the unit's pins.
// The unit needs the diagnostic firmware (bus_state parameter).
// Ctrl-C (ctx) stops sampling; the PCB is switched off on every path.
func Probe(ctx context.Context, lab *Lab, power Power, name string, seconds, interval time.Duration) (res *ProbeResult, err error) {
	u, e := FindUnit(lab, name); if e != nil { return nil, e }
	if !u.Recorder { return nil, fmt.Errorf("%s has no pin snapshots (needs the diagnostic firmware)", name) }
	st, e := power.Status(); if e != nil { return nil, e }
	if st.On != nil && *st.On { return nil, fmt.Errorf("PCB power is on; switch it off first") }
	l, e := Open(name); if e != nil { return nil, e }
	defer l.Close()
	res = &ProbeResult{Unit: name}
	for k := 0; k < 5; k++ {
		s, e := l.Get("bus_state"); if e != nil { return nil, e }
		res.Off = append(res.Off, s)
	}
	if e := ctx.Err(); e != nil { return nil, e }
	defer func() {
		off, e := power.Set(false)
		if e != nil { err = fmt.Errorf("THE PCB MAY STILL BE POWERED: %w", e); return }
		res.PowerOff = &off
	}()
	on, e := power.Set(true); if e != nil { return res, e }
	res.PowerOn = &on
	t0 := time.Now()
	for time.Since(t0) < seconds && ctx.Err() == nil {
		s, e := l.Get("bus_state"); if e != nil { break }
		res.Samples = append(res.Samples, ProbeSample{T: time.Since(t0).Seconds(), State: s})
		time.Sleep(interval)
	}
	res.summarize()
	return res, ctx.Err()
}

func (r *ProbeResult) summarize() {
	all, sel := map[int]int{}, map[int]int{}
	for _, s := range r.Samples {
		b, a, e := DecodeBusState(s.State); if e != nil { continue }
		for _, p := range []Pins{b, a} {
			r.Pins++
			all[p.Address]++
			if p.Selected() { r.Selected++; sel[p.Address]++ }
		}
	}
	r.Distinct = len(all)
	r.Top, r.TopRead = top(all), top(sel)
	switch {
	case r.Pins == 0: r.Verdict = "no samples"
	case r.Distinct == 1 && r.Selected == 0:
		r.Verdict = "address lines constant and the socket never selected: the CPU is stuck " +
			"(all ones usually means a tri-stated bus: reset, halt or no clock; another value is a cycle waiting for DTACK)"
	case r.Selected == 0: r.Verdict = "the socket was never selected while sampled"
	default: r.Verdict = "the socket is being read"
	}
}

func top(m map[int]int) []ProbeCount {
	var out []ProbeCount
	for a, n := range m { out = append(out, ProbeCount{Address: fmt.Sprintf("0x%05x", a), Count: n}) }
	sort.Slice(out, func(i, j int) bool { return out[i].Count > out[j].Count })
	if len(out) > 8 { out = out[:8] }
	return out
}
