/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
)

// MiSTerLaneStatus is one persisted lane selected without contacting a board.
type MiSTerLaneStatus struct {
	ProgressPath string
	Commit       string
	Key          string
	Lane         CaptureRunProgress
}

// ReadMiSTerLaneStatus reads only matching serial-result lanes from the
// existing flat progress files. Legacy top-level completion never satisfies
// a generation-qualified MiSTer status query.
func ReadMiSTerLaneStatus(root, generation, qualificationID string) ([]MiSTerLaneStatus, error) {
	if strings.TrimSpace(generation) == "" || strings.TrimSpace(qualificationID) == "" {
		return nil, fmt.Errorf("MiSTer status requires explicit generation and qualification ID")
	}
	entries, err := os.ReadDir(filepath.Join(root, "log"))
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var result []MiSTerLaneStatus
	for _, entry := range entries {
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		filename := filepath.Join(root, "log", entry.Name())
		info, err := os.Lstat(filename)
		if err != nil || !info.Mode().IsRegular() {
			return nil, fmt.Errorf("MiSTer progress input is not a regular file: %s", entry.Name())
		}
		data, err := os.ReadFile(filename)
		if err != nil {
			return nil, err
		}
		var progress Progress
		decoder := json.NewDecoder(strings.NewReader(string(data)))
		if err = decoder.Decode(&progress); err != nil {
			return nil, fmt.Errorf("decode regression progress %s: %w", entry.Name(), err)
		}
		var trailing any
		if err = decoder.Decode(&trailing); err != io.EOF {
			return nil, fmt.Errorf("regression progress %s has trailing JSON", entry.Name())
		}
		for key, lane := range progress.CaptureRuns {
			if lane.FinalizationKind != miSTerSerialResultsKind || lane.Target != "mister" || lane.CaptureGeneration != generation || lane.QualificationID != qualificationID {
				continue
			}
			if err = validateCaptureRunLane(key, lane); err != nil {
				return nil, fmt.Errorf("invalid MiSTer lane in %s: %w", entry.Name(), err)
			}
			result = append(result, MiSTerLaneStatus{ProgressPath: filename, Commit: progress.Commit, Key: key, Lane: lane.Clone()})
		}
	}
	sort.Slice(result, func(i, j int) bool {
		if result[i].Commit == result[j].Commit {
			return result[i].Key < result[j].Key
		}
		return result[i].Commit < result[j].Commit
	})
	return result, nil
}

