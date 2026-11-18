/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"golang.org/x/sys/unix"
)

type miSTerSerialResultEffects struct {
	log           *CommitLog
	root          string
	privateRoot   string
	qualification CaptureQualification
	games         map[PoolJobKey]MiSTerPreparedGame
	hosts         map[BoardKey]string
	clock         func() time.Time
	failureHook   func(string) error
}

func (e *miSTerSerialResultEffects) PrepareSerialResult(ctx context.Context, operationKey string, qualification CaptureQualification, jobKey PoolJobKey, portableID string, attempt AttemptKey, session PreparedSession, capture SessionCapture) (*MiSTerFinalizationPlan, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	prepared, ok := e.games[jobKey]
	if !ok {
		return nil, fmt.Errorf("serial result has no detached prepared input for %s", jobKey)
	}
	if qualification != e.qualification || session.Core != jobKey.Core || session.Setname != jobKey.Setname {
		return nil, fmt.Errorf("serial result does not match prepared selection or qualification")
	}
	identity, err := session.PortableIdentity()
	if err != nil || identity != portableID {
		return nil, fmt.Errorf("serial result portable identity changed after preparation")
	}
	if err := capture.ValidateEnvelope(attempt); err != nil {
		return nil, err
	}
	if capture.Cleanup.Required || !capture.Cleanup.Confirmed {
		return nil, fmt.Errorf("serial result cannot finalize before confirmed transport cleanup")
	}
	if capture.Receipt.Generation != qualification.Generation || capture.Receipt.CaptureConvention != qualification.Convention ||
		capture.Receipt.CABPayloadCRC32 != session.CAB.PayloadCRC32 {
		return nil, fmt.Errorf("capture receipt does not match the qualified prepared session")
	}
	planHash := sha256.Sum256(prepared.CapturePlan)
	if capture.Receipt.PlanSHA256 != hex.EncodeToString(planHash[:]) {
		return nil, fmt.Errorf("capture receipt plan digest differs from prepared plan")
	}
	if len(capture.Receipt.Images) == 0 || len(capture.Receipt.Images) != len(session.Checkpoints) || len(capture.PNGPaths) != len(capture.Receipt.Images) {
		return nil, fmt.Errorf("capture receipt image count differs from prepared schedule")
	}
	if e.clock == nil {
		e.clock = time.Now
	}
	gameRoot := filepath.Join(e.root, session.Core, session.Setname)
	if err := ensureSafeOwnedPath(e.root, gameRoot); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(filepath.Dir(e.privateRoot), 0700); err != nil {
		return nil, err
	}
	locator, err := e.stageCandidate(operationKey, capture, session)
	if err != nil {
		return nil, err
	}
	candidateSet, candidateProvenance, err := e.candidateSet(locator, capture, session, qualification)
	if err != nil {
		return nil, err
	}
	testDefinition, err := miSTerTestDefinitionID(session)
	if err != nil {
		return nil, err
	}
	candidateProvenance.TestDefinitionID = testDefinition
	if e.log != nil {
		candidateProvenance.SourceCommit = e.log.Progress.Commit
	}
	if err := candidateProvenance.Validate(); err != nil {
		return nil, err
	}
	candidateDigest, err := canonicalMiSTerDigest(candidateProvenance)
	if err != nil {
		return nil, err
	}
	qualifiedSlotsBefore, err := e.slotDigests(gameRoot)
	if err != nil {
		return nil, err
	}
	refSet, _, refDigest, refProvenanceSHA, refCRC, hasRef, err := e.readCompatibleReference(gameRoot, session, qualification, testDefinition)
	if err != nil {
		return nil, err
	}
	qualityFailure, ocrFailure, _, err := captureQualityContext(ctx, candidateSet, session.Profile.Startup)
	if err != nil {
		return nil, fmt.Errorf("validate capture quality: %w", err)
	}
	var effect MiSTerFinalizationEffect
	var outcome Outcome
	var stage, message string
	switch {
	case qualityFailure != "":
		outcome, stage, message = Fail, "quality", qualityFailure
		if hasRef {
			effect = MiSTerEffectFail
		} else {
			effect = MiSTerEffectPrivateFailure
		}
	case !hasRef && ocrFailure != "":
		outcome, stage, message, effect = Fail, "quality", ocrFailure, MiSTerEffectPrivateFailure
	case !hasRef:
		outcome, stage, message, effect = New, "reference", "no approved reference", MiSTerEffectNew
	default:
		diffs, compareErr := CompareCaptureSets(refSet, candidateSet, session.Profile.Startup)
		if compareErr != nil {
			return nil, fmt.Errorf("compare qualified reference: %w", compareErr)
		}
		if len(diffs) != 0 {
			outcome, stage = Fail, "compare"
			message = fmt.Sprintf("%d/%d frames differ", len(diffs), len(comparable_captures(candidateSet, session.Profile.Startup)))
			effect = MiSTerEffectFail
		} else {
			outcome, stage, message, effect = Pass, "compare", "all comparable checkpoints match exactly", MiSTerEffectPassClear
			if ocrFailure != "" {
				message += "; approved reference matches despite OCR warning"
			}
		}
	}
	before, err := e.slotDigests(gameRoot)
	if err != nil {
		return nil, err
	}
	if !equalStringMaps(qualifiedSlotsBefore, before) {
		return nil, fmt.Errorf("result slots changed while candidate/reference qualification was in progress")
	}
	if err := validateReferenceSnapshot(e.root, gameRoot, before["ref"], refProvenanceSHA); err != nil {
		return nil, err
	}
	after := cloneStringMap(before)
	switch effect {
	case MiSTerEffectNew:
		if hasRef {
			return nil, fmt.Errorf("qualified reference appeared before NEW planning")
		}
		after["new"] = candidatePngDirectoryDigest(candidateSet, candidateProvenance)
		after["fail"] = "absent"
	case MiSTerEffectFail:
		after["new"] = "absent"
		after["fail"] = candidatePngDirectoryDigest(candidateSet, candidateProvenance)
	case MiSTerEffectPassClear:
		after["new"], after["fail"] = "absent", "absent"
	}
	if candidateDigest == "" {
		return nil, fmt.Errorf("candidate digest is empty")
	}
	summary := MiSTerGameSummary{Result: outcome, PortableID: portableID, OutputDigest: candidateDigest, OperationKey: operationKey, Attempt: attempt, Stage: stage, Message: message}
	plan := &MiSTerFinalizationPlan{
		Summary: summary, Effect: effect, CandidateLocator: locator, Candidate: candidateProvenance,
		TestDefinitionID: testDefinition, CandidateDigest: candidateDigest, ReferenceDigest: refDigest,
		ReferenceProvenanceSHA256: refProvenanceSHA, BeforeSlotDigests: before, AfterSlotDigests: after,
	}
	if effect != MiSTerEffectPrivateFailure {
		row, historyPath, err := e.historyRow(session, outcome, refCRC, e.clock(), attempt.Board)
		if err != nil {
			return nil, err
		}
		prefixBytes, prefixSHA, err := historyPrefix(e.root, historyPath)
		if err != nil {
			return nil, err
		}
		rowSum := sha256.Sum256([]byte(row))
		plan.History = MiSTerHistoryWitness{PrefixBytes: prefixBytes, PrefixSHA256: prefixSHA, Row: row, RowSHA256: hex.EncodeToString(rowSum[:])}
	}
	if err := plan.Validate(); err != nil {
		return nil, err
	}
	return plan, nil
}

