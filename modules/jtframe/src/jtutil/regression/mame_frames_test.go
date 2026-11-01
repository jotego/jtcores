/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"syscall"
	"testing"
	"time"
)

func TestParseMameSetnames(t *testing.T) {
	selected, err := parse_mame_setnames(" hyperspt,  simpsons ")
	if err != nil || len(selected) != 2 || !selected["hyperspt"] || !selected["simpsons"] {
		t.Fatalf("unexpected selection %v, %v", selected, err)
	}
	for _, value := range []string{"", "hyperspt,", "hyperspt,hyperspt", "../hyperspt"} {
		if value == "" {
			continue
		}
		if _, err := parse_mame_setnames(value); err == nil {
			t.Errorf("accepted invalid set list %q", value)
		}
	}
}

func TestMameCandidateWorkersBoundAndOverlap(t *testing.T) {
	for _, limit := range []int{2, 4} {
		var active, maximum int32
		candidates := make([]mame_candidate, 8)
		for i := range candidates {
			candidates[i] = mame_candidate{core: "core", set: fmt.Sprintf("set%d", i)}
		}
		completed := start_mame_candidate_workers(context.Background(), limit, candidates, func(_ context.Context, _ int, candidate mame_candidate) MameFrameResult {
			current := atomic.AddInt32(&active, 1)
			for old := atomic.LoadInt32(&maximum); current > old && !atomic.CompareAndSwapInt32(&maximum, old, current); old = atomic.LoadInt32(&maximum) {
			}
			time.Sleep(30 * time.Millisecond)
			atomic.AddInt32(&active, -1)
			return MameFrameResult{Core: candidate.core, Setname: candidate.set, Verdict: "FAIL"}
		})
		count := 0
		for range completed {
			count++
		}
		if count != len(candidates) || int(maximum) != limit {
			t.Fatalf("jobs=%d processed=%d with maximum concurrency=%d", limit, count, maximum)
		}
	}
}

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

func TestMatchMamePNGsRequiresOrderedExactCaptureCodeMatches(t *testing.T) {
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
	got, err := match_mame_pngs(ref, fpga, paths, 4)
	if err != nil {
		t.Fatal(err)
	}
	if got[0] != 2 || got[1] != 4 {
		t.Fatalf("matches = %v, want [2 4]", got)
	}
	ref.Captures[1].Image = "frame_00000500.png"
	if _, err = match_mame_pngs(ref, fpga, paths, 4); err == nil {
		t.Fatal("same FPGA image incorrectly matched twice")
	}
}

func TestMameBoundaryDifferences(t *testing.T) {
	for _, bits := range []int{4, 5} {
		for _, tc := range []struct {
			name string
			x, y int
			want string
		}{
			{"top", 2, 0, "boundary differences at frame 500"},
			{"bottom", 2, 4, "boundary differences at frame 500"},
			{"left", 0, 2, "boundary differences at frame 500"},
			{"right", 4, 2, "boundary differences at frame 500"},
			{"corner", 0, 0, "boundary differences at frame 500"},
			{"interior", 1, 2, "no matches after frame 500"},
		} {
			t.Run(fmt.Sprintf("%d/%s", bits, tc.name), func(t *testing.T) {
				dir := t.TempDir()
				fpga := boundary_test_image(5, 5, false)
				mame := boundary_test_image(5, 5, false)
				mame.SetRGBA(tc.x, tc.y, color.RGBA{G: 255, A: 255})
				write_boundary_test_png(t, filepath.Join(dir, "fpga.png"), fpga)
				path := filepath.Join(dir, "mame.png")
				write_boundary_test_png(t, path, mame)
				ref := CaptureSet{Captures: []CaptureRecord{{Requested: 500, Image: "fpga.png"}, {Requested: 600, Image: "fpga.png"}}}
				got, err := match_mame_pngs(ref, dir, []string{path, path}, bits)
				if err == nil || err.Error() != tc.want || got != nil {
					t.Fatalf("got %v, %v; want FAIL %q", got, err, tc.want)
				}
			})
		}
	}
}

