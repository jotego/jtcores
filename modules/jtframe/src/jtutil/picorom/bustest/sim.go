/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package bustest

// Runs the test program in jtsim: the program replaces the original program
// ROM bytes, and a verification-only harness hook (sim_hook.h, enabled with
// -d SIM_HOOK) logs the marker reads with the simulated time.

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

type SimResult struct {
	Rc        int             `json:"jtsim_rc"`
	Patch     map[string]any  `json:"sdram_patch,omitempty"`
	Events    int             `json:"events"`
	Brackets  []BracketResult `json:"brackets"`
	StartSeen bool            `json:"start_seen"`
	EndSeen   bool            `json:"end_seen"`
	FatalSeen bool            `json:"fatal_seen"`
}

type BracketResult struct {
	Bracket
	DurationUs *float64 `json:"duration_us,omitempty"`
	Cycles     *float64 `json:"cycles_per_iteration"`
}

type Simulation struct {
	t       *Test
	dir     string
	log     *os.File
	cpu     []byte
	patched []byte
}

func NewSimulation(t *Test) *Simulation { return &Simulation{t: t, dir: t.OutDir()} }

// Run generates the program, prepares the core's ROM and runs jtsim
func (s *Simulation) Run() (*SimResult, error) {
	_, e := s.t.Generate(s.dir); if e != nil { return nil, e }
	s.cpu, e = os.ReadFile(filepath.Join(s.dir, "cpu.bin")); if e != nil { return nil, e }
	s.log, e = os.Create(filepath.Join(s.dir, "jtsim.log")); if e != nil { return nil, e }
	defer s.log.Close()
	res := &SimResult{}
	if s.t.Sim.Download == 0 {
		e = s.run_tool("sdram.log", s.jtutil(), "sdram", s.t.Set); if e != nil { return nil, e }
	}
	e = s.patch_rom(); if e != nil { return nil, e }
	if s.t.Sim.Download == 0 {
		res.Patch, e = s.patch_sdram(); if e != nil { return nil, e }
	}
	e = s.write_hook(); if e != nil { return nil, e }
	e = s.copy_mod(); if e != nil { return nil, e }
	res.Rc = s.jtsim()
	return res, s.parse_markers(res)
}

func (s *Simulation) jtutil() string {
	exe, e := os.Executable(); if e != nil { return "jtutil" }
	return exe
}

func (s *Simulation) run_tool(logname, name string, args ...string) error {
	f, e := os.Create(filepath.Join(s.dir, logname)); if e != nil { return e }
	defer f.Close()
	cmd := exec.Command(name, args...)
	cmd.Dir, cmd.Stdout, cmd.Stderr = s.dir, f, f
	e = cmd.Run(); if e != nil { return fmt.Errorf("%s %s failed (see %s): %w", name, strings.Join(args, " "), logname, e) }
	return nil
}

// patch_rom writes rom.bin: rom/<set>.rom with the test program in place of
// the original program ROM
func (s *Simulation) patch_rom() error {
	orig, e := os.ReadFile(filepath.Join(os.Getenv("JTROOT"), "rom", s.t.Set+".rom"))
	if e != nil { return fmt.Errorf("%w (run jtframe mra %s)", e, s.t.Core) }
	off := s.t.Rom.RomOffset
	if off+len(s.cpu) > len(orig) { return fmt.Errorf("rom/%s.rom is too short for the program at %d", s.t.Set, off) }
	s.patched = append([]byte{}, orig...)
	copy(s.patched[off:], s.rom_order(s.cpu))
	// rom_patch changes rom.bin only, e.g. header flags read during the download
	for _, p := range s.t.Sim.RomPatch {
		if p.Offset < 0 || p.Offset+len(p.Bytes) > len(s.patched) { return fmt.Errorf("rom_patch at 0x%x is outside rom.bin", p.Offset) }
		for k, b := range p.Bytes { s.patched[p.Offset+k] = byte(b) }
	}
	data := s.patched
	if s.t.Sim.Download > 0 { data = data[:min(len(data), s.t.Sim.Download)] }
	os.Remove(filepath.Join(s.dir, "rom.bin"))
	return os.WriteFile(filepath.Join(s.dir, "rom.bin"), data, 0o664)
}

func (s *Simulation) rom_order(data []byte) []byte {
	if !s.t.Rom.WordSwap { return data }
	return swap16(data)
}

func swap16(data []byte) []byte {
	out := append([]byte{}, data...)
	for k := 0; k+1 < len(out); k += 2 { out[k], out[k+1] = out[k+1], out[k] }
	return out
}