func (e *miSTerSerialResultEffects) CommitSerialResult(ctx context.Context, operationKey string, plan MiSTerFinalizationPlan, _ PreparedSession, _ SessionCapture) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", err
	}
	if plan.Summary.OperationKey != operationKey {
		return "", fmt.Errorf("serial result operation key differs from immutable plan")
	}
	if err := e.applyPlan(plan); err != nil {
		return "", err
	}
	return miSTerResultDigest(plan)
}

func (e *miSTerSerialResultEffects) RevalidateSerialResult(ctx context.Context, operationKey string, plan MiSTerFinalizationPlan, resultDigest string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if plan.Summary.OperationKey != operationKey {
		return fmt.Errorf("serial result operation key differs from immutable plan")
	}
	want, err := miSTerResultDigest(plan)
	if err != nil || want != resultDigest {
		return fmt.Errorf("serial result digest does not match its immutable plan")
	}
	if err := e.validatePrivateCandidate(plan); err != nil {
		return err
	}
	gameRoot := filepath.Join(e.root, plan.Candidate.Core, plan.Candidate.Setname)
	if err := ensureSafeOwnedPath(e.root, gameRoot); err != nil {
		return err
	}
	if err := validatePlannedReference(e.root, gameRoot, plan); err != nil {
		return err
	}
	current, err := e.slotDigests(gameRoot)
	if err != nil {
		return err
	}
	if !equalStringMaps(current, plan.AfterSlotDigests) {
		return fmt.Errorf("serial result slots changed after finalization")
	}
	if plan.Effect != MiSTerEffectPrivateFailure {
		if err := verifyHistoryApplied(e.root, e.historyPath(plan.Candidate.Core, plan.Candidate.Setname), plan.History); err != nil {
			return err
		}
	}
	return nil
}

func (e *miSTerSerialResultEffects) ReconcileSerialResult(ctx context.Context, operationKey string, plan MiSTerFinalizationPlan) (string, bool, error) {
	if err := ctx.Err(); err != nil {
		return "", false, err
	}
	if plan.Summary.OperationKey != operationKey {
		return "", false, fmt.Errorf("serial result operation key differs from immutable plan")
	}
	if err := e.applyPlan(plan); err != nil {
		return "", false, err
	}
	digest, err := miSTerResultDigest(plan)
	return digest, err == nil, err
}

func (e *miSTerSerialResultEffects) applyPlan(plan MiSTerFinalizationPlan) error {
	if err := plan.Validate(); err != nil {
		return err
	}
	if err := e.validatePrivateCandidate(plan); err != nil {
		return err
	}
	gameRoot := filepath.Join(e.root, plan.Candidate.Core, plan.Candidate.Setname)
	if err := ensureSafeOwnedPath(e.root, gameRoot); err != nil {
		return err
	}
	if err := validatePlannedReference(e.root, gameRoot, plan); err != nil {
		return err
	}
	if err := os.MkdirAll(gameRoot, 0750); err != nil {
		return err
	}
	if err := recoverOwnedSlotReplacement(gameRoot, plan); err != nil {
		return err
	}
	current, err := e.slotDigests(gameRoot)
	if err != nil {
		return err
	}
	if equalStringMaps(current, plan.BeforeSlotDigests) {
		if err := applyPlannedSlots(gameRoot, plan); err != nil {
			return err
		}
		if err := syncDir(gameRoot); err != nil {
			return err
		}
		current, err = e.slotDigests(gameRoot)
		if err != nil {
			return err
		}
	} else if !equalStringMaps(current, plan.AfterSlotDigests) {
		if err := validateOwnedPartialSlots(plan, current); err != nil {
			return err
		}
		if err := applyPlannedSlots(gameRoot, plan); err != nil {
			return err
		}
		if err := syncDir(gameRoot); err != nil {
			return err
		}
		current, err = e.slotDigests(gameRoot)
		if err != nil {
			return err
		}
		if !equalStringMaps(current, plan.AfterSlotDigests) {
			return fmt.Errorf("repaired serial result slots do not match the planned after state")
		}
	}
	if plan.Effect != MiSTerEffectPrivateFailure && e.failureHook != nil {
		if err := e.failureHook("after-slots"); err != nil {
			return fmt.Errorf("serial finalization interrupted after result-slot update: %w", err)
		}
	}
	if plan.Effect != MiSTerEffectPrivateFailure {
		if err := appendHistoryIdempotent(e.root, e.historyPath(plan.Candidate.Core, plan.Candidate.Setname), plan.History); err != nil {
			return err
		}
		if e.failureHook != nil {
			if err := e.failureHook("after-history"); err != nil {
				return fmt.Errorf("serial finalization interrupted after history append: %w", err)
			}
		}
	}
	return nil
}

func applyPlannedSlots(gameRoot string, plan MiSTerFinalizationPlan) error {
	switch plan.Effect {
	case MiSTerEffectPrivateFailure:
		return nil
	case MiSTerEffectNew:
		if _, err := os.Lstat(filepath.Join(gameRoot, "ref")); err == nil {
			return fmt.Errorf("ref appeared before serial NEW commit")
		} else if !os.IsNotExist(err) {
			return err
		}
		if err := PublishComplete(gameRoot, plan.CandidateLocator, New, nil); err != nil {
			return err
		}
	case MiSTerEffectFail:
		if err := PublishComplete(gameRoot, plan.CandidateLocator, Fail, nil); err != nil {
			return err
		}
	case MiSTerEffectPassClear:
		if err := clearResultSlots(gameRoot); err != nil {
			return err
		}
	default:
		return fmt.Errorf("unknown serial result effect %q", plan.Effect)
	}
	return nil
}