// AcceptMiSTerResult is an explicit, board-free curation operation. It only
// accepts a NEW slot whose completed journal plan, private candidate and live
// PNG tree all agree. It writes the candidate's provenance beside ref after
// the existing curation transaction succeeds; an interrupted write leaves an
// unqualified ref which subsequent captures reject.
func AcceptMiSTerResult(root, core, set, generation, qualificationID string) error {
	if err := RequireCaptureTarget(root, "mister"); err != nil {
		return err
	}
	if !safeComponent(core) || core == "log" || !safeComponent(set) || strings.TrimSpace(generation) == "" || strings.TrimSpace(qualificationID) == "" {
		return fmt.Errorf("MiSTer acceptance requires safe core/set and explicit generation/qualification")
	}
	gameRoot := filepath.Join(root, core, set)
	if err := ensureSafeOwnedPath(root, gameRoot); err != nil {
		return err
	}
	if _, err := os.Lstat(filepath.Join(gameRoot, "new")); err != nil {
		return fmt.Errorf("MiSTer acceptance requires a published new slot: %w", err)
	}
	entries, err := os.ReadDir(filepath.Join(root, "log"))
	if err != nil {
		return err
	}
	var candidates []MiSTerReferenceProvenance
	var matchedPlan *MiSTerFinalizationPlan
	for _, entry := range entries {
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		data, readErr := os.ReadFile(filepath.Join(root, "log", entry.Name()))
		if readErr != nil {
			return readErr
		}
		var progress Progress
		if readErr = json.Unmarshal(data, &progress); readErr != nil {
			return fmt.Errorf("decode progress %s: %w", entry.Name(), readErr)
		}
		for key, lane := range progress.CaptureRuns {
			if lane.Target != "mister" || lane.FinalizationKind != miSTerSerialResultsKind || lane.CaptureGeneration != generation || lane.QualificationID != qualificationID {
				continue
			}
			if err = validateCaptureRunLane(key, lane); err != nil {
				return err
			}
			jobKey := poolJobMapKey(PoolJobKey{Core: core, Setname: set})
			if lane.Selected[jobKey] == "" {
				continue
			}
			for _, finalization := range lane.Finalizations {
				plan := finalization.Plan
				if finalization.State != CaptureFinalizationComplete || plan == nil || finalization.JobKey != (PoolJobKey{Core: core, Setname: set}) || plan.Effect != MiSTerEffectNew || plan.Summary.Result != New || plan.Summary.PortableID != lane.Selected[jobKey] {
					continue
				}
				if lane.Games[jobKey].OperationKey != plan.Summary.OperationKey || lane.Games[jobKey].OutputDigest != plan.CandidateDigest {
					return fmt.Errorf("MiSTer curation lane summary differs from completed candidate")
				}
				if err = plan.Validate(); err != nil {
					return err
				}
				if _, _, err = readStagedCandidate(plan.CandidateLocator, plan.Candidate); err != nil {
					return fmt.Errorf("revalidate private MiSTer candidate: %w", err)
				}
				candidates = append(candidates, plan.Candidate)
				copy := plan.Clone()
				matchedPlan = copy
			}
		}
	}
	if len(candidates) != 1 || matchedPlan == nil {
		return fmt.Errorf("expected exactly one journaled NEW candidate for %s/%s in generation %s; found %d", core, set, generation, len(candidates))
	}
	provenance := candidates[0]
	if err = provenance.Validate(); err != nil {
		return err
	}
	if provenance.Core != core || provenance.Setname != set || provenance.Generation != generation || provenance.QualificationID != qualificationID {
		return fmt.Errorf("journaled candidate provenance does not match the requested game and generation")
	}
	effects := &miSTerSerialResultEffects{root: root, privateRoot: filepath.Dir(filepath.Dir(matchedPlan.CandidateLocator))}
	current, err := effects.slotDigests(gameRoot)
	if err != nil {
		return err
	}
	if !equalStringMaps(current, matchedPlan.AfterSlotDigests) {
		return fmt.Errorf("MiSTer new/fail/ref slots changed since the journaled candidate")
	}
	if current["new"] != matchedPlan.AfterSlotDigests["new"] {
		return fmt.Errorf("MiSTer new slot does not match completed candidate plan")
	}
	newSet, err := readMiSTerPublishedCandidate(filepath.Join(gameRoot, "new"), provenance)
	if err != nil {
		return err
	}
	if candidatePngDirectoryDigest(newSet, provenance) != current["new"] {
		return fmt.Errorf("MiSTer new slot changed during acceptance validation")
	}
	if err = validateMiSTerPriorReferenceForAcceptance(root, gameRoot, provenance); err != nil {
		return err
	}
	provenanceBytes, err := encodeMiSTerReferenceProvenance(provenance)
	if err != nil {
		return err
	}
	return accept_curation_game_with_metadata(gameRoot, provenanceBytes, nil)
}

func validateMiSTerPriorReferenceForAcceptance(root, gameRoot string, candidate MiSTerReferenceProvenance) error {
	ref := filepath.Join(gameRoot, "ref")
	info, err := os.Lstat(ref)
	if os.IsNotExist(err) {
		if _, sidecarErr := os.Lstat(filepath.Join(gameRoot, "ref", "reference-provenance.json")); sidecarErr == nil {
			return fmt.Errorf("orphan MiSTer reference provenance exists without a ref directory")
		} else if !os.IsNotExist(sidecarErr) {
			return sidecarErr
		}
		return nil
	}
	if err != nil {
		return err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("existing MiSTer reference is not an owned directory")
	}
	data, err := readOwnedFinalizerFile(root, filepath.Join(gameRoot, "ref", "reference-provenance.json"))
	if err != nil {
		return fmt.Errorf("existing MiSTer reference lacks trusted provenance: %w", err)
	}
	var previous MiSTerReferenceProvenance
	decoder := json.NewDecoder(strings.NewReader(string(data)))
	decoder.DisallowUnknownFields()
	if err = decoder.Decode(&previous); err != nil {
		return err
	}
	var trailing any
	if err = decoder.Decode(&trailing); err != io.EOF {
		return fmt.Errorf("existing reference provenance has trailing JSON")
	}
	if err = previous.Validate(); err != nil {
		return err
	}
	if previous.Core != candidate.Core || previous.Setname != candidate.Setname || previous.Generation != candidate.Generation || previous.Convention != candidate.Convention || previous.QualificationID != candidate.QualificationID || previous.TestDefinitionID != candidate.TestDefinitionID {
		return fmt.Errorf("existing MiSTer reference is from another qualified generation or test definition; explicit rollover is required")
	}
	if _, err = readMiSTerPublishedCandidate(ref, previous); err != nil {
		return fmt.Errorf("existing MiSTer reference no longer matches its provenance: %w", err)
	}
	return nil
}

