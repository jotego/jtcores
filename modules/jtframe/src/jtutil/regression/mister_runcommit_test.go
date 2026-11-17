/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

type runCommitTestDriver struct {
	root          string
	entered       chan<- string
	returned      chan<- string
	release       <-chan struct{}
	pixelBias     uint32
	black         bool
	mu            sync.Mutex
	calls         int
	captureHook   func(context.Context, AttemptKey, PreparedSession) (SessionCapture, error)
	reconcileHook func(context.Context, AttemptKey) (SessionCleanup, error)
}

func (d *runCommitTestDriver) Healthy(context.Context) error            { return nil }
func (d *runCommitTestDriver) Cancel(context.Context, AttemptKey) error { return nil }
func (d *runCommitTestDriver) Reconcile(ctx context.Context, attempt AttemptKey) (SessionCleanup, error) {
	if d.reconcileHook != nil {
		return d.reconcileHook(ctx, attempt)
	}
	return SessionCleanup{Confirmed: true}, nil
}
func (d *runCommitTestDriver) Capture(ctx context.Context, attempt AttemptKey, session PreparedSession) (SessionCapture, error) {
	d.mu.Lock()
	d.calls++
	d.mu.Unlock()
	if d.captureHook != nil {
		return d.captureHook(ctx, attempt, session)
	}
	if d.entered != nil {
		d.entered <- session.Setname
	}
	if d.release != nil {
		select {
		case <-ctx.Done():
			return SessionCapture{}, ctx.Err()
		case <-d.release:
		}
	}
	planPath := session.Paths.StagingDir
	planBytes, err := os.ReadFile(planPath)
	if err != nil {
		return SessionCapture{}, err
	}
	planSHA := sha256.Sum256(planBytes)
	capture, err := d.captureResult(attempt, session, hex.EncodeToString(planSHA[:]))
	if err == nil && d.returned != nil {
		d.returned <- session.Setname
	}
	return capture, err
}

func (d *runCommitTestDriver) captureResult(attempt AttemptKey, session PreparedSession, planSHA string) (SessionCapture, error) {
	imageDir := filepath.Join(d.root, "worker", string(attempt.Board), session.Setname)
	if err := os.MkdirAll(imageDir, 0700); err != nil {
		return SessionCapture{}, err
	}
	images := make([]ImageReceipt, 0, len(session.Checkpoints))
	paths := make([]string, 0, len(session.Checkpoints))
	for index, checkpoint := range session.Checkpoints {
		frame := image.NewRGBA(image.Rect(0, 0, 16, 12))
		for y := 0; y < 12; y++ {
			for x := 0; x < 16; x++ {
				pixel := color.RGBA{R: uint8(checkpoint + uint32(x) + d.pixelBias), G: uint8(y + 40), B: uint8(index + 80), A: 255}
				if d.black {
					pixel = color.RGBA{A: 255}
				}
				frame.SetRGBA(x, y, pixel)
			}
		}
		name := png_capture_name(int(checkpoint), int(checkpoint-1))
		path := filepath.Join(imageDir, name)
		file, err := os.Create(path)
		if err != nil {
			return SessionCapture{}, err
		}
		if err = png.Encode(file, frame); err != nil {
			_ = file.Close()
			return SessionCapture{}, err
		}
		if err = file.Close(); err != nil {
			return SessionCapture{}, err
		}
		info, err := os.Stat(path)
		if err != nil {
			return SessionCapture{}, err
		}
		paths = append(paths, path)
		images = append(images, ImageReceipt{RequestedFrame: checkpoint, ActualFrame: checkpoint - 1, Checkpoint: checkpoint,
			Width: 16, Height: 12, Pitch: 256, Slot: uint32(index % 3), Mode: 0, DescriptorCRC32: uint32(index + 1), Released: true,
			PNGPath: path, PNGBytes: info.Size(), PNGComplete: true})
	}
	return SessionCapture{Key: attempt, Receipt: CaptureReceipt{SessionID: attempt.SessionID, Generation: session.Generation, CaptureConvention: session.Convention,
		CaptureProtocol: miSTerCaptureProtocolV2, PlanSHA256: planSHA, CABPayloadCRC32: session.CAB.PayloadCRC32, Images: images}, PNGPaths: paths, Cleanup: SessionCleanup{Confirmed: true}}, nil
}

func TestMiSTerSerialCandidateSetUsesPreviousFrame(t *testing.T) {
	imageDir := t.TempDir()
	frame := image.NewRGBA(image.Rect(0, 0, 16, 12))
	for y := 0; y < 12; y++ {
		for x := 0; x < 16; x++ {
			frame.SetRGBA(x, y, color.RGBA{R: uint8(x + 1), G: uint8(y + 2), B: 3, A: 255})
		}
	}
	path := filepath.Join(imageDir, png_capture_name(1, 0))
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(file, frame); err != nil {
		_ = file.Close()
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}

	session := PreparedSession{Core: "circus", Setname: "circusc", Checkpoints: []uint32{1}}
	qualification := CaptureQualification{Generation: "generation", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qualification"}
	capture := SessionCapture{Receipt: CaptureReceipt{CaptureProtocol: miSTerCaptureProtocolV2, Images: []ImageReceipt{{RequestedFrame: 1, ActualFrame: 0, Checkpoint: 1,
		Width: 16, Height: 12, Pitch: 48, Slot: 0, Released: true, PNGComplete: true}}}, PNGPaths: []string{path}}
	effects := miSTerSerialResultEffects{}
	set, provenance, err := effects.candidateSet(imageDir, capture, session, qualification)
	if err != nil {
		t.Fatalf("candidateSet rejected requested frame 1 / actual frame 0: %v", err)
	}
	if len(set.Captures) != 1 || set.Captures[0].Requested != 1 || set.Captures[0].Actual != 0 {
		t.Fatalf("unexpected capture record: %+v", set.Captures)
	}
	provenance.TestDefinitionID = strings.Repeat("a", 64)
	provenance.SourceCommit = strings.Repeat("b", 40)
	if err := provenance.Validate(); err != nil {
		t.Fatalf("provenance rejected requested frame 1 / actual frame 0: %v", err)
	}

	for _, actual := range []uint32{1} {
		bad := capture
		bad.Receipt.Images = append([]ImageReceipt(nil), capture.Receipt.Images...)
		bad.Receipt.Images[0].ActualFrame = actual
		if _, _, err := effects.candidateSet(imageDir, bad, session, qualification); err == nil {
			t.Fatalf("candidateSet accepted requested frame 1 / shifted actual frame %d", actual)
		}
	}
	legacy := capture
	legacy.Receipt.CaptureProtocol = ""
	if _, _, err := effects.candidateSet(imageDir, legacy, session, qualification); err == nil {
		t.Fatal("candidateSet accepted a markerless legacy receipt as a fresh v2 capture")
	}
	sequenced := capture
	sequenced.Receipt.Images = append([]ImageReceipt(nil), capture.Receipt.Images...)
	sequenced.Receipt.Images[0].Sequence = 1
	if _, _, err := effects.candidateSet(imageDir, sequenced, session, qualification); err == nil {
		t.Fatal("candidateSet accepted a v2 screenshot-sequence alias")
	}
}

func TestMiSTerReferenceProvenanceCaptureProtocolRoundTripsAndOldRecordsRead(t *testing.T) {
	current := MiSTerReferenceProvenance{Version: 1, CaptureProtocol: "jtframe-capture-v2"}
	data, err := json.Marshal(current)
	if err != nil {
		t.Fatal(err)
	}
	var decoded MiSTerReferenceProvenance
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatal(err)
	}
	if decoded.CaptureProtocol != current.CaptureProtocol {
		t.Fatalf("capture protocol round trip = %q, want %q", decoded.CaptureProtocol, current.CaptureProtocol)
	}
	var historical MiSTerReferenceProvenance
	if err := json.Unmarshal([]byte(`{"version":1,"target":"mister"}`), &historical); err != nil {
		t.Fatalf("historical provenance without capture protocol should remain readable: %v", err)
	}
	if historical.CaptureProtocol != "" {
		t.Fatalf("historical missing capture protocol decoded as %q", historical.CaptureProtocol)
	}
}