func (e *miSTerSerialResultEffects) validatePrivateCandidate(plan MiSTerFinalizationPlan) error {
	if err := plan.Candidate.Validate(); err != nil {
		return err
	}
	root, err := filepath.Abs(e.privateRoot)
	if err != nil {
		return err
	}
	locator, err := filepath.Abs(plan.CandidateLocator)
	if err != nil {
		return err
	}
	want := filepath.Join(root, "mister-candidates", plan.Summary.OperationKey)
	if locator != want || !strings.HasPrefix(locator, root+string(os.PathSeparator)) {
		return fmt.Errorf("private candidate locator is outside its owned operation directory")
	}
	if err := ensureNoSymlinkPath(root, locator); err != nil {
		return err
	}
	capture, provenance, err := readStagedCandidate(locator, plan.Candidate)
	if err != nil {
		return err
	}
	digest, err := canonicalMiSTerDigest(provenance)
	if err != nil || digest != plan.CandidateDigest {
		return fmt.Errorf("private candidate content no longer matches its finalization plan")
	}
	if plan.Effect == MiSTerEffectNew || plan.Effect == MiSTerEffectFail {
		treeDigest, err := digestOwnedTree(locator)
		if err != nil {
			return err
		}
		slot := "new"
		if plan.Effect == MiSTerEffectFail {
			slot = "fail"
		}
		if plan.AfterSlotDigests[slot] != treeDigest {
			return fmt.Errorf("private candidate files do not match the planned result-slot digest")
		}
	}
	if capture.Width == 0 {
		return fmt.Errorf("private candidate contains no decoded images")
	}
	return nil
}

func (e *miSTerSerialResultEffects) stageCandidate(operationKey string, capture SessionCapture, session PreparedSession) (string, error) {
	if !isSHA256Hex(operationKey) {
		return "", fmt.Errorf("invalid serial operation key")
	}
	dir := filepath.Join(e.privateRoot, "mister-candidates", operationKey)
	if err := ensureNoSymlinkPath(e.privateRoot, filepath.Dir(dir)); err != nil && !os.IsNotExist(err) {
		return "", err
	}
	if err := os.MkdirAll(filepath.Dir(dir), 0700); err != nil {
		return "", err
	}
	if _, err := os.Lstat(dir); err == nil {
		return dir, nil
	} else if !os.IsNotExist(err) {
		return "", err
	}
	staging, err := os.MkdirTemp(filepath.Dir(dir), operationKey+".staging-")
	if err != nil {
		return "", err
	}
	keep := false
	defer func() {
		if !keep {
			_ = os.RemoveAll(staging)
		}
	}()
	for index, record := range capture.Receipt.Images {
		if index >= len(capture.PNGPaths) || record.RequestedFrame != session.Checkpoints[index] {
			return "", fmt.Errorf("capture image order differs from prepared checkpoints")
		}
		name := png_capture_name(int(record.RequestedFrame), int(record.ActualFrame))
		if !safePreparedPNGName(name) {
			return "", fmt.Errorf("unsafe candidate image name")
		}
		fileInfo, statErr := os.Lstat(capture.PNGPaths[index])
		if statErr != nil || !fileInfo.Mode().IsRegular() || fileInfo.Mode()&os.ModeSymlink != 0 || record.PNGBytes <= 0 || fileInfo.Size() != record.PNGBytes {
			return "", fmt.Errorf("worker PNG %d does not match its receipt size", index)
		}
		if err := copySyncedRegular(capture.PNGPaths[index], filepath.Join(staging, name)); err != nil {
			return "", fmt.Errorf("stage capture image %d: %w", index, err)
		}
	}
	if err := syncDir(staging); err != nil {
		return "", err
	}
	if err := os.Rename(staging, dir); err != nil {
		if _, statErr := os.Lstat(dir); statErr == nil {
			return dir, nil
		}
		return "", err
	}
	keep = true
	if err := syncDir(filepath.Dir(dir)); err != nil {
		return "", err
	}
	return dir, nil
}

func (e *miSTerSerialResultEffects) candidateSet(locator string, capture SessionCapture, session PreparedSession, qualification CaptureQualification) (CaptureSet, MiSTerReferenceProvenance, error) {
	set := CaptureSet{Dir: locator, Format: "png"}
	provenance := MiSTerReferenceProvenance{Version: 1, CaptureProtocol: capture.Receipt.CaptureProtocol, Target: "mister", Core: session.Core, Setname: session.Setname, Generation: qualification.Generation, Convention: qualification.Convention, QualificationID: qualification.QualificationID}
	if capture.Receipt.CaptureProtocol != miSTerCaptureProtocolV2 || capture.Receipt.Epoch != 0 || len(capture.Receipt.Images) != len(session.Checkpoints) {
		return set, provenance, fmt.Errorf("fresh MiSTer candidate requires a complete v2 capture receipt")
	}
	var previousCheckpoint uint32
	for index, receipt := range capture.Receipt.Images {
		if index >= len(capture.PNGPaths) || receipt.Sequence != 0 || receipt.RequestedFrame == 0 || receipt.RequestedFrame != session.Checkpoints[index] || receipt.Checkpoint != receipt.RequestedFrame || receipt.Checkpoint <= previousCheckpoint || receipt.ActualFrame != receipt.RequestedFrame-1 ||
			receipt.Width == 0 || receipt.Height == 0 || receipt.Width > 512 || receipt.Height > 512 || receipt.Pitch < receipt.Width*3 || receipt.Slot > 2 || !receipt.Released || !receipt.PNGComplete {
			return set, provenance, fmt.Errorf("capture receipt image %d is incomplete or differs from the qualified schedule", index)
		}
		name := png_capture_name(int(receipt.RequestedFrame), int(receipt.ActualFrame))
		decoded, err := decode_capture_image(filepath.Join(locator, name))
		if err != nil {
			return set, provenance, fmt.Errorf("decode candidate checkpoint %d: %w", receipt.RequestedFrame, err)
		}
		if decoded.width != int(receipt.Width) || decoded.height != int(receipt.Height) {
			return set, provenance, fmt.Errorf("candidate checkpoint %d geometry differs from receipt", receipt.RequestedFrame)
		}
		source, err := decode_capture_image(capture.PNGPaths[index])
		if err != nil || source.width != decoded.width || source.height != decoded.height || decodedRGBDigest(source) != decodedRGBDigest(decoded) {
			return set, provenance, fmt.Errorf("staged candidate checkpoint %d differs from worker output", receipt.RequestedFrame)
		}
		if set.Width == 0 {
			set.Width, set.Height = decoded.width, decoded.height
		}
		if set.Width != decoded.width || set.Height != decoded.height {
			return set, provenance, fmt.Errorf("candidate geometry changes between checkpoints")
		}
		rgbDigest := decodedRGBDigest(decoded)
		set.Captures = append(set.Captures, CaptureRecord{Type: "capture", Requested: int(receipt.RequestedFrame), Actual: int(receipt.ActualFrame), Image: name})
		provenance.Images = append(provenance.Images, MiSTerImageProvenance{Sequence: receipt.Sequence, RequestedFrame: receipt.RequestedFrame, ActualFrame: receipt.ActualFrame, Checkpoint: receipt.Checkpoint, Width: receipt.Width, Height: receipt.Height, Pitch: receipt.Pitch, Slot: receipt.Slot, Mode: receipt.Mode, DescriptorCRC32: receipt.DescriptorCRC32, RGBSHA256: rgbDigest})
		previousCheckpoint = receipt.Checkpoint
	}
	return set, provenance, nil
}

