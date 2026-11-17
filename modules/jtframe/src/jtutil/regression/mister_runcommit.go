/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	miSTerSerialResultsKind   = "serial-results-v1"
	miSTerPrivateResultsKind  = "private-v1"
	MiSTerAutomaticRunScopeID = "automatic-v1"
)

// MiSTerPreparedGame is the detached handoff from serial fixture preparation
// to the board pool and serial result finalizer.
type MiSTerPreparedGame struct {
	Job         PoolJob
	Spec        GameSpec
	PackedCAB   []byte
	CapturePlan []byte
}

func (p MiSTerPreparedGame) Clone() MiSTerPreparedGame {
	p.Job.Session = p.Job.Session.Clone()
	p.PackedCAB = append([]byte(nil), p.PackedCAB...)
	p.CapturePlan = append([]byte(nil), p.CapturePlan...)
	p.Spec.Profile = cloneProfile(p.Spec.Profile)
	p.Spec.ROMs = append([]string(nil), p.Spec.ROMs...)
	p.Spec.PreparedHashes = cloneStringMap(p.Spec.PreparedHashes)
	p.Spec.PreparationWarnings = append([]PreparationWarning(nil), p.Spec.PreparationWarnings...)
	if p.Spec.MisterAssets != nil {
		assets := *p.Spec.MisterAssets
		assets.ROMArchives = append([]MiSTerAssetFile(nil), assets.ROMArchives...)
		assets.DefaultRAM = append([]MiSTerAssetFile(nil), assets.DefaultRAM...)
		p.Spec.MisterAssets = &assets
	}
	return p
}

// MiSTerRunPolicy binds one selected RunCommit invocation to a durable scope.
type MiSTerRunPolicy struct {
	Manual        bool
	Retry         bool
	RunScopeID    string
	FullInventory bool
	ArchiveSHA256 string
}

// MiSTerCommitDeps injects actual board drivers and deterministic coordinator
// timing. It intentionally does not accept a replacement result finalizer.
type MiSTerCommitDeps struct {
	Qualification      CaptureQualification
	Boards             []PoolBoard
	CoordinatorOptions CaptureCoordinatorOptions
	PrivateWorkRoot    string
	FailureHook        func(string) error
}

