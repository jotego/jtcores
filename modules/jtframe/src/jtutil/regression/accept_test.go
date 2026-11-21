/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAcceptPromotesSetnamesAndCores(t *testing.T) {
	root := t.TempDir()
	write := func(path string) {
		if e := os.MkdirAll(filepath.Dir(path), 0750); e != nil { t.Fatal(e) }
		if e := os.WriteFile(path, []byte(path), 0640); e != nil { t.Fatal(e) }
	}
	write(filepath.Join(root, "log", "lock"))
	write(filepath.Join(root, "cps1", "ffight", "new", "frame_00000100.png"))
	write(filepath.Join(root, "cps1", "sf2", "ref", "frame_00000100.png"))
	write(filepath.Join(root, "cps1", "sf2", "fail", "frame_00000200.png"))
	write(filepath.Join(root, "cps1", "sf2", "fail", "MiSTer.log"))
	write(filepath.Join(root, "1942", "vulgus", "new", "frame_00000100.png"))
	if e := Accept(root, []string{"cps1", "vulgus"}, io.Discard); e != nil { t.Fatal(e) }
	for _, path := range []string{"cps1/ffight/ref/frame_00000100.png", "cps1/sf2/ref/frame_00000200.png", "1942/vulgus/ref/frame_00000100.png"} {
		if _, e := os.Stat(filepath.Join(root, path)); e != nil { t.Error(e) }
	}
	for _, path := range []string{"cps1/sf2/ref/frame_00000100.png", "cps1/sf2/ref/MiSTer.log", "cps1/sf2/fail", "cps1/ffight/new", "cps1/sf2/ref.old"} {
		if _, e := os.Stat(filepath.Join(root, path)); e == nil { t.Errorf("%s is still there", path) }
	}
	if log, _ := os.ReadFile(filepath.Join(root, "cps1", "sf2", "log")); !strings.Contains(string(log), " manual        ACCEPT      ") {
		t.Errorf("sf2 log is %q", log)
	}
	if e := Accept(root, []string{"vulgus"}, io.Discard); e == nil { t.Error("accepting a game with nothing pending did not fail") }
	if e := Accept(root, []string{"../x"}, io.Discard); e == nil { t.Error("a path was accepted as a name") }
	if e := Unaccept(root, []string{"vulgus"}, io.Discard); e != nil { t.Fatal(e) }
	if _, e := os.Stat(filepath.Join(root, "1942", "vulgus", "new", "frame_00000100.png")); e != nil { t.Error(e) }
	if _, e := os.Stat(filepath.Join(root, "1942", "vulgus", "ref")); e == nil { t.Error("vulgus ref is still there") }
	if log, _ := os.ReadFile(filepath.Join(root, "1942", "vulgus", "log")); !strings.HasSuffix(string(log), " manual        UNACCEPT    --------\n") {
		t.Errorf("vulgus log is %q", log)
	}
	if e := Unaccept(root, []string{"vulgus"}, io.Discard); e == nil { t.Error("a game without ref was taken back") }
	write(filepath.Join(root, "cps1", "sf2", "new", "frame_00000300.png"))
	if e := Unaccept(root, []string{"sf2"}, io.Discard); e == nil { t.Error("ref replaced pending new frames") }
}
