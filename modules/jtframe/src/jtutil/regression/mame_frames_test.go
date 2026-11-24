/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"hash/crc32"
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

func TestMameFramesArchiveTargetGuardPrecedesLogAndPromotion(t *testing.T) {
	for _, target := range []string{"mister", "unmarked"} {
		t.Run(target, func(t *testing.T) {
			root := t.TempDir()
			if target == "mister" {
				if err := GuardCaptureTarget(root, "mister"); err != nil { t.Fatal(err) }
			} else {
				if err := os.MkdirAll(filepath.Join(root,"core","set","new"),0700); err != nil { t.Fatal(err) }
			}
			_, err := RunMameFrames(context.Background(), root, "", "", false, 1, "", MameFrameOptions{Target:"sidi128", LegacySiDi128:true})
			if err == nil { t.Fatal("cross-target or unmarked legacy write was accepted") }
			if _, statErr := os.Lstat(filepath.Join(root,"log","mame-frames.log")); !os.IsNotExist(statErr) {
				t.Fatalf("rejected archive write created a MAME log: %v",statErr)
			}
			if _, statErr := os.Lstat(filepath.Join(root,".capture-target.json")); target == "unmarked" && !os.IsNotExist(statErr) {
				t.Fatalf("nonempty legacy archive was silently claimed: %v",statErr)
			}
		})
	}
}

func TestMameDryrunCanReadUnmarkedEmptyArchiveWithoutClaimingIt(t *testing.T) {
	root := t.TempDir()
	results, err := RunMameFrames(context.Background(), root, "", "", true, 1, "", MameFrameOptions{Target:"sidi128"})
	if err != nil || len(results) != 0 { t.Fatalf("empty historical dry run = %v, %v",results,err) }
	if _, err = os.Lstat(filepath.Join(root,".capture-target.json")); !os.IsNotExist(err) { t.Fatalf("dry run claimed archive: %v",err) }
	if _, err = os.Lstat(filepath.Join(root,"log")); !os.IsNotExist(err) { t.Fatalf("dry run created log directory: %v",err) }
}

func TestMameCannotPromoteJournaledMiSTerNewFromLegacyContext(t *testing.T) {
	f := newRunCommitRecoveryFixture(t, "mame-data-guard")
	if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err != nil {
		t.Fatal(err)
	}
	candidates, err := discover_mame_candidates(f.log.Root, "", nil)
	if err != nil || len(candidates) != 1 {
		t.Fatalf("discovery error=%v candidates=%d", err, len(candidates))
	}
	candidate := candidates[0]
	if candidate.preflight_error != "" {
		t.Fatalf("fixture is not a valid capture set: %s", candidate.preflight_error)
	}
	if candidate.promotion_error == "" {
		t.Fatal("journal-only MiSTer candidate was not blocked during discovery")
	}
	// Reproduce a legacy digest entry that would otherwise make MAME matching
	// look valid. The target-data guard must still stop the final rename.
	f.log.Progress.Games["fake/alpha"] = ProgressGame{Result: New, Output: candidate.digest}
	if err = f.log.Save(); err != nil {
		t.Fatal(err)
	}
	candidates, err = discover_mame_candidates(f.log.Root, "", nil)
	if err != nil || len(candidates) != 1 {
		t.Fatalf("rediscovery error=%v candidates=%d", err, len(candidates))
	}
	if err = promote_mame_candidate(f.log.Root, candidates[0]); err == nil {
		t.Fatal("legacy MAME path accepted a journaled MiSTer RGB888 candidate")
	}
	if _, err = os.Stat(f.gameRoot() + "/ref"); !os.IsNotExist(err) {
		t.Fatalf("blocked MiSTer candidate created ref: %v", err)
	}
}