func (e *miSTerSerialResultEffects) readCompatibleReference(gameRoot string, session PreparedSession, qualification CaptureQualification, testDefinition string) (CaptureSet, MiSTerReferenceProvenance, string, string, string, bool, error) {
	var empty CaptureSet
	ref := filepath.Join(gameRoot, "ref")
	info, err := os.Lstat(ref)
	if os.IsNotExist(err) {
		return empty, MiSTerReferenceProvenance{}, "", "", "--------", false, nil
	}
	if err != nil {
		return empty, MiSTerReferenceProvenance{}, "", "", "", false, err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return empty, MiSTerReferenceProvenance{}, "", "", "", false, fmt.Errorf("approved reference is not an owned regular directory")
	}
	provenancePath := filepath.Join(gameRoot, "ref", "reference-provenance.json")
	data, err := readOwnedFinalizerFile(e.root, provenancePath)
	if err != nil {
		return empty, MiSTerReferenceProvenance{}, "", "", "", false, fmt.Errorf("approved reference lacks trusted MiSTer provenance: %w", err)
	}
	var provenance MiSTerReferenceProvenance
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&provenance); err != nil {
		return empty, provenance, "", "", "", false, fmt.Errorf("decode reference provenance: %w", err)
	}
	var trailing any
	if err := decoder.Decode(&trailing); err != io.EOF {
		return empty, provenance, "", "", "", false, fmt.Errorf("reference provenance has trailing data")
	}
	if err := provenance.Validate(); err != nil || provenance.Core != session.Core || provenance.Setname != session.Setname || provenance.Generation != qualification.Generation || provenance.Convention != qualification.Convention || provenance.QualificationID != qualification.QualificationID || provenance.TestDefinitionID != testDefinition {
		return empty, provenance, "", "", "", false, fmt.Errorf("approved reference provenance is incompatible with this qualified test")
	}
	set, err := readMiSTerReferenceCaptureSet(ref, provenance, session.Checkpoints)
	if err != nil {
		return empty, provenance, "", "", "", false, fmt.Errorf("read approved reference: %w", err)
	}
	if len(set.Captures) != len(provenance.Images) {
		return empty, provenance, "", "", "", false, fmt.Errorf("approved reference image inventory differs from its provenance")
	}
	for index, record := range set.Captures {
		decoded, err := decode_capture_image(filepath.Join(ref, record.Image))
		if err != nil {
			return empty, provenance, "", "", "", false, err
		}
		image := provenance.Images[index]
		if record.Requested != int(image.RequestedFrame) || record.Actual != int(image.ActualFrame) || decoded.width != int(image.Width) || decoded.height != int(image.Height) || decodedRGBDigest(decoded) != image.RGBSHA256 {
			return empty, provenance, "", "", "", false, fmt.Errorf("approved reference pixels differ from provenance at checkpoint %d", record.Requested)
		}
	}
	digest, err := canonicalMiSTerDigest(provenance)
	if err != nil {
		return empty, provenance, "", "", "", false, err
	}
	provenanceSHA := sha256.Sum256(data)
	crc, err := reference_crc(ref)
	if err != nil {
		return empty, provenance, "", "", "", false, err
	}
	return set, provenance, digest, hex.EncodeToString(provenanceSHA[:]), crc, true, nil
}

func readMiSTerReferenceCaptureSet(dir string, provenance MiSTerReferenceProvenance, checkpoints []uint32) (CaptureSet, error) {
	set := CaptureSet{Dir: dir, Format: "png"}
	if len(provenance.Images) != len(checkpoints) {
		return set, fmt.Errorf("MiSTer reference provenance does not cover the prepared checkpoint schedule")
	}
	files, err := filepath.Glob(filepath.Join(dir, "frame_*.png"))
	if err != nil {
		return set, err
	}
	if len(files) != len(checkpoints) {
		return set, fmt.Errorf("MiSTer reference PNG inventory differs from the prepared checkpoint schedule")
	}
	expectedNames := make(map[string]bool, len(checkpoints))
	for index, image := range provenance.Images {
		if image.RequestedFrame == 0 || image.RequestedFrame != checkpoints[index] || image.ActualFrame != image.RequestedFrame-1 || image.Checkpoint != image.RequestedFrame {
			return set, fmt.Errorf("invalid MiSTer reference frame pair at sequence %d", image.Sequence)
		}
		name := png_capture_name(int(image.RequestedFrame), int(image.ActualFrame))
		expectedNames[name] = true
		decoded, err := decode_capture_image(filepath.Join(dir, name))
		if err != nil {
			return set, err
		}
		if decoded.width != int(image.Width) || decoded.height != int(image.Height) || decodedRGBDigest(decoded) != image.RGBSHA256 {
			return set, fmt.Errorf("MiSTer reference pixels differ from provenance at checkpoint %d", image.RequestedFrame)
		}
		if set.Width == 0 {
			set.Width, set.Height = decoded.width, decoded.height
		}
		if set.Width != decoded.width || set.Height != decoded.height {
			return set, fmt.Errorf("MiSTer reference geometry changes between checkpoints")
		}
		set.Captures = append(set.Captures, CaptureRecord{Type: "capture", Requested: int(image.RequestedFrame), Actual: int(image.ActualFrame), Image: name})
	}
	for _, path := range files {
		if !expectedNames[filepath.Base(path)] {
			return set, fmt.Errorf("MiSTer reference contains an unlisted PNG: %s", filepath.Base(path))
		}
	}
	return set, nil
}

