/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// Content and input roles identify a game independently of disposable checkout
// and preparation directories. Names still matter for the board's ROM slots.
func portable_fingerprint(cfg Config, commit, core string, game GameSpec) (string, error) {
	files := map[string]string{}
	add := func(role, path string) (string, error) {
		if path == "" {
			return "", nil
		}
		name := role + "/" + filepath.Base(path)
		if _, err := os.Stat(path); err == nil {
			files[name] = path
		} else if !os.IsNotExist(err) {
			return "", err
		}
		return name, nil
	}
	var err error
	if game.ARC, err = add("arc", game.ARC); err != nil {
		return "", err
	}
	if game.RBF, err = add("rbf", game.RBF); err != nil {
		return "", err
	}
	if game.CAB, err = add("cab", game.CAB); err != nil {
		return "", err
	}
	source_cab, err := add("source-cab", game.SourceCAB)
	if err != nil {
		return "", err
	}
	game.ROMs = append([]string(nil), game.ROMs...)
	for i, path := range game.ROMs {
		game.ROMs[i], err = add(fmt.Sprintf("rom-%d", i), path)
		if err != nil {
			return "", err
		}
	}
	if _, err = add("global-profile", cfg.GlobalProfile); err != nil {
		return "", err
	}
	if _, err = add("core-profile", filepath.Join(cfg.Source, "cores", core, "cfg", "reg.yaml")); err != nil {
		return "", err
	}
	hash, err := HashFiles(files)
	if err != nil {
		return "", err
	}
	payload, err := json.Marshal(struct {
		Commit, Core, Firmware, FirmwareSHA, CaptureToolSHA, Files, SourceCAB string
		Game                                                                  GameSpec
	}{commit, core, cfg.Firmware, cfg.FirmwareSHA256, cfg.CaptureToolSHA256, hash, source_cab, game})
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(payload)
	return "v2:" + hex.EncodeToString(digest[:]), nil
}
