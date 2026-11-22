/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestNativeVideoInventoryOmitsInterlacedVariants(t *testing.T) {
	root := t.TempDir()
	native := `<misterromdescription><name>Native</name><setname>game</setname><rbf>jtfake</rbf><rom index="0"><part>AA</part></rom><rom index="1"><part>00 B5 03</part></rom></misterromdescription>`
	variant := strings.Replace(native, "00 B5 03", "00 B5 07", 1)
	// Deliberately misleading names: mode bytes must drive classification.
	files := map[string]string{"release/mra/Game (15kHz).mra": native, "release/mra/Game.mra": variant, "release/sidi128/jtfake.rbf": "rbf"}
	archive := filepath.Join(root, "build.zip")
	writeZip(t, archive, files)
	paths, tuples, err := readArtifactMainMRAs(archive, filepath.Join(root, "inventory"))
	if err != nil || len(paths) != 1 || len(tuples) != 1 || tuples[0].Setname != "game" { t.Fatalf("automatic inventory: %v %v %v", paths, tuples, err) }
	if readString(t, paths[0]) != native { t.Fatal("automatic inventory selected interlaced mode") }
	mra_root := filepath.Join(root, "mra")
	manualWrite(t, filepath.Join(mra_root, "Game.mra"), []byte(variant))
	native_path := filepath.Join(mra_root, "Game (15kHz).mra")
	manualWrite(t, native_path, []byte(native))
	if _, ok := readTuple(filepath.Join(mra_root, "Game.mra")); ok { t.Fatal("generated inventory included interlaced mode") }
	if tuple, ok := readTuple(native_path); !ok || tuple.Setname != "game" { t.Fatal("generated inventory lost native mode") }
	for _, set := range []string{"", "game"} {
		paths, err = manualMRAs(mra_root, "fake", set)
		if err != nil || len(paths) != 1 || paths[0] != native_path { t.Fatalf("local/JTBIN inventory set=%q: %v %v", set, paths, err) }
		digest, err := fileSHA256(archive); if err != nil { t.Fatal(err) }
		var sets []string
		if set != "" { sets = []string{set} }
		selected, err := ExtractManualArchive(context.Background(), ManualArchive{Path: archive, SHA256: digest}, t.TempDir(), []string{"fake"}, sets)
		if err != nil || len(selected.Games) != 1 { t.Fatalf("archive inventory set=%q: %+v %v", set, selected.Games, err) }
		paths, err = manualMRAs(filepath.Join(selected.ReleaseRoot, "mra"), "fake", set)
		if err != nil || len(paths) != 1 || readString(t, paths[0]) != native { t.Fatalf("archive selected interlaced mode: %v %v", paths, err) }
	}
}

func TestNativeVideoInventoryStillRejectsDuplicateNativeTuples(t *testing.T) {
	for _, conflicting := range []bool{false, true} {
		root := t.TempDir()
		first := string(manualMRA("game", "fake"))
		second := first
		if conflicting { second = strings.Replace(first, "<setname>", "<name>Different</name><setname>", 1) }
		archive := filepath.Join(root, "build.zip")
		writeZip(t, archive, map[string]string{"release/mra/One.mra": first, "release/mra/Two.mra": second, "release/sidi128/jtfake.rbf": "rbf"})
		if _, _, err := readArtifactMainMRAs(archive, filepath.Join(root, "inventory")); err == nil || !strings.Contains(err.Error(), "duplicate artifact") { t.Fatalf("duplicate accepted: %v", err) }
		mra_root := filepath.Join(root, "mra")
		manualWrite(t, filepath.Join(mra_root, "One.mra"), []byte(first))
		manualWrite(t, filepath.Join(mra_root, "Two.mra"), []byte(second))
		if _, err := manualMRAs(mra_root, "fake", ""); err == nil || !strings.Contains(err.Error(), "ambiguous MRA") { t.Fatalf("manual duplicate accepted: %v", err) }
		digest, err := fileSHA256(archive); if err != nil { t.Fatal(err) }
		if _, err = ExtractManualArchive(context.Background(), ManualArchive{Path: archive, SHA256: digest}, t.TempDir(), []string{"fake"}, nil); err == nil || !strings.Contains(err.Error(), "duplicate selected archive") { t.Fatalf("archive duplicate accepted: %v", err) }
	}
}

func TestNativeVideoModeDoesNotTreatOtherModeBitsAsInterlaced(t *testing.T) {
	for _, mode := range []string{"00 B5", "00 B5 01", "00 B5 02", "00 B5 08"} {
		path := filepath.Join(t.TempDir(), "Game.mra")
		data := strings.Replace(string(manualMRA("game", "fake")), "</misterromdescription>", `<rom index="1"><part>`+mode+`</part></rom></misterromdescription>`, 1)
		if err := os.WriteFile(path, []byte(data), 0600); err != nil { t.Fatal(err) }
		if _, ok := readTuple(path); !ok { t.Fatalf("native mode %q excluded", mode) }
	}
}
