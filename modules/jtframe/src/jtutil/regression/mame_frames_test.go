/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"encoding/json"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestReadPublishedMameFramesRequiresNumericScheduleAndPNGOnly(t *testing.T) {
	dir := t.TempDir()
	write_mame_test_png(t, filepath.Join(dir, "frame_00000500.png"), color.RGBA{R: 10, A: 255})
	write_mame_test_png(t, filepath.Join(dir, "frame_00000600_actual_00000602.png"), color.RGBA{G: 20, A: 255})
	set, err := read_published_mame_frames(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(set.Captures) != 2 || set.Captures[1].Actual != 602 {
		t.Fatalf("unexpected capture set: %+v", set)
	}
	if err = os.WriteFile(filepath.Join(dir, "metadata.json"), []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err = read_published_mame_frames(dir); err == nil || !strings.Contains(err.Error(), "unexpected entry") {
		t.Fatalf("extra non-PNG entry accepted: %v", err)
	}
	_ = os.Remove(filepath.Join(dir, "metadata.json"))
	if err = os.Rename(filepath.Join(dir, "frame_00000600_actual_00000602.png"), filepath.Join(dir, "frame_00000650.png")); err != nil {
		t.Fatal(err)
	}
	if _, err = read_published_mame_frames(dir); err == nil {
		t.Fatal("irregular checkpoints accepted")
	}
}

func TestMatchMamePNGsRequiresOrderedFullRGBMatches(t *testing.T) {
	root := t.TempDir()
	fpga, mame := filepath.Join(root, "fpga"), filepath.Join(root, "mame")
	if err := os.MkdirAll(fpga, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(mame, 0700); err != nil {
		t.Fatal(err)
	}
	black := color.RGBA{A: 255}
	red := color.RGBA{R: 255, A: 255}
	green := color.RGBA{G: 255, A: 255}
	write_mame_test_png(t, filepath.Join(fpga, "frame_00000500.png"), red)
	write_mame_test_png(t, filepath.Join(fpga, "frame_00000600.png"), green)
	write_mame_test_png(t, filepath.Join(mame, "mame_00000001.png"), black)
	write_mame_test_png(t, filepath.Join(mame, "mame_00000002.png"), red)
	write_mame_test_png(t, filepath.Join(mame, "mame_00000003.png"), black)
	write_mame_test_png(t, filepath.Join(mame, "mame_00000004.png"), green)
	ref := CaptureSet{Dir: fpga, Captures: []CaptureRecord{
		{Requested: 500, Actual: 500, Image: "frame_00000500.png"},
		{Requested: 600, Actual: 600, Image: "frame_00000600.png"},
	}}
	paths, err := filepath.Glob(filepath.Join(mame, "*.png"))
	if err != nil {
		t.Fatal(err)
	}
	got, err := match_mame_pngs(ref, fpga, paths)
	if err != nil {
		t.Fatal(err)
	}
	if got[0] != 2 || got[1] != 4 {
		t.Fatalf("matches = %v, want [2 4]", got)
	}
	ref.Captures[1].Image = "frame_00000500.png"
	if _, err = match_mame_pngs(ref, fpga, paths); err == nil {
		t.Fatal("same FPGA image incorrectly matched twice")
	}
}

func TestMameProgressSelectionRejectsActiveAndFiltersOtherJSON(t *testing.T) {
	root := t.TempDir()
	log_dir := filepath.Join(root, "log")
	if err := os.MkdirAll(log_dir, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(log_dir, "upload-directories.json"), []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}
	if mame_progress_filename("upload-directories.json") {
		t.Fatal("non-progress JSON accepted as a campaign file")
	}
	commit := strings.Repeat("a", 40)
	key := LogKey(commit, false)
	progress := Progress{Commit: commit, Status: "running", Updated: time.Now(), Current: "core/other", Games: map[string]ProgressGame{
		"core/set":   {Result: New, Output: "digest"},
		"core/other": {Result: Pending},
	}}
	write_mame_test_progress(t, filepath.Join(log_dir, key+".json"), progress)
	wrong_path := filepath.Join(root, "bbbbbbb.json")
	write_mame_test_progress(t, wrong_path, progress)
	if _, err := read_mame_progress(root, wrong_path); err == nil {
		t.Fatal("progress was accepted from a filename with a different identity")
	}
	path, err := matching_mame_progress(root, "core", "set", "digest")
	if err != nil || path == "" {
		t.Fatalf("valid progress not found: %s, %v", path, err)
	}
	progress.Current = "core/set"
	write_mame_test_progress(t, filepath.Join(log_dir, key+".json"), progress)
	if _, err = matching_mame_progress(root, "core", "set", "digest"); err == nil || !strings.Contains(err.Error(), "active") {
		t.Fatalf("active game was promotable: %v", err)
	}
}

func TestPromoteMameCandidatePreservesResultDigestFallback(t *testing.T) {
	root := t.TempDir()
	game_root := filepath.Join(root, "core", "set")
	new_dir := filepath.Join(game_root, "new")
	if err := os.MkdirAll(filepath.Join(root, "log"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(new_dir, 0700); err != nil {
		t.Fatal(err)
	}
	write_mame_test_png(t, filepath.Join(new_dir, "frame_00000100.png"), color.RGBA{R: 1, A: 255})
	digest, err := result_slot_digest(new_dir)
	if err != nil {
		t.Fatal(err)
	}
	commit := strings.Repeat("b", 40)
	progress_path := filepath.Join(root, "log", LogKey(commit, false)+".json")
	progress := Progress{Commit: commit, Status: "complete", Updated: time.Now(), Games: map[string]ProgressGame{
		"core/set": {Result: New, Output: digest},
	}}
	write_mame_test_progress(t, progress_path, progress)
	frames, err := read_published_mame_frames(new_dir)
	if err != nil {
		t.Fatal(err)
	}
	candidate := mame_candidate{core: "core", set: "set", dir: new_dir, digest: digest, progress_path: progress_path, frames: frames}
	if err = promote_mame_candidate(root, candidate); err != nil {
		t.Fatal(err)
	}
	if _, err = os.Stat(filepath.Join(game_root, "new")); !os.IsNotExist(err) {
		t.Fatalf("new slot remains after promotion: %v", err)
	}
	if _, err = os.Stat(filepath.Join(game_root, "ref", "frame_00000100.png")); err != nil {
		t.Fatal(err)
	}
	after, err := result_digest(root, "core", "set", New)
	if err != nil || after != digest {
		t.Fatalf("New digest fallback = %s, %v; want %s", after, err, digest)
	}
}

func TestMameFramesLogKeepsOneFixedWidthLinePerGame(t *testing.T) {
	root := t.TempDir()
	result := MameFrameResult{Core: "core", Setname: "set", Verdict: "FAIL", Detail: "MAME failed\nwith another line\r\n"}
	if err := append_mame_frames_log(root, result); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(root, "log", "mame-frames.log"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Count(string(data), "\n") != 1 || strings.Contains(string(data), "\r") {
		t.Fatalf("log entry is not one line: %q", data)
	}
	if !strings.Contains(string(data), "core/set") || !strings.Contains(string(data), "MAME failed with another line") {
		t.Fatalf("fixed-width log fields missing: %q", data)
	}
}

func TestPromoteMameCandidateRefusesExistingRefAndChangedDigest(t *testing.T) {
	for _, mutate := range []string{"ref exists", "digest changed", "active run"} {
		t.Run(mutate, func(t *testing.T) {
			root := t.TempDir()
			game_root := filepath.Join(root, "core", "set")
			new_dir := filepath.Join(game_root, "new")
			if err := os.MkdirAll(filepath.Join(root, "log"), 0700); err != nil {
				t.Fatal(err)
			}
			if err := os.MkdirAll(new_dir, 0700); err != nil {
				t.Fatal(err)
			}
			write_mame_test_png(t, filepath.Join(new_dir, "frame_00000100.png"), color.RGBA{R: 1, A: 255})
			digest, err := result_slot_digest(new_dir)
			if err != nil {
				t.Fatal(err)
			}
			commit := strings.Repeat("c", 40)
			progress_path := filepath.Join(root, "log", LogKey(commit, false)+".json")
			progress := Progress{Commit: commit, Status: "running", Updated: time.Now(), Games: map[string]ProgressGame{
				"core/set":   {Result: New, Output: digest},
				"core/other": {Result: Pending},
			}}
			candidate_digest := digest
			switch mutate {
			case "ref exists":
				if err = os.Mkdir(filepath.Join(game_root, "ref"), 0700); err != nil {
					t.Fatal(err)
				}
			case "digest changed":
				candidate_digest = strings.Repeat("0", 64)
			case "active run":
				progress.Current = "core/set"
			}
			write_mame_test_progress(t, progress_path, progress)
			frames, err := read_published_mame_frames(new_dir)
			if err != nil {
				t.Fatal(err)
			}
			candidate := mame_candidate{core: "core", set: "set", dir: new_dir, digest: candidate_digest, progress_path: progress_path, frames: frames}
			if err = promote_mame_candidate(root, candidate); err == nil {
				t.Fatal("unsafe candidate was promoted")
			}
			if _, err = os.Stat(new_dir); err != nil {
				t.Fatalf("new slot was changed after failed promotion: %v", err)
			}
		})
	}
}

func write_mame_test_progress(t *testing.T, path string, progress Progress) {
	t.Helper()
	data, err := json.Marshal(progress)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
}

func write_mame_test_png(t *testing.T, path string, value color.RGBA) {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 2, 2))
	for y := 0; y < 2; y++ {
		for x := 0; x < 2; x++ {
			img.SetRGBA(x, y, value)
		}
	}
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	if err = png.Encode(file, img); err != nil {
		file.Close()
		t.Fatal(err)
	}
	if err = file.Close(); err != nil {
		t.Fatal(err)
	}
}