// RunCommitMiSTer validates detached prepared games and runs their board
// captures through the durable serial-results coordinator lane. It never
// invokes the legacy Batch path or exposes result storage to board workers.
func RunCommitMiSTer(ctx context.Context, log *CommitLog, prepared []MiSTerPreparedGame, cfg Config, deps MiSTerCommitDeps, policy MiSTerRunPolicy) (PoolSnapshot, error) {
	if ctx == nil || log == nil || log.file == nil || log.Progress == nil || strings.TrimSpace(log.Root) == "" {
		return PoolSnapshot{}, fmt.Errorf("MiSTer RunCommit requires context and an opened commit log")
	}
	if err := cfg.ValidateMiSTerRun(); err != nil {
		return PoolSnapshot{}, fmt.Errorf("validate MiSTer run config: %w", err)
	}
	if cfg.Target != "mister" || cfg.LegacySiDi128 {
		return PoolSnapshot{}, fmt.Errorf("MiSTer regression requires config target=mister and rejects legacy SiDi128 opt-in")
	}
	if strings.TrimSpace(cfg.Root) == "" {
		return PoolSnapshot{}, fmt.Errorf("MiSTer config requires an explicit results root")
	}
	configRoot, err := filepath.Abs(cfg.Root)
	if err != nil {
		return PoolSnapshot{}, fmt.Errorf("MiSTer config requires a usable results root")
	}
	logRoot, err := filepath.Abs(log.Root)
	if err != nil || configRoot != logRoot {
		return PoolSnapshot{}, fmt.Errorf("MiSTer config root must match the opened commit-log results root")
	}
	if err := RequireCaptureTarget(logRoot, "mister"); err != nil {
		return PoolSnapshot{}, err
	}
	if strings.TrimSpace(deps.PrivateWorkRoot) == "" {
		return PoolSnapshot{}, fmt.Errorf("MiSTer RunCommit requires an owned private work root")
	}
	if len(prepared) == 0 {
		return PoolSnapshot{}, fmt.Errorf("MiSTer RunCommit requires selected prepared games")
	}
	if deps.Qualification.Target != "mister" || !deps.Qualification.Qualified || deps.Qualification.Generation == "" || deps.Qualification.Convention != CaptureNativeNonRotatedRGB888 {
		return PoolSnapshot{}, fmt.Errorf("MiSTer RunCommit requires explicit qualified native capture")
	}
	if cfg.CaptureContract == nil || cfg.CaptureContract.Generation != deps.Qualification.Generation || cfg.CaptureContract.Convention != deps.Qualification.Convention || cfg.CaptureContract.QualificationID != deps.Qualification.QualificationID {
		return PoolSnapshot{}, fmt.Errorf("MiSTer config capture contract does not match the qualified lane")
	}
	if deps.CoordinatorOptions.CaptureTimeout != time.Duration(cfg.CaptureContract.CaptureTimeoutSeconds)*time.Second || deps.CoordinatorOptions.CleanupTimeout != time.Duration(cfg.CaptureContract.CleanupTimeoutSeconds)*time.Second {
		return PoolSnapshot{}, fmt.Errorf("coordinator deadlines must match the frozen MiSTer capture contract")
	}
	if err := validateMiSTerRunBoards(cfg.Boards, deps.Boards); err != nil {
		return PoolSnapshot{}, err
	}
	if strings.TrimSpace(policy.RunScopeID) == "" {
		return PoolSnapshot{}, fmt.Errorf("MiSTer RunCommit requires a durable run scope ID")
	}
	if len(policy.RunScopeID) > 256 || hasControl(policy.RunScopeID) || strings.TrimSpace(policy.RunScopeID) != policy.RunScopeID {
		return PoolSnapshot{}, fmt.Errorf("MiSTer run scope ID is not a bounded safe value")
	}
	if !policy.Manual && policy.RunScopeID != MiSTerAutomaticRunScopeID {
		return PoolSnapshot{}, fmt.Errorf("automatic MiSTer runs require the stable %q scope", MiSTerAutomaticRunScopeID)
	}
	if policy.Manual && !policy.Retry {
		if scopeRetired(log.Progress, deps.Qualification, policy.RunScopeID) {
			return PoolSnapshot{}, fmt.Errorf("manual MiSTer refresh requires a fresh run scope ID")
		}
	}
	if err := os.MkdirAll(deps.PrivateWorkRoot, 0700); err != nil {
		return PoolSnapshot{}, fmt.Errorf("create private MiSTer work root: %w", err)
	}
	privateRoot, err := filepath.Abs(deps.PrivateWorkRoot)
	if err != nil {
		return PoolSnapshot{}, err
	}
	games := make(map[PoolJobKey]MiSTerPreparedGame, len(prepared))
	jobs := make([]PoolJob, 0, len(prepared))
	for _, item := range prepared {
		if err := validateMiSTerPreparedGame(item); err != nil {
			return PoolSnapshot{}, fmt.Errorf("validate prepared MiSTer game %s/%s: %w", item.Job.Session.Core, item.Job.Session.Setname, err)
		}
		key := PoolJobKey{Core: item.Job.Session.Core, Setname: item.Job.Session.Setname}
		if _, exists := games[key]; exists {
			return PoolSnapshot{}, fmt.Errorf("duplicate prepared MiSTer game %s", key)
		}
		if item.Spec.MisterAssets == nil || item.Spec.MisterAssets.NativeStatus.MainSHA256 != cfg.CaptureContract.MainSHA256 {
			return PoolSnapshot{}, fmt.Errorf("prepared MiSTer game %s does not match the qualified Main parser", key)
		}
		games[key] = item.Clone()
		job := item.Job
		job.Session = item.Job.Session.Clone()
		jobs = append(jobs, job)
	}
	hosts := make(map[BoardKey]string, len(deps.Boards))
	for _, board := range deps.Boards {
		host := strings.TrimSpace(board.Host)
		if host == "" || strings.ContainsAny(host, " \t\r\n") || hosts[board.Key] != "" {
			return PoolSnapshot{}, fmt.Errorf("MiSTer result history requires one configured hostname per board")
		}
		hosts[board.Key] = host
	}
	effects := &miSTerSerialResultEffects{log: log, root: log.Root, privateRoot: privateRoot, qualification: deps.Qualification, games: games, hosts: hosts, clock: time.Now, failureHook: deps.FailureHook}
	options := deps.CoordinatorOptions
	options.FailureHook = deps.FailureHook
	coordinator, err := newSerialResultCaptureCoordinator(log, deps.Qualification, deps.Boards, effects, options, policy.RunScopeID, policy.ArchiveSHA256)
	if err != nil {
		return PoolSnapshot{}, err
	}
	return coordinator.Run(ctx, jobs)
}