// RejectMiSTerResult rejects one explicitly named game. Unlike legacy reject,
// it never searches by setname, which can be shared by different cores.
func RejectMiSTerResult(root, core, set, reason string) error {
	if err := RequireCaptureTarget(root, "mister"); err != nil {
		return err
	}
	if !safeComponent(core) || core == "log" || !safeComponent(set) || strings.ContainsAny(reason, "\r\n") {
		return fmt.Errorf("MiSTer rejection requires safe core/set names and a single-line reason")
	}
	gameRoot := filepath.Join(root, core, set)
	if err := ensureSafeOwnedPath(root, gameRoot); err != nil {
		return err
	}
	newDir, failDir := filepath.Join(gameRoot, "new"), filepath.Join(gameRoot, "fail")
	newExists, err := is_real_directory(newDir)
	if err != nil {
		return err
	}
	failExists, err := is_real_directory(failDir)
	if err != nil {
		return err
	}
	if !newExists && !failExists {
		return fmt.Errorf("no new/ or fail/ folder exists for %s/%s", core, set)
	}
	crc, err := reference_crc(filepath.Join(gameRoot, "ref"))
	if err != nil {
		return err
	}
	if err = preflight_curation_paths(gameRoot, "", filepath.Join(gameRoot, "ref")); err != nil {
		return err
	}
	return reject_pending_transaction(gameRoot, newDir, failDir, newExists, failExists, crc, reason, io.WriteString)
}

func readMiSTerPublishedCandidate(directory string, expected MiSTerReferenceProvenance) (CaptureSet, error) {
	set := CaptureSet{Dir: directory, Format: "png"}
	for _, item := range expected.Images {
		name := png_capture_name(int(item.RequestedFrame), int(item.ActualFrame))
		decoded, err := decode_capture_image(filepath.Join(directory, name))
		if err != nil || decoded.width != int(item.Width) || decoded.height != int(item.Height) || decodedRGBDigest(decoded) != item.RGBSHA256 {
			return set, fmt.Errorf("published new image %s does not match its completed capture receipt", name)
		}
		if set.Width == 0 {
			set.Width, set.Height = decoded.width, decoded.height
		}
		if set.Width != decoded.width || set.Height != decoded.height {
			return set, fmt.Errorf("published candidate geometry changes across images")
		}
		set.Captures = append(set.Captures, CaptureRecord{Type: "capture", Requested: int(item.RequestedFrame), Actual: int(item.ActualFrame), Image: name})
	}
	entries, err := os.ReadDir(directory)
	if err != nil {
		return set, err
	}
	if len(entries) != len(expected.Images) {
		if len(entries) != len(expected.Images)+1 {
			return set, fmt.Errorf("published candidate inventory differs from journaled images")
		}
		data, readErr := os.ReadFile(filepath.Join(directory, "reference-provenance.json"))
		if readErr != nil || string(data) == "" {
			return set, fmt.Errorf("published candidate provenance is missing")
		}
		var stored MiSTerReferenceProvenance
		decoder := json.NewDecoder(strings.NewReader(string(data)))
		decoder.DisallowUnknownFields()
		if decodeErr := decoder.Decode(&stored); decodeErr != nil || !reflect.DeepEqual(stored, expected) {
			return set, fmt.Errorf("published candidate provenance differs from the expected source")
		}
	}
	return set, nil
}

func encodeMiSTerReferenceProvenance(provenance MiSTerReferenceProvenance) ([]byte, error) {
	if err := provenance.Validate(); err != nil {
		return nil, err
	}
	data, err := json.MarshalIndent(provenance, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(data, '\n'), nil
}
