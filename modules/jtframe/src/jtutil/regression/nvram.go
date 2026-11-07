/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"encoding/xml"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type gameUploadFile struct{ local, remote, role string }

// Firmware loads ROM relative to the ARC but RAM exclusively from SD root.
func (h *FTPHardware) gameUploadFiles(game GameSpec) []gameUploadFile {
	files := []gameUploadFile{{game.ARC, h.core_dir + "/" + filepath.Base(game.ARC), "arc"}}
	for _, path := range game.ROMs {
		name, role := filepath.Base(path), "rom"
		remote := h.core_dir + "/" + name
		if strings.EqualFold(filepath.Ext(path), ".RAM") {
			remote = "/" + strings.ToUpper(name)
			role = "nvram"
		}
		files = append(files, gameUploadFile{path, remote, role})
	}
	return files
}

func ownedUploadFile(name string) bool { return ownedLoadFile(name) || ownedRootRAM(name) }

// Root RAM paths are admitted only as single safe filenames; each upload is
// recorded in the persistent cleanup ledger before the transfer starts.
func ownedRootRAM(name string) bool {
	base := strings.TrimPrefix(name, "/")
	if strings.Count(name, "/") != 1 || !strings.HasPrefix(name, "/") || !strings.EqualFold(filepath.Ext(base), ".RAM") || !safeComponent(base) {
		return false
	}
	stem := strings.TrimSuffix(base, filepath.Ext(base))
	if stem == "" {
		return false
	}
	for _, c := range stem {
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') {
			return false
		}
	}
	return true
}

// generatedNVRAM includes only defaults declared by this exact game's MRA.
// An <nvram> element alone enables saving but need not provide initial bytes.
func generatedNVRAM(source, mraPath, set string) (string, error) {
	data, err := os.ReadFile(mraPath)
	if err != nil {
		return "", err
	}
	var m mraInventory
	if err = xml.Unmarshal(data, &m); err != nil {
		return "", err
	}
	for _, rom := range m.ROM {
		if rom.Index != "2" || len(rom.AllParts()) == 0 {
			continue
		}
		path := filepath.Join(source, "rom", strings.ToUpper(set)+".RAM")
		if !regularNonempty(path) {
			return "", fmt.Errorf("MRA declares NVRAM defaults but jtframe did not generate nonempty %s", path)
		}
		return path, nil
	}
	return "", nil
}