func TestMameBoundaryDiagnosisPreservesOrderingAndExactMatches(t *testing.T) {
	for _, tc := range []struct {
		name       string
		candidates []string
		want       string
	}{
		{"later exact wins", []string{"boundary", "exact"}, ""},
		{"boundary before last exact ignored", []string{"boundary", "first"}, "no matches after frame 600"},
		{"boundary after last exact", []string{"first", "boundary", "boundary"}, "boundary differences at frame 600"},
		{"first ordinary failure wins", []string{"first"}, "no matches after frame 600"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			first := boundary_test_image(5, 5, false)
			first.SetRGBA(2, 2, color.RGBA{G: 255, A: 255})
			write_boundary_test_png(t, filepath.Join(dir, "first.png"), first)
			write_boundary_test_png(t, filepath.Join(dir, "exact.png"), boundary_test_image(5, 5, false))
			write_boundary_test_png(t, filepath.Join(dir, "boundary.png"), boundary_test_image(5, 5, true))
			ref := CaptureSet{Captures: []CaptureRecord{{Requested: 500, Image: "exact.png"}}}
			if tc.name != "later exact wins" {
				ref.Captures = []CaptureRecord{{Requested: 500, Image: "first.png"}, {Requested: 600, Image: "exact.png"}, {Requested: 700, Image: "exact.png"}}
			}
			paths := make([]string, len(tc.candidates))
			for i, name := range tc.candidates {
				paths[i] = filepath.Join(dir, name+".png")
			}
			got, err := match_mame_pngs(ref, dir, paths, 4)
			if tc.want == "" {
				if err != nil || len(got) != 1 || got[0] != 2 {
					t.Fatalf("exact match must take priority: %v, %v", got, err)
				}
			} else if err == nil || err.Error() != tc.want || got != nil {
				t.Fatalf("got %v, %v; want FAIL %q", got, err, tc.want)
			}
		})
	}
}

func TestMameBoundaryDiagnosisRejectsEmptyInteriorAndGeometryMismatch(t *testing.T) {
	for _, size := range [][4]int{{2, 5, 2, 5}, {5, 2, 5, 2}, {5, 5, 6, 5}} {
		dir := t.TempDir()
		write_boundary_test_png(t, filepath.Join(dir, "fpga.png"), boundary_test_image(size[0], size[1], false))
		path := filepath.Join(dir, "mame.png")
		write_boundary_test_png(t, path, boundary_test_image(size[2], size[3], true))
		ref := CaptureSet{Captures: []CaptureRecord{{Requested: 500, Image: "fpga.png"}}}
		if _, err := match_mame_pngs(ref, dir, []string{path}, 4); err == nil || err.Error() != "no matches after frame 500" {
			t.Fatalf("geometry %v: %v", size, err)
		}
	}
}

func boundary_test_image(width, height int, changed bool) *image.RGBA {
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			img.SetRGBA(x, y, color.RGBA{R: 255, A: 255})
		}
	}
	if changed {
		img.SetRGBA(width-1, height/2, color.RGBA{G: 255, A: 255})
	}
	return img
}