func validateMiSTerRunBoards(configured []MiSTerBoardConfig, boards []PoolBoard) error {
	if len(configured) == 0 || len(configured) != len(boards) {
		return fmt.Errorf("injected MiSTer drivers must match the configured board inventory")
	}
	want := make(map[BoardKey]string, len(configured))
	for _, board := range configured {
		want[BoardKey(strings.TrimSpace(board.ID))] = strings.ToLower(strings.TrimSpace(board.Host))
	}
	seen := make(map[BoardKey]bool, len(boards))
	for _, board := range boards {
		key := BoardKey(strings.TrimSpace(string(board.Key)))
		host := strings.ToLower(strings.TrimSpace(board.Host))
		if board.Driver == nil || key == "" || want[key] == "" || want[key] != host || seen[key] {
			return fmt.Errorf("injected MiSTer board %q does not match one configured unique host and driver", key)
		}
		seen[key] = true
	}
	return nil
}

func validateMiSTerPreparedGame(item MiSTerPreparedGame) error {
	session := item.Job.Session
	if err := session.Validate(); err != nil {
		return err
	}
	if strings.TrimSpace(item.Job.SessionID) == "" || strings.TrimSpace(item.Job.Nonce) == "" {
		return fmt.Errorf("prepared job requires assigned session ID and nonce")
	}
	if item.Spec.Setname != session.Setname || !sameJSONValue(item.Spec.Profile, session.Profile) {
		return fmt.Errorf("prepared GameSpec does not match immutable session profile")
	}
	if err := validateMiSTerAssets(session.Core, session.Setname, item.Spec, session); err != nil {
		return err
	}
	cab, err := inspectPackedCAB(item.PackedCAB)
	if err != nil {
		return err
	}
	cabSHA := sha256.Sum256(item.PackedCAB)
	if hex.EncodeToString(cabSHA[:]) != session.CAB.PackedSHA256 || cab.payloadCRC32 != session.CAB.PayloadCRC32 || cab.totalFrames != session.CAB.TotalFrames {
		return fmt.Errorf("packed CAB does not match the immutable session identity")
	}
	plan, err := decodePreparedCapturePlan(item.CapturePlan, cab, session.Checkpoints)
	if err != nil {
		return err
	}
	if plan.PackedCABPayloadCRC32 != cab.payloadCRC32 || plan.TotalFrames != cab.totalFrames || len(plan.Entries) != len(session.Checkpoints) {
		return fmt.Errorf("capture plan does not match the immutable session identity")
	}
	for i, entry := range plan.Entries {
		if entry.Checkpoint != session.Checkpoints[i] {
			return fmt.Errorf("capture plan entry %d does not match prepared checkpoints", i)
		}
	}
	return nil
}