// patch_sdram finds the original program in the SDRAM bank files made by
// jtutil sdram and overwrites it with the test program
func (s *Simulation) patch_sdram() (map[string]any, error) {
	orig, _ := os.ReadFile(filepath.Join(os.Getenv("JTROOT"), "rom", s.t.Set+".rom"))
	native := orig[s.t.Rom.RomOffset : s.t.Rom.RomOffset+len(s.cpu)]
	if s.t.Rom.WordSwap { native = swap16(native) }
	probe := native[:256]
	banks, _ := filepath.Glob(filepath.Join(s.dir, "sdram_bank*.bin"))
	for _, bank := range banks {
		d, e := os.ReadFile(bank); if e != nil { return nil, e }
		for _, v := range []struct{ order string; pat, img []byte }{
			{"native", probe, s.cpu}, {"swapped", swap16(probe), swap16(s.cpu)}} {
			if i := bytes.Index(d, v.pat); i >= 0 {
				copy(d[i:], v.img)
				return map[string]any{"bank": filepath.Base(bank), "offset": i, "order": v.order}, os.WriteFile(bank, d, 0o664)
			}
		}
	}
	return nil, fmt.Errorf("could not find the original program ROM in the SDRAM banks")
}

func (s *Simulation) write_hook() error {
	lo, hi := s.t.MarkWindow()
	hook := s.t.Backend.SimHook(s.t.Sim.CpuPath, lo, hi)
	os.Remove(filepath.Join(s.dir, "marker_log.csv"))
	return os.WriteFile(filepath.Join(s.dir, "sim_hook.h"), []byte(hook), 0o664)
}

// copy_mod provides the game selection and DIP switches that -setname would
// give; -setname is not used because it would link rom.bin to the original
func (s *Simulation) copy_mod() error {
	mod, e := os.ReadFile(filepath.Join(os.Getenv("JTROOT"), "rom", s.t.Set+".mod"))
	if os.IsNotExist(e) { return nil }
	if e != nil { return e }
	return os.WriteFile(filepath.Join(s.dir, "core.mod"), mod, 0o664)
}

// jtsim stops on simulated time: without video setup some cores never
// produce frames
func (s *Simulation) jtsim() int {
	args := []string{"-d", "SIM_HOOK", "-d", "NOSOUND"}
	if s.t.Sim.Download > 0 { args = append(args, "-load") }
	for _, d := range s.t.Sim.Defs { args = append(args, "-d", d) }
	args = append(args, "-time", strconv.Itoa(s.t.Sim.Ms))
	cmd := exec.Command("jtsim", args...)
	cmd.Dir, cmd.Stdout, cmd.Stderr = s.dir, s.log, s.log
	if e := cmd.Run(); e != nil {
		if ee, ok := e.(*exec.ExitError); ok { return ee.ExitCode() }
		fmt.Fprintln(s.log, e)
		return -1
	}
	return 0
}

func (s *Simulation) parse_markers(res *SimResult) error {
	data, _ := os.ReadFile(filepath.Join(s.dir, "marker_log.csv"))
	lo, _ := s.t.MarkWindow()
	times := map[int]float64{}
	for _, line := range strings.Fields(string(data)) {
		ts, as, _ := strings.Cut(line, ",")
		t, e1 := strconv.ParseFloat(ts, 64)
		a, e2 := strconv.ParseInt(as, 16, 32)
		if e1 != nil || e2 != nil { continue }
		res.Events++
		code := (int(a) - lo) / s.t.Backend.Lanes()
		if _, seen := times[code]; !seen { times[code] = t }
	}
	hz := float64(s.t.CpuHz)
	for _, b := range s.t.Brackets {
		br := BracketResult{Bracket: b}
		ts, ok1 := times[b.start]
		te, ok2 := times[b.end]
		if ok1 && ok2 {
			c := round3((te - ts) * 1e-12 * hz / Iterations)
			br.Cycles = &c
		}
		res.Brackets = append(res.Brackets, br)
	}
	_, res.StartSeen = times[MarkStart]
	_, res.EndSeen = times[MarkEnd]
	_, res.FatalSeen = times[MarkFatal]
	js, _ := json.MarshalIndent(res, "", "  ")
	return os.WriteFile(filepath.Join(s.dir, "sim_result.json"), append(js, '\n'), 0o664)
}

func round3(v float64) float64 { return math.Round(v*1000) / 1000 }