func write_boundary_test_png(t *testing.T, path string, img image.Image) {
	t.Helper()
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	if err = png.Encode(file, img); err != nil {
		t.Fatal(err)
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
	result := MameFrameResult{Core: "core", Setname: "abcdefghijklmnop", Verdict: "FAIL", Detail: "MAME failed\nwith another line\r\n"}
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
	if !strings.Contains(string(data), "abcdefghijklmnop") || !strings.Contains(string(data), "MAME failed with another line") {
		t.Fatalf("fixed-width log fields missing: %q", data)
	}
	if strings.Index(string(data), "FAIL") != 37 {
		t.Fatalf("maximum-length setname shifted the fixed verdict column: %q", data)
	}
}

func TestValidatePublishedCapturePrecisionRejectsMixedOrInvalidFormat(t *testing.T) {
	dir := t.TempDir()
	write_mame_test_png(t, filepath.Join(dir, "frame_00000100.png"), color.RGBA{R: 17, A: 255})
	write_mame_test_png(t, filepath.Join(dir, "frame_00000200.png"), color.RGBA{R: 123, A: 255})
	set, err := read_published_mame_frames(dir)
	if err != nil {
		t.Fatal(err)
	}
	if err = validate_published_capture_precision(set, 4); err == nil {
		t.Fatal("mixed RGB444/RGB555 expansion values were accepted")
	}
	if err = validate_published_capture_precision(set, 5); err == nil {
		t.Fatal("RGB444-expanded pixel was accepted as an RGB555 capture")
	}
}

func TestMameFramesCancellationStopsBeforeNextCandidate(t *testing.T) {
	root := t.TempDir()
	source := os.Getenv("JTROOT")
	for _, set := range []string{"first", "second"} {
		new_dir := filepath.Join(root, "gng", set, "new")
		if err := os.MkdirAll(new_dir, 0700); err != nil {
			t.Fatal(err)
		}
		if set == "first" {
			if err := os.WriteFile(filepath.Join(new_dir, "frame_00000100.png"), []byte("invalid PNG"), 0600); err != nil {
				t.Fatal(err)
			}
		} else {
			write_mame_test_png(t, filepath.Join(new_dir, "frame_00000100.png"), color.RGBA{R: 17, A: 255})
		}
	}
	bin := t.TempDir()
	ocr_marker := filepath.Join(bin, "ocr-started")
	mame_marker := filepath.Join(bin, "mame-started")
	ocr_script := "#!/bin/sh\nprintf '%s\\n' \"$$\" > \"" + ocr_marker + "\"\nexec /bin/sleep 30\n"
	mame_script := "#!/bin/sh\nprintf started > \"" + mame_marker + "\"\nexit 1\n"
	for name, script := range map[string]string{"tesseract": ocr_script, "mame": mame_script} {
		if err := os.WriteFile(filepath.Join(bin, name), []byte(script), 0700); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	workspaces_before, err := filepath.Glob("/tmp/jtutil-mame-frames-*")
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	child_started := make(chan struct{})
	go func() {
		deadline := time.NewTimer(5 * time.Second)
		defer deadline.Stop()
		ticker := time.NewTicker(10 * time.Millisecond)
		defer ticker.Stop()
		for {
			_, markerErr := os.Stat(ocr_marker)
			log_data, logErr := os.ReadFile(filepath.Join(root, "log", "mame-frames.log"))
			if markerErr == nil && logErr == nil && strings.Contains(string(log_data), "first") {
				close(child_started)
				cancel()
				return
			}
			select {
			case <-deadline.C:
				return
			case <-ticker.C:
			}
		}
	}()
	results, err := RunMameFrames(ctx, root, source, "", false, 2, "")
	if !errors.Is(err, context.Canceled) || len(results) != 1 || results[0].Setname != "first" || results[0].Verdict != "FAIL" {
		t.Fatalf("cancelled sweep returned results=%v err=%v", results, err)
	}
	select {
	case <-child_started:
	default:
		t.Fatal("cancellation test did not observe the live OCR child")
	}
	if _, err = os.Stat(mame_marker); !os.IsNotExist(err) {
		t.Fatalf("MAME started after cancellation: %v", err)
	}
	data, err := os.ReadFile(filepath.Join(root, "log", "mame-frames.log"))
	if err != nil || !strings.Contains(string(data), "first") || strings.Contains(string(data), "second") {
		t.Fatalf("completed candidate log not retained or canceled candidate logged: %q, %v", data, err)
	}
	workspaces_after, err := filepath.Glob("/tmp/jtutil-mame-frames-*")
	if err != nil {
		t.Fatal(err)
	}
	if strings.Join(workspaces_after, "\n") != strings.Join(workspaces_before, "\n") {
		t.Fatalf("candidate temporary workspace leaked: before=%v after=%v", workspaces_before, workspaces_after)
	}
	data, err = os.ReadFile(ocr_marker)
	if err != nil {
		t.Fatalf("fake OCR did not start: %v", err)
	}
	var pid int
	if _, err = fmt.Sscanf(string(data), "%d", &pid); err != nil {
		t.Fatal(err)
	}
	if err = syscall.Kill(pid, 0); err == nil {
		t.Fatalf("OCR child PID %d is still running", pid)
	} else if !errors.Is(err, syscall.ESRCH) {
		t.Fatalf("could not verify OCR child exit: %v", err)
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