func TestMiSTerHistoryRowAppendsHostnameForAttemptBoard(t *testing.T) {
	root := t.TempDir()
	old := "2026-11-14 12:00:00 aaaaaaa NEW --------\n"
	if err := os.MkdirAll(filepath.Join(root, "fake", "alpha"), 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "fake", "alpha", "log"), []byte(old), 0640); err != nil {
		t.Fatal(err)
	}
	log := &CommitLog{Root: root, Progress: &Progress{Commit: strings.Repeat("a", 40)}}
	effects := &miSTerSerialResultEffects{log: log, root: root, hosts: map[BoardKey]string{"board-a": "mister.home", "board-b": "mister2.home"}}
	row, path, err := effects.historyRow(PreparedSession{Core: "fake", Setname: "alpha"}, Pass, "12345678", time.Date(2026, 11, 15, 12, 0, 0, 0, time.UTC), "board-b", "mister-real.local")
	if err != nil {
		t.Fatal(err)
	}
	if path != filepath.Join(root, "fake", "alpha", "log") || !strings.HasSuffix(row, " 12345678 mister-real.local\n") {
		t.Fatalf("history row did not bind the executing board hostname: path=%s row=%q", path, row)
	}
	witness := MiSTerHistoryWitness{PrefixBytes: int64(len(old)), PrefixSHA256: sha256Hex([]byte(old)), Row: row}
	if err = appendHistoryIdempotent(root, path, witness); err != nil {
		t.Fatal(err)
	}
	if err = appendHistoryIdempotent(root, path, witness); err != nil {
		t.Fatalf("idempotent recovery failed: %v", err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(string(data), old) || strings.Count(string(data), "\n") != 2 || !strings.HasSuffix(string(data), "mister-real.local\n") {
		t.Fatalf("hostname/history append changed prior rows or duplicated the new row: %q", data)
	}
}

func TestMiSTerReferenceProvenanceRejectsShiftedFrames(t *testing.T) {
	base := MiSTerReferenceProvenance{Version: 1, Target: "mister", Core: "circus", Setname: "circusc", Generation: "generation",
		Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qualification", TestDefinitionID: strings.Repeat("a", 64), SourceCommit: strings.Repeat("b", 40),
		Images: []MiSTerImageProvenance{{Sequence: 1, RequestedFrame: 1, ActualFrame: 0, Checkpoint: 1, Width: 16, Height: 12, Pitch: 48, RGBSHA256: strings.Repeat("c", 64)}}}
	if err := base.Validate(); err != nil {
		t.Fatalf("requested frame 1 / actual frame 0 should validate: %v", err)
	}
	for _, pair := range [][2]uint32{{1, 1}, {500, 500}, {500, 498}} {
		bad := base
		bad.Images = append([]MiSTerImageProvenance(nil), base.Images...)
		bad.Images[0].RequestedFrame, bad.Images[0].Checkpoint, bad.Images[0].ActualFrame = pair[0], pair[0], pair[1]
		if err := bad.Validate(); err == nil {
			t.Fatalf("provenance accepted requested frame %d / shifted actual frame %d", pair[0], pair[1])
		}
	}
}

func TestMiSTerReferenceReaderAcceptsFrameOneAsActualZero(t *testing.T) {
	root := t.TempDir()
	session := PreparedSession{Core: "circus", Setname: "circusc", Checkpoints: []uint32{1}}
	qualification := CaptureQualification{Generation: "generation", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qualification"}
	testDefinition, err := miSTerTestDefinitionID(session)
	if err != nil {
		t.Fatal(err)
	}
	gameRoot := filepath.Join(root, session.Core, session.Setname)
	refDir := filepath.Join(gameRoot, "ref")
	if err := os.MkdirAll(refDir, 0750); err != nil {
		t.Fatal(err)
	}
	frame := image.NewRGBA(image.Rect(0, 0, 16, 12))
	for y := 0; y < 12; y++ {
		for x := 0; x < 16; x++ {
			frame.SetRGBA(x, y, color.RGBA{R: uint8(x + 1), G: uint8(y + 2), B: 3, A: 255})
		}
	}
	path := filepath.Join(refDir, png_capture_name(1, 0))
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(file, frame); err != nil {
		_ = file.Close()
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	decoded, err := decode_capture_image(path)
	if err != nil {
		t.Fatal(err)
	}
	provenance := MiSTerReferenceProvenance{Version: 1, Target: "mister", Core: session.Core, Setname: session.Setname,
		Generation: qualification.Generation, Convention: qualification.Convention, QualificationID: qualification.QualificationID,
		TestDefinitionID: testDefinition, SourceCommit: strings.Repeat("b", 40),
		Images: []MiSTerImageProvenance{{Sequence: 1, RequestedFrame: 1, ActualFrame: 0, Checkpoint: 1, Width: 16, Height: 12, Pitch: 48, RGBSHA256: decodedRGBDigest(decoded)}}}
	data, err := json.Marshal(provenance)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(gameRoot, "ref", "reference-provenance.json"), data, 0640); err != nil {
		t.Fatal(err)
	}
	effects := miSTerSerialResultEffects{root: root}
	if _, _, _, _, _, ok, err := effects.readCompatibleReference(gameRoot, session, qualification, testDefinition); err != nil || !ok {
		t.Fatalf("qualified reference requested 1 / actual 0 was rejected: ok=%t err=%v", ok, err)
	}
}

func TestLegacyPNGReaderStillRejectsZeroActualFrame(t *testing.T) {
	dir := t.TempDir()
	frame := image.NewRGBA(image.Rect(0, 0, 16, 12))
	for y := 0; y < 12; y++ {
		for x := 0; x < 16; x++ {
			frame.SetRGBA(x, y, color.RGBA{R: uint8(x + 1), G: uint8(y + 2), B: 3, A: 255})
		}
	}
	path := filepath.Join(dir, png_capture_name(100, 0))
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(file, frame); err != nil {
		_ = file.Close()
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	if _, err := ReadCaptureSet(dir, 100, 100, 100); err == nil {
		t.Fatal("legacy PNG reader accepted an actual-frame-zero capture")
	}
}

func TestRunCommitMiSTerReferenceRequiresExactInventoryAndCoverage(t *testing.T) {
	for _, kind := range []string{"extra-png", "truncated-provenance"} {
		t.Run(kind, func(t *testing.T) {
			f := newRunCommitRecoveryFixture(t, "scope-reference-"+kind)
			if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err != nil {
				t.Fatal(err)
			}
			var plan MiSTerFinalizationPlan
			for _, lane := range f.log.Progress.CaptureRuns {
				for _, item := range lane.Finalizations {
					if item.Plan != nil {
						plan = *item.Plan.Clone()
					}
				}
			}
			refDir := filepath.Join(f.gameRoot(), "ref")
			if err := copy_tree(filepath.Join(f.gameRoot(), "new"), refDir); err != nil {
				t.Fatal(err)
			}
			provenance := plan.Candidate
			writeProvenance := func() {
				data, err := json.MarshalIndent(provenance, "", "  ")
				if err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(f.gameRoot(), "ref", "reference-provenance.json"), data, 0640); err != nil {
					t.Fatal(err)
				}
			}
			writeProvenance()
			effects := miSTerSerialResultEffects{root: f.log.Root}
			read := func() error {
				_, _, _, _, _, _, err := effects.readCompatibleReference(f.gameRoot(), f.prepared[0].Job.Session, f.deps.Qualification, plan.TestDefinitionID)
				return err
			}
			if err := read(); err != nil {
				t.Fatalf("qualified N-1 reference rejected: %v", err)
			}
			if kind == "extra-png" {
				first := provenance.Images[0]
				data, err := os.ReadFile(filepath.Join(refDir, png_capture_name(int(first.RequestedFrame), int(first.ActualFrame))))
				if err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(refDir, png_capture_name(999, 998)), data, 0640); err != nil {
					t.Fatal(err)
				}
			} else {
				if len(provenance.Images) < 2 {
					t.Fatal("need a multi-checkpoint reference fixture")
				}
				for _, image := range provenance.Images[1:] {
					path := filepath.Join(refDir, png_capture_name(int(image.RequestedFrame), int(image.ActualFrame)))
					if err := os.Remove(path); err != nil {
						t.Fatal(err)
					}
				}
				provenance.Images = provenance.Images[:1]
				writeProvenance()
			}
			if err := read(); err == nil {
				t.Errorf("qualified MiSTer reference accepted %s", kind)
			}
		})
	}
}

func TestRunCommitMiSTerDoesNotRelabelLegacyReceiptAsProtocolV2(t *testing.T) {
	f := newRunCommitRecoveryFixture(t, "legacy-receipt-protocol")
	for _, driver := range []*runCommitTestDriver{f.driverA, f.driverB} {
		driver := driver
		driver.captureHook = func(ctx context.Context, attempt AttemptKey, session PreparedSession) (SessionCapture, error) {
			planBytes, err := os.ReadFile(session.Paths.StagingDir)
			if err != nil {
				return SessionCapture{}, err
			}
			planSHA := sha256.Sum256(planBytes)
			capture, err := driver.captureResult(attempt, session, hex.EncodeToString(planSHA[:]))
			if err != nil {
				return capture, err
			}
			capture.Receipt.CaptureProtocol = ""
			capture.Receipt.Epoch = 1
			for index := range capture.Receipt.Images {
				capture.Receipt.Images[index].Sequence = uint32(index + 1)
			}
			return capture, nil
		}
	}
	if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil || !strings.Contains(err.Error(), "v2 capture receipt") {
		t.Fatalf("fresh capture accepted a legacy image-v1 receipt: %v", err)
	}
	for _, lane := range f.log.Progress.CaptureRuns {
		for _, finalization := range lane.Finalizations {
			if finalization.Plan != nil && finalization.Plan.Candidate.CaptureProtocol == "jtframe-capture-v2" {
				t.Fatal("legacy image-v1 receipt was relabeled as protocol-v2")
			}
		}
	}
}

func TestRunCommitMiSTerTwoBoardEffectsAndResume(t *testing.T) {
	first, firstOrder := runMiSTerCommitFixture(t, []string{"alpha", "beta"}, false)
	second, secondOrder := runMiSTerCommitFixture(t, []string{"alpha", "beta"}, true)
	if firstOrder != "alpha,beta" || secondOrder != "beta,alpha" {
		t.Fatalf("both boards did not overlap or complete in requested orders: %q / %q", firstOrder, secondOrder)
	}
	for _, setname := range []string{"alpha", "beta"} {
		if first[setname] != second[setname] {
			t.Fatalf("result digest for %s depends on board completion order", setname)
		}
	}
}

func TestRunCommitMiSTerUnqualifiedReferenceBlocksAllSharedEffects(t *testing.T) {
	root := t.TempDir()
	progressRoot := filepath.Join(root, "progress")
	if err := os.Mkdir(progressRoot, 0750); err != nil {
		t.Fatal(err)
	}
	if err := GuardCaptureTarget(progressRoot, "mister"); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(progressRoot, "log"), 0750); err != nil {
		t.Fatal(err)
	}
	log, err := OpenCommitLog(progressRoot, strings.Repeat("a", 40))
	if err != nil {
		t.Fatal(err)
	}
	defer log.Close()
	prepared := []MiSTerPreparedGame{makeRunCommitPreparedGame(t, root, "alpha")}
	gameRoot := filepath.Join(progressRoot, "fake", "alpha")
	ref := filepath.Join(gameRoot, "ref")
	if err = os.MkdirAll(ref, 0750); err != nil {
		t.Fatal(err)
	}
	frame := image.NewRGBA(image.Rect(0, 0, 16, 12))
	for y := 0; y < 12; y++ {
		for x := 0; x < 16; x++ {
			frame.SetRGBA(x, y, color.RGBA{R: 32, G: uint8(x + y), B: 80, A: 255})
		}
	}
	refPNG := filepath.Join(ref, "frame_00000100.png")
	file, err := os.Create(refPNG)
	if err != nil {
		t.Fatal(err)
	}
	if err = png.Encode(file, frame); err != nil {
		_ = file.Close()
		t.Fatal(err)
	}
	if err = file.Close(); err != nil {
		t.Fatal(err)
	}
	before, err := digestOwnedTree(ref)
	if err != nil {
		t.Fatal(err)
	}
	boards := []PoolBoard{
		{Key: "board-a", Host: "192.0.2.1", Driver: &runCommitTestDriver{root: root}},
		{Key: "board-b", Host: "192.0.2.2", Driver: &runCommitTestDriver{root: root}},
	}
	cfg := runCommitTestConfig(progressRoot)
	qualification := CaptureQualification{Target: "mister", Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", Qualified: true}
	deps := MiSTerCommitDeps{Qualification: qualification, Boards: boards,
		CoordinatorOptions: CaptureCoordinatorOptions{CaptureTimeout: 5 * time.Second, CleanupTimeout: 5 * time.Second},
		PrivateWorkRoot:    filepath.Join(root, "private")}
	if _, err = RunCommitMiSTer(context.Background(), log, prepared, cfg, deps, MiSTerRunPolicy{Manual: true, RunScopeID: "scope-unqualified"}); err == nil || !strings.Contains(err.Error(), "lacks trusted MiSTer provenance") {
		t.Fatalf("unqualified ref was not blocked before publication: %v", err)
	}
	after, err := digestOwnedTree(ref)
	if err != nil || before != after {
		t.Fatalf("unqualified ref changed during blocked result: %q -> %q (%v)", before, after, err)
	}
	for _, slot := range []string{"new", "fail"} {
		if _, err := os.Lstat(filepath.Join(gameRoot, slot)); !os.IsNotExist(err) {
			t.Fatalf("unqualified reference failure mutated %s slot: %v", slot, err)
		}
	}
	if _, err := os.Lstat(filepath.Join(gameRoot, "log")); !os.IsNotExist(err) {
		t.Fatalf("unqualified reference failure appended game history: %v", err)
	}
}

func TestRunCommitMiSTerAcceptsQualifiedReferenceAcrossRBFs(t *testing.T) {
	root := t.TempDir()
	progressRoot := filepath.Join(root, "progress")
	if err := os.Mkdir(progressRoot, 0750); err != nil {
		t.Fatal(err)
	}
	if err := GuardCaptureTarget(progressRoot, "mister"); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(progressRoot, "log"), 0750); err != nil {
		t.Fatal(err)
	}
	log, err := OpenCommitLog(progressRoot, strings.Repeat("a", 40))
	if err != nil {
		t.Fatal(err)
	}
	defer log.Close()
	first := makeRunCommitPreparedGame(t, root, "alpha")
	driverA := &runCommitTestDriver{root: root}
	driverB := &runCommitTestDriver{root: root}
	boards := []PoolBoard{{Key: "board-a", Host: "192.0.2.1", Driver: driverA}, {Key: "board-b", Host: "192.0.2.2", Driver: driverB}}
	cfg := runCommitTestConfig(progressRoot)
	qualification := CaptureQualification{Target: "mister", Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", Qualified: true}
	deps := MiSTerCommitDeps{Qualification: qualification, Boards: boards, CoordinatorOptions: CaptureCoordinatorOptions{CaptureTimeout: 5 * time.Second, CleanupTimeout: 5 * time.Second}, PrivateWorkRoot: filepath.Join(root, "private")}
	if _, err = RunCommitMiSTer(context.Background(), log, []MiSTerPreparedGame{first}, cfg, deps, MiSTerRunPolicy{Manual: true, RunScopeID: "scope-new"}); err != nil {
		t.Fatal(err)
	}
	firstLane := log.Progress.CaptureRuns[captureRunLaneForTest(log.Progress, "scope-new")]
	var candidate MiSTerFinalizationPlan
	for _, item := range firstLane.Finalizations {
		if item.Plan != nil {
			candidate = *item.Plan.Clone()
			break
		}
	}
	if candidate.CandidateDigest == "" {
		t.Fatal("first run did not retain candidate provenance")
	}
	gameRoot := filepath.Join(progressRoot, "fake", "alpha")
	refDir := filepath.Join(gameRoot, "ref")
	if err := copy_tree(filepath.Join(gameRoot, "new"), refDir); err != nil {
		t.Fatal(err)
	}
	provenanceBytes, err := json.MarshalIndent(candidate.Candidate, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(gameRoot, "ref", "reference-provenance.json"), append(provenanceBytes, '\n'), 0640); err != nil {
		t.Fatal(err)
	}
	second := makeRunCommitPreparedGame(t, root, "alpha", "rebuild")
	if first.Job.Session.RBF.SHA256 == second.Job.Session.RBF.SHA256 {
		t.Fatal("test fixture did not vary the test RBF")
	}
	firstTestDefinition, err := miSTerTestDefinitionID(first.Job.Session)
	if err != nil {
		t.Fatal(err)
	}
	secondTestDefinition, err := miSTerTestDefinitionID(second.Job.Session)
	if err != nil {
		t.Fatal(err)
	}
	if firstTestDefinition != secondTestDefinition {
		t.Fatal("semantic test definition incorrectly includes test RBF bytes")
	}
	if _, err := RunCommitMiSTer(context.Background(), log, []MiSTerPreparedGame{second}, cfg, deps, MiSTerRunPolicy{Manual: true, RunScopeID: "scope-rebuild"}); err != nil {
		t.Fatalf("qualified matching reference rejected across RBFs: %v", err)
	}
	if _, err := os.Stat(filepath.Join(gameRoot, "new")); !os.IsNotExist(err) {
		t.Fatalf("matching pass did not clear new slot: %v", err)
	}
	if _, err := os.Stat(filepath.Join(gameRoot, "fail")); !os.IsNotExist(err) {
		t.Fatalf("matching pass did not clear fail slot: %v", err)
	}
	if _, err := os.Stat(filepath.Join(gameRoot, "ref")); err != nil {
		t.Fatalf("matching pass changed or removed approved ref: %v", err)
	}
	history, err := os.ReadFile(filepath.Join(gameRoot, "log"))
	if err != nil || strings.Count(string(history), "\n") != 2 {
		t.Fatalf("expected one history row per qualified run: %q (%v)", history, err)
	}
	driverA.pixelBias, driverB.pixelBias = 1, 1
	third := makeRunCommitPreparedGame(t, root, "alpha", "mismatch")
	if _, err := RunCommitMiSTer(context.Background(), log, []MiSTerPreparedGame{third}, cfg, deps, MiSTerRunPolicy{Manual: true, RunScopeID: "scope-mismatch"}); err != nil {
		t.Fatalf("compare mismatching qualified candidate: %v", err)
	}
	if _, err := os.Stat(filepath.Join(gameRoot, "fail")); err != nil {
		t.Fatalf("mismatching candidate did not publish fail slot: %v", err)
	}
	if _, err := os.Stat(filepath.Join(gameRoot, "new")); !os.IsNotExist(err) {
		t.Fatalf("mismatching candidate left new slot: %v", err)
	}
	finalRefDigest, err := digestOwnedTree(filepath.Join(gameRoot, "ref"))
	if err != nil || finalRefDigest == "absent" {
		t.Fatalf("mismatch changed approved ref: %q (%v)", finalRefDigest, err)
	}
	history, err = os.ReadFile(filepath.Join(gameRoot, "log"))
	if err != nil || strings.Count(string(history), "\n") != 3 {
		t.Fatalf("expected mismatch to append one exact history row: %q (%v)", history, err)
	}
}

func TestRunCommitMiSTerNoReferenceQualityFailureStaysPrivate(t *testing.T) {
	root := t.TempDir()
	progressRoot := filepath.Join(root, "progress")
	if err := os.Mkdir(progressRoot, 0750); err != nil {
		t.Fatal(err)
	}
	if err := GuardCaptureTarget(progressRoot, "mister"); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(progressRoot, "log"), 0750); err != nil {
		t.Fatal(err)
	}
	log, err := OpenCommitLog(progressRoot, strings.Repeat("a", 40))
	if err != nil {
		t.Fatal(err)
	}
	defer log.Close()
	prepared := []MiSTerPreparedGame{makeRunCommitPreparedGame(t, root, "alpha")}
	driverA, driverB := &runCommitTestDriver{root: root, black: true}, &runCommitTestDriver{root: root, black: true}
	boards := []PoolBoard{{Key: "board-a", Host: "192.0.2.1", Driver: driverA}, {Key: "board-b", Host: "192.0.2.2", Driver: driverB}}
	cfg := runCommitTestConfig(progressRoot)
	qualification := CaptureQualification{Target: "mister", Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", Qualified: true}
	deps := MiSTerCommitDeps{Qualification: qualification, Boards: boards, CoordinatorOptions: CaptureCoordinatorOptions{CaptureTimeout: 5 * time.Second, CleanupTimeout: 5 * time.Second}, PrivateWorkRoot: filepath.Join(root, "private")}
	if _, err := RunCommitMiSTer(context.Background(), log, prepared, cfg, deps, MiSTerRunPolicy{Manual: true, RunScopeID: "scope-black"}); err != nil {
		t.Fatal(err)
	}
	gameRoot := filepath.Join(progressRoot, "fake", "alpha")
	for _, slot := range []string{"new", "fail", "ref", "log"} {
		if _, err := os.Lstat(filepath.Join(gameRoot, slot)); !os.IsNotExist(err) {
			t.Fatalf("no-ref quality failure wrote shared %s: %v", slot, err)
		}
	}
	lane := log.Progress.CaptureRuns[captureRunLaneForTest(log.Progress, "scope-black")]
	summary := lane.Games["fake/alpha"]
	if !lane.Complete || summary.Result != Fail || summary.Stage != "quality" || summary.Message == "" {
		t.Fatalf("private quality failure is missing from lane summary: %+v", lane)
	}
	if len(lane.Finalizations) != 1 {
		t.Fatalf("private failure did not retain its finalization intent: %+v", lane.Finalizations)
	}
	for _, item := range lane.Finalizations {
		if item.Plan.Effect != MiSTerEffectPrivateFailure || item.Plan.CandidateLocator == "" {
			t.Fatalf("private failure evidence is not retained: %+v", item.Plan)
		}
	}
}

func TestRunCommitMiSTerRecoversCrashBoundariesWithoutRecapture(t *testing.T) {
	t.Run("pending-directory-sync", func(t *testing.T) {
		f := newRunCommitRecoveryFixture(t, "scope-pending-sync")
		failed := false
		f.deps.CoordinatorOptions.SyncDirectory = func(path string) error {
			if !failed && pendingSerialPlan(f.log.Progress) {
				failed = true
				return os.ErrInvalid
			}
			return sync_capture_progress_dir(path)
		}
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil || !failed {
			t.Fatalf("pending directory-sync failure was not observed: failed=%v err=%v", failed, err)
		}
		f.assertNoSharedEffects(t)
		f.retry(t)
		f.assertOneResult(t)
		f.assertCaptureCalls(t, 1)
	})

	t.Run("slots-applied-before-history", func(t *testing.T) {
		f := newRunCommitRecoveryFixture(t, "scope-slots-history")
		f.failOnce("after-slots")
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil {
			t.Fatal("after-slots crash hook did not interrupt the transaction")
		}
		f.assertNewSlot(t)
		f.assertHistoryRows(t, 0)
		f.retry(t)
		f.assertOneResult(t)
		f.assertCaptureCalls(t, 1)
	})

	t.Run("partial-history-tail", func(t *testing.T) {
		f := newRunCommitRecoveryFixture(t, "scope-partial-history")
		f.failOnce("after-slots")
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil {
			t.Fatal("after-slots crash hook did not interrupt the transaction")
		}
		plan := f.onlyPendingPlan(t)
		cut := len(plan.History.Row) / 2
		if cut == 0 {
			t.Fatal("history test row is too small")
		}
		if err := os.WriteFile(f.historyPath(), []byte(plan.History.Row[:cut]), 0640); err != nil {
			t.Fatal(err)
		}
		f.retry(t)
		f.assertHistoryRows(t, 1)
		got, err := os.ReadFile(f.historyPath())
		if err != nil || string(got) != plan.History.Row {
			t.Fatalf("partial history recovery did not complete exact planned row: %q (%v)", got, err)
		}
		f.assertOneResult(t)
		f.assertCaptureCalls(t, 1)
	})

	t.Run("full-history-before-complete-marker", func(t *testing.T) {
		f := newRunCommitRecoveryFixture(t, "scope-full-history")
		f.failOnce("after-history")
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil {
			t.Fatal("after-history crash hook did not interrupt the transaction")
		}
		f.assertHistoryRows(t, 1)
		f.retry(t)
		f.assertHistoryRows(t, 1)
		f.assertOneResult(t)
		f.assertCaptureCalls(t, 1)
	})

	t.Run("pool-completion-directory-sync", func(t *testing.T) {
		f := newRunCommitRecoveryFixture(t, "scope-pool-complete-sync")
		failed := false
		f.deps.CoordinatorOptions.SyncDirectory = func(path string) error {
			for _, lane := range f.log.Progress.CaptureRuns {
				if !failed && lane.FinalizationKind == miSTerSerialResultsKind && lane.Complete {
					failed = true
					return os.ErrInvalid
				}
			}
			return sync_capture_progress_dir(path)
		}
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil || !failed {
			t.Fatalf("pool completion sync failure was not observed: failed=%v err=%v", failed, err)
		}
		f.retry(t)
		f.assertOneResult(t)
		f.assertCaptureCalls(t, 1)
	})
}

func TestRunCommitMiSTerResumesZeroSummaryLaneAfterOldKeyRecovery(t *testing.T) {
	root := t.TempDir()
	progressRoot := filepath.Join(root, "progress")
	if err := os.Mkdir(progressRoot, 0750); err != nil {
		t.Fatal(err)
	}
	if err := GuardCaptureTarget(progressRoot, "mister"); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(progressRoot, "log"), 0750); err != nil {
		t.Fatal(err)
	}
	commit := strings.Repeat("a", 40)
	log, err := OpenCommitLog(progressRoot, commit)
	if err != nil {
		t.Fatal(err)
	}
	prepared := []MiSTerPreparedGame{makeRunCommitPreparedGame(t, root, "alpha"), makeRunCommitPreparedGame(t, root, "beta")}
	entered := make(chan struct{}, 2)
	var reconcileCalls int
	driverA := &runCommitTestDriver{root: root}
	driverA.captureHook = func(ctx context.Context, attempt AttemptKey, session PreparedSession) (SessionCapture, error) {
		entered <- struct{}{}
		<-entered
		return SessionCapture{Key: attempt, Cleanup: SessionCleanup{Confirmed: true}}, errors.New("injected keyed cancellation")
	}
	driverB := &runCommitTestDriver{root: root}
	driverB.captureHook = func(ctx context.Context, attempt AttemptKey, session PreparedSession) (SessionCapture, error) {
		entered <- struct{}{}
		<-ctx.Done()
		return SessionCapture{}, errors.New("injected transfer loss")
	}
	driverB.reconcileHook = func(ctx context.Context, attempt AttemptKey) (SessionCleanup, error) {
		reconcileCalls++
		if reconcileCalls == 1 {
			return SessionCleanup{Required: true}, nil
		}
		return SessionCleanup{Confirmed: true}, nil
	}
	boards := []PoolBoard{{Key: "board-a", Host: "192.0.2.1", Driver: driverA}, {Key: "board-b", Host: "192.0.2.2", Driver: driverB}}
	cfg := runCommitTestConfig(progressRoot)
	qualification := CaptureQualification{Target: "mister", Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", Qualified: true}
	deps := MiSTerCommitDeps{Qualification: qualification, Boards: boards, CoordinatorOptions: CaptureCoordinatorOptions{CaptureTimeout: 5 * time.Second, CleanupTimeout: 5 * time.Second}, PrivateWorkRoot: filepath.Join(root, "private")}
	policy := MiSTerRunPolicy{Manual: true, RunScopeID: "scope-zero-summary"}
	if _, err = RunCommitMiSTer(context.Background(), log, prepared, cfg, deps, policy); err == nil {
		t.Fatal("unfinished sibling failures were reported complete")
	}
	laneKey := captureRunLaneForTest(log.Progress, policy.RunScopeID)
	lane := log.Progress.CaptureRuns[laneKey]
	if len(lane.Snapshot.Checkpoint.Completed) != 0 || len(lane.Games) != 0 || lane.Games == nil {
		t.Fatalf("first run did not retain a non-complete, empty summary inventory: %+v", lane)
	}
	var oldUnknown PoolBoardQuarantine
	for _, item := range lane.Snapshot.Checkpoint.Quarantined {
		oldUnknown = item
	}
	if oldUnknown.Attempt.SessionID == "" {
		t.Fatal("first run did not persist the unknown attempt key")
	}
	if err = log.Close(); err != nil {
		t.Fatal(err)
	}
	log, err = OpenCommitLog(progressRoot, commit)
	if err != nil {
		t.Fatal(err)
	}
	lane = log.Progress.CaptureRuns[laneKey]
	if lane.Games != nil {
		t.Fatal("empty summary map was unexpectedly encoded despite omitempty")
	}
	if err = validateCaptureRunLane(laneKey, lane); err != nil {
		t.Fatalf("public lane validation rejected a saved lane with no finalized summaries: %v", err)
	}
	var recoveredCleanup SessionCleanup
	for _, board := range boards {
		if board.Key == oldUnknown.Board {
			recoveredCleanup, err = board.Driver.Reconcile(context.Background(), oldUnknown.Attempt)
			break
		}
	}
	if err != nil || !recoveredCleanup.Confirmed || recoveredCleanup.Required {
		t.Fatalf("reconcile exact old key: cleanup=%+v err=%v", recoveredCleanup, err)
	}
	lane = log.Progress.CaptureRuns[laneKey]
	if err = lane.Snapshot.Checkpoint.RecoverBoard(RecoveryWitness{Board: oldUnknown.Board, Attempt: oldUnknown.Attempt, CaptureGeneration: qualification.Generation, FullRBFReloaded: true, Reconciled: recoveredCleanup}); err != nil {
		t.Fatalf("recover exact old quarantined key: %v", err)
	}
	log.Progress.CaptureRuns[laneKey] = lane
	if err = log.Save(); err != nil {
		t.Fatal(err)
	}
	if err = log.Close(); err != nil {
		t.Fatal(err)
	}
	log, err = OpenCommitLog(progressRoot, commit)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = log.Close() })
	driverA.captureHook, driverB.captureHook, driverB.reconcileHook = nil, nil, nil
	for index := range prepared {
		prepared[index].Job.SessionID += "-retry"
		prepared[index].Job.Nonce += "-retry"
	}
	policy.Retry = true
	snapshot, err := RunCommitMiSTer(context.Background(), log, prepared, cfg, deps, policy)
	if err != nil || len(snapshot.Checkpoint.Completed) != 2 {
		t.Fatalf("fresh-identity retry failed after reopening the empty summary lane: snapshot=%+v err=%v", snapshot.Checkpoint, err)
	}
	newSlots := make(map[string]string, len(prepared))
	for _, game := range prepared {
		history, readErr := os.ReadFile(filepath.Join(progressRoot, "fake", game.Job.Session.Setname, "log"))
		if readErr != nil || strings.Count(string(history), "\n") != 1 {
			t.Fatalf("retry produced duplicate or missing history for %s: %q (%v)", game.Job.Session.Setname, history, readErr)
		}
		newPath := filepath.Join(progressRoot, "fake", game.Job.Session.Setname, "new")
		newSlots[game.Job.Session.Setname], readErr = digestOwnedTree(newPath)
		if readErr != nil {
			t.Fatalf("retry did not publish result images for %s: %v", game.Job.Session.Setname, readErr)
		}
	}
	if _, err = RunCommitMiSTer(context.Background(), log, prepared, cfg, deps, policy); err != nil {
		t.Fatalf("completed retry resume failed: %v", err)
	}
	for _, game := range prepared {
		history, readErr := os.ReadFile(filepath.Join(progressRoot, "fake", game.Job.Session.Setname, "log"))
		if readErr != nil || strings.Count(string(history), "\n") != 1 {
			t.Fatalf("completed resume duplicated history for %s: %q (%v)", game.Job.Session.Setname, history, readErr)
		}
		newDigest, readErr := digestOwnedTree(filepath.Join(progressRoot, "fake", game.Job.Session.Setname, "new"))
		if readErr != nil || newDigest != newSlots[game.Job.Session.Setname] {
			t.Fatalf("completed resume changed result images for %s: %s -> %s (%v)", game.Job.Session.Setname, newSlots[game.Job.Session.Setname], newDigest, readErr)
		}
	}
	completeLane := log.Progress.CaptureRuns[laneKey].Clone()
	completeLane.Games = nil
	if err = validateCaptureRunLane(laneKey, completeLane); err == nil || !strings.Contains(err.Error(), "missing summaries") {
		t.Fatalf("completed lane without its finalized summaries was accepted: %v", err)
	}
}

