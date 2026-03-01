package sdram

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"jotego/jtframe/macros"
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
