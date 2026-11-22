/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package bustest

import (
	"fmt"
	"sort"
	"strings"
)

// Backend adapts the test to one CPU family. To support another CPU, add a
// file with a type that implements Backend and register it in init().
type Backend interface {
	Name() string
	// Lanes is the number of ROM chips that make one data word:
	// 2 for a 16-bit bus split in even/odd bytes, 1 for an 8-bit bus
	Lanes() int
	// Source renders the test program for the layout in t
	Source(t *Test) (string, error)
	// Assemble returns the binary image placed at the ROM's CPU base,
	// and an assembler listing
	Assemble(src string) (code []byte, listing string, e error)
	// Nominal gives the cycles per loop iteration without wait states
	Nominal() map[string]int
	// SimHook is the C++ sim_hook.h that logs CPU reads in [lo,hi] to
	// marker_log.csv as "<time ps>,<hex address>"
	SimHook(cpu_path string, lo, hi int) string
}

var backends = map[string]Backend{}

func register(b Backend) { backends[b.Name()] = b }

func GetBackend(name string) (Backend, error) {
	b, ok := backends[name]
	if !ok {
		var names []string
		for k := range backends { names = append(names, k) }
		sort.Strings(names)
		return nil, fmt.Errorf("no bustest backend for cpu %q (available: %s)", name, strings.Join(names, ", "))
	}
	return b, nil
}