func TestRunCommitMiSTerRejectsTamperedPendingRecovery(t *testing.T) {
	t.Run("slot-mismatch", func(t *testing.T) {
		f := newRunCommitRecoveryFixture(t, "scope-slot-tamper")
		f.failOnce("after-slots")
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil {
			t.Fatal("after-slots crash hook did not interrupt the transaction")
		}
		path := filepath.Join(f.gameRoot(), "new", png_capture_name(100, 99))
		if err := os.WriteFile(path, []byte("tampered"), 0640); err != nil {
			t.Fatal(err)
		}
		before, err := digestOwnedTree(filepath.Join(f.gameRoot(), "new"))
		if err != nil {
			t.Fatal(err)
		}
		if _, err = RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy.retryPolicy()); err == nil {
			t.Fatal("tampered result slot was accepted during recovery")
		}
		after, err := digestOwnedTree(filepath.Join(f.gameRoot(), "new"))
		if err != nil || before != after {
			t.Fatalf("blocked recovery changed the mismatching slot: %s -> %s (%v)", before, after, err)
		}
	})

	t.Run("reference-appeared-after-intent", func(t *testing.T) {
		f := newRunCommitRecoveryFixture(t, "scope-ref-tamper")
		f.failOnce("after-pending")
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil {
			t.Fatal("after-pending crash hook did not interrupt the transaction")
		}
		ref := filepath.Join(f.gameRoot(), "ref")
		if err := os.MkdirAll(ref, 0750); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(ref, "unexpected"), []byte("new reference"), 0640); err != nil {
			t.Fatal(err)
		}
		before, err := digestOwnedTree(ref)
		if err != nil {
			t.Fatal(err)
		}
		if _, err = RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy.retryPolicy()); err == nil {
			t.Fatal("reference change after intent was accepted during recovery")
		}
		after, err := digestOwnedTree(ref)
		if err != nil || before != after {
			t.Fatalf("blocked recovery changed the reference: %s -> %s (%v)", before, after, err)
		}
		if _, err := os.Lstat(filepath.Join(f.gameRoot(), "new")); !os.IsNotExist(err) {
			t.Fatalf("reference mismatch still applied result slot: %v", err)
		}
	})

	t.Run("history-tail-mismatch", func(t *testing.T) {
		f := newRunCommitRecoveryFixture(t, "scope-history-tamper")
		f.failOnce("after-slots")
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil {
			t.Fatal("after-slots crash hook did not interrupt the transaction")
		}
		unrelated := []byte("unrelated history tail\n")
		if err := os.WriteFile(f.historyPath(), unrelated, 0640); err != nil {
			t.Fatal(err)
		}
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy.retryPolicy()); err == nil {
			t.Fatal("unrelated history tail was accepted during recovery")
		}
		got, err := os.ReadFile(f.historyPath())
		if err != nil || string(got) != string(unrelated) {
			t.Fatalf("blocked history recovery changed unrelated tail: %q (%v)", got, err)
		}
	})

	t.Run("foreign-staging-tree", func(t *testing.T) {
		f := newRunCommitRecoveryFixture(t, "scope-foreign-staging")
		f.failOnce("after-pending")
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil {
			t.Fatal("after-pending failure did not leave a pending plan")
		}
		staging := filepath.Join(f.gameRoot(), "new.staging")
		if err := os.MkdirAll(staging, 0750); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(staging, "foreign"), []byte("unrelated staging"), 0640); err != nil {
			t.Fatal(err)
		}
		before, err := digestOwnedTree(staging)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy.retryPolicy()); err == nil {
			t.Fatal("foreign staging tree was accepted as an owned PublishComplete state")
		}
		after, err := digestOwnedTree(staging)
		if err != nil || before != after {
			t.Fatalf("blocked recovery changed foreign staging tree: %s -> %s (%v)", before, after, err)
		}
	})
}