func TestMameFindsFinalizedV3JournalProvenance(t *testing.T) {
	f := newRunCommitRecoveryFixture(t, "mame-v3-journal")
	proof, receipt, ref := newMiSTerCaptureV3Fixture(t)
	item := &f.prepared[0]
	packed := testPackedCAB(t, 1, make([]byte, 8), 200)
	packedHash := sha256.Sum256(packed)
	proof.expected.PackedCAB = packed
	proof.expected.Prepared.CAB.PackedSHA256 = fmt.Sprintf("%x", packedHash)
	proof.expected.Prepared.CAB.PayloadCRC32 = binary.LittleEndian.Uint32(packed[24:28])
	proof.expected.Prepared.CAB.TotalFrames = 200
	cabText := fmt.Sprintf("%08x", proof.expected.Prepared.CAB.PayloadCRC32)
	oldReceiptPath := ref.ReceiptPath
	ref.ReceiptPath = "/tmp/jtframe-capture-sess-v2-checkpoint-00064.receipt.json"
	ref.Checkpoint = 100
	proof.files.ReceiptLocal[ref.ReceiptPath] = filepath.Join(proof.root, "receipt_00000100.json")
	delete(proof.files.ReceiptLocal, oldReceiptPath)
	delete(proof.files.ReceiptJSON, oldReceiptPath)
	if err := os.Remove(filepath.Join(proof.root, "receipt_00000001.json")); err != nil { t.Fatal(err) }
	oldPNG := receipt.PNGPath
	receipt.PNGPath = "/media/fat/screenshots/circusc/20261115_123456-cabcap_sess-v2_0064.png"
	newLocalPNG := filepath.Join(proof.root, CapturePNGLocalName(100))
	if err := os.Rename(proof.files.PNGLocal[oldPNG], newLocalPNG); err != nil { t.Fatal(err) }
	delete(proof.files.PNGLocal, oldPNG)
	proof.files.PNGLocal[receipt.PNGPath] = newLocalPNG
	receipt.RequestedCheckpoint, receipt.ActualCheckpoint, receipt.DescriptorCheckpoint, receipt.ActualInterval = 100, 100, 100, 99
	desc, err := hex.DecodeString(receipt.DescriptorBytesHex); if err != nil { t.Fatal(err) }
	binary.LittleEndian.PutUint16(desc[8:10], 100); binary.LittleEndian.PutUint16(desc[10:12], 99)
	descriptorCRC := crc32.ChecksumIEEE(desc[:56]); binary.LittleEndian.PutUint32(desc[56:60], descriptorCRC)
	receipt.DescriptorBytesHex, receipt.DescriptorCRC32 = hex.EncodeToString(desc), fmt.Sprintf("%08x", descriptorCRC)
	item.Job.SessionID, item.Job.Nonce = proof.expected.Attempt.SessionID, proof.expected.Attempt.Nonce
	item.Job.Session.Profile.Video, item.Job.Session.Profile.Startup = 200, 0
	item.Spec.Profile = item.Job.Session.Profile
	item.Job.Session.Checkpoints = []uint32{100}
	item.Job.Session.CAB = proof.expected.Prepared.CAB
	item.PackedCAB = append([]byte(nil), proof.expected.PackedCAB...)
	f.cfg.CaptureContract.MaxHoldMS = 1000
	item.CapturePlan, err = EncodeCapturePlan(item.PackedCAB, []CapturePlanEntry{{Checkpoint: 100, MaxHoldMS: 1000}})
	if err != nil { t.Fatal(err) }
	if err = os.WriteFile(item.Job.Session.Paths.StagingDir, item.CapturePlan, 0600); err != nil { t.Fatal(err) }
	planCRC := binary.LittleEndian.Uint32(item.CapturePlan[len(item.CapturePlan)-4:])
	planText := fmt.Sprintf("%08x", planCRC)
	var status miSTerCaptureStatusV2
	if err = decodeJSONValueFromBytes(proof.status, &status); err != nil { t.Fatal(err) }
	status.ScheduleCRC32 = planText
	status.PackedCABCRC32, status.Checkpoint, status.Output = cabText, 100, receipt.PNGPath
	proof.status = marshalTestJSON(t, status)
	var manifest miSTerCaptureManifestV2
	if err = decodeJSONValueFromBytes(proof.manifest, &manifest); err != nil { t.Fatal(err) }
	manifest.PlanCRC32, manifest.PackedCABCRC32 = planText, cabText
	manifest.PlanTotalFrames, manifest.PlannedCheckpoints[0] = 200, 100
	manifest.Images[0] = ref
	manifest.Images[0].PlanCRC32, manifest.Images[0].PackedCABCRC32 = planText, cabText
	manifest.CABTerminal.Frames, manifest.CABTerminal.FramesTotal = 200, 200
	proof.manifest = marshalTestJSON(t, manifest)
	receipt.PlanCRC32, receipt.PackedCABCRC32 = planText, cabText
	writeMiSTerV3TestReceipt(t, &proof, ref, receipt, false)
	planHash := sha256.Sum256(item.CapturePlan)
	proof.expected.PlanCRC32 = planCRC
	proof.expected.MaxHoldMS = 1000
	hook := func(_ context.Context, attempt AttemptKey, session PreparedSession) (SessionCapture, error) {
		expected := proof.expected
		expected.Attempt, expected.Prepared = attempt, session
		validated, err := ValidateMiSTerCapture(expected, proof.status, proof.manifest, proof.files, proof.root)
		if err != nil { return SessionCapture{}, err }
		result := SessionCapture{Key: attempt, HostName: "MiSTer", Cleanup: SessionCleanup{Confirmed: true}, Receipt: CaptureReceipt{SessionID: attempt.SessionID, Generation: session.Generation, CaptureConvention: session.Convention, CaptureProtocol: validated.CaptureProtocol, PlanSHA256: fmt.Sprintf("%x", planHash), CABPayloadCRC32: session.CAB.PayloadCRC32}}
		for _, image := range validated.Images {
			local := proof.files.PNGLocal[image.PNGPath]
			result.PNGPaths = append(result.PNGPaths, local)
			result.Receipt.Images = append(result.Receipt.Images, ImageReceipt{RequestedFrame: image.Checkpoint, ActualFrame: image.Checkpoint-1, Checkpoint: image.Checkpoint, Width: image.Width, Height: image.Height, Pitch: image.RowPitch, Slot: image.Slot, Mode: image.Mode, DescriptorCRC32: image.DescriptorCRC32, Released: true, PNGPath: local, PNGBytes: int64(image.PNGSize), PNGComplete: true})
		}
		return result, nil
	}
	f.driverA.captureHook, f.driverB.captureHook = hook, hook
	if _, err = RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err != nil { t.Fatal(err) }
	newDir := filepath.Join(f.gameRoot(), "new")
	frames, err := read_published_mame_frames(newDir); if err != nil { t.Fatal(err) }
	found, provenance, _, err := findMiSTerMameProvenance(f.log.Root, "fake", "alpha", newDir, frames, "gen-r1", "qual-r1")
	if err != nil || !found || provenance == nil || provenance.CaptureProtocol != miSTerCaptureProtocolV3 { t.Fatalf("v3 journal lookup found=%v provenance=%+v err=%v", found, provenance, err) }
	found, _, _, err = findMiSTerMameProvenance(f.log.Root, "fake", "alpha", newDir, frames, "other-generation", "qual-r1")
	if err != nil || found { t.Fatalf("different generation matched: found=%v err=%v", found, err) }
	for _, unsupported := range []string{"", "jtframe-capture-v1", "jtframe-capture-v99"} {
		for key, lane := range f.log.Progress.CaptureRuns {
			for operation, finalization := range lane.Finalizations {
				if finalization.Plan != nil { plan := *finalization.Plan; plan.Candidate.CaptureProtocol = unsupported; finalization.Plan = &plan; lane.Finalizations[operation] = finalization }
			}
			f.log.Progress.CaptureRuns[key] = lane
		}
		if err = f.log.Save(); err != nil { t.Fatal(err) }
		found, _, _, _ = findMiSTerMameProvenance(f.log.Root, "fake", "alpha", newDir, frames, "gen-r1", "qual-r1")
		if found { t.Fatalf("unsupported capture protocol %q matched", unsupported) }
	}
}