func scopeRetired(progress *Progress, qualification CaptureQualification, scope string) bool {
	if progress == nil {
		return false
	}
	for key, lane := range progress.CaptureRuns {
		if lane.FinalizationKind == miSTerSerialResultsKind && lane.Target == qualification.Target && lane.CaptureGeneration == qualification.Generation && lane.CaptureConvention == qualification.Convention && lane.QualificationID == qualification.QualificationID && lane.RunScopeID == scope && key == laneKeyFromProgress(lane) {
			return true
		}
	}
	return false
}

// MiSTerGameSummary is lane-local progress; legacy Progress.Games is not used
// to infer completion for a MiSTer capture generation.
type MiSTerGameSummary struct {
	Result       Outcome    `json:"result"`
	PortableID   string     `json:"portable_id"`
	OutputDigest string     `json:"output_digest"`
	OperationKey string     `json:"operation_key"`
	Attempt      AttemptKey `json:"attempt"`
	Seconds      float64    `json:"seconds"`
	Stage        string     `json:"stage,omitempty"`
	Message      string     `json:"message,omitempty"`
}

type MiSTerHistoryWitness struct {
	PrefixBytes  int64  `json:"prefix_bytes"`
	PrefixSHA256 string `json:"prefix_sha256"`
	Row          string `json:"row"`
	RowSHA256    string `json:"row_sha256"`
}

type MiSTerFinalizationEffect string

const (
	MiSTerEffectNew            MiSTerFinalizationEffect = "new"
	MiSTerEffectFail           MiSTerFinalizationEffect = "fail"
	MiSTerEffectPassClear      MiSTerFinalizationEffect = "pass-clear"
	MiSTerEffectPrivateFailure MiSTerFinalizationEffect = "private-failure"
)

// MiSTerImageProvenance records the actual receipt tuple and decoded pixel
// identity for one ordered image. PNG compression and filesystem paths are
// intentionally excluded.
type MiSTerImageProvenance struct {
	Sequence        uint32 `json:"sequence,omitempty"`
	RequestedFrame  uint32 `json:"requested_frame"`
	ActualFrame     uint32 `json:"actual_frame"`
	Checkpoint      uint32 `json:"checkpoint"`
	Width           uint32 `json:"width"`
	Height          uint32 `json:"height"`
	Pitch           uint32 `json:"pitch"`
	Slot            uint32 `json:"slot"`
	Mode            uint32 `json:"mode"`
	DescriptorCRC32 uint32 `json:"descriptor_crc32"`
	RGBSHA256       string `json:"rgb_sha256"`
}

// MiSTerReferenceProvenance is stored beside an approved ref set and embedded
// in a pending candidate plan. SourceCommit is the selected Compile all
// workflow commit recorded in the run log.
type MiSTerReferenceProvenance struct {
	Version          int                     `json:"version"`
	CaptureProtocol  string                  `json:"capture_protocol,omitempty"`
	Target           string                  `json:"target"`
	Core             string                  `json:"core"`
	Setname          string                  `json:"setname"`
	Generation       string                  `json:"generation"`
	Convention       CaptureConvention       `json:"convention"`
	QualificationID  string                  `json:"qualification_id"`
	TestDefinitionID string                  `json:"test_definition_id"`
	SourceCommit     string                  `json:"source_commit"`
	Images           []MiSTerImageProvenance `json:"images"`
}

// MiSTerFinalizationPlan binds every shared result/history effect to immutable
// capture and reference digests. It contains no image bytes.
type MiSTerFinalizationPlan struct {
	Summary                   MiSTerGameSummary         `json:"summary"`
	Effect                    MiSTerFinalizationEffect  `json:"effect"`
	CandidateLocator          string                    `json:"candidate_locator"`
	Candidate                 MiSTerReferenceProvenance `json:"candidate"`
	TestDefinitionID          string                    `json:"test_definition_id"`
	CandidateDigest           string                    `json:"candidate_digest"`
	ReferenceDigest           string                    `json:"reference_digest"`
	ReferenceProvenanceSHA256 string                    `json:"reference_provenance_sha256"`
	BeforeSlotDigests         map[string]string         `json:"before_slot_digests"`
	AfterSlotDigests          map[string]string         `json:"after_slot_digests"`
	History                   MiSTerHistoryWitness      `json:"history"`
}