func TestRunCommitMiSTerCompletedResumeRevalidatesReferenceAbsence(t *testing.T) {
	f := newRunCommitRecoveryFixture(t, "scope-complete-ref-revalidate")
	if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err != nil {
		t.Fatal(err)
	}
	ref := filepath.Join(f.gameRoot(), "ref")
	if err := os.MkdirAll(ref, 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(ref, "unexpected"), []byte("appeared after finalization"), 0640); err != nil {
		t.Fatal(err)
	}
	before, err := digestOwnedTree(ref)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy.retryPolicy()); err == nil {
		t.Fatal("completed result resume skipped changed reference-state validation")
	}
	after, err := digestOwnedTree(ref)
	if err != nil || before != after {
		t.Fatalf("blocked completed resume changed the reference: %s -> %s (%v)", before, after, err)
	}
	f.assertCaptureCalls(t, 1)
}

func TestRunCommitMiSTerHistoryRecoveryRejectsSubstitutedSymlink(t *testing.T) {
	f := newRunCommitRecoveryFixture(t, "scope-history-symlink")
	f.failOnce("after-slots")
	if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil {
		t.Fatal("after-slots failure did not leave a pending history transaction")
	}
	outside := filepath.Join(f.root, "unrelated-empty-file")
	if err := os.WriteFile(outside, nil, 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, f.historyPath()); err != nil {
		t.Fatal(err)
	}
	if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy.retryPolicy()); err == nil {
		t.Fatal("recovery followed substituted history symlink")
	}
	data, err := os.ReadFile(outside)
	if err != nil || len(data) != 0 {
		t.Fatalf("blocked recovery wrote outside the owned game directory: %q (%v)", data, err)
	}
}

