/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"encoding/binary"
	"hash/crc32"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestReadMameCabRLEVersionsAndCRC(t *testing.T) {
	for _, tc := range []struct {
		name    string
		version uint32
		runs    []MameCabRun
		dumps   uint32
	}{
		{"controls and idle tail", 1, []MameCabRun{{Frames: 2, Inputs: 1}, {Frames: 1, Inputs: 0x104}, {Frames: 3}}, 0},
		{"dipsw", 2, []MameCabRun{{Frames: 2, Inputs: 1, HasDIPSW: true, DIPSW: 0xef77}, {Frames: 4}}, 0},
		{"dump marker", 3, []MameCabRun{{Frames: 1, Dump: true}, {Frames: 5}}, 1},
	} {
		t.Run(tc.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "inputs.jtcab")
			write_mame_cab_fixture(t, path, tc.version, tc.runs, tc.dumps)
			frames := 0
			for _, run := range tc.runs {
				frames += int(run.Frames)
			}
			got, err := ReadMameCab(path, frames)
			if err != nil {
				t.Fatal(err)
			}
			if got.Version != tc.version || len(got.Runs) != len(tc.runs) {
				t.Fatalf("unexpected script: %+v", got)
			}
			for i := range tc.runs {
				if got.Runs[i] != tc.runs[i] {
					t.Fatalf("run %d: got %+v want %+v", i, got.Runs[i], tc.runs[i])
				}
			}
		})
	}
	path := filepath.Join(t.TempDir(), "corrupt.jtcab")
	write_mame_cab_fixture(t, path, 1, []MameCabRun{{Frames: 6}}, 0)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	data[len(data)-1] ^= 0xff
	if err = os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
	if _, err = ReadMameCab(path, 6); err == nil {
		t.Fatal("accepted corrupt CAB CRC")
	}
}

func TestMakeMameCaptureLuaReplaysRLEAndNeutralEOF(t *testing.T) {
	cab := MameCabScript{Frames: 20, Runs: []MameCabRun{{Frames: 10}, {Frames: 4, Inputs: 1}, {Frames: 2, Inputs: 0x104}, {Frames: 4}}}
	lua, err := make_mame_capture_lua(cab, 520, "/tmp/snap", "/tmp/complete", "/tmp/failure")
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		`{ 10, 0 },`, `{ 4, 1 },`, `{ 2, 260 },`,
		`{ bit = 0, token = "COIN1" }`, `{ bit = 8, token = "P1_BUTTON1" }`,
		"apply(0)", "screen:snapshot", "apply(completed)", "frame >= profile_frames then return 0",
		"machine:exit()", "/tmp/failure", "wanted[token] and field.enabled",
	} {
		if !strings.Contains(lua, want) {
			t.Fatalf("generated Lua omits %q", want)
		}
	}
}

func TestMakeMameCaptureLuaRejectsUnmappedCabActions(t *testing.T) {
	for _, cab := range []MameCabScript{
		{Frames: 1, Runs: []MameCabRun{{Frames: 1, Inputs: 1 << 11}}},
		{Frames: 1, Runs: []MameCabRun{{Frames: 1, Inputs: 1 << 12}}},
		{Frames: 1, Runs: []MameCabRun{{Frames: 1, HasDIPSW: true}}},
		{Frames: 1, Runs: []MameCabRun{{Frames: 1, Dump: true}}},
	} {
		if _, err := make_mame_capture_lua(cab, 501, "/tmp/snap", "/tmp/complete", "/tmp/failure"); err == nil {
			t.Fatalf("accepted unsupported CAB script %+v", cab)
		}
	}
}

func TestReadMameCabRejectsBadBudgetAndRecordTotals(t *testing.T) {
	path := filepath.Join(t.TempDir(), "inputs.jtcab")
	write_mame_cab_fixture(t, path, 1, []MameCabRun{{Frames: 4}}, 0)
	if _, err := ReadMameCab(path, 5); err == nil {
		t.Fatal("accepted mismatched profile frame budget")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	binary.LittleEndian.PutUint32(data[32:36], 3)
	if err = os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
	if _, err = ReadMameCab(path, 4); err == nil {
		t.Fatal("accepted CAB records with wrong total frames")
	}
}

func TestResolveMameCandidateUsesOnlySelectedProfileCAB(t *testing.T) {
	source := t.TempDir()
	global := filepath.Join(source, "global.yaml")
	if err := os.WriteFile(global, []byte("video: 900\nstart-up: 100\n"), 0600); err != nil {
		t.Fatal(err)
	}
	core := "taitox"
	set := "ballbros"
	core_dir := filepath.Join(source, "cores", core)
	cab := filepath.Join(core_dir, "ver", set, "reg.cab")
	if err := os.MkdirAll(filepath.Dir(cab), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(cab, []byte("120\n2 coin\n"), 0600); err != nil {
		t.Fatal(err)
	}
	local := filepath.Join(core_dir, "cfg", "reg.yaml")
	if err := os.MkdirAll(filepath.Dir(local), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(local, []byte("ballbros:\n  inputs: reg.cab\n  video: 1200\n"), 0600); err != nil {
		t.Fatal(err)
	}
	candidate := mame_candidate{core: core, set: set}
	if err := resolve_mame_candidate_profile(source, global, &candidate); err != nil {
		t.Fatal(err)
	}
	if candidate.profile.Video != 1200 || candidate.profile.Startup != 100 || candidate.cab_source != cab {
		t.Fatalf("wrong selected profile: %+v", candidate)
	}
	if err := os.WriteFile(local, []byte("ballbros:\n  video: 1200\n"), 0600); err != nil {
		t.Fatal(err)
	}
	candidate = mame_candidate{core: core, set: set}
	if err := resolve_mame_candidate_profile(source, global, &candidate); err != nil {
		t.Fatal(err)
	}
	if candidate.cab_source != "" {
		t.Fatalf("orphan reg.cab was auto-selected: %s", candidate.cab_source)
	}
}

func write_mame_cab_fixture(t *testing.T, path string, version uint32, runs []MameCabRun, dumps uint32) {
	t.Helper()
	stride := 8
	if version > 1 {
		stride = 12
	}
	data := make([]byte, 32+stride*len(runs))
	copy(data[:8], []byte{'J', 'T', 'C', 'A', 'B', '0', byte('0' + version), 0})
	put := func(offset int, value uint32) { binary.LittleEndian.PutUint32(data[offset:offset+4], value) }
	put(8, version)
	var frames uint32
	for i, run := range runs {
		frames += run.Frames
		offset := 32 + i*stride
		encoded := run.Inputs
		if run.HasDIPSW {
			encoded |= 0x00200000
		}
		if run.Dump {
			encoded |= 0x00400000
		}
		put(offset, run.Frames)
		put(offset+4, encoded)
		if version > 1 {
			put(offset+8, run.DIPSW)
		}
	}
	put(12, frames)
	put(16, uint32(len(runs)))
	put(20, dumps)
	put(24, crc32.ChecksumIEEE(data[32:]))
	put(28, 32)
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
}
