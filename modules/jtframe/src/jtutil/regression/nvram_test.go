/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"os"
	"path/filepath"
	"testing"
)

func TestGeneratedNVRAMRequiresDeclaredDefaults(t *testing.T) {
	root := t.TempDir()
	os.MkdirAll(filepath.Join(root, "rom"), 0750)
	mra := filepath.Join(root, "game.mra")
	write := func(body string) {
		t.Helper()
		if err := os.WriteFile(mra, []byte("<misterromdescription>"+body+"</misterromdescription>"), 0600); err != nil {
			t.Fatal(err)
		}
	}
	write(`<nvram index="2" size="2048"/><rom index="2"><part>00 ff</part></rom>`)
	if _, err := generatedNVRAM(root, mra, "game"); err == nil {
		t.Fatal("missing required NVRAM accepted")
	}
	ram := filepath.Join(root, "rom", "GAME.RAM")
	os.WriteFile(ram, []byte{0, 255}, 0600)
	if got, err := generatedNVRAM(root, mra, "game"); err != nil || got != ram {
		t.Fatalf("RAM missing: %q %v", got, err)
	}
	write(`<nvram index="2" size="2048"/>`)
	if got, err := generatedNVRAM(root, mra, "game"); err != nil || got != "" {
		t.Fatalf("stale RAM accepted: %q %v", got, err)
	}
}
func TestRAMUploadUsesFirmwareRootAndCleansIt(t *testing.T) {
	h, root := mock_rbf_hardware(t)
	game := mock_rbf_game(t, root, "game")
	ram := filepath.Join(root, "GAME.RAM")
	if err := os.WriteFile(ram, []byte{1, 2, 3}, 0600); err != nil {
		t.Fatal(err)
	}
	game.ROMs = append(game.ROMs, ram)
	info, err := h.Load(game)
	if err != nil {
		t.Fatal(err)
	}
	if len(info.Transfers) != 4 || info.Transfers[3].Role != "nvram" || info.Transfers[3].Name != "GAME.RAM" {
		t.Fatalf("RAM transfer missing: %+v", info)
	}
	found := false
	for _, remote := range info.RemoteFiles {
		if remote == "/GAME.RAM" {
			found = true
		}
	}
	if !found {
		t.Fatal("RAM not transferred at firmware root")
	}
	calls := mock_curl_calls(t, root)
	found = false
	for _, args := range calls {
		for _, arg := range args {
			if arg == "ftp://board/GAME.RAM" {
				found = true
			}
		}
	}
	if !found {
		t.Fatal("RAM upload URL is not rooted")
	}
	if _, err = os.Stat(filepath.Join(root, "remote", h.core_dir, "game.rom")); err != nil {
		t.Fatal("normal ROM path changed:", err)
	}
	if err = h.Cleanup(info.RemoteFiles); err != nil {
		t.Fatal(err)
	}
	if _, err = os.Stat(filepath.Join(root, "remote", "GAME.RAM")); !os.IsNotExist(err) {
		t.Fatal("root RAM retained")
	}
	for _, path := range []string{"/../GAME.RAM", "/dir/GAME.RAM", "/GAME.ROM", "GAME.RAM"} {
		if ownedRootRAM(path) {
			t.Fatalf("unsafe RAM ownership %q", path)
		}
	}
}
