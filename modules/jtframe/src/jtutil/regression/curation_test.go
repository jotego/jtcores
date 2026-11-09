/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func curation_png(t *testing.T, dir string, n int, pixel color.RGBA) {
	t.Helper()
	if err := os.MkdirAll(dir, 0750); err != nil {
		t.Fatal(err)
	}
	frame := image.NewRGBA(image.Rect(0, 0, 2, 2))
	for y := 0; y < 2; y++ {
		for x := 0; x < 2; x++ {
			frame.SetRGBA(x, y, pixel)
		}
	}
	file, err := os.Create(filepath.Join(dir, fmt.Sprintf("frame_%08d.png", n)))
	if err != nil {
		t.Fatal(err)
	}
	if err = png.Encode(file, frame); err != nil {
		t.Fatal(err)
	}
	if err = file.Close(); err != nil {
		t.Fatal(err)
	}
}

func TestAcceptResultQualityAndPromotion(t *testing.T) {
	root := t.TempDir()
	game := filepath.Join(root, "core", "game")
	ref := filepath.Join(game, "ref")
	curation_png(t, ref, 1, color.RGBA{R: 255, A: 255})
	newDir := filepath.Join(game, "new")
	curation_png(t, newDir, 1, color.RGBA{R: 255, A: 255})
	curation_png(t, newDir, 2, color.RGBA{G: 255, A: 255})
	curation_png(t, newDir, 3, color.RGBA{B: 255, A: 255})
	if err := AcceptResult(root, "game"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(game, "new")); !os.IsNotExist(err) {
		t.Fatalf("new slot remains: %v", err)
	}
	if _, err := os.Stat(filepath.Join(ref, "frame_00000003.png")); err != nil {
		t.Fatalf("new reference missing: %v", err)
	}
	log, err := os.ReadFile(filepath.Join(game, "log"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(log), "ACCEPT") {
		t.Fatalf("accept event missing: %s", log)
	}
}

func TestAcceptResultRejectsQualityAndAmbiguousSlots(t *testing.T) {
	for _, test := range []struct {
		name   string
		colors []color.RGBA
		code   int
	}{
		{"empty", nil, 2},
		{"black", []color.RGBA{{A: 255}, {A: 255}}, 4},
		{"majority", []color.RGBA{{R: 1, A: 255}, {R: 1, A: 255}, {G: 1, A: 255}}, 5},
	} {
		t.Run(test.name, func(t *testing.T) {
			root := t.TempDir()
			slot := filepath.Join(root, "core", "game", "new")
			if err := os.MkdirAll(slot, 0750); err != nil {
				t.Fatal(err)
			}
			for i, pixel := range test.colors {
				curation_png(t, slot, i+1, pixel)
			}
			err := AcceptResult(root, "game")
			coded, ok := err.(*CurationError)
			if !ok || coded.Code != test.code {
				t.Fatalf("wanted curation exit %d, got %v", test.code, err)
			}
		})
	}
	root := t.TempDir()
	for _, core := range []string{"core1", "core2"} {
		if err := os.MkdirAll(filepath.Join(root, core, "same", "new"), 0750); err != nil {
			t.Fatal(err)
		}
	}
	if err := AcceptResult(root, "same"); err == nil {
		t.Fatal("ambiguous setname accepted")
	}
}

func TestAcceptResultAllowsExactlyHalfDuplicateFrames(t *testing.T) {
	root := t.TempDir()
	slot := filepath.Join(root, "core", "game", "new")
	curation_png(t, slot, 1, color.RGBA{R: 1, A: 255})
	curation_png(t, slot, 2, color.RGBA{R: 1, A: 255})
	curation_png(t, slot, 3, color.RGBA{G: 1, A: 255})
	curation_png(t, slot, 4, color.RGBA{B: 1, A: 255})
	if err := AcceptResult(root, "game"); err != nil {
		t.Fatalf("exactly half identical should pass: %v", err)
	}
}

func TestAcceptCoreResultsAndValidateAllCoreSelectionsFirst(t *testing.T) {
	root := t.TempDir()
	for _, core := range []string{"core1", "core2"} {
		slot := filepath.Join(root, core, "same", "new")
		curation_png(t, slot, 1, color.RGBA{R: 1, A: 255})
		curation_png(t, slot, 2, color.RGBA{G: 1, A: 255})
	}
	if err := AcceptCoreResults(root, []string{"core1", "missing"}); err == nil {
		t.Fatal("missing selected core was accepted")
	}
	for _, core := range []string{"core1", "core2"} {
		if _, err := os.Stat(filepath.Join(root, core, "same", "new")); err != nil {
			t.Fatalf("selection validation partially accepted %s: %v", core, err)
		}
	}
	if err := AcceptCoreResults(root, []string{"core1", "core2"}); err != nil {
		t.Fatal(err)
	}
	for _, core := range []string{"core1", "core2"} {
		game := filepath.Join(root, core, "same")
		if _, err := os.Stat(filepath.Join(game, "new")); !os.IsNotExist(err) {
			t.Fatalf("%s new slot remains: %v", core, err)
		}
		if _, err := os.Stat(filepath.Join(game, "ref")); err != nil {
			t.Fatalf("%s reference missing: %v", core, err)
		}
	}
}

func TestRejectResultAndStatus(t *testing.T) {
	root := t.TempDir()
	game := filepath.Join(root, "core", "game")
	for _, slot := range []string{"new", "fail"} {
		if err := os.MkdirAll(filepath.Join(game, slot), 0750); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(game, "log"), []byte("2026-11-07 12:00:00 build FAIL --------\n"), 0640); err != nil {
		t.Fatal(err)
	}
	if err := RejectResult(root, "game", "wrong rotation"); err != nil {
		t.Fatal(err)
	}
	for _, slot := range []string{"new", "fail"} {
		if _, err := os.Stat(filepath.Join(game, slot)); !os.IsNotExist(err) {
			t.Fatalf("%s remains: %v", slot, err)
		}
	}
	log, err := os.ReadFile(filepath.Join(game, "log"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(log), "REJECT") || !strings.Contains(string(log), "wrong rotation") {
		t.Fatalf("rejection event missing: %s", log)
	}
	status, err := ReadCurationStatus(root)
	if err != nil {
		t.Fatal(err)
	}
	if status.Totals[Outcome("reject")] != 1 || status.Totals[Fail] != 0 {
		t.Fatalf("FAIL total changed by event: %+v", status.Totals)
	}
}

func TestAcceptPreflightPreservesReferenceOnBadTree(t *testing.T) {
	root := t.TempDir()
	game := filepath.Join(root, "core", "game")
	ref := filepath.Join(game, "ref")
	if err := os.MkdirAll(ref, 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(ref, "old.png"), []byte("old reference"), 0640); err != nil {
		t.Fatal(err)
	}
	newDir := filepath.Join(game, "new")
	curation_png(t, newDir, 1, color.RGBA{R: 1, A: 255})
	if err := os.Mkdir(filepath.Join(newDir, "nested"), 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("/dev/null", filepath.Join(newDir, "nested", "bad.png")); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}
	err := AcceptResult(root, "game")
	if err == nil || !strings.Contains(err.Error(), "symlink") {
		t.Fatalf("symlink tree accepted: %v", err)
	}
	if data, err := os.ReadFile(filepath.Join(ref, "old.png")); err != nil || string(data) != "old reference" {
		t.Fatalf("old reference changed: %q %v", data, err)
	}
	if _, err := os.Stat(filepath.Join(newDir, "frame_00000001.png")); err != nil {
		t.Fatalf("pending capture changed: %v", err)
	}
}

func TestAcceptPreflightPreservesReferenceWhenLogNotWritable(t *testing.T) {
	root := t.TempDir()
	game := filepath.Join(root, "core", "game")
	ref := filepath.Join(game, "ref")
	if err := os.MkdirAll(ref, 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(ref, "old.png"), []byte("old reference"), 0640); err != nil {
		t.Fatal(err)
	}
	curation_png(t, filepath.Join(game, "new"), 1, color.RGBA{R: 1, A: 255})
	curation_png(t, filepath.Join(game, "new"), 2, color.RGBA{G: 1, A: 255})
	curation_png(t, filepath.Join(game, "new"), 3, color.RGBA{B: 1, A: 255})
	if err := os.Mkdir(filepath.Join(game, "log"), 0750); err != nil {
		t.Fatal(err)
	}
	if err := AcceptResult(root, "game"); err == nil {
		t.Fatal("accepted with invalid log path")
	}
	if data, err := os.ReadFile(filepath.Join(ref, "old.png")); err != nil || string(data) != "old reference" {
		t.Fatalf("old reference changed: %q %v", data, err)
	}
}

func TestCurationEventsSupersedeCheckStatus(t *testing.T) {
	root := t.TempDir()
	game := filepath.Join(root, "core", "game")
	if err := os.MkdirAll(filepath.Join(game, "new"), 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(game, "log"), []byte("2026-11-07 12:00:00 build NEW --------\n"), 0640); err != nil {
		t.Fatal(err)
	}
	if err := append_curation_event(game, "ACCEPT", "12345678", ""); err != nil {
		t.Fatal(err)
	}
	status, err := ReadCurationStatus(root)
	if err != nil {
		t.Fatal(err)
	}
	if status.Totals[Outcome("accept")] != 1 || status.Totals[New] != 0 || status.Totals[Pass] != 0 {
		t.Fatalf("review changed into capture outcome: %+v", status.Totals)
	}
}

func TestRejectPartialLogWriteRestoresPendingAndHistory(t *testing.T) {
	game := t.TempDir()
	newDir := filepath.Join(game, "new")
	curation_png(t, newDir, 1, color.RGBA{R: 1, A: 255})
	curation_png(t, newDir, 2, color.RGBA{G: 1, A: 255})
	oldHistory := []byte("prior check row\n")
	if err := os.WriteFile(filepath.Join(game, "log"), oldHistory, 0640); err != nil {
		t.Fatal(err)
	}
	writePartial := func(dst io.Writer, line string) (int, error) {
		n, _ := io.WriteString(dst, line[:8])
		return n, errors.New("injected partial write")
	}
	err := reject_pending_transaction(game, newDir, filepath.Join(game, "fail"), true, false, "12345678", "test", writePartial)
	if err == nil || !strings.Contains(err.Error(), "injected partial write") {
		t.Fatalf("partial event write did not fail: %v", err)
	}
	if data, err := os.ReadFile(filepath.Join(game, "log")); err != nil || !bytes.Equal(data, oldHistory) {
		t.Fatalf("history was not restored: %q %v", data, err)
	}
	for _, path := range []string{filepath.Join(newDir, "frame_00000001.png"), filepath.Join(newDir, "frame_00000002.png")} {
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("pending capture was lost: %s: %v", path, err)
		}
	}
	for _, path := range []string{newDir + ".rejecting", filepath.Join(game, "fail.rejecting")} {
		if _, err := os.Lstat(path); !os.IsNotExist(err) {
			t.Fatalf("staging remains %s: %v", path, err)
		}
	}
}

func TestRegressionBusyUsesFlockState(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "log"), 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "log", "lock"), nil, 0640); err != nil {
		t.Fatal(err)
	}
	busy, err := RegressionBusy(root)
	if err != nil || busy {
		t.Fatalf("idle lock reports busy=%v err=%v", busy, err)
	}
	lock, err := AcquireLock(root)
	if err != nil {
		t.Fatal(err)
	}
	defer ReleaseLock(lock)
	busy, err = RegressionBusy(root)
	if err != nil || !busy {
		t.Fatalf("held lock reports busy=%v err=%v", busy, err)
	}
}
