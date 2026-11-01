/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"archive/zip"
	"bytes"
	"context"
	"fmt"
	"hash/crc32"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"jotego/jtframe/mra"
)

func mame_nvram_fixture(t *testing.T, machine, probe string) (string, string, string) {
	t.Helper()
	root := t.TempDir()
	workspace := filepath.Join(root, "work")
	core := filepath.Join(root, "cores", "test", "cfg")
	if err := os.MkdirAll(core, 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(workspace, 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(core, "mame2mra.toml"), []byte("[ROM]\nnvram = { defaults=[] }\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(root, "release", "mra"), 0750); err != nil {
		t.Fatal(err)
	}
	fake := filepath.Join(root, "mame")
	roms := filepath.Join(root, "roms")
	if err := os.MkdirAll(roms, 0750); err != nil {
		t.Fatal(err)
	}
	body := fmt.Sprintf("#!/bin/sh\nif [ \"$1\" = \"-listxml\" ]; then\n  printf '%%s\\n' '<mame><machine name=\"game\" cloneof=\"parent\"><rom name=\"seed.bin\" size=\"4\" crc=\"%08x\" region=\"nvram\"/></machine></mame>'\n  exit 0\nfi\n", crc32.ChecksumIEEE([]byte{1, 2, 3, 4}))
	body += probe
	if err := os.WriteFile(fake, []byte(body), 0700); err != nil {
		t.Fatal(err)
	}
	return root, workspace, fake
}

func mame_nvram_probe_script(count int) string {
	return `nvram=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-nvram_directory" ]; then nvram="$2"; shift 2; else shift; fi
done
mkdir -p "$nvram/game"
printf '\001\002\003\004' > "$nvram/game/nvram"
` + func() string {
		if count > 1 {
			return "printf '\001\002\003\004' > \"$nvram/game/other\"\n"
		}
		return ""
	}()
}

func mame_nvram_seed_mra(t *testing.T, root string, data []byte) {
	t.Helper()
	romdir := filepath.Join(root, "rom")
	if err := os.MkdirAll(romdir, 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(romdir, "GAME.RAM"), data, 0600); err != nil {
		t.Fatal(err)
	}
	mra := `<misterromdescription><name>Game</name><setname>game</setname><rom index="2"><part>` + func() string {
		var s strings.Builder
		for i, b := range data {
			if i > 0 {
				s.WriteByte(' ')
			}
			const h = "0123456789abcdef"
			s.WriteByte(h[b>>4])
			s.WriteByte(h[b&15])
		}
		return s.String()
	}() + `</part></rom></misterromdescription>`
	if err := os.WriteFile(filepath.Join(root, "release", "mra", "game.mra"), []byte(mra), 0600); err != nil {
		t.Fatal(err)
	}
}

func TestPrepareMameNVRAMLeavesUnseededDirectoryEmpty(t *testing.T) {
	root, workspace, mame := mame_nvram_fixture(t, "", mame_nvram_probe_script(1))
	err := prepare_mame_nvram(context.Background(), mame, "game", filepath.Join(root, "roms"), workspace, root, "test")
	if err != nil {
		t.Fatal(err)
	}
	entries, err := os.ReadDir(filepath.Join(workspace, "nvram"))
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Fatalf("unconfigured NVRAM was seeded: %v", entries)
	}
}

func TestPrepareMameNVRAMUsesSetNVMBeforeTOML(t *testing.T) {
	root, workspace, mame := mame_nvram_fixture(t, "", mame_nvram_probe_script(1))
	seed := []byte{9, 8, 7, 6}
	mame_nvram_seed_mra(t, root, seed)
	if err := os.WriteFile(filepath.Join(root, "cores", "test", "cfg", "game.nvm"), seed, 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "cores", "test", "cfg", "mame2mra.toml"), []byte("[ROM]\nnvram = { defaults=[{setname=\"game\",data=\"01 02 03 04\"}] }"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := prepare_mame_nvram(context.Background(), mame, "game", filepath.Join(root, "roms"), workspace, root, "test"); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(filepath.Join(workspace, "nvram", "game", "nvram"))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(seed) {
		t.Fatalf("NVRAM seed = %v, want %v", got, seed)
	}
}

func TestPrepareMameNVRAMUsesSelectedTOMLDefault(t *testing.T) {
	root, workspace, mame := mame_nvram_fixture(t, "", mame_nvram_probe_script(1))
	seed := []byte{0x10, 0x20, 0x30, 0x40}
	toml := "[ROM]\nnvram = { defaults=[{machine=\"parent\",data=\"ff ff ff ff\"},{setname=\"game\",data=\"10 20 30 40\"}] }"
	if err := os.WriteFile(filepath.Join(root, "cores", "test", "cfg", "mame2mra.toml"), []byte(toml), 0600); err != nil {
		t.Fatal(err)
	}
	if err := prepare_mame_nvram(context.Background(), mame, "game", filepath.Join(root, "roms"), workspace, root, "test"); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(filepath.Join(workspace, "nvram", "game", "nvram"))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(seed) {
		t.Fatalf("NVRAM seed = %v, want selected TOML bytes %v", got, seed)
	}
}

func TestPrepareMameNVRAMUsesCloneNVMFallback(t *testing.T) {
	root, workspace, mame := mame_nvram_fixture(t, "", mame_nvram_probe_script(1))
	seed := []byte{5, 6, 7, 8}
	if err := os.WriteFile(filepath.Join(root, "cores", "test", "cfg", "parent.nvm"), seed, 0600); err != nil {
		t.Fatal(err)
	}
	if err := prepare_mame_nvram(context.Background(), mame, "game", filepath.Join(root, "roms"), workspace, root, "test"); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(filepath.Join(workspace, "nvram", "game", "nvram"))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(seed) {
		t.Fatalf("clone NVRAM seed = %v, want %v", got, seed)
	}
}

func TestPrepareMameNVRAMUsesMameRegionAfterJTDefaults(t *testing.T) {
	root, workspace, mame := mame_nvram_fixture(t, "", mame_nvram_probe_script(1))
	if err := os.WriteFile(filepath.Join(root, "cores", "test", "cfg", "mame2mra.toml"), []byte("[ROM]\nregions=[{name=\"nvram\"}]\n"), 0600); err != nil {
		t.Fatal(err)
	}
	seed := []byte{1, 2, 3, 4}
	archive, err := os.Create(filepath.Join(root, "roms", "game.zip"))
	if err != nil {
		t.Fatal(err)
	}
	z := zip.NewWriter(archive)
	f, err := z.Create("seed.bin")
	if err != nil {
		t.Fatal(err)
	}
	if _, err = f.Write(seed); err != nil {
		t.Fatal(err)
	}
	if err = z.Close(); err != nil {
		t.Fatal(err)
	}
	if err = archive.Close(); err != nil {
		t.Fatal(err)
	}
	crc := crc32.ChecksumIEEE(seed)
	mra := fmt.Sprintf(`<misterromdescription><name>Game</name><setname>game</setname><rom index="2" zip="game.zip"><part name="seed.bin" crc="%08x"/></rom></misterromdescription>`, crc)
	if err = os.WriteFile(filepath.Join(root, "release", "mra", "game.mra"), []byte(mra), 0600); err != nil {
		t.Fatal(err)
	}
	if err = prepare_mame_nvram(context.Background(), mame, "game", filepath.Join(root, "roms"), workspace, root, "test"); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(filepath.Join(workspace, "nvram", "game", "nvram"))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(seed) {
		t.Fatalf("MAME region seed = %v, want %v", got, seed)
	}
}

func TestPrepareMameNVRAMRejectsUnresolvedDefaultsAndAmbiguousDevices(t *testing.T) {
	t.Run("MRA bytes resolved directly from config", func(t *testing.T) {
		root, workspace, mame := mame_nvram_fixture(t, "", mame_nvram_probe_script(1))
		seed := []byte{1, 2, 3, 4}
		if err := os.WriteFile(filepath.Join(root, "cores", "test", "cfg", "mame2mra.toml"), []byte("[ROM]\nnvram = { defaults=[{setname=\"game\",data=\"01 02 03 04\"}] }"), 0600); err != nil {
			t.Fatal(err)
		}
		err := prepare_mame_nvram(context.Background(), mame, "game", filepath.Join(root, "roms"), workspace, root, "test")
		if err != nil {
			t.Fatal(err)
		}
		got, err := os.ReadFile(filepath.Join(workspace, "nvram", "game", "nvram"))
		if err != nil || string(got) != string(seed) {
			t.Fatalf("config seed = %v, %v; want %v", got, err, seed)
		}
	})
	t.Run("ambiguous equal-sized devices", func(t *testing.T) {
		root, workspace, mame := mame_nvram_fixture(t, "", mame_nvram_probe_script(2))
		seed := []byte{1, 2, 3, 4}
		mame_nvram_seed_mra(t, root, seed)
		if err := os.WriteFile(filepath.Join(root, "cores", "test", "cfg", "game.nvm"), seed, 0600); err != nil {
			t.Fatal(err)
		}
		err := prepare_mame_nvram(context.Background(), mame, "game", filepath.Join(root, "roms"), workspace, root, "test")
		if err == nil || !strings.Contains(err.Error(), "cannot uniquely map") {
			t.Fatalf("expected ambiguous mapping error, got %v", err)
		}
	})
}

func TestSimsonSimpsonsNVRAMUsesOnlyMapped128OfVerified144Bytes(t *testing.T) {
	source := t.TempDir()
	write_simpson_memmap(t, source, 7, 0)
	seed := make([]byte, 144)
	for i := range seed {
		seed[i] = byte(i)
	}
	machine := mra.MachineXML{Name: "simpsons", Rom: []mra.MameROM{{Region: "eeprom", Size: 128}}}
	files := []mame_nvram_file{{path: "simpsons/eeprom", data: make([]byte, 128)}}
	got, path, err := mame_nvram_seed_target(source, "simson", "simpsons", machine, seed, files)
	if err != nil {
		t.Fatal(err)
	}
	if path != "simpsons/eeprom" || !bytes.Equal(got, seed[:128]) {
		t.Fatalf("seed target = %s/%d bytes; expected simpsons/eeprom with the 128 FPGA-addressable bytes", path, len(got))
	}
}

func TestNVRAMMappingRejectsOtherOrMismatchedFormats(t *testing.T) {
	seed := make([]byte, 144)
	machine := mra.MachineXML{Name: "simpsons", Rom: []mra.MameROM{{Region: "eeprom", Size: 128}}}
	device := []mame_nvram_file{{path: "simpsons/eeprom", data: make([]byte, 128)}}
	for _, tc := range []struct {
		name, core, set string
		addr_width      int
		ioctl_order     int
		machine         mra.MachineXML
		seed            []byte
		files           []mame_nvram_file
	}{
		{"other core", "other", "simpsons", 7, 0, machine, seed, device},
		{"wrong seed size", "simson", "simpsons", 7, 0, machine, seed[:128], device},
		{"wrong FPGA address width", "simson", "simpsons", 8, 0, machine, seed, device},
		{"wrong IOCTL restore order", "simson", "simpsons", 7, 1, machine, seed, device},
		{"wrong MAME capacity", "simson", "simpsons", 7, 0, mra.MachineXML{Name: "simpsons", Rom: []mra.MameROM{{Region: "eeprom", Size: 144}}}, seed, device},
		{"wrong MAME path", "simson", "simpsons", 7, 0, machine, seed, []mame_nvram_file{{path: "simpsons/nvram", data: make([]byte, 128)}}},
		{"wrong MAME size", "simson", "simpsons", 7, 0, machine, seed, []mame_nvram_file{{path: "simpsons/eeprom", data: make([]byte, 144)}}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			source := t.TempDir()
			write_simpson_memmap(t, source, tc.addr_width, tc.ioctl_order)
			if _, _, err := mame_nvram_seed_target(source, tc.core, tc.set, tc.machine, tc.seed, tc.files); err == nil {
				t.Fatal("unsupported NVRAM mapping was accepted")
			}
		})
	}
}

func write_simpson_memmap(t *testing.T, source string, addr_width, ioctl_order int) {
	t.Helper()
	cfg := filepath.Join(source, "cores", "simson", "cfg")
	if err := os.MkdirAll(cfg, 0700); err != nil {
		t.Fatal(err)
	}
	data := fmt.Sprintf("bram:\n  - name: nvram\n    addr_width: %d\n    data_width: 8\n    ioctl: { save: true, restore: true, order: %d }\n", addr_width, ioctl_order)
	if err := os.WriteFile(filepath.Join(cfg, "mem.yaml"), []byte(data), 0600); err != nil {
		t.Fatal(err)
	}
}
