/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"jotego/jtframe/mra"
)

// sourceExclusions uses jtframe's own TOML model and selector matcher. A
// machine selector also selects its clones, so plain setname matching is not
// sufficient for artifact or JTBIN MRAs (which do not carry cloneof metadata).
func sourceExclusions(source string, tuples []InventoryTuple) (map[string]string, error) {
	configs := map[string]mra.Mame2MRA{}
	wanted := map[string]bool{}
	for _, t := range tuples {
		if _, ok := configs[t.Core]; ok {
			continue
		}
		path := filepath.Join(source, "cores", t.Core, "cfg", "mame2mra.toml")
		file, err := os.Open(path)
		if os.IsNotExist(err) {
			configs[t.Core] = mra.Mame2MRA{}
			continue
		}
		if err != nil {
			return nil, err
		}
		cfg, parseErr := mra.NewMRAcfgFromTOML(file)
		closeErr := file.Close()
		if parseErr != nil {
			return nil, fmt.Errorf("regression eligibility %s: %w", path, parseErr)
		}
		if closeErr != nil {
			return nil, closeErr
		}
		configs[t.Core] = cfg
	}
	excluded := map[string]string{}
	for _, t := range tuples {
		cfg := configs[t.Core]
		// Exact set selectors require no MAME metadata. Family selectors do.
		if exactSetSelector(cfg.Parse.Debug.Selectable, t.Setname) {
			excluded[tupleKey(t)] = "working-project parse.debug selection (--nodbg)"
			continue
		}
		if exactSetSelector(cfg.Parse.Skip.Selectable, t.Setname) {
			excluded[tupleKey(t)] = "working-project parse.skip selection"
			continue
		}
		if familySelector(cfg.Parse.Debug.Selectable) || familySelector(cfg.Parse.Skip.Selectable) || cfg.Parse.Skip.Bootlegs || len(cfg.Parse.Skip.Descriptions) > 0 {
			wanted[t.Setname] = true
		}
	}
	machines, err := selectedMAMEMachines(filepath.Join(source, "doc", "mame.xml"), wanted)
	if err != nil {
		return nil, err
	}
	for _, t := range tuples {
		if excluded[tupleKey(t)] != "" {
			continue
		}
		cfg := configs[t.Core]
		machine := mra.MachineXML{Name: t.Setname}
		if wanted[t.Setname] {
			found, ok := machines[t.Setname]
			if !ok {
				return nil, fmt.Errorf("cannot classify regression eligibility for %s/%s: machine metadata missing from doc/mame.xml", t.Core, t.Setname)
			}
			machine = found
		}
		switch {
		case cfg.Parse.Debug.Match(&machine) > 1:
			excluded[tupleKey(t)] = "working-project parse.debug selection (--nodbg)"
		case cfg.Parse.Skip.Match(&machine) > 1:
			excluded[tupleKey(t)] = "working-project parse.skip selection"
		case cfg.Parse.Skip.Bootlegs && strings.Contains(strings.ToLower(machine.Description), "bootleg"):
			excluded[tupleKey(t)] = "working-project parse.skip.bootlegs selection"
		default:
			for _, description := range cfg.Parse.Skip.Descriptions {
				if strings.Contains(machine.Description, description) {
					excluded[tupleKey(t)] = "working-project parse.skip.descriptions selection"
					break
				}
			}
		}
	}
	return excluded, nil
}
func exactSetSelector(s mra.Selectable, set string) bool {
	if s.Setname == set {
		return true
	}
	for _, name := range s.Setnames {
		if name == set {
			return true
		}
	}
	return false
}
func familySelector(s mra.Selectable) bool { return s.Machine != "" || len(s.Machines) > 0 }

func selectedMAMEMachines(path string, wanted map[string]bool) (map[string]mra.MachineXML, error) {
	result := map[string]mra.MachineXML{}
	if len(wanted) == 0 {
		return result, nil
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("regression family eligibility needs %s: %w", path, err)
	}
	defer file.Close()
	decoder := xml.NewDecoder(file)
	for len(result) < len(wanted) {
		token, err := decoder.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		start, ok := token.(xml.StartElement)
		if !ok || start.Name.Local != "machine" {
			continue
		}
		name := attrValue(start.Attr, "name")
		if !wanted[name] {
			if err = decoder.Skip(); err != nil {
				return nil, err
			}
			continue
		}
		var machine mra.MachineXML
		if err = decoder.DecodeElement(&machine, &start); err != nil {
			return nil, err
		}
		result[name] = machine
	}
	return result, nil
}

func debugMRADirectory(root, path string) bool {
	relative, err := filepath.Rel(root, filepath.Dir(path))
	if err != nil {
		return false
	}
	for _, part := range strings.Split(filepath.ToSlash(relative), "/") {
		if strings.EqualFold(part, "_debug") || strings.EqualFold(part, "debug") {
			return true
		}
	}
	return false
}

// ValidateManifestEligibility rejects obsolete explicit inventories without
// modifying them or their resume state. Historical results remain historical;
// a newly selected inventory must obey the working project's release policy.
func ValidateManifestEligibility(source string, manifest Manifest) error {
	tuples := []InventoryTuple{}
	for _, core := range manifest.Cores {
		if !manualComponent(core.Core) {
			return fmt.Errorf("manifest contains unsafe core name %q", core.Core)
		}
		for _, game := range core.Games {
			if !manualComponent(game.Setname) {
				return fmt.Errorf("manifest contains unsafe setname %q", game.Setname)
			}
			tuples = append(tuples, InventoryTuple{Core: core.Core, Setname: game.Setname, RBF: "jt" + core.Core})
		}
	}
	excluded, err := sourceExclusions(source, tuples)
	if err != nil {
		return err
	}
	reasons := []string{}
	for _, tuple := range tuples {
		if reason := excluded[tupleKey(tuple)]; reason != "" {
			reasons = append(reasons, tuple.Core+"/"+tuple.Setname+": "+reason)
		}
	}
	if len(reasons) > 0 {
		return fmt.Errorf("manifest contains games excluded from regression: %s; regenerate the inventory with --nodbg; historical capture and resume state must remain unchanged", strings.Join(reasons, "; "))
	}
	return nil
}