func TestRunCommitMiSTerRecoversActualPublishCompleteRenameWindows(t *testing.T) {
	for _, window := range []string{"fail-cleared", "old-staging-window"} {
		t.Run(window, func(t *testing.T) {
			f := newRunCommitRecoveryFixture(t, "scope-publish-window-"+window)
			for _, slot := range []string{"new", "fail"} {
				path := filepath.Join(f.gameRoot(), slot)
				if err := os.MkdirAll(path, 0750); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(path, "previous.txt"), []byte("previous "+slot), 0640); err != nil {
					t.Fatal(err)
				}
			}
			f.failOnce("after-pending")
			if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil {
				t.Fatal("after-pending failure did not preserve the durable slot intent")
			}
			plan := f.onlyPendingPlan(t)
			if err := os.RemoveAll(filepath.Join(f.gameRoot(), "fail")); err != nil {
				t.Fatal(err)
			}
			if window == "old-staging-window" {
				destination := filepath.Join(f.gameRoot(), "new")
				if err := copy_tree(plan.CandidateLocator, destination+".staging"); err != nil {
					t.Fatal(err)
				}
				if err := os.Rename(destination, destination+".old"); err != nil {
					t.Fatal(err)
				}
			}
			if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy.retryPolicy()); err != nil {
				t.Fatalf("could not recover owned PublishComplete window: %v", err)
			}
			f.assertOneResult(t)
			f.assertCaptureCalls(t, 1)
		})
	}
}

