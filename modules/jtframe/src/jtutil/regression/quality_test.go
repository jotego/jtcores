/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCaptureQualityUsesAllPostStartupPixels(t *testing.T) {
	for _, tc := range []struct {
		name    string
		pixels  []uint16
		startup int
		want    string
	}{
		{"black", []uint16{0, 0, 0}, 0, "black"}, {"static", []uint16{1, 1, 1}, 0, "pixel-identical"},
		{"moving", []uint16{1, 2, 1}, 0, ""}, {"startup excluded", []uint16{1, 2, 2}, 100, "pixel-identical"},
		{"startup black excluded", []uint16{0, 1, 2}, 100, ""}, {"single nonblack", []uint16{1}, 0, ""}, {"single black", []uint16{0}, 0, "black"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := make_capture_fixture(t, tc.pixels)
			set, err := ReadCaptureSet(dir, len(tc.pixels)*100, tc.startup, 100)
			if err != nil {
				t.Fatal(err)
			}
			got, err := captureQualityFailure(set, tc.startup)
			if err != nil || tc.want == "" && got != "" || tc.want != "" && !strings.Contains(got, tc.want) {
				t.Fatalf("got%q err%v", got, err)
			}
		})
	}
}

type qualityHardware struct {
	fixture string
	loads   int
	fail    bool
}

func (h *qualityHardware) Load(GameSpec) (LoadInfo, error) {
	h.loads++
	return LoadInfo{Firmware: "TEST"}, nil
}
func (h *qualityHardware) Cleanup([]string) error { return nil }
func (h *qualityHardware) Run(g GameSpec, cab, dir string) (RunInfo, error) {
	if h.fail {
		return RunInfo{}, errors.New("synthetic capture failure")
	}
	hash, err := FileSHA256(cab)
	if err != nil {
		return RunInfo{}, err
	}
	remote := "/REG169_0123456789abcdef/CAB0123456789abcdef.JTC"
	report := map[string]any{"firmware": "TEST", "video_retrieved": true, "video_remote_dir": "/video/TEST/run_01234567_89abcdef", "video_local_dir": h.fixture, "remote_cab_path": remote, "frames": g.Profile.Video, "status": map[string]any{"STATE": "3", "INPUTS": "000000", "FRAME": g.Profile.Video, "TOTAL": g.Profile.Video}, "cab_clip_mode": "prefix", "cab_frame_budget": g.Profile.Video, "cab_source_sha256": hash, "capture_every": 100, "first_frame": 100, "timebase": "native-game-with-validated-video-pauses", "cab_sha256": hash, "packed_sha256": strings.Repeat("a", 64)}
	path := filepath.Join(filepath.Dir(h.fixture), "quality-report-"+g.Setname+".json")
	if err = os.WriteFile(path, mustJSONForQuality(report), 0600); err != nil {
		return RunInfo{}, err
	}
	return RunInfo{CaptureDir: h.fixture, Report: path, RemoteFiles: []string{remote}}, nil
}

