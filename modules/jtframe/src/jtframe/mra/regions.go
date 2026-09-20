/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package mra

import (
	"fmt"
	"strings"
	"jotego/jtframe/common"
)

// Shared rules and ROM.order may include regions used by only some games.
// Validate names across the applicable sets, while make_ROM checks each layout.
func validate_rom_regions(machines []ParsedMachine, cfg Mame2MRA) (all_errors error) {
	for _, reg := range cfg.ROM.Regions {
		if reg.Skip || reg.Name == "nvram" || generated_rom_region(reg.Name) || len(reg.Files) != 0 { continue }
		applicable := []string{}
		found := false
		for _, parsed := range machines {
			if reg.Match(parsed.machine) == 0 { continue }
			selected := find_region_cfg(parsed.machine, reg.EffName(), cfg)
			if selected.Name == reg.Name && selected.Match(parsed.machine) == reg.Match(parsed.machine) {
				applicable = append(applicable, parsed.machine.Name)
			}
			// A shared region can exist in games whose more specific rule
			// overrides this one, and be empty in the remaining games.
			names := parsed.rom_regions
			if reg.Rename == "" {
				// Consumer rules use the names after all configured renames.
				// Rename rules themselves must still name a real input region.
				names = add_unlisted_regions(parsed.machine.Rom, nil)
			}
			source := RegCfg{Name: reg.Name}
			for _, name := range names {
				if source.MatchRegion(name) { found = true; break }
			}
		}
		if !found && len(applicable) != 0 {
			all_errors = common.JoinErrors(all_errors, fmt.Errorf("ROM region %q does not match any MAME region in applicable sets: %s", reg.Name, strings.Join(applicable, ", ")))
		}
	}
	for _, name := range cfg.ROM.Order {
		found := false
		for _, parsed := range machines {
			reg := find_region_cfg(parsed.machine, name, cfg)
			// Configured padding, explicit files and skip rules define valid
			// output regions even when the input has no corresponding ROMs.
			if reg.Skip || reg.Name == "nvram" || generated_rom_region(name) || reg.Len > 0 || len(reg.Files) != 0 { found = true; break }
			for _, rom := range parsed.machine.Rom {
				if reg.MatchRegion(rom.Region) { found = true; break }
			}
			if found { break }
		}
		if !found && len(machines) != 0 {
			all_errors = common.JoinErrors(all_errors, fmt.Errorf("ROM.order region %q does not match any MAME region", name))
		}
	}
	return all_errors
}

func generated_rom_region(name string) bool {
	// make_devROM supplies this lookup table from built-in data, not MAME.
	return name == "fd1089"
}