func miSTerTestDefinitionID(session PreparedSession) (string, error) {
	profile := cloneProfile(session.Profile)
	profile.Inputs = ""
	options, err := canonicalIdentityMap(profile.Options)
	if err != nil {
		return "", err
	}
	profile.Options = options
	fixtures := append([]FixtureDigest(nil), session.Fixtures...)
	sort.Slice(fixtures, func(i, j int) bool {
		if fixtures[i].Role == fixtures[j].Role {
			return fixtures[i].SHA256 < fixtures[j].SHA256
		}
		return fixtures[i].Role < fixtures[j].Role
	})
	identity := struct {
		Core                  string            `json:"core"`
		Setname               string            `json:"setname"`
		Profile               Profile           `json:"profile"`
		OriginalMRA           FixtureDigest     `json:"original_mra"`
		Fixtures              []FixtureDigest   `json:"fixtures"`
		NativeVideoStatusSeed FixtureDigest     `json:"native_video_status_seed"`
		CAB                   CABIdentity       `json:"cab"`
		Checkpoints           []uint32          `json:"checkpoints"`
		Convention            CaptureConvention `json:"capture_convention"`
	}{session.Core, session.Setname, profile, session.OriginalMRA, fixtures, session.NativeVideoStatusSeed, session.CAB, append([]uint32(nil), session.Checkpoints...), session.Convention}
	return canonicalMiSTerDigest(identity)
}

func (e *miSTerSerialResultEffects) slotDigests(gameRoot string) (map[string]string, error) {
	result := make(map[string]string, 3)
	for _, slot := range []string{"new", "fail", "ref"} {
		path := filepath.Join(gameRoot, slot)
		for _, suffix := range []string{".old", ".staging"} {
			if _, err := os.Lstat(path + suffix); err == nil {
				return nil, fmt.Errorf("result slot %s has unresolved replacement recovery state", slot)
			} else if !os.IsNotExist(err) {
				return nil, err
			}
		}
		digest, err := digestOwnedTree(path)
		if err != nil {
			return nil, err
		}
		result[slot] = digest
	}
	return result, nil
}

func validatePlannedReference(root, gameRoot string, plan MiSTerFinalizationPlan) error {
	return validateReferenceSnapshot(root, gameRoot, plan.BeforeSlotDigests["ref"], plan.ReferenceProvenanceSHA256)
}

func validateReferenceSnapshot(root, gameRoot, expectedRefDigest, expectedSidecarSHA string) error {
	refDigest, err := digestOwnedTree(filepath.Join(gameRoot, "ref"))
	if err != nil {
		return err
	}
	if refDigest != expectedRefDigest {
		return fmt.Errorf("approved reference changed after serial intent was planned")
	}
	sidecar := filepath.Join(gameRoot, "ref", "reference-provenance.json")
	if expectedSidecarSHA == "" {
		if _, err := os.Lstat(sidecar); err == nil {
			return fmt.Errorf("reference provenance appeared after serial intent was planned")
		} else if !os.IsNotExist(err) {
			return err
		}
		return nil
	}
	data, err := readOwnedFinalizerFile(root, sidecar)
	if err != nil {
		return fmt.Errorf("approved reference provenance changed after serial intent was planned: %w", err)
	}
	if sha256Hex(data) != expectedSidecarSHA {
		return fmt.Errorf("approved reference provenance changed after serial intent was planned")
	}
	return nil
}

// recoverOwnedSlotReplacement accepts only PublishComplete's exact rename
// states, verified against the pending intent's before/after tree digests.
func recoverOwnedSlotReplacement(gameRoot string, plan MiSTerFinalizationPlan) error {
	target := ""
	switch plan.Effect {
	case MiSTerEffectNew:
		target = "new"
	case MiSTerEffectFail:
		target = "fail"
	default:
		for _, name := range []string{"new", "fail"} {
			if err := requireNoReplacementArtifacts(filepath.Join(gameRoot, name)); err != nil {
				return err
			}
		}
		return nil
	}
	for _, name := range []string{"new", "fail"} {
		if name != target {
			if err := requireNoReplacementArtifacts(filepath.Join(gameRoot, name)); err != nil {
				return err
			}
		}
	}
	destination := filepath.Join(gameRoot, target)
	oldPath, stagingPath := destination+".old", destination+".staging"
	destDigest, err := digestOwnedTree(destination)
	if err != nil {
		return err
	}
	oldDigest, err := digestOwnedTree(oldPath)
	if err != nil {
		return err
	}
	stagingDigest, err := digestOwnedTree(stagingPath)
	if err != nil {
		return err
	}
	before, after := plan.BeforeSlotDigests[target], plan.AfterSlotDigests[target]
	if before == "" || after == "" {
		return fmt.Errorf("serial slot intent lacks target digests")
	}
	if oldDigest == "absent" && stagingDigest == "absent" {
		return nil
	}
	if oldDigest != "absent" && oldDigest != before {
		return fmt.Errorf("replacement .old tree does not match the journaled previous slot")
	}
	if stagingDigest != "absent" && stagingDigest != after {
		return fmt.Errorf("replacement staging tree does not match the journaled candidate slot")
	}
	switch {
	case destDigest == after && oldDigest == before && stagingDigest == "absent":
		if err := os.RemoveAll(oldPath); err != nil {
			return err
		}
	case destDigest == "absent" && oldDigest == before && stagingDigest == after:
		if err := os.Rename(stagingPath, destination); err != nil {
			return err
		}
		if err := os.RemoveAll(oldPath); err != nil {
			return err
		}
	case destDigest == before && oldDigest == "absent" && stagingDigest == after:
		if err := os.RemoveAll(stagingPath); err != nil {
			return err
		}
	case destDigest == "absent" && oldDigest == before && stagingDigest == "absent":
		if err := os.Rename(oldPath, destination); err != nil {
			return err
		}
	default:
		return fmt.Errorf("replacement files do not match an owned PublishComplete rename window")
	}
	return syncDir(gameRoot)
}

func requireNoReplacementArtifacts(slot string) error {
	for _, path := range []string{slot + ".old", slot + ".staging"} {
		if _, err := os.Lstat(path); err == nil {
			return fmt.Errorf("unrelated result replacement artifact exists: %s", path)
		} else if !os.IsNotExist(err) {
			return err
		}
	}
	return nil
}

func readOwnedFinalizerFile(root, path string) ([]byte, error) {
	data, err := readOwnedFileIfExists(root, path)
	if os.IsNotExist(err) {
		return nil, fmt.Errorf("file does not exist")
	}
	return data, err
}

