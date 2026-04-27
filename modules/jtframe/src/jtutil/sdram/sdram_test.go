package sdram

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"jotego/jtframe/macros"
	"jotego/jtframe/mem"
	"jotego/jtframe/mra"
)

func TestSwapBytes(t *testing.T) {
	rom := []byte{0, 1, 2, 3, 4, 5}
	swapBytes(rom, 0)
	want := []byte{1, 0, 3, 2, 5, 4}
	if !bytes.Equal(rom, want) {
		t.Fatalf("swapBytes start 0 mismatch: got=%v want=%v", rom, want)
	}

	rom = []byte{0, 1, 2, 3, 4, 5}
	swapBytes(rom, 2)
	want = []byte{0, 1, 3, 2, 5, 4}
	if !bytes.Equal(rom, want) {
		t.Fatalf("swapBytes start 2 mismatch: got=%v want=%v", rom, want)
	}
}

func TestDeriveGameFromWD(t *testing.T) {
	wd := t.TempDir()
	gameDir := filepath.Join(wd, "bublbobl")
	mustMkdirAll(t, gameDir)

	restore := chdir(t, gameDir)
	defer restore()

	got, err := deriveGameFromWD()
	if err != nil {
		t.Fatalf("deriveGameFromWD returned error: %v", err)
	}
	if got != "bublbobl" {
		t.Fatalf("deriveGameFromWD mismatch: got=%q", got)
	}
}