func (p *MiSTerFinalizationPlan) Clone() *MiSTerFinalizationPlan {
	if p == nil {
		return nil
	}
	copy := *p
	copy.BeforeSlotDigests = cloneStringMap(p.BeforeSlotDigests)
	copy.AfterSlotDigests = cloneStringMap(p.AfterSlotDigests)
	copy.Candidate.Images = append([]MiSTerImageProvenance(nil), p.Candidate.Images...)
	return &copy
}

func cloneStringMap(values map[string]string) map[string]string {
	if values == nil {
		return nil
	}
	copy := make(map[string]string, len(values))
	for key, value := range values {
		copy[key] = value
	}
	return copy
}

func (p MiSTerFinalizationPlan) InputDigest() (string, error) {
	encoded, err := json.Marshal(p)
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(encoded)
	return hex.EncodeToString(digest[:]), nil
}

func (p MiSTerFinalizationPlan) Validate() error {
	if p.Summary.Result != Pass && p.Summary.Result != New && p.Summary.Result != Fail {
		return fmt.Errorf("invalid MiSTer finalization outcome %q", p.Summary.Result)
	}
	switch p.Effect {
	case MiSTerEffectNew:
		if p.Summary.Result != New {
			return fmt.Errorf("new effect must have a new summary")
		}
	case MiSTerEffectFail:
		if p.Summary.Result != Fail {
			return fmt.Errorf("fail effect must have a fail summary")
		}
	case MiSTerEffectPassClear:
		if p.Summary.Result != Pass {
			return fmt.Errorf("pass-clear effect must have a pass summary")
		}
	case MiSTerEffectPrivateFailure:
		if p.Summary.Result != Fail {
			return fmt.Errorf("private-failure effect must have a fail summary")
		}
	default:
		return fmt.Errorf("invalid MiSTer finalization effect %q", p.Effect)
	}
	for name, digest := range map[string]string{
		"portable ID":     p.Summary.PortableID,
		"candidate":       p.CandidateDigest,
		"test definition": p.TestDefinitionID,
	} {
		if !isSHA256Hex(digest) {
			return fmt.Errorf("MiSTer finalization %s digest is invalid", name)
		}
	}
	if p.ReferenceDigest != "" && !isSHA256Hex(p.ReferenceDigest) {
		return fmt.Errorf("MiSTer reference digest is invalid")
	}
	if p.ReferenceProvenanceSHA256 != "" && !isSHA256Hex(p.ReferenceProvenanceSHA256) {
		return fmt.Errorf("MiSTer reference provenance digest is invalid")
	}
	if p.CandidateLocator == "" || p.Candidate.TestDefinitionID != p.TestDefinitionID || p.Summary.OutputDigest != p.CandidateDigest {
		return fmt.Errorf("MiSTer finalization candidate identity is incomplete")
	}
	candidateDigest, err := canonicalMiSTerDigest(p.Candidate)
	if err != nil || candidateDigest != p.CandidateDigest {
		return fmt.Errorf("MiSTer candidate digest does not match its provenance")
	}
	if (p.ReferenceDigest == "") != (p.ReferenceProvenanceSHA256 == "") {
		return fmt.Errorf("MiSTer reference digest and provenance must be present together")
	}
	for _, slots := range []map[string]string{p.BeforeSlotDigests, p.AfterSlotDigests} {
		if len(slots) != 3 {
			return fmt.Errorf("MiSTer finalization must bind all three result slots")
		}
		for slot, digest := range slots {
			if slot != "new" && slot != "fail" && slot != "ref" {
				return fmt.Errorf("invalid MiSTer result slot %q", slot)
			}
			if digest != "absent" && !isSHA256Hex(digest) {
				return fmt.Errorf("invalid MiSTer %s slot digest", slot)
			}
		}
	}
	if p.Effect == MiSTerEffectPrivateFailure {
		if p.ReferenceDigest != "" || p.History != (MiSTerHistoryWitness{}) || p.BeforeSlotDigests["ref"] != "absent" || !equalStringMaps(p.BeforeSlotDigests, p.AfterSlotDigests) {
			return fmt.Errorf("private failure cannot mutate shared slots or history")
		}
	} else {
		if p.History.PrefixBytes < 0 || strings.TrimSpace(p.History.Row) == "" || !strings.HasSuffix(p.History.Row, "\n") ||
			!isSHA256Hex(p.History.PrefixSHA256) || !isSHA256Hex(p.History.RowSHA256) {
			return fmt.Errorf("invalid MiSTer history witness")
		}
		rowDigest := sha256.Sum256([]byte(p.History.Row))
		if hex.EncodeToString(rowDigest[:]) != p.History.RowSHA256 {
			return fmt.Errorf("MiSTer history row digest mismatch")
		}
	}
	if err := p.Candidate.Validate(); err != nil {
		return fmt.Errorf("invalid candidate provenance: %w", err)
	}
	if p.Candidate.Core == "" || p.Candidate.Setname == "" || !isCommitSHA(p.Candidate.SourceCommit) {
		return fmt.Errorf("candidate provenance is missing game or selected source commit")
	}
	if p.Effect == MiSTerEffectNew && (p.BeforeSlotDigests["ref"] != "absent" || p.AfterSlotDigests["ref"] != "absent" || p.AfterSlotDigests["new"] == "absent" || p.AfterSlotDigests["fail"] != "absent") {
		return fmt.Errorf("new effect has inconsistent result-slot transition")
	}
	if p.Effect == MiSTerEffectFail && (p.BeforeSlotDigests["ref"] == "absent" || p.AfterSlotDigests["ref"] != p.BeforeSlotDigests["ref"] || p.AfterSlotDigests["new"] != "absent" || p.AfterSlotDigests["fail"] == "absent") {
		return fmt.Errorf("fail effect has inconsistent result-slot transition")
	}
	if p.Effect == MiSTerEffectPassClear && (p.BeforeSlotDigests["ref"] == "absent" || p.AfterSlotDigests["ref"] != p.BeforeSlotDigests["ref"] || p.AfterSlotDigests["new"] != "absent" || p.AfterSlotDigests["fail"] != "absent") {
		return fmt.Errorf("pass effect has inconsistent result-slot transition")
	}
	return nil
}