func TestMamePromotionKeepsLegacyOnlyCandidateBehavior(t *testing.T) {
	root := t.TempDir()
	if err := GuardCaptureTarget(root, "sidi128"); err != nil { t.Fatal(err) }
	game := filepath.Join(root, "legacy", "set")
	newDir := filepath.Join(game, "new")
	if err := os.MkdirAll(newDir, 0700); err != nil {
		t.Fatal(err)
	}
	write_mame_test_png(t, filepath.Join(newDir, "frame_00000500.png"), color.RGBA{R: 12, G: 34, B: 56, A: 255})
	frames, err := read_published_mame_frames(newDir)
	if err != nil {
		t.Fatal(err)
	}
	digest, err := result_slot_digest(newDir)
	if err != nil {
		t.Fatal(err)
	}
	if err = InitializeLog(root); err != nil {
		t.Fatal(err)
	}
	log, err := OpenCommitLog(root, strings.Repeat("a", 40))
	if err != nil {
		t.Fatal(err)
	}
	log.Progress.Games["legacy/set"] = ProgressGame{Result: New, Output: digest}
	if err = log.Save(); err != nil {
		t.Fatal(err)
	}
	if err = log.Close(); err != nil {
		t.Fatal(err)
	}
	candidates, err := discover_mame_candidates(root, "", nil)
	if err != nil || len(candidates) != 1 {
		t.Fatalf("legacy discovery error=%v candidates=%d", err, len(candidates))
	}
	candidate := candidates[0]
	candidate.frames = frames
	if candidate.promotion_error != "" {
		t.Fatalf("legacy candidate unexpectedly blocked: %s", candidate.promotion_error)
	}
	candidate.target, candidate.legacy_sidi128 = "sidi128", true
	if err = promote_mame_candidate(root, candidate); err != nil {
		t.Fatalf("legacy-only promotion changed: %v", err)
	}
	if _, err = os.Stat(filepath.Join(game, "ref", "frame_00000500.png")); err != nil {
		t.Fatalf("legacy ref not promoted: %v", err)
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
	if err := GuardCaptureTarget(root, "sidi128"); err != nil { t.Fatal(err) }
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
	candidate := mame_candidate{core: "core", set: "set", dir: new_dir, digest: digest, progress_path: progress_path, frames: frames, target:"sidi128", legacy_sidi128:true}
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
	if err := GuardCaptureTarget(root, "sidi128"); err != nil {
		t.Fatal(err)
	}
	result := MameFrameResult{Core: "core", Setname: "abcdefghijklmnop", Verdict: "FAIL", Detail: "MAME failed\nwith another line\r\n"}
	if err := append_mame_frames_log(root, "sidi128", result); err != nil {
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

func TestMameWriterRespectsHeldCommonArchiveLock(t *testing.T) {
	root := t.TempDir()
	lock, err := AcquireLock(root)
	if err != nil {
		t.Fatal(err)
	}
	defer ReleaseLock(lock)
	_, err = RunMameFrames(context.Background(), root, "", "", false, 1, "", MameFrameOptions{Target: "sidi128", LegacySiDi128: true})
	if !errors.Is(err, ErrBoardBusy) {
		t.Fatalf("MAME writer did not respect the common lock: %v", err)
	}
	if _, err = os.Lstat(filepath.Join(root, captureTargetMarkerName)); !os.IsNotExist(err) {
		t.Fatalf("MAME claimed target while another writer held the lock: %v", err)
	}
}

func TestMameFrameCaptureTimeoutCancelsWithoutCompletion(t *testing.T) {
	root := t.TempDir()
	fakeMame := filepath.Join(root, "mame-stall")
	if err := os.WriteFile(fakeMame, []byte("#!/bin/sh\nexec sleep 5\n"), 0700); err != nil {
		t.Fatal(err)
	}
	cab := MameCabScript{Version: 1, Frames: 1, Runs: []MameCabRun{{Frames: 1}}}
	err := capture_mame_frames(context.Background(), fakeMame, "fake", "", root, 1, 1, 25*time.Millisecond, cab)
	if err == nil || !strings.Contains(err.Error(), "timed out") {
		t.Fatalf("stalled MAME was not cancelled at its wall deadline: %v", err)
	}
	if _, err := os.Stat(filepath.Join(root, "complete")); !os.IsNotExist(err) {
		t.Fatalf("timed out MAME capture was marked complete: %v", err)
	}
}

func TestMameLogWriterRequiresLockedMatchingTarget(t *testing.T) {
	root := t.TempDir()
	if err := GuardCaptureTarget(root, "mister"); err != nil {
		t.Fatal(err)
	}
	result := MameFrameResult{Setname: "game", Verdict: "FAIL"}
	if err := append_mame_frames_log(root, "sidi128", result); err == nil {
		t.Fatal("MAME log accepted a target mismatch")
	}
	if _, err := os.Stat(filepath.Join(root, "log", "mame-frames.log")); !os.IsNotExist(err) {
		t.Fatalf("target mismatch created a MAME log: %v", err)
	}
	lock, err := AcquireLock(root)
	if err != nil {
		t.Fatal(err)
	}
	defer ReleaseLock(lock)
	if err = append_mame_frames_log(root, "mister", result); !errors.Is(err, ErrBoardBusy) {
		t.Fatalf("MAME log writer ignored held archive lock: %v", err)
	}
	if _, err = os.Stat(filepath.Join(root, "log", "mame-frames.log")); !os.IsNotExist(err) {
		t.Fatalf("MAME log was created while archive lock was held: %v", err)
	}
}

func TestValidatePublishedCapturePrecisionRejectsMixedOrInvalidFormat(t *testing.T) {
	dir := t.TempDir()
	write_mame_test_png(t, filepath.Join(dir, "frame_00000100.png"), color.RGBA{R: 17, A: 255})
	write_mame_test_png(t, filepath.Join(dir, "frame_00000200.png"), color.RGBA{R: 123, G: 37, A: 255})
	set, err := read_published_mame_frames(dir)
	if err != nil {
		t.Fatal(err)
	}
	if err = validate_published_capture_precision(set, 4); err != nil {
		t.Fatalf("RGB888 low-bit expansion differences were rejected: %v", err)
	}
	if err = validate_published_capture_precision(set, 5); err != nil {
		t.Fatalf("valid native 5-bit channel values were rejected: %v", err)
	}
	write_mame_test_png(t, filepath.Join(dir, "frame_00000200.png"), color.RGBA{R: 140, G: 37, A: 255})
	set, err = read_published_mame_frames(dir)
	if err != nil { t.Fatal(err) }
	if err = validate_published_capture_precision(set, 5); err != nil {
		t.Fatalf("an arbitrary RGB888 expansion was rejected for bit replication: %v", err)
	}
}

func TestMameFramesCancellationStopsBeforeNextCandidate(t *testing.T) {
	root := t.TempDir()
	if err := GuardCaptureTarget(root, "sidi128"); err != nil { t.Fatal(err) }
	source := test_jtroot(t)
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
	results, err := RunMameFrames(ctx, root, source, "", false, 2, "", MameFrameOptions{Target:"sidi128", LegacySiDi128:true})
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
			if err := GuardCaptureTarget(root, "sidi128"); err != nil { t.Fatal(err) }
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
			candidate := mame_candidate{core: "core", set: "set", dir: new_dir, digest: candidate_digest, progress_path: progress_path, frames: frames, target:"sidi128", legacy_sidi128:true}
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