func TestDeriveGameFromWDFailsForGenericFolder(t *testing.T) {
	wd := t.TempDir()
	gameDir := filepath.Join(wd, "game")
	mustMkdirAll(t, gameDir)

	restore := chdir(t, gameDir)
	defer restore()

	_, err := deriveGameFromWD()
	if err == nil {
		t.Fatalf("deriveGameFromWD should fail for folder named game")
	}
	if !strings.Contains(err.Error(), "jtutil sdram <game>") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestValidateWD(t *testing.T) {
	root := t.TempDir()
	good := filepath.Join(root, "core", "ver", "mygame")
	bad := filepath.Join(root, "core", "sim", "mygame")
	mustMkdirAll(t, good)
	mustMkdirAll(t, bad)

	restore := chdir(t, good)
	defer restore()

	if err := validateWD(); err != nil {
		t.Fatalf("validateWD should pass in ver/game folder: %v", err)
	}

	restore2 := chdir(t, bad)
	defer restore2()

	err := validateWD()
	if err == nil {
		t.Fatalf("validateWD should fail outside ver/game")
	}
	if !strings.Contains(err.Error(), "ver/game") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestDeriveCoreFromWD(t *testing.T) {
	jtroot := t.TempDir()
	t.Setenv("JTROOT", jtroot)
	mustMkdirAll(t, filepath.Join(jtroot, "cores", "contra"))

	root := t.TempDir()
	wd := filepath.Join(root, "contra", "ver", "g1")
	mustMkdirAll(t, wd)

	restore := chdir(t, wd)
	defer restore()

	got, err := deriveCoreFromWD()
	if err != nil {
		t.Fatalf("deriveCoreFromWD returned error: %v", err)
	}
	if got != "contra" {
		t.Fatalf("deriveCoreFromWD mismatch: got=%q want=%q", got, "contra")
	}
}

func TestDeriveCoreFromWDFailsWhenCoreFolderMissing(t *testing.T) {
	jtroot := t.TempDir()
	t.Setenv("JTROOT", jtroot)
	mustMkdirAll(t, filepath.Join(jtroot, "cores"))

	root := t.TempDir()
	wd := filepath.Join(root, "missingcore", "ver", "g1")
	mustMkdirAll(t, wd)

	restore := chdir(t, wd)
	defer restore()

	_, err := deriveCoreFromWD()
	if err == nil {
		t.Fatalf("deriveCoreFromWD should fail when core folder does not exist")
	}
	if !strings.Contains(err.Error(), "core folder not found") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestDumpWritesAndPads(t *testing.T) {
	dir := t.TempDir()
	restore := chdir(t, dir)
	defer restore()

	rom := []byte{0, 1, 2, 3, 4, 5, 6, 7}
	next, err := dump("sdram_bank0.bin", rom, 2, 6, len(rom), 8)
	if err != nil {
		t.Fatalf("dump returned error: %v", err)
	}
	if next != 6 {
		t.Fatalf("dump next mismatch: got=%d want=%d", next, 6)
	}

	got, err := os.ReadFile("sdram_bank0.bin")
	if err != nil {
		t.Fatalf("failed reading output file: %v", err)
	}
	want := []byte{2, 3, 4, 5, 0, 0, 0, 0}
	if !bytes.Equal(got, want) {
		t.Fatalf("dump output mismatch: got=%v want=%v", got, want)
	}
}

func TestDumpUsesLimitWhenEndIsZero(t *testing.T) {
	dir := t.TempDir()
	restore := chdir(t, dir)
	defer restore()

	rom := []byte{10, 11, 12, 13, 14}
	next, err := dump("sdram_bank1.bin", rom, 1, 0, 4, 0)
	if err != nil {
		t.Fatalf("dump returned error: %v", err)
	}
	if next != 4 {
		t.Fatalf("dump next mismatch: got=%d want=%d", next, 4)
	}

	got, err := os.ReadFile("sdram_bank1.bin")
	if err != nil {
		t.Fatalf("failed reading output file: %v", err)
	}
	want := []byte{11, 12, 13}
	if !bytes.Equal(got, want) {
		t.Fatalf("dump output mismatch: got=%v want=%v", got, want)
	}
}

func TestDumpErrorsWhenBoundsAreInvalid(t *testing.T) {
	dir := t.TempDir()
	restore := chdir(t, dir)
	defer restore()

	rom := []byte{0, 1, 2, 3}

	_, err := dump("bad.bin", rom, 3, 2, len(rom), 0)
	if err == nil {
		t.Fatalf("dump should fail when p1 < p0")
	}
	if !strings.Contains(err.Error(), "beyond end") {
		t.Fatalf("unexpected error: %v", err)
	}

	_, err = dump("bad2.bin", rom, 0, 10, len(rom), 0)
	if err == nil {
		t.Fatalf("dump should fail when p1 > len(rom)")
	}
	if !strings.Contains(err.Error(), "ROM file is too short") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestDumpRemovesEmptyRegionFile(t *testing.T) {
	dir := t.TempDir()
	restore := chdir(t, dir)
	defer restore()

	rom := []byte{0, 1, 2, 3}
	if err := os.WriteFile("empty.bin", []byte{1, 2}, 0664); err != nil {
		t.Fatalf("setup failed: %v", err)
	}

	next, err := dump("empty.bin", rom, 2, 2, len(rom), 0)
	if err != nil {
		t.Fatalf("dump returned error: %v", err)
	}
	if next != 2 {
		t.Fatalf("dump next mismatch: got=%d want=%d", next, 2)
	}

	_, err = os.Stat("empty.bin")
	if !os.IsNotExist(err) {
		t.Fatalf("empty.bin should be removed, stat err=%v", err)
	}
}

func TestSdramBankSizeDefaultsTo8MB(t *testing.T) {
	macros.MakeFromMap(map[string]string{})
	got := sdramBankSize()
	want := 8 * 1024 * 1024
	if got != want {
		t.Fatalf("sdramBankSize default mismatch: got=%d want=%d", got, want)
	}
}

func TestSdramBankSizeUsesLargeMacroFallback(t *testing.T) {
	macros.MakeFromMap(map[string]string{
		"JTFRAME_SDRAM_LARGE": "1",
	})
	got := sdramBankSize()
	want := 16 * 1024 * 1024
	if got != want {
		t.Fatalf("sdramBankSize large mismatch: got=%d want=%d", got, want)
	}
}

func TestBankOffsetReadsReversedHeaderEntries(t *testing.T) {
	macros.MakeFromMap(map[string]string{
		"JTFRAME_HEADER": "16",
	})
	rom := make([]byte, 0x250010)
	copy(rom, []byte{
		0x00, 0x00,
		0x40, 0x00, // 0x0040 << 12 = 0x40000
		0x50, 0x01, // 0x0150 << 12 = 0x150000
		0x50, 0x02, // 0x0250 << 12 = 0x250000
	})
	hinfo := mra.HeaderOffset{
		Bits:    12,
		Reverse: true,
		Start:   0,
		Regions: []string{"maincpu", "audiocpu", "k052109", "obj"},
	}

	offsets, regions, err := bankOffset(len(hinfo.Regions), hinfo, rom)
	if err != nil {
		t.Fatalf("bankOffset returned error: %v", err)
	}
	if len(regions) != len(hinfo.Regions) {
		t.Fatalf("region count mismatch: got=%d want=%d", len(regions), len(hinfo.Regions))
	}
	if got, want := offsets[1], 0x40000+16; got != want {
		t.Fatalf("bank 1 offset mismatch: got=%#x want=%#x", got, want)
	}
	if got, want := offsets[2], 0x150000+16; got != want {
		t.Fatalf("bank 2 offset mismatch: got=%#x want=%#x", got, want)
	}
	if got, want := offsets[3], 0x250000+16; got != want {
		t.Fatalf("bank 3 offset mismatch: got=%#x want=%#x", got, want)
	}
}

func TestRemapAddressBitsHvvvx(t *testing.T) {
	macros.MakeFromMap(map[string]string{"JTFRAME_HEADER": "0"})
	gfx, err := parseGfxPattern("hvvvx")
	if err != nil {
		t.Fatalf("parseGfxPattern returned error: %v", err)
	}
	got := make([]int, 16)
	for k := range got {
		got[k] = remapAddressBits(k, gfx)
	}
	want := []int{0, 1, 4, 5, 8, 9, 12, 13, 16, 17, 20, 21, 24, 25, 28, 29}
	if !bytes.Equal(intsToBytes(got), intsToBytes(want)) {
		t.Fatalf("hvvvx mapping mismatch: got=%v want=%v", got, want)
	}
}

func TestApplyGfxSortRangeHvvvx(t *testing.T) {
	macros.MakeFromMap(map[string]string{"JTFRAME_HEADER": "0"})
	rom := make([]byte, 32)
	for k := range rom {
		rom[k] = byte(k)
	}
	err := applyGfxSortRange(rom, 0, len(rom), "hvvvx")
	if err != nil {
		t.Fatalf("applyGfxSortRange returned error: %v", err)
	}
	gfx, err := parseGfxPattern("hvvvx")
	if err != nil {
		t.Fatalf("parseGfxPattern returned error: %v", err)
	}
	for src := 0; src < len(rom); src++ {
		dst := remapAddressBits(src, gfx)
		if rom[dst] != byte(src) {
			t.Fatalf("wrong byte at dst=%d: got=%d want=%d", dst, rom[dst], src)
		}
	}
}

func TestApplyGfxSortRangeHvvvv(t *testing.T) {
	macros.MakeFromMap(map[string]string{"JTFRAME_HEADER": "0"})
	rom := make([]byte, 32)
	for k := range rom {
		rom[k] = byte(k)
	}
	err := applyGfxSortRange(rom, 0, len(rom), "hvvvv")
	if err != nil {
		t.Fatalf("applyGfxSortRange returned error: %v", err)
	}
	gfx, err := parseGfxPattern("hvvvv")
	if err != nil {
		t.Fatalf("parseGfxPattern returned error: %v", err)
	}
	for src := 0; src < len(rom); src++ {
		dst := remapAddressBits(src, gfx)
		if rom[dst] != byte(src) {
			t.Fatalf("wrong byte at dst=%d: got=%d want=%d", dst, rom[dst], src)
		}
	}
}

func TestShouldApplyGfxEn(t *testing.T) {
	if !shouldApplyGfxEn("not_higemaru", "1942") {
		t.Fatalf("not_higemaru should apply for game 1942")
	}
	if shouldApplyGfxEn("not_higemaru", "higemaru") {
		t.Fatalf("not_higemaru should not apply for game higemaru")
	}
	if shouldApplyGfxEn("metrocrs", "rthunder") {
		t.Fatalf("metrocrs should not apply for game rthunder")
	}
	if !shouldApplyGfxEn("metrocrs", "metrocrs") {
		t.Fatalf("metrocrs should apply for game metrocrs")
	}
}

func TestCollectSimFiles(t *testing.T) {
	cfg := &mem.MemConfig{
		Params: []mem.Param{{Name: "TILES", Value: "22'h100"}},
		SDRAM: mem.SDRAMCfg{
			Banks: []mem.SDRAMBank{{
				Buses: []mem.SDRAMBus{{
					Name:       "tiles",
					Offset:     "TILES",
					Addr_width: 4,
					Data_width: 16,
					Simfile:    mem.SDRAMBusSimfile{Name: "tiles.bin", Big_endian: true},
				}},
			}},
			Cache_lanes: []mem.SDRAMCacheLine{{
				Name:       "line",
				Data_width: 32,
				Blocks:     mem.SDRAMCacheCfg{Count: 1, Size: "64B"},
				At:         mem.SDRAMCacheAddr{Bank: 3, Offset: "0x20", Length: "64B"},
				Simfile:    mem.SDRAMCacheSimfile{Name: "line.bin", Big_endian: true},
			}},
		},
	}
	all, err := collectSimFiles(cfg)
	if err != nil {
		t.Fatalf("collectSimFiles returned error: %v", err)
	}
	if len(all) != 2 {
		t.Fatalf("collectSimFiles length mismatch: got=%d want=2", len(all))
	}
	if all[0].offset != 0x200 || all[0].length != 16 || !all[0].big_endian {
		t.Fatalf("unexpected bus sim entry: %+v", all[0])
	}
	if all[1].bank != 3 || all[1].offset != 0x40 || all[1].length != 64 || !all[1].big_endian {
		t.Fatalf("unexpected cache-lane sim entry: %+v", all[1])
	}
}

func TestCollectSimFilesRejects8BitBigEndian(t *testing.T) {
	cfg := &mem.MemConfig{
		SDRAM: mem.SDRAMCfg{
			Banks: []mem.SDRAMBank{{
				Buses: []mem.SDRAMBus{{
					Name:       "tiles",
					Addr_width: 4,
					Data_width: 8,
					Simfile:    mem.SDRAMBusSimfile{Name: "tiles.bin", Big_endian: true},
				}},
			}},
		},
	}
	_, err := collectSimFiles(cfg)
	if err == nil {
		t.Fatalf("collectSimFiles should reject 8-bit big-endian simfiles")
	}
}

func TestCollectSimFilesUsesExplicitWideCacheLaneSimDataType(t *testing.T) {
	cfg := &mem.MemConfig{
		SDRAM: mem.SDRAMCfg{
			Cache_lanes: []mem.SDRAMCacheLine{{
				Name:       "tiles",
				Data_width: 128,
				Blocks:     mem.SDRAMCacheCfg{Count: 1, Size: "64B"},
				At:         mem.SDRAMCacheAddr{Bank: 3, Offset: "0x20", Length: "64B"},
				Simfile:    mem.SDRAMCacheSimfile{Name: "tiles.bin", Big_endian: true, Data_type: "u32"},
			}},
		},
	}
	all, err := collectSimFiles(cfg)
	if err != nil {
		t.Fatalf("collectSimFiles returned error: %v", err)
	}
	if len(all) != 1 {
		t.Fatalf("collectSimFiles length mismatch: got=%d want=1", len(all))
	}
	if all[0].data_width != 32 {
		t.Fatalf("wrong resolved simfile data width: got=%d want=32", all[0].data_width)
	}
}

func TestCollectSimFilesRejectsWideBigEndianWithoutDataType(t *testing.T) {
	cfg := &mem.MemConfig{
		SDRAM: mem.SDRAMCfg{
			Cache_lanes: []mem.SDRAMCacheLine{{
				Name:       "tiles",
				Data_width: 128,
				Blocks:     mem.SDRAMCacheCfg{Count: 1, Size: "64B"},
				At:         mem.SDRAMCacheAddr{Bank: 3, Offset: "0x20", Length: "64B"},
				Simfile:    mem.SDRAMCacheSimfile{Name: "tiles.bin", Big_endian: true},
			}},
		},
	}
	_, err := collectSimFiles(cfg)
	if err == nil {
		t.Fatalf("collectSimFiles should reject wide big-endian simfiles without data_type")
	}
	if !strings.Contains(err.Error(), "simfile.data_type") {
		t.Fatalf("wrong error for missing data_type: %v", err)
	}
}

func TestApplySimFileCreatesAndPatchesBank(t *testing.T) {
	dir := t.TempDir()
	restore := chdir(t, dir)
	defer restore()

	if err := os.WriteFile("tiles.bin", []byte{0, 1, 2, 3}, 0664); err != nil {
		t.Fatalf("setup failed: %v", err)
	}
	entry := sim_file_entry{
		kind:       "bus",
		name:       "tiles",
		path:       "tiles.bin",
		bank:       2,
		offset:     2,
		length:     4,
		data_width: 16,
		big_endian: true,
	}
	if err := applySimFile(entry); err != nil {
		t.Fatalf("applySimFile returned error: %v", err)
	}
	got, err := os.ReadFile("sdram_bank2.bin")
	if err != nil {
		t.Fatalf("failed reading output bank: %v", err)
	}
	if len(got) != sdramBankSize() {
		t.Fatalf("bank size mismatch: got=%d want=%d", len(got), sdramBankSize())
	}
	want := []byte{0, 0, 1, 0, 3, 2}
	if !bytes.Equal(got[:6], want) {
		t.Fatalf("patched bank mismatch: got=%v want=%v", got[:6], want)
	}
}

func TestApplySimFileRejectsWrongSize(t *testing.T) {
	dir := t.TempDir()
	restore := chdir(t, dir)
	defer restore()

	if err := os.WriteFile("tiles.bin", []byte{0, 1, 2}, 0664); err != nil {
		t.Fatalf("setup failed: %v", err)
	}
	entry := sim_file_entry{
		kind:       "bus",
		name:       "tiles",
		path:       "tiles.bin",
		bank:       0,
		offset:     0,
		length:     4,
		data_width: 16,
	}
	err := applySimFile(entry)
	if err == nil {
		t.Fatalf("applySimFile should reject wrong-sized simfiles")
	}
	if !strings.Contains(err.Error(), "must be 4 bytes") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func intsToBytes(ref []int) []byte {
	aux := make([]byte, len(ref))
	for k := range ref {
		aux[k] = byte(ref[k])
	}
	return aux
}

func mustMkdirAll(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(path, 0775); err != nil {
		t.Fatalf("mkdir failed for %s: %v", path, err)
	}
}

func chdir(t *testing.T, dir string) func() {
	t.Helper()
	old, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd failed: %v", err)
	}
	if err = os.Chdir(dir); err != nil {
		t.Fatalf("chdir to %s failed: %v", dir, err)
	}
	return func() {
		if e := os.Chdir(old); e != nil {
			t.Fatalf("restore chdir failed: %v", e)
		}
	}
}