func TestRunCommitMiSTerRecoversFailAndPassClearPartialTransitions(t *testing.T) {
	t.Run("fail-cleared-new-before-fail-replacement", func(t *testing.T) {
		f := newRunCommitRecoveryFixture(t, "scope-prime-fail")
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err != nil {
			t.Fatal(err)
		}
		installRunCommitReference(t, f)
		writeRunCommitSentinelSlots(t, f)
		f.driverA.pixelBias, f.driverB.pixelBias = 1, 1
		f.prepared[0].Job.SessionID, f.prepared[0].Job.Nonce = "fail-session", "fail-nonce"
		policy := MiSTerRunPolicy{Manual: true, RunScopeID: "scope-partial-fail"}
		f.failOnce("after-pending")
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, policy); err == nil {
			t.Fatal("after-pending fail publication did not stop")
		}
		plan := f.onlyPendingPlan(t)
		if plan.Effect != MiSTerEffectFail {
			t.Fatalf("test candidate did not select FAIL effect: %s", plan.Effect)
		}
		if err := os.RemoveAll(filepath.Join(f.gameRoot(), "new")); err != nil {
			t.Fatal(err)
		}
		policy.Retry = true
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, policy); err != nil {
			t.Fatalf("could not recover FAIL after its first clear step: %v", err)
		}
		if _, err := os.Stat(filepath.Join(f.gameRoot(), "new")); !os.IsNotExist(err) {
			t.Fatalf("FAIL recovery left the new slot: %v", err)
		}
		if _, err := os.Stat(filepath.Join(f.gameRoot(), "fail")); err != nil {
			t.Fatalf("FAIL recovery did not publish fail slot: %v", err)
		}
		f.assertHistoryRows(t, 2)
		f.assertCaptureCalls(t, 2)
	})

	t.Run("pass-clears-one-of-two-slots", func(t *testing.T) {
		f := newRunCommitRecoveryFixture(t, "scope-prime-pass")
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err != nil {
			t.Fatal(err)
		}
		installRunCommitReference(t, f)
		writeRunCommitSentinelSlots(t, f)
		f.prepared[0].Job.SessionID, f.prepared[0].Job.Nonce = "pass-session", "pass-nonce"
		policy := MiSTerRunPolicy{Manual: true, RunScopeID: "scope-partial-pass"}
		f.failOnce("after-pending")
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, policy); err == nil {
			t.Fatal("after-pending pass-clear did not stop")
		}
		plan := f.onlyPendingPlan(t)
		if plan.Effect != MiSTerEffectPassClear {
			t.Fatalf("test candidate did not select PASS-clear effect: %s", plan.Effect)
		}
		if err := os.RemoveAll(filepath.Join(f.gameRoot(), "new")); err != nil {
			t.Fatal(err)
		}
		policy.Retry = true
		if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, policy); err != nil {
			t.Fatalf("could not recover PASS after first slot clear: %v", err)
		}
		for _, slot := range []string{"new", "fail"} {
			if _, err := os.Lstat(filepath.Join(f.gameRoot(), slot)); !os.IsNotExist(err) {
				t.Fatalf("PASS-clear recovery left %s slot: %v", slot, err)
			}
		}
		f.assertHistoryRows(t, 2)
		f.assertCaptureCalls(t, 2)
	})
}

func installRunCommitReference(t *testing.T, f *runCommitRecoveryFixture) {
	t.Helper()
	if err := copy_tree(filepath.Join(f.gameRoot(), "new"), filepath.Join(f.gameRoot(), "ref")); err != nil {
		t.Fatal(err)
	}
	var provenance MiSTerReferenceProvenance
	for _, lane := range f.log.Progress.CaptureRuns {
		for _, item := range lane.Finalizations {
			if item.Plan != nil {
				provenance = item.Plan.Candidate
			}
		}
	}
	if provenance.TestDefinitionID == "" {
		t.Fatal("initial qualified candidate has no reference provenance")
	}
	data, err := json.Marshal(provenance)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(f.gameRoot(), "ref", "reference-provenance.json"), data, 0640); err != nil {
		t.Fatal(err)
	}
}

func writeRunCommitSentinelSlots(t *testing.T, f *runCommitRecoveryFixture) {
	t.Helper()
	for _, slot := range []string{"new", "fail"} {
		path := filepath.Join(f.gameRoot(), slot)
		if err := os.RemoveAll(path); err != nil {
			t.Fatal(err)
		}
		if err := os.MkdirAll(path, 0750); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(path, "previous.txt"), []byte("previous "+slot), 0640); err != nil {
			t.Fatal(err)
		}
	}
}

func TestRunCommitMiSTerLaneKindSelectionAndManualScopeIsolation(t *testing.T) {
	root := t.TempDir()
	progressRoot := filepath.Join(root, "progress")
	if err := os.Mkdir(progressRoot, 0750); err != nil {
		t.Fatal(err)
	}
	if err := GuardCaptureTarget(progressRoot, "mister"); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(progressRoot, "log"), 0750); err != nil {
		t.Fatal(err)
	}
	log, err := OpenCommitLog(progressRoot, strings.Repeat("a", 40))
	if err != nil {
		t.Fatal(err)
	}
	defer log.Close()
	prepared := makeRunCommitPreparedGame(t, root, "alpha")
	qualification := CaptureQualification{Target: "mister", Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", Qualified: true}
	job := prepared.Job
	job.SessionID, job.Nonce = "private-session", "private-nonce"
	privateDriver := &coordinatorTestDriver{}
	privateEffects := newCoordinatorTestEffects()
	privateCoordinator, err := NewCaptureCoordinator(log, qualification, []PoolBoard{poolBoard("board-a", "192.0.2.1", privateDriver)}, privateEffects, CaptureCoordinatorOptions{CaptureTimeout: 5 * time.Second, CleanupTimeout: 5 * time.Second})
	if err != nil {
		t.Fatal(err)
	}
	if _, err = privateCoordinator.Run(context.Background(), []PoolJob{job}); err != nil {
		t.Fatalf("complete private-v1 lane: %v", err)
	}
	privateKey := privateCoordinator.laneKey
	if privateKey == captureRunLaneForTest(log.Progress, "scope-serial") {
		t.Fatal("serial-results lane reused private-v1 identity")
	}
	serialDriverA, serialDriverB := &runCommitTestDriver{root: root}, &runCommitTestDriver{root: root}
	boards := []PoolBoard{{Key: "board-a", Host: "192.0.2.1", Driver: serialDriverA}, {Key: "board-b", Host: "192.0.2.2", Driver: serialDriverB}}
	cfg := runCommitTestConfig(progressRoot)
	deps := MiSTerCommitDeps{Qualification: qualification, Boards: boards, CoordinatorOptions: CaptureCoordinatorOptions{CaptureTimeout: 5 * time.Second, CleanupTimeout: 5 * time.Second}, PrivateWorkRoot: filepath.Join(root, "private")}
	prepared.Job.SessionID, prepared.Job.Nonce = "serial-session", "serial-nonce"
	policy := MiSTerRunPolicy{Manual: true, RunScopeID: "scope-serial"}
	if _, err = RunCommitMiSTer(context.Background(), log, []MiSTerPreparedGame{prepared}, cfg, deps, policy); err != nil {
		t.Fatalf("private completion incorrectly satisfied serial result lane: %v", err)
	}
	serialKey := captureRunLaneForTest(log.Progress, policy.RunScopeID)
	if serialKey == privateKey || log.Progress.CaptureRuns[privateKey].FinalizationKind != "" || !log.Progress.CaptureRuns[serialKey].Complete {
		t.Fatalf("private and serial completion markers were conflated: private=%+v serial=%+v", log.Progress.CaptureRuns[privateKey], log.Progress.CaptureRuns[serialKey])
	}
	serialDriverA.mu.Lock()
	serialCallsA := serialDriverA.calls
	serialDriverA.mu.Unlock()
	serialDriverB.mu.Lock()
	serialCallsB := serialDriverB.calls
	serialDriverB.mu.Unlock()
	if serialCallsA+serialCallsB != 1 {
		t.Fatalf("serial lane did not dispatch fresh attempt after private completion: %d", serialCallsA+serialCallsB)
	}
	if _, err = RunCommitMiSTer(context.Background(), log, []MiSTerPreparedGame{prepared}, cfg, deps, policy); err == nil || !strings.Contains(err.Error(), "fresh run scope") {
		t.Fatalf("manual refresh reused a retired scope without retry: %v", err)
	}
	changed := makeRunCommitPreparedGame(t, root, "beta")
	changed.Job.SessionID, changed.Job.Nonce = "another-session", "another-nonce"
	prepared.Job.SessionID, prepared.Job.Nonce = "partial-session", "partial-nonce"
	if _, err = RunCommitMiSTer(context.Background(), log, []MiSTerPreparedGame{prepared, changed}, cfg, deps, MiSTerRunPolicy{Manual: true, RunScopeID: "scope-partial"}); err != nil {
		t.Fatalf("partial manual selection should complete in its own scope: %v", err)
	}
	partial := log.Progress.CaptureRuns[captureRunLaneForTest(log.Progress, "scope-partial")]
	if !partial.Complete || len(partial.Selected) != 2 || len(partial.Games) != 2 {
		t.Fatalf("manual scope claims a different selection: %+v", partial)
	}
	if _, err = RunCommitMiSTer(context.Background(), log, []MiSTerPreparedGame{prepared}, cfg, deps, MiSTerRunPolicy{RunScopeID: "unstable-auto"}); err == nil || !strings.Contains(err.Error(), "stable") {
		t.Fatalf("automatic run accepted an unstable scope: %v", err)
	}
}

