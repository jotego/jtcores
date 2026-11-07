/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package mra

import (
	"fmt"
	"strings"
)

type ButtonCfg struct {
	Selectable
	Names string
	Map   string
}

func (cfg Mame2MRA) select_buttons(machine *MachineXML) (selected *ButtonCfg) {
	for k := range cfg.Buttons.Names {
		b := &cfg.Buttons.Names[k]
		m := b.Match(machine)
		if (m == 1 && selected == nil) || m == 2 {
			selected = b
		}
		if m == 3 { return b }
	}
	return selected
}

func (cfg Mame2MRA) validate_button_maps() error {
	for _, b := range cfg.Buttons.Names {
		if b.Map == "" { continue }
		names := strings.Split(b.Names, ",")
		if b.Names == "" || len(b.Map) != len(names) || len(names) > 6 {
			return fmt.Errorf("buttons %q: map must have one character per name (up to six)", b.Names)
		}
		used := ""
		for k, key := range b.Map {
			if !strings.ContainsRune("ABXYLR-", key) {
				return fmt.Errorf("buttons %q: invalid map key %q; use ABXYLR or -", b.Names, key)
			}
			if key == '-' {
				if strings.TrimSpace(names[k]) != "-" {
					return fmt.Errorf("buttons %q: map key - is only allowed for unused buttons", b.Names)
				}
				continue
			}
			if strings.ContainsRune(used, key) {
				return fmt.Errorf("buttons %q: repeated map key %q", b.Names, key)
			}
			used += string(key)
		}
	}
	return nil
}
