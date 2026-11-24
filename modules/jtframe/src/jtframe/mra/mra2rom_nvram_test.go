/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package mra

import (
	"bytes"
	"jotego/jtframe/xmlnode"
	"os"
	"path/filepath"
	"testing"
)

func TestMra2romSavesROMAndNVRAMDefaults(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("JTROOT", dir)
	root := xmlnode.MakeNode("misterromdescription")
	root.AddNode("setname", "defaults")
	root.AddNode("rom").AddAttr("index", "0").AddNode("part", "01 02 03")
	root.AddNode("rom").AddAttr("index", "2").AddNode("part", "ab cd")
	if e := Mra2rom(&root, true, t.TempDir()); e != nil {
		t.Fatal(e)
	}
	for name, want := range map[string][]byte{"defaults.rom": {1, 2, 3}, "DEFAULTS.RAM": {0xab, 0xcd}} {
		got, e := os.ReadFile(filepath.Join(dir, "rom", name))
		if e != nil || !bytes.Equal(got, want) {
			t.Fatalf("%s got% x err%v", name, got, e)
		}
	}
}
