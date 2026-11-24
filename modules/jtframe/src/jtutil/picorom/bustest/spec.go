/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

// Package bustest times CPU bus accesses on a PCB and in jtsim with the same
// test program. Board definitions live in cores/<core>/cfg/picorom.yaml.
package bustest

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gopkg.in/yaml.v2"
	"jotego/jtframe/common"
)

// Access is one timed bus operation, or a setup/watchdog write
type Access struct {
	Name   string `yaml:"name"   json:"name,omitempty"`
	Addr   int    `yaml:"addr"   json:"addr"`
	Access string `yaml:"access" json:"access"` // read.w, write.w, read.b, write.b
	Value  int    `yaml:"value"  json:"value,omitempty"`
	Expect string `yaml:"expect" json:"expect,omitempty"` // printed next to the results
	Why    string `yaml:"why"    json:"why,omitempty"`    // comment for setup writes
}

type Rom struct {
	CpuBase   int    `yaml:"cpu_base"`
	Even      string `yaml:"even"`       // socket holding D15-D8 (16-bit buses)
	Odd       string `yaml:"odd"`        // socket holding D7-D0 (16-bit buses)
	Socket    string `yaml:"socket"`     // single socket (8-bit buses)
	Chip      string `yaml:"chip"`
	Pins      int    `yaml:"pins"`       // DIP pins of the program sockets
	CommsLane string `yaml:"comms_lane"` // socket that serves the markers: even (default) or odd
	RomOffset int    `yaml:"rom_offset"` // program offset inside rom/<set>.rom
	WordSwap  bool   `yaml:"word_swap"`  // .rom stores each CPU word byte-swapped
}

type Ram struct {
	Base int `yaml:"base"`
	Size int `yaml:"size"`
}

type RomPatch struct {
	Offset int   `yaml:"offset"`
	Bytes  []int `yaml:"bytes"`
}

// Sim holds the jtsim options a board needs
type Sim struct {
	Ms       int        `yaml:"ms"`       // simulated time limit (default 60)
	Download int        `yaml:"download"` // send the first N bytes through the simulated download instead of jtutil sdram
	Defs     []string   `yaml:"defs"`     // extra jtsim -d macros
	CpuPath  string     `yaml:"cpu_path"` // Verilator path prefix of the CPU, if not the backend default
	RomPatch []RomPatch `yaml:"rom_patch"` // byte changes to rom.bin before jtsim (e.g. disable a decryption flag)
}

// Spec is the bustest definition of one set
type Spec struct {
	Core      string   `yaml:"-"`
	Set       string   `yaml:"-"`
	Board     string   `yaml:"board"`
	Cpu       string   `yaml:"cpu"`
	CpuHz     int      `yaml:"cpu_hz"`
	Rom       Rom      `yaml:"rom"`
	Ram       Ram      `yaml:"ram"`
	Watchdog  *Access  `yaml:"watchdog"`
	Init      []Access `yaml:"init"`
	Preamble  []string `yaml:"preamble"` // raw instructions right after reset (diagnostics)
	Cases     []Access `yaml:"cases"`
	Checklist []string `yaml:"checklist"` // printed before power-on
	Sim       Sim      `yaml:"sim"`
}

type cfg_file struct {
	Bustest map[string]*Spec `yaml:"bustest"`
}

// LoadSpec reads cores/<core>/cfg/picorom.yaml and returns the set's test
func LoadSpec(core, set string) (*Spec, error) {
	sets, e := load_cfg(core); if e != nil { return nil, e }
	s, ok := sets[set]
	if !ok {
		var names []string
		for k := range sets { names = append(names, k) }
		sort.Strings(names)
		return nil, fmt.Errorf("no bustest for %s in %s. Available: %s", set,
			common.ConfigFilePath(core, "picorom.yaml"), strings.Join(names, ", "))
	}
	s.Core, s.Set = core, set
	return s, s.validate()
}

func load_cfg(core string) (map[string]*Spec, error) {
	path := common.ConfigFilePath(core, "picorom.yaml")
	data, e := os.ReadFile(path); if e != nil { return nil, e }
	var f cfg_file
	e = yaml.UnmarshalStrict(data, &f); if e != nil { return nil, fmt.Errorf("%s: %w", path, e) }
	return f.Bustest, nil
}

// Sets lists the bustest sets of a core
func Sets(core string) ([]string, error) {
	sets, e := load_cfg(core); if e != nil { return nil, e }
	var names []string
	for k := range sets { names = append(names, k) }
	sort.Strings(names)
	return names, nil
}

func (s *Spec) validate() error {
	where := fmt.Sprintf("%s bustest %s", common.ConfigFilePath(s.Core, "picorom.yaml"), s.Set)
	if s.Cpu == "" { s.Cpu = "m68k" }
	if _, e := GetBackend(s.Cpu); e != nil { return fmt.Errorf("%s: %w", where, e) }
	if s.CpuHz <= 0 { return fmt.Errorf("%s: cpu_hz missing", where) }
	if len(s.Cases) == 0 { return fmt.Errorf("%s: no cases", where) }
	if s.Rom.CommsLane == "" { s.Rom.CommsLane = "even" }
	if s.Sim.Ms == 0 { s.Sim.Ms = 60 }
	for _, c := range append(append([]Access{}, s.Cases...), s.Init...) {
		if !valid_access(c.Access) { return fmt.Errorf("%s: case %q has access %q", where, c.Name, c.Access) }
	}
	names := map[string]bool{"baseline": true} // the test adds the baseline case
	for _, c := range s.Cases {
		if c.Name == "" || names[c.Name] { return fmt.Errorf("%s: case names must be unique, not empty and not baseline (%q)", where, c.Name) }
		names[c.Name] = true
	}
	// bracket marker codes must stay below the start/end/fatal markers
	if max_cases := (0x100-MarkCase0)/(2*Reps) - 1; len(s.Cases) > max_cases {
		return fmt.Errorf("%s: %d cases, at most %d", where, len(s.Cases), max_cases)
	}
	if s.Watchdog != nil && !valid_access(s.Watchdog.Access) {
		return fmt.Errorf("%s: watchdog access %q", where, s.Watchdog.Access)
	}
	return nil
}

func valid_access(a string) bool {
	switch a {
	case "read.w", "write.w", "read.b", "write.b": return true
	}
	return false
}

// OutDir is cores/<core>/ver/<set>_bustest: a jtsim folder for the core,
// ignored by Git, that also keeps the generated images and the PCB runs
func (s *Spec) OutDir() string {
	return filepath.Join(os.Getenv("JTROOT"), "cores", s.Core, "ver", s.Set+"_bustest")
}