func readOwnedFileIfExists(root, path string) ([]byte, error) {
	if _, err := os.Lstat(filepath.Dir(path)); os.IsNotExist(err) {
		return nil, os.ErrNotExist
	} else if err != nil {
		return nil, err
	}
	directory, name, err := openOwnedParent(root, path)
	if err != nil {
		return nil, err
	}
	defer directory.Close()
	file, err := openOwnedRegularAt(directory, name, false)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	data, err := readOpenedFile(file)
	if err != nil {
		return nil, err
	}
	if err := verifyOpenedLeaf(directory, name, file); err != nil {
		return nil, err
	}
	return data, nil
}

func openOwnedParent(root, path string) (*os.File, string, error) {
	parent, name := filepath.Dir(path), filepath.Base(path)
	if !safePreparedPNGName(name) && name != "log" && name != "reference-provenance.json" {
		return nil, "", fmt.Errorf("unsafe owned file name")
	}
	if err := ensureSafeOwnedPath(root, parent); err != nil {
		return nil, "", err
	}
	if err := ensureNoSymlinkComponents(parent); err != nil {
		return nil, "", err
	}
	fd, err := unix.Open(parent, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		return nil, "", err
	}
	directory := os.NewFile(uintptr(fd), parent)
	openedInfo, err := directory.Stat()
	if err != nil {
		directory.Close()
		return nil, "", err
	}
	pathInfo, err := os.Lstat(parent)
	if err != nil || !pathInfo.IsDir() || pathInfo.Mode()&os.ModeSymlink != 0 || !os.SameFile(openedInfo, pathInfo) {
		directory.Close()
		if err != nil {
			return nil, "", err
		}
		return nil, "", fmt.Errorf("owned file parent changed during open")
	}
	return directory, name, nil
}

func openOwnedRegularAt(directory *os.File, name string, create bool) (*os.File, error) {
	for attempt := 0; attempt < 2; attempt++ {
		var before unix.Stat_t
		err := unix.Fstatat(int(directory.Fd()), name, &before, unix.AT_SYMLINK_NOFOLLOW)
		if err == nil {
			if before.Mode&unix.S_IFMT != unix.S_IFREG {
				return nil, fmt.Errorf("owned file is not a regular file")
			}
			flags := unix.O_RDONLY
			if create {
				flags = unix.O_RDWR
			}
			fd, openErr := unix.Openat(int(directory.Fd()), name, flags|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
			if openErr != nil {
				return nil, openErr
			}
			file := os.NewFile(uintptr(fd), name)
			var opened unix.Stat_t
			if statErr := unix.Fstat(fd, &opened); statErr != nil || opened.Mode&unix.S_IFMT != unix.S_IFREG || opened.Dev != before.Dev || opened.Ino != before.Ino {
				file.Close()
				if statErr != nil {
					return nil, statErr
				}
				return nil, fmt.Errorf("owned file identity changed while opening")
			}
			if err := verifyOpenedLeaf(directory, name, file); err != nil {
				file.Close()
				return nil, err
			}
			return file, nil
		}
		if !errors.Is(err, unix.ENOENT) || !create {
			return nil, err
		}
		fd, createErr := unix.Openat(int(directory.Fd()), name, unix.O_RDWR|unix.O_CREAT|unix.O_EXCL|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0640)
		if createErr == nil {
			file := os.NewFile(uintptr(fd), name)
			if err := verifyOpenedLeaf(directory, name, file); err != nil {
				file.Close()
				return nil, err
			}
			return file, nil
		}
		if !errors.Is(createErr, unix.EEXIST) {
			return nil, createErr
		}
	}
	return nil, fmt.Errorf("owned file changed repeatedly while opening")
}

func readOpenedFile(file *os.File) ([]byte, error) {
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		return nil, err
	}
	return io.ReadAll(file)
}

func verifyOpenedLeaf(directory *os.File, name string, file *os.File) error {
	if err := verifyOwnedDirectoryPath(directory); err != nil {
		return err
	}
	var opened, named unix.Stat_t
	if err := unix.Fstat(int(file.Fd()), &opened); err != nil {
		return err
	}
	if err := unix.Fstatat(int(directory.Fd()), name, &named, unix.AT_SYMLINK_NOFOLLOW); err != nil {
		return err
	}
	if opened.Mode&unix.S_IFMT != unix.S_IFREG || named.Mode&unix.S_IFMT != unix.S_IFREG || opened.Dev != named.Dev || opened.Ino != named.Ino {
		return fmt.Errorf("owned file path no longer names the opened regular file")
	}
	return nil
}

func verifyOwnedDirectoryPath(directory *os.File) error {
	if err := ensureNoSymlinkComponents(directory.Name()); err != nil {
		return err
	}
	opened, err := directory.Stat()
	if err != nil {
		return err
	}
	pathInfo, err := os.Lstat(directory.Name())
	if err != nil || !pathInfo.IsDir() || pathInfo.Mode()&os.ModeSymlink != 0 || !os.SameFile(opened, pathInfo) {
		if err != nil {
			return err
		}
		return fmt.Errorf("owned file parent changed after open")
	}
	return nil
}

func ensureNoSymlinkComponents(path string) error {
	abs, err := filepath.Abs(path)
	if err != nil {
		return err
	}
	volume := filepath.VolumeName(abs)
	current := volume + string(os.PathSeparator)
	rest := strings.TrimPrefix(abs, current)
	for _, part := range strings.Split(rest, string(os.PathSeparator)) {
		if part == "" || part == "." {
			continue
		}
		current = filepath.Join(current, part)
		info, err := os.Lstat(current)
		if os.IsNotExist(err) {
			return nil
		}
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("owned path contains a symlink component: %s", current)
		}
	}
	return nil
}

