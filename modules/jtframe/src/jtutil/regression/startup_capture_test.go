/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestStartupCaptureScheduleBoundaries(t *testing.T) {
	for _, tc := range []struct{ startup, first int }{{0, 100}, {1, 100}, {100, 100}, {101, 200}, {300, 300}, {301, 400}, {500, 500}} {
		if got := firstCaptureFrame(tc.startup); got != tc.first {
			t.Fatalf("startup%d first%d want%d", tc.startup, got, tc.first)
		}
	}
	for _, tc := range []struct {
		video, first, count int
		valid               bool
	}{{450, 300, 2, true}, {4000, 500, 36, true}, {300, 300, 1, true}, {250, 300, 0, false}, {300, 150, 0, false}, {300, -100, 0, false}} {
		_, count, err := captureSchedule(tc.video, 100, tc.first)
		if (err == nil) != tc.valid || tc.valid && count != tc.count {
			t.Fatalf("schedule%+v count%d error%v", tc, count, err)
		}
	}
	p := Profile{Video: 4000, Startup: 500}
	data, _ := json.Marshal(p)
	if strings.Contains(string(data), "first-frame") {
		t.Fatal("new profile field breaks legacy identity")
	}
}
func TestDelayedScheduleStrictNewAndHistoricalReceipts(t *testing.T) {
	full := make_capture_fixture(t, []uint16{1, 2, 3, 4})
	if _, err := ReadCaptureSet(full, 450, 300, 100, 300); err == nil {
		t.Fatal("new capture accepts early checkpoints")
	}
	historical, err := readHistoricalCaptureSet(full, 450, 300, 100)
	if err != nil {
		t.Fatal(err)
	}
	receipt, err := make_capture_receipt(historical)
	if err != nil {
		t.Fatal(err)
	}
	profile := Profile{Video: 450, Startup: 300}
	if err = validate_capture_receipt(receipt, profile, "rgb555"); err != nil {
		t.Fatal("legacy receipt rejected:", err)
	}
	index := filepath.Join(full, "index.jsonl")
	data, err := os.ReadFile(index)
	if err != nil {
		t.Fatal(err)
	}
	var lines []string
	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		if strings.Contains(line, `"requested":100`) || strings.Contains(line, `"requested":200`) {
			continue
		}
		line = strings.ReplaceAll(line, `"count":4`, `"count":2`)
		line = strings.ReplaceAll(line, `"captures":4`, `"captures":2`)
		lines = append(lines, line)
	}
	if err = os.WriteFile(index, []byte(strings.Join(lines, "\n")+"\n"), 0600); err != nil {
		t.Fatal(err)
	}
	delayed, err := ReadCaptureSet(full, 450, 300, 100, 300)
	if err != nil {
		t.Fatal(err)
	}
	if len(delayed.Captures) != 2 || delayed.Captures[0].Requested != 300 {
		t.Fatal("wrong first capture")
	}
	if diffs, compareErr := CompareCaptureSets(historical, delayed, 300); compareErr != nil || len(diffs) != 0 {
		t.Fatalf("historical comparison changed: %v %v", diffs, compareErr)
	}
	if len(comparable_captures(delayed, 300)) != 1 || comparable_captures(delayed, 300)[0].Requested != 400 {
		t.Fatal("start-up comparison cutoff changed")
	}
	receipt, err = make_capture_receipt(delayed)
	if err != nil {
		t.Fatal(err)
	}
	if err = validate_capture_receipt(receipt, profile, "rgb555"); err != nil {
		t.Fatal("delayed receipt rejected:", err)
	}
	receipt.Frames = append(receipt.Frames, capture_frame_receipt{Requested: 200, Actual: 200})
	if err = validate_capture_receipt(receipt, profile, "rgb555"); err == nil {
		t.Fatal("intermediate receipt accepted")
	}
	pngDir := t.TempDir()
	if err = export_png_frames(full, pngDir); err != nil {
		t.Fatal(err)
	}
	// RAW fixture retains the unused early payloads; remove their exported PNGs.
	os.Remove(filepath.Join(pngDir, "frame_00000100.png"))
	os.Remove(filepath.Join(pngDir, "frame_00000200.png"))
	if _, err = ReadCaptureSet(pngDir, 450, 300, 100, 300); err != nil {
		t.Fatal("PNG schedule rejected:", err)
	}
}