func (p MiSTerReferenceProvenance) Validate() error {
	if p.Version != 1 || p.Target != "mister" || !safeComponent(p.Core) || !safeComponent(p.Setname) ||
		strings.TrimSpace(p.Generation) == "" || p.Convention != CaptureNativeNonRotatedRGB888 ||
		strings.TrimSpace(p.QualificationID) == "" || !isSHA256Hex(p.TestDefinitionID) || !isCommitSHA(p.SourceCommit) || len(p.Images) == 0 {
		return fmt.Errorf("invalid MiSTer image provenance identity")
	}
	if p.CaptureProtocol != "" && p.CaptureProtocol != miSTerCaptureProtocolV2 {
		return fmt.Errorf("unsupported MiSTer capture protocol %q", p.CaptureProtocol)
	}
	var previous uint32
	for i, image := range p.Images {
		sequenceInvalid := p.CaptureProtocol == miSTerCaptureProtocolV2 && image.Sequence != 0 ||
			p.CaptureProtocol != miSTerCaptureProtocolV2 && image.Sequence != uint32(i+1)
		if sequenceInvalid || image.RequestedFrame == 0 || image.ActualFrame != image.RequestedFrame-1 || image.Checkpoint != image.RequestedFrame ||
			image.Width == 0 || image.Height == 0 || image.Pitch < image.Width*3 || !isSHA256Hex(image.RGBSHA256) ||
			(i > 0 && image.RequestedFrame <= previous) {
			return fmt.Errorf("invalid MiSTer image provenance entry %d", i)
		}
		previous = image.RequestedFrame
	}
	return nil
}
