/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package bustest

// Test layout shared by every CPU backend. The program times ITER iterations
// of a 4-access loop per bracket, REPS brackets per case, between marker reads
// of the recorder PicoROM's communications window. Between cases it waits for
// a host acknowledge, but only when a PicoROM session is active, so the same
// image runs unchanged in simulation.

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"jtutil/picorom"
)

const (
	PicoBase      = 0x0DC00 // window inside the recorder chip (lower 64 KiB)
	tx_offset     = 0x200   // TX half: reads there are recorded as events
	active_offset = 0x04
	inseq_offset  = 0x0C
	Iterations    = 256
	Reps          = 3
	lane_bytes    = 0x10000 // usable bytes per chip (PicoROM 64k mode)
	MarkStart     = 0x101
	MarkEnd       = 0x112
	MarkFatal     = 0x11F
	MarkCase0     = 0x020 // bracket k: start MarkCase0+2k, end +1
	LoadSize      = "64k"
)

type Bracket struct {
	Case   string `json:"case"`
	Access string `json:"access"`
	Addr   string `json:"addr"`
	Rep    int    `json:"rep"`
	Start  string `json:"start"`
	End    string `json:"end"`
	start  int
	end    int
}

// Test is a spec bound to its CPU backend, with the derived layout
type Test struct {
	*Spec
	Backend  Backend
	Lane     int // ROM lane that serves the markers
	Cases    []Access
	Brackets []Bracket
}

func NewTest(s *Spec) (*Test, error) {
	b, e := GetBackend(s.Cpu); if e != nil { return nil, e }
	t := &Test{Spec: s, Backend: b}
	switch s.Rom.CommsLane {
	case "even": t.Lane = 0
	case "odd": t.Lane = 1
	default: return nil, fmt.Errorf("comms_lane %q: use even or odd", s.Rom.CommsLane)
	}
	if b.Lanes() == 1 { t.Lane = 0 }
	t.Cases = append([]Access{{Name: "baseline", Addr: s.Ram.Base, Access: "none"}}, s.Cases...)
	k := 0
	for _, c := range t.Cases {
		for r := 0; r < Reps; r++ {
			code := MarkCase0 + 2*k
			t.Brackets = append(t.Brackets, Bracket{Case: c.Name, Access: c.Access,
				Addr: fmt.Sprintf("0x%x", c.Addr), Rep: r, start: code, end: code + 1,
				Start: fmt.Sprintf("0x%03x", code), End: fmt.Sprintf("0x%03x", code+1)})
			k++
		}
	}
	return t, nil
}

// CpuAddr is the CPU byte address of byte phys of the chip on a lane
func (t *Test) CpuAddr(phys, lane int) int {
	return t.Rom.CpuBase + t.Backend.Lanes()*phys + lane
}

func (t *Test) Mark(code int) int  { return t.CpuAddr(PicoBase+tx_offset+code, t.Lane) }
func (t *Test) Active() int        { return t.CpuAddr(PicoBase+active_offset, t.Lane) }
func (t *Test) InSeq() int         { return t.CpuAddr(PicoBase+inseq_offset, t.Lane) }
func (t *Test) RxData() int        { return t.CpuAddr(PicoBase+tx_offset, t.Lane) }
func (t *Test) Stack() int         { return t.Ram.Base + t.Ram.Size }
func (t *Test) MarkWindow() (int, int) { return t.Mark(0), t.Mark(0x1ff) }

// LaneNames names the ROM images: even/odd, or rom for 8-bit buses
func (t *Test) LaneNames() []string {
	if t.Backend.Lanes() == 1 { return []string{"rom"} }
	return []string{"even", "odd"}
}

func (t *Test) LaneSockets() []string {
	if t.Backend.Lanes() == 1 { return []string{t.Rom.Socket} }
	return []string{t.Rom.Even, t.Rom.Odd}
}