func validateOwnedPartialSlots(plan MiSTerFinalizationPlan, current map[string]string) error {
	if current["ref"] != plan.BeforeSlotDigests["ref"] {
		return fmt.Errorf("approved reference changed during partial result-slot transition")
	}
	newBefore, failBefore := plan.BeforeSlotDigests["new"], plan.BeforeSlotDigests["fail"]
	newAfter, failAfter := plan.AfterSlotDigests["new"], plan.AfterSlotDigests["fail"]
	newNow, failNow := current["new"], current["fail"]
	valid := false
	switch plan.Effect {
	case MiSTerEffectNew:
		// PublishComplete(New) clears fail before replacing new.
		valid = (newNow == newBefore && failNow == failBefore) ||
			(newNow == newBefore && failNow == failAfter) ||
			(newNow == newAfter && failNow == failAfter)
	case MiSTerEffectFail:
		// PublishComplete(Fail) clears new before replacing fail.
		valid = (newNow == newBefore && failNow == failBefore) ||
			(newNow == newAfter && failNow == failBefore) ||
			(newNow == newAfter && failNow == failAfter)
	case MiSTerEffectPassClear:
		valid = (newNow == newBefore || newNow == newAfter) && (failNow == failBefore || failNow == failAfter)
	default:
		return fmt.Errorf("serial effect has no owned partial slot transition")
	}
	if !valid {
		return fmt.Errorf("result slots match neither a journaled boundary nor an owned partial transition")
	}
	return nil
}

func (e *miSTerSerialResultEffects) historyPath(core, set string) string {
	return filepath.Join(e.root, core, set, "log")
}

func (e *miSTerSerialResultEffects) historyRow(session PreparedSession, outcome Outcome, refCRC string, at time.Time, board BoardKey) (string, string, error) {
	if !safeComponent(session.Core) || !safeComponent(session.Setname) || !valid_commit(e.log.Progress.Commit) {
		return "", "", fmt.Errorf("invalid MiSTer history identity")
	}
	host := e.hosts[board]
	if host == "" || strings.ContainsAny(host, " \t\r\n") {
		return "", "", fmt.Errorf("MiSTer attempt board %q has no single configured hostname", board)
	}
	row := fmt.Sprintf("%s %-13s %-11s %s %s\n", LogTime(at), LogKey(e.log.Progress.Commit, e.log.Progress.Dirty), strings.ToUpper(string(outcome)), refCRC, host)
	return row, e.historyPath(session.Core, session.Setname), nil
}

func historyPrefix(root, path string) (int64, string, error) {
	data, err := readOwnedFileIfExists(root, path)
	if os.IsNotExist(err) {
		sum := sha256.Sum256(nil)
		return 0, hex.EncodeToString(sum[:]), nil
	}
	if err != nil {
		return 0, "", err
	}
	sum := sha256.Sum256(data)
	return int64(len(data)), hex.EncodeToString(sum[:]), nil
}

func appendHistoryIdempotent(root, path string, witness MiSTerHistoryWitness) error {
	if witness.PrefixBytes < 0 || witness.PrefixBytes > 1<<31 {
		return fmt.Errorf("history witness has invalid prefix length")
	}
	directory, name, err := openOwnedParent(root, path)
	if err != nil {
		return err
	}
	defer directory.Close()
	var existing unix.Stat_t
	err = unix.Fstatat(int(directory.Fd()), name, &existing, unix.AT_SYMLINK_NOFOLLOW)
	if errors.Is(err, unix.ENOENT) {
		emptySHA := sha256Hex(nil)
		if witness.PrefixBytes != 0 || witness.PrefixSHA256 != emptySHA {
			return fmt.Errorf("history is missing its journaled prefix")
		}
	} else if err != nil {
		return err
	}
	file, err := openOwnedRegularAt(directory, name, true)
	if err != nil {
		return err
	}
	defer file.Close()
	if err := unix.Flock(int(file.Fd()), unix.LOCK_EX); err != nil {
		return err
	}
	defer unix.Flock(int(file.Fd()), unix.LOCK_UN)
	data, err := readOpenedFile(file)
	if err != nil {
		return err
	}
	if int64(len(data)) < witness.PrefixBytes {
		return fmt.Errorf("history is shorter than the journaled prefix")
	}
	prefix := data[:witness.PrefixBytes]
	if sha256Hex(prefix) != witness.PrefixSHA256 {
		return fmt.Errorf("history prefix changed since the transaction was planned")
	}
	row := []byte(witness.Row)
	tail := data[witness.PrefixBytes:]
	if len(tail) >= len(row) {
		if string(tail[:len(row)]) != witness.Row {
			return fmt.Errorf("history at the planned offset contains a different row")
		}
		if err := verifyOpenedLeaf(directory, name, file); err != nil {
			return err
		}
		if err := file.Sync(); err != nil {
			return err
		}
		if err := verifyOpenedLeaf(directory, name, file); err != nil {
			return err
		}
		return directory.Sync()
	}
	if len(tail) > 0 && !strings.HasPrefix(witness.Row, string(tail)) {
		return fmt.Errorf("history has an unrelated partial row at the planned offset")
	}
	if len(tail) == 0 || strings.HasPrefix(witness.Row, string(tail)) {
		if err := verifyOpenedLeaf(directory, name, file); err != nil {
			return err
		}
		latest, err := readOpenedFile(file)
		if err != nil {
			return err
		}
		if !bytes.Equal(latest, data) {
			return fmt.Errorf("history changed while preparing the journaled append")
		}
		if _, err := file.Seek(0, io.SeekEnd); err != nil {
			return err
		}
		if _, err := file.Write(row[len(tail):]); err != nil {
			return err
		}
		if err := file.Sync(); err != nil {
			return err
		}
		written, err := readOpenedFile(file)
		if err != nil {
			return err
		}
		want := append(append([]byte(nil), data...), row[len(tail):]...)
		if !bytes.Equal(written, want) {
			return fmt.Errorf("history bytes differ after the journaled append")
		}
		if err := verifyOpenedLeaf(directory, name, file); err != nil {
			return err
		}
		return directory.Sync()
	}
	return fmt.Errorf("history recovery state is ambiguous")
}

func verifyHistoryApplied(root, path string, witness MiSTerHistoryWitness) error {
	data, err := readOwnedFinalizerFile(root, path)
	if err != nil {
		return fmt.Errorf("read finalized history row: %w", err)
	}
	end := witness.PrefixBytes + int64(len(witness.Row))
	if int64(len(data)) < end || sha256Hex(data[:witness.PrefixBytes]) != witness.PrefixSHA256 || string(data[witness.PrefixBytes:end]) != witness.Row {
		return fmt.Errorf("finalized history row no longer matches its operation witness")
	}
	return nil
}

func (e *miSTerSerialResultEffects) readStagedCandidateForPlan(plan MiSTerFinalizationPlan) (CaptureSet, error) {
	set, _, err := readStagedCandidate(plan.CandidateLocator, plan.Candidate)
	return set, err
}