type runCommitRecoveryFixture struct {
	log      *CommitLog
	prepared []MiSTerPreparedGame
	cfg      Config
	deps     MiSTerCommitDeps
	policy   MiSTerRunPolicy
	driverA  *runCommitTestDriver
	driverB  *runCommitTestDriver
	root     string
}

func newRunCommitRecoveryFixture(t *testing.T, scope string) *runCommitRecoveryFixture {
	t.Helper()
	root := t.TempDir()
	progressRoot := filepath.Join(root, "progress")
	if err := os.Mkdir(progressRoot, 0750); err != nil {
		t.Fatal(err)
	}
	if err := GuardCaptureTarget(progressRoot, "mister"); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(progressRoot, "log"), 0750); err != nil {
		t.Fatal(err)
	}
	log, err := OpenCommitLog(progressRoot, strings.Repeat("a", 40))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = log.Close() })
	prepared := []MiSTerPreparedGame{makeRunCommitPreparedGame(t, root, "alpha")}
	driverA, driverB := &runCommitTestDriver{root: root}, &runCommitTestDriver{root: root}
	boards := []PoolBoard{{Key: "board-a", Host: "192.0.2.1", Driver: driverA}, {Key: "board-b", Host: "192.0.2.2", Driver: driverB}}
	cfg := runCommitTestConfig(progressRoot)
	qualification := CaptureQualification{Target: "mister", Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", Qualified: true}
	deps := MiSTerCommitDeps{Qualification: qualification, Boards: boards, CoordinatorOptions: CaptureCoordinatorOptions{CaptureTimeout: 5 * time.Second, CleanupTimeout: 5 * time.Second}, PrivateWorkRoot: filepath.Join(root, "private")}
	return &runCommitRecoveryFixture{log: log, prepared: prepared, cfg: cfg, deps: deps, policy: MiSTerRunPolicy{Manual: true, RunScopeID: scope}, driverA: driverA, driverB: driverB, root: root}
}

func (f *runCommitRecoveryFixture) failOnce(stage string) {
	failed := false
	f.deps.FailureHook = func(observed string) error {
		if !failed && observed == stage {
			failed = true
			return os.ErrInvalid
		}
		return nil
	}
}

func (f *runCommitRecoveryFixture) retry(t *testing.T) {
	t.Helper()
	policy := f.policy
	policy.Retry = true
	if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, policy); err != nil {
		t.Fatalf("resume serial finalization: %v", err)
	}
}

func (f *runCommitRecoveryFixture) retryPolicy() MiSTerRunPolicy {
	policy := f.policy
	policy.Retry = true
	return policy
}

func (f *runCommitRecoveryFixture) gameRoot() string {
	return filepath.Join(f.log.Root, "fake", "alpha")
}

func (f *runCommitRecoveryFixture) historyPath() string {
	return filepath.Join(f.gameRoot(), "log")
}

func (f *runCommitRecoveryFixture) onlyPendingPlan(t *testing.T) MiSTerFinalizationPlan {
	t.Helper()
	for _, lane := range f.log.Progress.CaptureRuns {
		for _, item := range lane.Finalizations {
			if item.State == CaptureFinalizationPending && item.Plan != nil {
				return *item.Plan.Clone()
			}
		}
	}
	t.Fatal("no pending serial plan found")
	return MiSTerFinalizationPlan{}
}

func (f *runCommitRecoveryFixture) assertNewSlot(t *testing.T) {
	t.Helper()
	if _, err := os.Stat(filepath.Join(f.gameRoot(), "new")); err != nil {
		t.Fatalf("new slot was not applied: %v", err)
	}
}

func (f *runCommitRecoveryFixture) assertNoSharedEffects(t *testing.T) {
	t.Helper()
	for _, name := range []string{"new", "fail", "ref", "log"} {
		if _, err := os.Lstat(filepath.Join(f.gameRoot(), name)); !os.IsNotExist(err) {
			t.Fatalf("pending persistence failure changed shared %s: %v", name, err)
		}
	}
}

func (f *runCommitRecoveryFixture) assertHistoryRows(t *testing.T, want int) {
	t.Helper()
	data, err := os.ReadFile(f.historyPath())
	if want == 0 && os.IsNotExist(err) {
		return
	}
	if err != nil || strings.Count(string(data), "\n") != want {
		t.Fatalf("history row count mismatch: got %q want %d (%v)", data, want, err)
	}
}

func (f *runCommitRecoveryFixture) assertOneResult(t *testing.T) {
	t.Helper()
	f.assertNewSlot(t)
	f.assertHistoryRows(t, 1)
	lane := f.log.Progress.CaptureRuns[captureRunLaneForTest(f.log.Progress, f.policy.RunScopeID)]
	if !lane.Complete || len(lane.Games) != 1 {
		t.Fatalf("serial selection did not complete with one game summary: %+v", lane)
	}
}

func (f *runCommitRecoveryFixture) assertCaptureCalls(t *testing.T, want int) {
	t.Helper()
	f.driverA.mu.Lock()
	a := f.driverA.calls
	f.driverA.mu.Unlock()
	f.driverB.mu.Lock()
	b := f.driverB.calls
	f.driverB.mu.Unlock()
	if a+b != want {
		t.Fatalf("unexpected recapture count: A=%d B=%d want total %d", a, b, want)
	}
}

func pendingSerialPlan(progress *Progress) bool {
	for _, lane := range progress.CaptureRuns {
		if lane.FinalizationKind != miSTerSerialResultsKind {
			continue
		}
		for _, item := range lane.Finalizations {
			if item.State == CaptureFinalizationPending && item.Plan != nil {
				return true
			}
		}
	}
	return false
}

func (policy MiSTerRunPolicy) retryPolicy() MiSTerRunPolicy {
	policy.Retry = true
	return policy
}