func mustJSONForQuality(v any) []byte { data, _ := json.Marshal(v); return data }
func qualityBatch(t *testing.T, pixels []uint16) (*Batch, GameSpec, *qualityHardware) {
	t.Helper()
	root := t.TempDir()
	h := &qualityHardware{fixture: make_capture_fixture(t, pixels)}
	game := mock_rbf_game(t, root, "quality")
	b := makeBatch(t, root, h, []GameSpec{game})
	b.Firmware = "TEST"
	b.FirmwareSHA256 = strings.Repeat("1", 64)
	b.CaptureToolSHA256 = strings.Repeat("2", 64)
	if err := os.WriteFile(b.GlobalProfile, []byte("video: "+jsonNumber(len(pixels)*100)+"\nstart-up: 0\n"), 0600); err != nil {
		t.Fatal(err)
	}
	return b, game, h
}
func TestQualityFailurePublishesWithoutReferenceAndResumes(t *testing.T) {
	for _, withRef := range []bool{false, true} {
		t.Run(map[bool]string{false: "without-ref", true: "with-ref"}[withRef], func(t *testing.T) {
			b, game, h := qualityBatch(t, []uint16{1, 1, 1})
			gameRoot := filepath.Join(b.Root, b.Core, game.Setname)
			var refHash string
			if withRef {
				ref := filepath.Join(gameRoot, "ref")
				os.MkdirAll(ref, 0750)
				if err := export_png_frames(h.fixture, ref); err != nil {
					t.Fatal(err)
				}
				refHash, _ = HashFiles(map[string]string{"ref": filepath.Join(ref, "frame_00000100.png")})
			}
			if err := b.Run(); err != nil {
				t.Fatal(err)
			}
			result := b.State.Games[game.Setname]
			if result.Outcome != Fail || result.Stage != "quality" || !strings.Contains(result.Message, "pixel-identical") {
				t.Fatalf("wrong quality result: %+v", result)
			}
			if _, err := os.Stat(filepath.Join(gameRoot, "fail", "frame_00000100.png")); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(filepath.Join(gameRoot, "new")); !os.IsNotExist(err) {
				t.Fatal("new coexists with quality fail")
			}
			if !b.verifyFinalized(game, result) {
				t.Fatal("finalized quality fail not verified")
			}
			if err := b.Run(); err != nil {
				t.Fatal(err)
			}
			if h.loads != 1 {
				t.Fatal("finalized quality fail recaptured")
			}
			if withRef {
				after, _ := HashFiles(map[string]string{"ref": filepath.Join(gameRoot, "ref", "frame_00000100.png")})
				if after != refHash {
					t.Fatal("designer ref changed")
				}
			}
		})
	}
}
func TestPublicationRemovesStaleSiblingAndRecoveryFiles(t *testing.T) {
	for _, outcome := range []Outcome{New, Fail, Pass} {
		t.Run(string(outcome), func(t *testing.T) {
			root := t.TempDir()
			source := make_capture_fixture(t, []uint16{1, 2, 3})
			for _, slot := range []string{"new", "fail"} {
				for _, suffix := range []string{"", ".old", ".staging"} {
					os.MkdirAll(filepath.Join(root, slot)+suffix, 0750)
					os.WriteFile(filepath.Join(root, slot)+suffix+"/stale", []byte("stale"), 0600)
				}
			}
			ref := filepath.Join(root, "ref")
			if outcome != New {
				os.MkdirAll(ref, 0750)
				os.WriteFile(filepath.Join(ref, "designer"), []byte("keep"), 0600)
			}
			if err := PublishComplete(root, source, outcome, nil); err != nil {
				t.Fatal(err)
			}
			for _, slot := range []string{"new", "fail"} {
				keep := outcome == New && slot == "new" || outcome == Fail && slot == "fail"
				if _, err := os.Stat(filepath.Join(root, slot)); keep && err != nil || !keep && !os.IsNotExist(err) {
					t.Fatalf("wrong slot%s keep%v err%v", slot, keep, err)
				}
				for _, suffix := range []string{".old", ".staging"} {
					if _, err := os.Stat(filepath.Join(root, slot) + suffix); !os.IsNotExist(err) {
						t.Fatal("stale recovery survives")
					}
				}
			}
			if outcome != New {
				if data, err := os.ReadFile(filepath.Join(ref, "designer")); err != nil || string(data) != "keep" {
					t.Fatal("ref modified")
				}
			}
		})
	}
}
func TestFailedAttemptClearsOnlySelectedGameSlots(t *testing.T) {
	b, game, h := qualityBatch(t, []uint16{1, 2, 3})
	h.fail = true
	gameRoot := filepath.Join(b.Root, b.Core, game.Setname)
	other := filepath.Join(b.Root, b.Core, "unselected", "new")
	for _, path := range []string{filepath.Join(gameRoot, "new"), filepath.Join(gameRoot, "fail.old"), filepath.Join(gameRoot, "ref"), other} {
		os.MkdirAll(path, 0750)
		os.WriteFile(filepath.Join(path, "keep"), []byte("old"), 0600)
	}
	if err := b.Run(); err != nil {
		t.Fatal(err)
	}
	if b.State.Games[game.Setname].Outcome != Error {
		t.Fatal("failed capture not error")
	}
	for _, slot := range []string{"new", "fail", "fail.old"} {
		if _, err := os.Stat(filepath.Join(gameRoot, slot)); !os.IsNotExist(err) {
			t.Fatal("stale selected slot retained")
		}
	}
	for _, path := range []string{filepath.Join(gameRoot, "ref", "keep"), filepath.Join(other, "keep")} {
		if data, err := os.ReadFile(path); err != nil || string(data) != "old" {
			t.Fatal("unselected/ref modified")
		}
	}
}

func TestBlackCaptureFailsWithoutReference(t *testing.T) {
	b, game, _ := qualityBatch(t, []uint16{0, 0, 0})
	if err := b.Run(); err != nil {
		t.Fatal(err)
	}
	result := b.State.Games[game.Setname]
	if result.Outcome != Fail || result.Stage != "quality" || !strings.Contains(result.Message, "black") {
		t.Fatalf("black capture result: %+v", result)
	}
	if !b.verifyFinalized(game, result) {
		t.Fatal("black quality fail receipt cannot resume")
	}
}
func TestMovingCaptureWithoutReferenceRemainsNew(t *testing.T) {
	b, game, _ := qualityBatch(t, []uint16{1, 1, 2})
	if err := b.Run(); err != nil {
		t.Fatal(err)
	}
	if result := b.State.Games[game.Setname]; result.Outcome != New {
		t.Fatalf("partially static sequence should remain New: %+v", result)
	}
}