type Manifest struct {
	Set        string            `json:"set"`
	Board      string            `json:"board"`
	Core       string            `json:"core"`
	Cpu        string            `json:"cpu"`
	CpuHz      int               `json:"cpu_hz"`
	CpuBase    string            `json:"cpu_base"`
	Lanes      []string          `json:"lanes"`
	Sockets    []string          `json:"sockets"`
	CommsLane  string            `json:"comms_lane"`
	Size       string            `json:"size"`
	PicoBase   string            `json:"pico_base"`
	MarkWindow [2]string         `json:"marker_cpu_window"`
	Iterations int               `json:"iterations"`
	Reps       int               `json:"reps"`
	Accesses   int               `json:"kernel_accesses"`
	Nominal    map[string]int    `json:"nominal_cycles_per_iteration"`
	Markers    map[string]string `json:"markers"`
	Brackets   []Bracket         `json:"brackets"`
	Expected   int               `json:"events_expected"`
	CodeBytes  int               `json:"code_bytes"`
	Sha256     map[string]string `json:"sha256"`
}

// Generate writes the program, its images and manifest.json to dir
func (t *Test) Generate(dir string) (*Manifest, error) {
	src, e := t.Backend.Source(t); if e != nil { return nil, e }
	e = os.MkdirAll(dir, 0o775); if e != nil { return nil, e }
	e = os.WriteFile(filepath.Join(dir, "test.s"), []byte(src), 0o664); if e != nil { return nil, e }
	code, lst, e := t.Backend.Assemble(src); if e != nil { return nil, e }
	e = os.WriteFile(filepath.Join(dir, "test.lst"), []byte(lst), 0o664); if e != nil { return nil, e }
	lanes := t.Backend.Lanes()
	if win := t.CpuAddr(PicoBase, 0) - t.Rom.CpuBase; len(code) >= win {
		return nil, fmt.Errorf("code is %d bytes and reaches the PicoROM window at 0x%x", len(code), win)
	}
	cpu := bytes.Repeat([]byte{0xFF}, lanes*lane_bytes)
	copy(cpu, code)
	files := map[string][]byte{"cpu.bin": cpu}
	pad := bytes.Repeat([]byte{0xFF}, lane_bytes)
	for k, name := range t.LaneNames() {
		img := make([]byte, 0, 2*lane_bytes)
		for i := k; i < len(cpu); i += lanes { img = append(img, cpu[i]) }
		files[name+"_lane.bin"] = append(img, pad...)
	}
	m := t.manifest(len(code))
	for name, data := range files {
		e = os.WriteFile(filepath.Join(dir, name), data, 0o664); if e != nil { return nil, e }
		m.Sha256[name] = picorom.Sha(data)
	}
	js, _ := json.MarshalIndent(m, "", "  ")
	e = os.WriteFile(filepath.Join(dir, "manifest.json"), append(js, '\n'), 0o664)
	return m, e
}

func (t *Test) manifest(code_bytes int) *Manifest {
	lo, hi := t.MarkWindow()
	return &Manifest{Set: t.Set, Board: t.Board, Core: t.Core, Cpu: t.Cpu, CpuHz: t.CpuHz,
		CpuBase: fmt.Sprintf("0x%x", t.Rom.CpuBase), Lanes: t.LaneNames(), Sockets: t.LaneSockets(),
		CommsLane: t.LaneNames()[t.Lane], Size: LoadSize, PicoBase: fmt.Sprintf("0x%x", PicoBase),
		MarkWindow: [2]string{fmt.Sprintf("0x%x", lo), fmt.Sprintf("0x%x", hi)},
		Iterations: Iterations, Reps: Reps, Accesses: 4, Nominal: t.Backend.Nominal(),
		Markers: map[string]string{"start": fmt.Sprintf("0x%03x", MarkStart),
			"end": fmt.Sprintf("0x%03x", MarkEnd), "fatal": fmt.Sprintf("0x%03x", MarkFatal)},
		Brackets: t.Brackets, Expected: 2 + 2*len(t.Brackets), CodeBytes: code_bytes,
		Sha256: map[string]string{}}
}