func runMiSTerCommitFixture(t *testing.T, sets []string, reverse bool) (map[string]string, string) {
	t.Helper()
	root := t.TempDir()
	progressRoot := filepath.Join(root, "progress")
	if err := os.Mkdir(progressRoot, 0750); err != nil {
		t.Fatal(err)
	}
	if err := GuardCaptureTarget(progressRoot, "mister"); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(progressRoot, "log"), 0750); err != nil {
		t.Fatal(err)
	}
	const commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	log, err := OpenCommitLog(progressRoot, commit)
	if err != nil {
		t.Fatal(err)
	}
	defer log.Close()
	prepared := make([]MiSTerPreparedGame, 0, len(sets))
	for _, setname := range sets {
		prepared = append(prepared, makeRunCommitPreparedGame(t, root, setname))
	}
	entered := make(chan string, len(sets))
	returned := make(chan string, len(sets))
	releases := map[string]chan struct{}{}
	for _, setname := range sets {
		releases[setname] = make(chan struct{})
	}
	driverA := &runCommitTestDriver{root: root, entered: entered, returned: returned, release: releases["alpha"]}
	driverB := &runCommitTestDriver{root: root, entered: entered, returned: returned, release: releases["beta"]}
	boards := []PoolBoard{{Key: "board-a", Host: "192.0.2.1", Driver: driverA}, {Key: "board-b", Host: "192.0.2.2", Driver: driverB}}
	cfg := runCommitTestConfig(progressRoot)
	qualification := CaptureQualification{Target: "mister", Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", Qualified: true}
	deps := MiSTerCommitDeps{Qualification: qualification, Boards: boards,
		CoordinatorOptions: CaptureCoordinatorOptions{CaptureTimeout: 5 * time.Second, CleanupTimeout: 5 * time.Second},
		PrivateWorkRoot:    filepath.Join(root, "private")}
	log.Progress.AutomaticComplete = true
	log.Progress.Status = "legacy-done"
	log.Progress.Games["legacy/kept"] = ProgressGame{Result: Pass, Input: "old-input", Output: "old-output"}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	result := make(chan error, 1)
	go func() {
		_, runErr := RunCommitMiSTer(ctx, log, prepared, cfg, deps, MiSTerRunPolicy{Manual: true, RunScopeID: "scope-r1"})
		result <- runErr
	}()
	seen := map[string]bool{}
	for range sets {
		select {
		case setname := <-entered:
			seen[setname] = true
		case <-ctx.Done():
			t.Fatal("two boards did not enter capture concurrently")
		}
	}
	if !seen["alpha"] || !seen["beta"] {
		t.Fatalf("both selected jobs were not active: %v", seen)
	}
	order := []string{"alpha", "beta"}
	if reverse {
		order = []string{"beta", "alpha"}
	}
	for _, setname := range order {
		close(releases[setname])
		if setname == order[0] && len(order) > 1 {
			select {
			case returnedSet := <-returned:
				if returnedSet != setname {
					t.Fatalf("first released driver returned %s, want %s", returnedSet, setname)
				}
			case err := <-result:
				t.Fatalf("RunCommit exited before the second board was released: %v", err)
			case <-ctx.Done():
				t.Fatal(ctx.Err())
			}
		}
	}
	select {
	case err := <-result:
		if err != nil {
			t.Fatal(err)
		}
	case <-ctx.Done():
		t.Fatal(ctx.Err())
	}
	laneKey := captureRunLaneForTest(log.Progress, "scope-r1")
	if !log.Progress.CaptureRuns[laneKey].Complete {
		t.Fatal("serial lane did not durably mark its selected inventory complete")
	}
	if _, err := RunCommitMiSTer(ctx, log, prepared, cfg, deps, MiSTerRunPolicy{Manual: true, Retry: true, RunScopeID: "scope-r1"}); err != nil {
		t.Fatalf("resume completed MiSTer lane: %v", err)
	}
	driverA.mu.Lock()
	callsA := driverA.calls
	driverA.mu.Unlock()
	driverB.mu.Lock()
	callsB := driverB.calls
	driverB.mu.Unlock()
	if callsA != 1 || callsB != 1 {
		t.Fatalf("completed resume redispatched capture: board A=%d B=%d", callsA, callsB)
	}
	if !log.Progress.AutomaticComplete || log.Progress.Status != "legacy-done" || log.Progress.Games["legacy/kept"].Input != "old-input" {
		t.Fatal("MiSTer lane changed legacy progress fields")
	}
	outputs := map[string]string{}
	for _, setname := range sets {
		gameRoot := filepath.Join(progressRoot, "fake", setname)
		if _, err := os.Stat(filepath.Join(gameRoot, "new")); err != nil {
			t.Fatalf("new slot for %s was not published: %v", setname, err)
		}
		if _, err := os.Stat(filepath.Join(gameRoot, "ref")); !os.IsNotExist(err) {
			t.Fatalf("new candidate unexpectedly changed ref for %s", setname)
		}
		history, err := os.ReadFile(filepath.Join(progressRoot, "fake", setname, "log"))
		if err != nil || strings.Count(string(history), "\n") != 1 {
			t.Fatalf("expected exactly one history row for %s, got %q (%v)", setname, history, err)
		}
		outputs[setname] = log.Progress.CaptureRuns[captureRunLaneForTest(log.Progress, "scope-r1")].Games["fake/"+setname].OutputDigest
	}
	return outputs, strings.Join(order, ",")
}

func makeRunCommitPreparedGame(t *testing.T, root, setname string, suffixes ...string) MiSTerPreparedGame {
	t.Helper()
	suffix := ""
	if len(suffixes) > 0 {
		suffix = suffixes[0]
	}
	inputs := filepath.Join(root, "fixtures", setname+suffix)
	if err := os.MkdirAll(inputs, 0700); err != nil {
		t.Fatal(err)
	}
	core := "fake"
	rbf := filepath.Join(inputs, "jtfake.rbf")
	mra := filepath.Join(inputs, setname+".mra")
	if err := os.WriteFile(rbf, []byte("RBF:"+setname+suffix), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(mra, []byte("<mame><name>"+setname+"</name><setname>"+setname+"</setname><rbf>jtfake</rbf></mame>"), 0600); err != nil {
		t.Fatal(err)
	}
	rbfSHA, err := FileSHA256(rbf)
	if err != nil {
		t.Fatal(err)
	}
	mraSHA, err := FileSHA256(mra)
	if err != nil {
		t.Fatal(err)
	}
	mainSHA := strings.Repeat("c", 64)
	assets := &MiSTerGameAssets{
		OriginalMRA:  MiSTerAssetFile{Role: FixtureOriginalMRA, Name: filepath.Base(mra), Path: mra, SHA256: mraSHA},
		LaunchMRA:    MiSTerAssetFile{Role: FixtureLaunchMRA, Name: filepath.Base(mra), Path: mra, SHA256: mraSHA},
		NativeStatus: MiSTerNativeStatusProof{MainSHA256: mainSHA, ExpectedCoreName: setname, NativeStatusPath: filepath.Join(miSTerNativeConfigRoot, setname+".CFG")},
	}
	packed := testPackedCAB(t, 1, nil, 200)
	packedSHA := sha256.Sum256(packed)
	entries, err := CapturePlanEntries(200, 0, 100, 250)
	if err != nil {
		t.Fatal(err)
	}
	plan, err := EncodeCapturePlan(packed, entries)
	if err != nil {
		t.Fatal(err)
	}
	cab, err := inspectPackedCAB(packed)
	if err != nil {
		t.Fatal(err)
	}
	profile := Profile{Setname: setname, Video: 200, Startup: 0}
	session := PreparedSession{Core: core, Setname: setname, Profile: profile,
		OriginalMRA: FixtureDigest{Role: FixtureOriginalMRA, SHA256: mraSHA}, LaunchMRA: FixtureDigest{Role: FixtureLaunchMRA, SHA256: mraSHA},
		RBF: FixtureDigest{Role: FixtureRBF, SHA256: rbfSHA}, NativeVideoStatusSeed: NativeVideoStatusSeedFixture(),
		CAB:         CABIdentity{EffectiveSHA256: strings.Repeat("d", 64), PackedSHA256: hex.EncodeToString(packedSHA[:]), PayloadCRC32: cab.payloadCRC32, ExporterVersion: "test-v1", TotalFrames: cab.totalFrames},
		Checkpoints: []uint32{100, 200}, Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888,
		Paths: SessionPaths{OriginalMRA: mra, LaunchMRA: mra, StagingDir: filepath.Join(inputs, "capture-plan.jtcp")}}
	if err = os.WriteFile(session.Paths.StagingDir, plan, 0600); err != nil {
		t.Fatal(err)
	}
	if err = session.Validate(); err != nil {
		t.Fatal(err)
	}
	spec := GameSpec{Setname: setname, RBF: rbf, Profile: profile, MisterAssets: assets}
	if err = validateMiSTerAssets(core, setname, spec, session); err != nil {
		t.Fatal(err)
	}
	return MiSTerPreparedGame{Job: PoolJob{Session: session, SessionID: "sid-" + setname + suffix, Nonce: "nonce-" + setname + suffix}, Spec: spec, PackedCAB: packed, CapturePlan: plan}
}

func runCommitTestConfig(root string) Config {
	return Config{Target: "mister", Root: root, Boards: []MiSTerBoardConfig{
		{ID: "board-a", Host: "192.0.2.1", User: "jt", SSHConfig: "/tmp/ssh-config", RemoteStagingRoot: "/tmp/board-a"},
		{ID: "board-b", Host: "192.0.2.2", User: "jt", SSHConfig: "/tmp/ssh-config", RemoteStagingRoot: "/tmp/board-b"},
	}, CaptureContract: &MiSTerCaptureContract{Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", QualificationEvidence: "/tmp/qualification.json", MainSHA256: strings.Repeat("c", 64), CommandTimeoutSeconds: 5, LoadTimeoutSeconds: 5, CaptureTimeoutSeconds: 5, CleanupTimeoutSeconds: 5, MaxHoldMS: 250, ExpectedBridgeCount: 2}}
}

func captureRunLaneForTest(progress *Progress, scope string) string {
	key, _ := captureLaneKeyForKind(CaptureQualification{Target: "mister", Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", Qualified: true}, miSTerSerialResultsKind, scope)
	return key
}

var _ = color.RGBA{}