func readStagedCandidate(locator string, expected MiSTerReferenceProvenance) (CaptureSet, MiSTerReferenceProvenance, error) {
	set := CaptureSet{Dir: locator, Format: "png"}
	actual := expected
	actual.Images = nil
	for _, image := range expected.Images {
		name := png_capture_name(int(image.RequestedFrame), int(image.ActualFrame))
		if !safePreparedPNGName(name) {
			return set, actual, fmt.Errorf("unsafe image path in candidate provenance")
		}
		path := filepath.Join(locator, name)
		info, err := os.Lstat(path)
		if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 {
			return set, actual, fmt.Errorf("candidate image %s is missing or not regular", name)
		}
		decoded, err := decode_capture_image(path)
		if err != nil {
			return set, actual, err
		}
		if decoded.width != int(image.Width) || decoded.height != int(image.Height) || decodedRGBDigest(decoded) != image.RGBSHA256 {
			return set, actual, fmt.Errorf("candidate image %s changed from its saved RGB identity", name)
		}
		if set.Width == 0 {
			set.Width, set.Height = decoded.width, decoded.height
		}
		if set.Width != decoded.width || set.Height != decoded.height {
			return set, actual, fmt.Errorf("candidate geometry changed between images")
		}
		set.Captures = append(set.Captures, CaptureRecord{Type: "capture", Requested: int(image.RequestedFrame), Actual: int(image.ActualFrame), Image: name})
		actual.Images = append(actual.Images, image)
	}
	dirEntries, err := os.ReadDir(locator)
	if err != nil {
		return set, actual, err
	}
	if len(dirEntries) != len(expected.Images) {
		return set, actual, fmt.Errorf("private candidate directory contains unexpected files")
	}
	return set, actual, nil
}

func candidatePngDirectoryDigest(set CaptureSet, _ MiSTerReferenceProvenance) string {
	digest, err := digestOwnedTree(set.Dir)
	if err != nil {
		return ""
	}
	return digest
}

func canonicalMiSTerDigest(value any) (string, error) {
	data, err := json.Marshal(value)
	if err != nil {
		return "", err
	}
	return sha256Hex(data), nil
}

func miSTerResultDigest(plan MiSTerFinalizationPlan) (string, error) {
	value := struct {
		Kind       string                   `json:"kind"`
		Effect     MiSTerFinalizationEffect `json:"effect"`
		PortableID string                   `json:"portable_id"`
		Outcome    Outcome                  `json:"outcome"`
		Candidate  string                   `json:"candidate_digest"`
		Reference  string                   `json:"reference_digest"`
		Before     map[string]string        `json:"before_slots"`
		After      map[string]string        `json:"after_slots"`
	}{miSTerSerialResultsKind, plan.Effect, plan.Summary.PortableID, plan.Summary.Result, plan.CandidateDigest, plan.ReferenceDigest, plan.BeforeSlotDigests, plan.AfterSlotDigests}
	return canonicalMiSTerDigest(value)
}

func decodedRGBDigest(decoded decodedImage) string {
	hash := sha256.New()
	var pixel [3]byte
	for _, value := range decoded.pixels {
		pixel[0], pixel[1], pixel[2] = byte(value>>16), byte(value>>8), byte(value)
		_, _ = hash.Write(pixel[:])
	}
	return hex.EncodeToString(hash.Sum(nil))
}

func digestOwnedTree(path string) (string, error) {
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return "absent", nil
	}
	if err != nil {
		return "", err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return "", fmt.Errorf("result slot is not a regular directory")
	}
	files := make([]string, 0)
	err = filepath.WalkDir(path, func(current string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if current == path {
			return nil
		}
		if entry.Type()&os.ModeSymlink != 0 {
			return fmt.Errorf("result slot contains a symlink")
		}
		if entry.IsDir() {
			return nil
		}
		if !entry.Type().IsRegular() {
			return fmt.Errorf("result slot contains a non-regular file")
		}
		relative, err := filepath.Rel(path, current)
		if err != nil {
			return err
		}
		files = append(files, filepath.ToSlash(relative))
		return nil
	})
	if err != nil {
		return "", err
	}
	sort.Strings(files)
	hash := sha256.New()
	for _, relative := range files {
		data, err := os.ReadFile(filepath.Join(path, filepath.FromSlash(relative)))
		if err != nil {
			return "", err
		}
		fmt.Fprintf(hash, "%s\x00%d\x00", relative, len(data))
		_, _ = hash.Write(data)
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func safePreparedPNGName(name string) bool {
	return filepath.Base(name) == name && strings.HasPrefix(name, "frame_") && strings.HasSuffix(name, ".png")
}

func copySyncedRegular(source, destination string) error {
	info, err := os.Lstat(source)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("source PNG is not a regular file")
	}
	in, err := os.Open(source)
	if err != nil {
		return err
	}
	out, err := os.OpenFile(destination, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		_ = in.Close()
		return err
	}
	_, copyErr := io.Copy(out, in)
	if copyErr == nil {
		copyErr = out.Sync()
	}
	closeOut := out.Close()
	closeIn := in.Close()
	if copyErr != nil {
		return copyErr
	}
	if closeOut != nil {
		return closeOut
	}
	return closeIn
}

func ensureSafeOwnedPath(root, child string) error {
	root, err := filepath.Abs(root)
	if err != nil {
		return err
	}
	child, err = filepath.Abs(child)
	if err != nil {
		return err
	}
	if child != root && !strings.HasPrefix(child, root+string(os.PathSeparator)) {
		return fmt.Errorf("result path escapes the configured root")
	}
	return ensureNoSymlinkPath(root, child)
}

func ensureNoSymlinkPath(root, child string) error {
	root, err := filepath.Abs(root)
	if err != nil {
		return err
	}
	child, err = filepath.Abs(child)
	if err != nil {
		return err
	}
	if child != root && !strings.HasPrefix(child, root+string(os.PathSeparator)) {
		return fmt.Errorf("path escapes trusted root")
	}
	relative, err := filepath.Rel(root, child)
	if err != nil {
		return err
	}
	current := root
	if _, err := os.Lstat(current); err == nil {
		info, _ := os.Lstat(current)
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("trusted root is a symlink")
		}
	}
	for _, part := range strings.Split(relative, string(os.PathSeparator)) {
		if part == "." || part == "" {
			continue
		}
		current = filepath.Join(current, part)
		info, err := os.Lstat(current)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("path contains symlink component %s", current)
		}
	}
	return nil
}

func syncDir(path string) error {
	directory, err := os.Open(path)
	if err != nil {
		return err
	}
	syncErr := directory.Sync()
	closeErr := directory.Close()
	if syncErr != nil {
		return syncErr
	}
	return closeErr
}

func sha256Hex(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}
