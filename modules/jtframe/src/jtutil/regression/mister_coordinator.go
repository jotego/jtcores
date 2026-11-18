/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"time"
)

const captureRunSchemaVersion = 1

type CaptureQualification struct {
	Target          string            `json:"target"`
	Generation      string            `json:"capture_generation"`
	Convention      CaptureConvention `json:"capture_convention"`
	QualificationID string            `json:"qualification_id"`
	Qualified       bool              `json:"qualified"`
}

type CaptureFinalizationState string

const (
	CaptureFinalizationPending  CaptureFinalizationState = "pending"
	CaptureFinalizationComplete CaptureFinalizationState = "complete"
)

type CaptureFinalizationProgress struct {
	JobKey       PoolJobKey               `json:"job_key"`
	PortableID   string                   `json:"portable_id"`
	Attempt      AttemptKey               `json:"attempt"`
	InputDigest  string                   `json:"input_digest"`
	State        CaptureFinalizationState `json:"state"`
	ResultDigest string                   `json:"result_digest,omitempty"`
	Plan         *MiSTerFinalizationPlan  `json:"plan,omitempty"`
}

type CaptureRunProgress struct {
	SchemaVersion         int                                    `json:"schema_version"`
	Target                string                                 `json:"target"`
	CaptureGeneration     string                                 `json:"capture_generation"`
	CaptureConvention     CaptureConvention                      `json:"capture_convention"`
	QualificationID       string                                 `json:"qualification_id"`
	FinalizationKind      string                                 `json:"finalization_kind,omitempty"`
	RunScopeID            string                                 `json:"run_scope_id,omitempty"`
	SelectionSHA256       string                                 `json:"selection_sha256,omitempty"`
	SelectedArchiveSHA256 string                                 `json:"selected_archive_sha256,omitempty"`
	Selected              map[string]string                      `json:"selected,omitempty"`
	Games                 map[string]MiSTerGameSummary           `json:"games,omitempty"`
	Current               string                                 `json:"current,omitempty"`
	Status                string                                 `json:"status,omitempty"`
	Complete              bool                                   `json:"complete,omitempty"`
	Snapshot              PoolSnapshot                           `json:"snapshot"`
	Finalizations         map[string]CaptureFinalizationProgress `json:"finalizations,omitempty"`
}

func (p CaptureRunProgress) Clone() CaptureRunProgress {
	p.Snapshot = p.Snapshot.Clone()
	if p.Finalizations != nil {
		finalizations := make(map[string]CaptureFinalizationProgress, len(p.Finalizations))
		for key, item := range p.Finalizations {
			item.Plan = item.Plan.Clone()
			finalizations[key] = item
		}
		p.Finalizations = finalizations
	}
	p.Selected = cloneStringMap(p.Selected)
	if p.Games != nil {
		games := make(map[string]MiSTerGameSummary, len(p.Games))
		for key, item := range p.Games {
			games[key] = item
		}
		p.Games = games
	}
	return p
}

type PrivateCaptureEffects interface {
	// VerifyPrivate is read-only. It returns a SHA256 over the exact qualified
	// capture content and intent that CommitPrivate will consume.
	VerifyPrivate(context.Context, CaptureQualification, PoolJobKey, string, AttemptKey, PreparedSession, SessionCapture) (inputDigest string, err error)
	// CommitPrivate is private and idempotent for operationKey+inputDigest.
	CommitPrivate(context.Context, string, string, PreparedSession, SessionCapture) (resultDigest string, err error)
	// RevalidatePrivate proves that a previously recorded private result still
	// exists and has the recorded digest.
	RevalidatePrivate(context.Context, string, string, string) error
	// ReconcilePrivate may report committed only after proving the same result
	// for a pending operation. Unknown outcomes must remain blocked.
	ReconcilePrivate(context.Context, string, string) (resultDigest string, committed bool, err error)
}

type captureFinalizationEffects interface {
	PrepareCapture(context.Context, string, CaptureQualification, PoolJobKey, string, AttemptKey, PreparedSession, SessionCapture) (string, *MiSTerFinalizationPlan, error)
	CommitCapture(context.Context, string, string, *MiSTerFinalizationPlan, PreparedSession, SessionCapture) (string, error)
	RevalidateCapture(context.Context, string, string, string, *MiSTerFinalizationPlan) error
	ReconcileCapture(context.Context, string, string, *MiSTerFinalizationPlan) (string, bool, error)
}

type serialResultCaptureEffects interface {
	PrepareSerialResult(context.Context, string, CaptureQualification, PoolJobKey, string, AttemptKey, PreparedSession, SessionCapture) (*MiSTerFinalizationPlan, error)
	CommitSerialResult(context.Context, string, MiSTerFinalizationPlan, PreparedSession, SessionCapture) (string, error)
	RevalidateSerialResult(context.Context, string, MiSTerFinalizationPlan, string) error
	ReconcileSerialResult(context.Context, string, MiSTerFinalizationPlan) (string, bool, error)
}

type privateCaptureEffectsAdapter struct{ effects PrivateCaptureEffects }

func (a privateCaptureEffectsAdapter) PrepareCapture(ctx context.Context, _ string, qualification CaptureQualification, job PoolJobKey, portableID string, attempt AttemptKey, session PreparedSession, capture SessionCapture) (string, *MiSTerFinalizationPlan, error) {
	digest, err := a.effects.VerifyPrivate(ctx, qualification, job, portableID, attempt, session, capture)
	return digest, nil, err
}

func (a privateCaptureEffectsAdapter) CommitCapture(ctx context.Context, operationKey, inputDigest string, _ *MiSTerFinalizationPlan, session PreparedSession, capture SessionCapture) (string, error) {
	return a.effects.CommitPrivate(ctx, operationKey, inputDigest, session, capture)
}

func (a privateCaptureEffectsAdapter) RevalidateCapture(ctx context.Context, operationKey, inputDigest, resultDigest string, _ *MiSTerFinalizationPlan) error {
	return a.effects.RevalidatePrivate(ctx, operationKey, inputDigest, resultDigest)
}

func (a privateCaptureEffectsAdapter) ReconcileCapture(ctx context.Context, operationKey, inputDigest string, _ *MiSTerFinalizationPlan) (string, bool, error) {
	return a.effects.ReconcilePrivate(ctx, operationKey, inputDigest)
}

type serialResultEffectsAdapter struct{ effects serialResultCaptureEffects }

func (a serialResultEffectsAdapter) PrepareCapture(ctx context.Context, operationKey string, qualification CaptureQualification, job PoolJobKey, portableID string, attempt AttemptKey, session PreparedSession, capture SessionCapture) (string, *MiSTerFinalizationPlan, error) {
	plan, err := a.effects.PrepareSerialResult(ctx, operationKey, qualification, job, portableID, attempt, session, capture)
	if err != nil {
		return "", nil, err
	}
	if plan == nil {
		return "", nil, fmt.Errorf("serial result preparer returned no plan")
	}
	inputDigest, err := plan.InputDigest()
	return inputDigest, plan, err
}

func (a serialResultEffectsAdapter) CommitCapture(ctx context.Context, operationKey, inputDigest string, plan *MiSTerFinalizationPlan, session PreparedSession, capture SessionCapture) (string, error) {
	if plan == nil {
		return "", fmt.Errorf("serial result finalization has no plan")
	}
	return a.effects.CommitSerialResult(ctx, operationKey, *plan.Clone(), session, capture)
}

func (a serialResultEffectsAdapter) RevalidateCapture(ctx context.Context, operationKey, inputDigest, resultDigest string, plan *MiSTerFinalizationPlan) error {
	if plan == nil {
		return fmt.Errorf("serial result finalization has no plan")
	}
	return a.effects.RevalidateSerialResult(ctx, operationKey, *plan.Clone(), resultDigest)
}

func (a serialResultEffectsAdapter) ReconcileCapture(ctx context.Context, operationKey, inputDigest string, plan *MiSTerFinalizationPlan) (string, bool, error) {
	if plan == nil {
		return "", false, fmt.Errorf("serial result finalization has no plan")
	}
	return a.effects.ReconcileSerialResult(ctx, operationKey, *plan.Clone())
}

type CaptureCoordinatorOptions struct {
	CaptureTimeout time.Duration
	CleanupTimeout time.Duration
	Clock          PoolClock
	SyncDirectory  func(string) error
	FailureHook    func(string) error
}

type CaptureCoordinator struct {
	log                   *CommitLog
	qualification         CaptureQualification
	boards                []PoolBoard
	effects               captureFinalizationEffects
	options               CaptureCoordinatorOptions
	laneKey               string
	finalizationKind      string
	runScopeID            string
	selectedArchiveSHA256 string
	running               atomic.Bool
}

func NewCaptureCoordinator(log *CommitLog, qualification CaptureQualification, boards []PoolBoard, effects PrivateCaptureEffects, options CaptureCoordinatorOptions) (*CaptureCoordinator, error) {
	if log == nil || log.Progress == nil || strings.TrimSpace(log.Root) == "" {
		return nil, fmt.Errorf("capture coordinator requires an opened commit log")
	}
	if qualification.Target != "mister" || strings.TrimSpace(qualification.Generation) == "" || qualification.Convention != CaptureNativeNonRotatedRGB888 || strings.TrimSpace(qualification.QualificationID) == "" || !qualification.Qualified {
		return nil, fmt.Errorf("capture coordinator requires explicit matching MiSTer qualification")
	}
	if effects == nil {
		return nil, fmt.Errorf("capture coordinator requires private capture effects")
	}
	return newCaptureCoordinator(log, qualification, boards, privateCaptureEffectsAdapter{effects: effects}, options, "", "")
}

// newSerialResultCaptureCoordinator is reserved for RunCommitMiSTer. It shares
// the accepted pool/checkpoint machinery while using a distinct result-effects
// journal identity from private-v1.
func newSerialResultCaptureCoordinator(log *CommitLog, qualification CaptureQualification, boards []PoolBoard, effects serialResultCaptureEffects, options CaptureCoordinatorOptions, runScopeID, selectedArchiveSHA256 string) (*CaptureCoordinator, error) {
	if strings.TrimSpace(runScopeID) == "" {
		return nil, fmt.Errorf("serial MiSTer results require a persisted run scope ID")
	}
	if selectedArchiveSHA256 != "" && !isSHA256Hex(selectedArchiveSHA256) {
		return nil, fmt.Errorf("serial MiSTer selected archive identity is not SHA256")
	}
	if effects == nil {
		return nil, fmt.Errorf("serial MiSTer results require real result effects")
	}
	c, err := newCaptureCoordinator(log, qualification, boards, serialResultEffectsAdapter{effects: effects}, options, miSTerSerialResultsKind, runScopeID)
	if err != nil {
		return nil, err
	}
	c.selectedArchiveSHA256 = selectedArchiveSHA256
	return c, nil
}

func newCaptureCoordinator(log *CommitLog, qualification CaptureQualification, boards []PoolBoard, effects captureFinalizationEffects, options CaptureCoordinatorOptions, finalizationKind, runScopeID string) (*CaptureCoordinator, error) {
	if log == nil || log.Progress == nil || strings.TrimSpace(log.Root) == "" {
		return nil, fmt.Errorf("capture coordinator requires an opened commit log")
	}
	if qualification.Target != "mister" || strings.TrimSpace(qualification.Generation) == "" || qualification.Convention != CaptureNativeNonRotatedRGB888 || strings.TrimSpace(qualification.QualificationID) == "" || !qualification.Qualified {
		return nil, fmt.Errorf("capture coordinator requires explicit matching MiSTer qualification")
	}
	if effects == nil {
		return nil, fmt.Errorf("capture coordinator requires capture finalization effects")
	}
	if finalizationKind != "" && finalizationKind != miSTerSerialResultsKind {
		return nil, fmt.Errorf("unsupported capture finalization kind %q", finalizationKind)
	}
	if finalizationKind == miSTerSerialResultsKind && strings.TrimSpace(runScopeID) == "" {
		return nil, fmt.Errorf("serial MiSTer results require a persisted run scope ID")
	}
	if options.CaptureTimeout <= 0 || options.CleanupTimeout <= 0 {
		return nil, fmt.Errorf("capture coordinator deadlines must be positive")
	}
	if options.SyncDirectory == nil {
		options.SyncDirectory = sync_capture_progress_dir
	}
	normalizedBoards := append([]PoolBoard(nil), boards...)
	for index := range normalizedBoards {
		normalizedBoards[index].Key = BoardKey(strings.TrimSpace(string(normalizedBoards[index].Key)))
		normalizedBoards[index].Host = strings.ToLower(strings.TrimSpace(normalizedBoards[index].Host))
	}
	laneKey, err := captureLaneKeyForKind(qualification, finalizationKind, runScopeID)
	if err != nil {
		return nil, fmt.Errorf("encode capture lane identity: %w", err)
	}
	return &CaptureCoordinator{log: log, qualification: qualification, boards: normalizedBoards, effects: effects, options: options, laneKey: laneKey, finalizationKind: finalizationKind, runScopeID: runScopeID}, nil
}

func captureLaneKeyForKind(qualification CaptureQualification, finalizationKind, runScopeID string) (string, error) {
	if finalizationKind == "" {
		identity := struct {
			Version         int               `json:"version"`
			Target          string            `json:"target"`
			Generation      string            `json:"generation"`
			Convention      CaptureConvention `json:"convention"`
			QualificationID string            `json:"qualification_id"`
		}{captureRunSchemaVersion, qualification.Target, qualification.Generation, qualification.Convention, qualification.QualificationID}
		encoded, err := json.Marshal(identity)
		if err != nil {
			return "", err
		}
		digest := sha256.Sum256(encoded)
		return "v1-" + hex.EncodeToString(digest[:]), nil
	}
	identity := struct {
		Version          int               `json:"version"`
		Target           string            `json:"target"`
		Generation       string            `json:"generation"`
		Convention       CaptureConvention `json:"convention"`
		QualificationID  string            `json:"qualification_id"`
		FinalizationKind string            `json:"finalization_kind"`
		RunScopeID       string            `json:"run_scope_id"`
	}{captureRunSchemaVersion, qualification.Target, qualification.Generation, qualification.Convention, qualification.QualificationID, finalizationKind, runScopeID}
	encoded, err := json.Marshal(identity)
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(encoded)
	return "v2-" + hex.EncodeToString(digest[:]), nil
}

// Run owns one CommitLog writer and must be called under the caller's existing
// regression lock. Workers receive detached PoolJobs and never see the log.
func (c *CaptureCoordinator) Run(ctx context.Context, inputJobs []PoolJob) (PoolSnapshot, error) {
	if c == nil || c.log == nil {
		return PoolSnapshot{}, fmt.Errorf("capture coordinator is nil")
	}
	if ctx == nil {
		return PoolSnapshot{}, fmt.Errorf("capture coordinator context is nil")
	}
	if !c.running.CompareAndSwap(false, true) {
		return PoolSnapshot{}, fmt.Errorf("capture coordinator Run already active")
	}
	defer c.running.Store(false)
	normalizedJobs, err := normalizePoolJobs(inputJobs)
	if err != nil {
		return PoolSnapshot{}, err
	}
	jobs := make([]PoolJob, len(normalizedJobs))
	for index := range normalizedJobs {
		jobs[index] = normalizedJobs[index].job
	}
	if len(jobs) == 0 {
		return PoolSnapshot{}, fmt.Errorf("capture coordinator requires prepared jobs")
	}
	for index := range jobs {
		if jobs[index].Session.Generation != c.qualification.Generation || jobs[index].Session.Convention != c.qualification.Convention {
			return PoolSnapshot{}, fmt.Errorf("prepared job %s/%s does not match qualified lane", jobs[index].Session.Core, jobs[index].Session.Setname)
		}
	}
	selected, selectionSHA256, err := selectedPoolInventory(jobs)
	if err != nil {
		return PoolSnapshot{}, err
	}
	if err := c.ensureCaptureRuns(); err != nil {
		return PoolSnapshot{}, err
	}
	lane, exists := c.log.Progress.CaptureRuns[c.laneKey]
	if exists {
		if err := validateCaptureRunLane(c.laneKey, lane); err != nil {
			return PoolSnapshot{}, err
		}
		if c.finalizationKind == miSTerSerialResultsKind &&
			(lane.FinalizationKind != c.finalizationKind || lane.RunScopeID != c.runScopeID || lane.SelectionSHA256 != selectionSHA256 || lane.SelectedArchiveSHA256 != c.selectedArchiveSHA256 || !equalStringMaps(lane.Selected, selected)) {
			return PoolSnapshot{}, fmt.Errorf("saved MiSTer result lane does not match run scope or selected inventory")
		}
	} else {
		lane = CaptureRunProgress{SchemaVersion: captureRunSchemaVersion, Target: c.qualification.Target, CaptureGeneration: c.qualification.Generation, CaptureConvention: c.qualification.Convention, QualificationID: c.qualification.QualificationID, Finalizations: map[string]CaptureFinalizationProgress{}}
		if c.finalizationKind == miSTerSerialResultsKind {
			lane.FinalizationKind = c.finalizationKind
			lane.RunScopeID = c.runScopeID
			lane.SelectionSHA256 = selectionSHA256
			lane.SelectedArchiveSHA256 = c.selectedArchiveSHA256
			lane.Selected = selected
			lane.Games = map[string]MiSTerGameSummary{}
			lane.Status = "running"
		}
	}
	if err := c.checkOtherLaneFences(jobs); err != nil {
		return PoolSnapshot{}, err
	}
	if err := c.validateAttemptFreshness(jobs, lane); err != nil {
		return PoolSnapshot{}, err
	}
	observer := captureRunObserver{coordinator: c}
	finalizer := captureRunFinalizer{coordinator: c}
	pool, err := NewSessionPool(c.boards, PoolOptions{CaptureTimeout: c.options.CaptureTimeout, CleanupTimeout: c.options.CleanupTimeout, Clock: c.options.Clock, Observer: observer, Finalizer: finalizer})
	if err != nil {
		return PoolSnapshot{}, err
	}
	if err := c.recoverFinalizations(ctx, &lane, jobs); err != nil {
		return PoolSnapshot{}, err
	}
	if err := c.persistLane(lane); err != nil {
		return PoolSnapshot{}, fmt.Errorf("persist capture lane before dispatch: %w", err)
	}
	snapshot, runErr := pool.Run(ctx, jobs, lane.Snapshot.Checkpoint.Clone())
	snapshot = snapshot.Clone()
	if runErr != nil {
		return snapshot, runErr
	}
	for _, result := range snapshot.Jobs {
		if result.State != PoolResultComplete {
			message := strings.TrimSpace(result.Message)
			if message == "" {
				message = string(result.State)
			}
			return snapshot, fmt.Errorf("capture lane incomplete for %s: %s", result.JobKey, message)
		}
	}
	if c.finalizationKind == miSTerSerialResultsKind {
		lane = c.log.Progress.CaptureRuns[c.laneKey].Clone()
		for _, result := range snapshot.Jobs {
			if result.State != PoolResultComplete {
				return snapshot, fmt.Errorf("MiSTer result lane has an incomplete selected job %s", result.JobKey)
			}
			opKey := captureOperationKey(c.laneKey, result.JobKey, result.PortableID, result.Attempt)
			item, ok := lane.Finalizations[opKey]
			if !ok || item.State != CaptureFinalizationComplete || item.Plan == nil || item.Plan.Summary.OutputDigest == "" {
				return snapshot, fmt.Errorf("MiSTer result lane is missing completed summary for %s", result.JobKey)
			}
			lane.Games[poolJobMapKey(result.JobKey)] = item.Plan.Summary
		}
		lane.Current = ""
		lane.Status = "complete"
		lane.Complete = true
		if err := c.persistLane(lane); err != nil {
			return snapshot, fmt.Errorf("persist completed MiSTer result selection: %w", err)
		}
	}
	return snapshot, nil
}

func selectedPoolInventory(jobs []PoolJob) (map[string]string, string, error) {
	selected := make(map[string]string, len(jobs))
	for _, job := range jobs {
		portableID, err := job.Session.PortableIdentity()
		if err != nil {
			return nil, "", err
		}
		key := poolJobMapKey(PoolJobKey{Core: job.Session.Core, Setname: job.Session.Setname})
		if _, exists := selected[key]; exists {
			return nil, "", fmt.Errorf("duplicate selected MiSTer job %s", key)
		}
		selected[key] = portableID
	}
	digest, err := selectedMapDigest(selected)
	if err != nil {
		return nil, "", err
	}
	return selected, digest, nil
}

func selectedMapDigest(selected map[string]string) (string, error) {
	if selected == nil {
		return "", fmt.Errorf("selected inventory is nil")
	}
	encoded, err := json.Marshal(selected)
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(encoded)
	return hex.EncodeToString(digest[:]), nil
}

func poolJobMapKey(job PoolJobKey) string { return job.Core + "/" + job.Setname }

func parsePoolJobMapKey(value string) (PoolJobKey, bool) {
	core, setname, ok := strings.Cut(value, "/")
	if !ok || !safeComponent(core) || !safeComponent(setname) || strings.Contains(setname, "/") {
		return PoolJobKey{}, false
	}
	return PoolJobKey{Core: core, Setname: setname}, true
}

func equalStringMaps(left, right map[string]string) bool {
	if len(left) != len(right) {
		return false
	}
	for key, value := range left {
		if right[key] != value {
			return false
		}
	}
	return true
}

func (c *CaptureCoordinator) ensureCaptureRuns() error {
	if c.log.Progress.CaptureRuns == nil {
		c.log.Progress.CaptureRuns = map[string]CaptureRunProgress{}
	}
	return nil
}

func (c *CaptureCoordinator) checkOtherLaneFences(jobs []PoolJob) error {
	selectedBoards := make(map[BoardKey]bool, len(c.boards))
	for _, board := range c.boards {
		selectedBoards[board.Key] = true
	}
	selectedTuples := make(map[PoolJobKey]bool, len(jobs))
	for _, job := range jobs {
		selectedTuples[PoolJobKey{Core: job.Session.Core, Setname: job.Session.Setname}] = true
	}
	for key, lane := range c.log.Progress.CaptureRuns {
		if key == c.laneKey {
			continue
		}
		if err := validateCaptureRunLane(key, lane); err != nil {
			return fmt.Errorf("validate saved capture lane %s: %w", key, err)
		}
		checkpoint, err := validatePoolCheckpoint(lane.Snapshot.Checkpoint)
		if err != nil {
			return fmt.Errorf("validate saved pool checkpoint %s: %w", key, err)
		}
		for _, record := range checkpoint.Attempts {
			if record.State != PoolAttemptInFlight && record.State != PoolAttemptUnknown {
				continue
			}
			if selectedBoards[record.Attempt.Board] || selectedTuples[record.JobKey] {
				return fmt.Errorf("capture lane %s retains unresolved attempt %s on board %s", key, record.JobKey, record.Attempt.Board)
			}
		}
		for _, item := range checkpoint.Quarantined {
			if selectedBoards[item.Board] || selectedTuples[item.JobKey] {
				return fmt.Errorf("capture lane %s quarantines selected board or tuple %s", key, item.JobKey)
			}
		}
		for _, item := range lane.Finalizations {
			if item.State == CaptureFinalizationPending && selectedTuples[item.JobKey] {
				return fmt.Errorf("capture lane %s retains unresolved private finalization for %s", key, item.JobKey)
			}
		}
	}
	return nil
}

func (c *CaptureCoordinator) validateAttemptFreshness(jobs []PoolJob, lane CaptureRunProgress) error {
	retiredSession, retiredNonce := map[string]bool{}, map[string]bool{}
	for key, saved := range c.log.Progress.CaptureRuns {
		if err := validateCaptureRunLane(key, saved); err != nil {
			return fmt.Errorf("validate saved capture lane %s: %w", key, err)
		}
		checkpoint, err := validatePoolCheckpoint(saved.Snapshot.Checkpoint)
		if err != nil {
			return fmt.Errorf("normalize saved capture checkpoint %s: %w", key, err)
		}
		for _, attempt := range checkpoint.Attempts {
			retiredSession[attempt.Attempt.SessionID] = true
			retiredNonce[attempt.Attempt.Nonce] = true
		}
		for _, item := range saved.Finalizations {
			retiredSession[item.Attempt.SessionID] = true
			retiredNonce[item.Attempt.Nonce] = true
		}
	}
	type resumeIdentity struct {
		job        PoolJobKey
		portableID string
	}
	allowedResume := map[resumeIdentity]AttemptKey{}
	for _, done := range lane.Snapshot.Checkpoint.Completed {
		allowedResume[resumeIdentity{job: done.JobKey, portableID: done.PortableID}] = done.Attempt
	}
	for _, item := range lane.Finalizations {
		identity := resumeIdentity{job: item.JobKey, portableID: item.PortableID}
		if previous, exists := allowedResume[identity]; exists && previous != item.Attempt {
			continue
		}
		allowedResume[identity] = item.Attempt
	}
	for _, input := range jobs {
		job := input
		key := PoolJobKey{Core: job.Session.Core, Setname: job.Session.Setname}
		portableID, err := job.Session.PortableIdentity()
		if err != nil {
			return fmt.Errorf("identify resumed job %s: %w", key, err)
		}
		if retiredSession[job.SessionID] || retiredNonce[job.Nonce] {
			previous, resume := allowedResume[resumeIdentity{job: key, portableID: portableID}]
			if !resume || previous.SessionID != job.SessionID || previous.Nonce != job.Nonce {
				return fmt.Errorf("attempt identity for %s reuses a retired session ID or nonce", key)
			}
		}
	}
	return nil
}

func (c *CaptureCoordinator) recoverFinalizations(ctx context.Context, lane *CaptureRunProgress, jobs []PoolJob) error {
	if lane.Finalizations == nil {
		lane.Finalizations = map[string]CaptureFinalizationProgress{}
	}
	if c.finalizationKind == miSTerSerialResultsKind && lane.Games == nil {
		lane.Games = map[string]MiSTerGameSummary{}
	}
	for operationKey, item := range lane.Finalizations {
		if operationKey != captureOperationKey(c.laneKey, item.JobKey, item.PortableID, item.Attempt) || !isSHA256Hex(item.PortableID) || !isSHA256Hex(item.InputDigest) || item.Attempt.Board == "" || item.Attempt.SessionID == "" || item.Attempt.Nonce == "" {
			return fmt.Errorf("capture finalization journal contains invalid operation identity")
		}
		if c.finalizationKind == miSTerSerialResultsKind {
			if item.Plan == nil {
				return fmt.Errorf("serial result finalization %s has no immutable plan", operationKey)
			}
			if err := item.Plan.Validate(); err != nil {
				return fmt.Errorf("invalid serial result plan %s: %w", operationKey, err)
			}
			inputDigest, err := item.Plan.InputDigest()
			if err != nil || inputDigest != item.InputDigest {
				return fmt.Errorf("serial result plan %s does not match its input digest", operationKey)
			}
		} else if item.Plan != nil {
			return fmt.Errorf("private capture finalization %s unexpectedly contains a serial result plan", operationKey)
		}
		switch item.State {
		case CaptureFinalizationPending:
			if item.ResultDigest != "" {
				return fmt.Errorf("pending capture finalization has a result digest")
			}
			if c.finalizationKind == miSTerSerialResultsKind && !miSTerCurrentCaptureProtocol(item.Plan.Candidate.CaptureProtocol) {
				return fmt.Errorf("pending MiSTer finalization %s uses a legacy or missing capture protocol; it cannot be replayed as v2", operationKey)
			}
			resultDigest, committed, err := c.effects.ReconcileCapture(ctx, operationKey, item.InputDigest, item.Plan.Clone())
			if err != nil {
				return fmt.Errorf("reconcile pending capture result %s: %w", operationKey, err)
			}
			if !committed || !isSHA256Hex(resultDigest) {
				return fmt.Errorf("capture finalization %s remains unresolved; dispatch is blocked", operationKey)
			}
			item.State, item.ResultDigest = CaptureFinalizationComplete, resultDigest
			lane.Finalizations[operationKey] = item
			if err = c.effects.RevalidateCapture(ctx, operationKey, item.InputDigest, item.ResultDigest, item.Plan.Clone()); err != nil {
				if item.Plan == nil {
					return fmt.Errorf("revalidate reconciled private capture: %w", err)
				}
				return fmt.Errorf("revalidate reconciled capture result: %w", err)
			}
			if item.Plan != nil {
				lane.Games[poolJobMapKey(item.JobKey)] = item.Plan.Summary
			}
		case CaptureFinalizationComplete:
			if !isSHA256Hex(item.ResultDigest) {
				return fmt.Errorf("complete capture finalization has invalid result digest")
			}
			if err := c.effects.RevalidateCapture(ctx, operationKey, item.InputDigest, item.ResultDigest, item.Plan.Clone()); err != nil {
				if item.Plan == nil {
					return fmt.Errorf("revalidate private capture %s: %w", operationKey, err)
				}
				return fmt.Errorf("revalidate capture result %s: %w", operationKey, err)
			}
			if item.Plan != nil {
				lane.Games[poolJobMapKey(item.JobKey)] = item.Plan.Summary
			}
		default:
			return fmt.Errorf("unknown capture finalization state %q", item.State)
		}
	}
	if err := repairCaptureCompletion(lane); err != nil {
		return err
	}
	if err := requireFinalizationForCompleted(lane); err != nil {
		return err
	}
	if len(jobs) == 0 {
		return fmt.Errorf("capture finalization recovery has no selected prepared jobs")
	}
	return nil
}

func (c *CaptureCoordinator) persistLane(lane CaptureRunProgress) error {
	if err := validateCaptureRunLane(c.laneKey, lane); err != nil {
		return err
	}
	c.log.Progress.CaptureRuns[c.laneKey] = lane.Clone()
	if err := c.log.Save(); err != nil {
		return err
	}
	return c.options.SyncDirectory(filepath.Join(c.log.Root, "log"))
}

func (c *CaptureCoordinator) updateSnapshot(snapshot PoolSnapshot) error {
	lane := c.log.Progress.CaptureRuns[c.laneKey].Clone()
	lane.Snapshot = snapshot.Clone()
	return c.persistLane(lane)
}

type captureRunObserver struct{ coordinator *CaptureCoordinator }

func (o captureRunObserver) Progress(snapshot PoolSnapshot) error {
	return o.coordinator.updateSnapshot(snapshot)
}

type captureRunFinalizer struct{ coordinator *CaptureCoordinator }

func (f captureRunFinalizer) Finalize(ctx context.Context, jobKey PoolJobKey, portableID string, attempt AttemptKey, session PreparedSession, capture SessionCapture) (string, error) {
	c := f.coordinator
	if session.Generation != c.qualification.Generation || session.Convention != c.qualification.Convention || capture.Receipt.Generation != c.qualification.Generation || capture.Receipt.CaptureConvention != c.qualification.Convention {
		return "", fmt.Errorf("capture does not match qualified generation and convention")
	}
	opKey := captureOperationKey(c.laneKey, jobKey, portableID, attempt)
	inputDigest, plan, err := c.effects.PrepareCapture(ctx, opKey, c.qualification, jobKey, portableID, attempt, session.Clone(), capture.Clone())
	if err != nil {
		return "", err
	}
	if !isSHA256Hex(inputDigest) {
		return "", fmt.Errorf("capture finalizer returned an invalid input digest")
	}
	if c.finalizationKind == miSTerSerialResultsKind {
		if plan == nil {
			return "", fmt.Errorf("serial result finalizer returned no immutable plan")
		}
		if err = plan.Validate(); err != nil {
			return "", err
		}
		if plan.Summary.PortableID != portableID || plan.Summary.Attempt != attempt || plan.Summary.OperationKey != opKey {
			return "", fmt.Errorf("serial result summary does not match selected job/attempt")
		}
		planDigest, digestErr := plan.InputDigest()
		if digestErr != nil || planDigest != inputDigest {
			return "", fmt.Errorf("serial result plan digest does not match prepared intent")
		}
	} else if plan != nil {
		return "", fmt.Errorf("private capture finalizer returned a serial result plan")
	}
	lane := c.log.Progress.CaptureRuns[c.laneKey].Clone()
	if prior, exists := lane.Finalizations[opKey]; exists {
		if prior.InputDigest != inputDigest || !sameMiSTerPlan(prior.Plan, plan) {
			return "", fmt.Errorf("capture operation key has conflicting input digest or plan")
		}
		if prior.State == CaptureFinalizationComplete {
			if err = c.effects.RevalidateCapture(ctx, opKey, prior.InputDigest, prior.ResultDigest, prior.Plan.Clone()); err != nil {
				return "", err
			}
			return prior.ResultDigest, nil
		}
		return "", fmt.Errorf("capture operation %s is already pending reconciliation", opKey)
	}
	if c.finalizationKind == miSTerSerialResultsKind {
		lane.Current = poolJobMapKey(jobKey)
		lane.Status = "finalizing"
		lane.Complete = false
	}
	lane.Finalizations[opKey] = CaptureFinalizationProgress{JobKey: jobKey, PortableID: portableID, Attempt: attempt, InputDigest: inputDigest, State: CaptureFinalizationPending, Plan: plan.Clone()}
	if err = c.persistLane(lane); err != nil {
		return "", fmt.Errorf("persist capture finalization intent: %w", err)
	}
	if c.finalizationKind == miSTerSerialResultsKind && c.options.FailureHook != nil {
		if err = c.options.FailureHook("after-pending"); err != nil {
			return "", fmt.Errorf("serial finalization interrupted after pending intent: %w", err)
		}
	}
	resultDigest, err := c.effects.CommitCapture(ctx, opKey, inputDigest, plan.Clone(), session.Clone(), capture.Clone())
	if err != nil {
		return "", err
	}
	if !isSHA256Hex(resultDigest) {
		return "", fmt.Errorf("capture result committer returned an invalid result digest")
	}
	lane = c.log.Progress.CaptureRuns[c.laneKey].Clone()
	item := lane.Finalizations[opKey]
	if item.State != CaptureFinalizationPending || item.InputDigest != inputDigest {
		return "", fmt.Errorf("private finalization intent changed during commit")
	}
	item.State, item.ResultDigest = CaptureFinalizationComplete, resultDigest
	lane.Finalizations[opKey] = item
	if item.Plan != nil {
		lane.Games[poolJobMapKey(jobKey)] = item.Plan.Summary
		lane.Current = ""
		lane.Status = "running"
	}
	if err = c.persistLane(lane); err != nil {
		return "", fmt.Errorf("persist capture finalization completion: %w", err)
	}
	return resultDigest, nil
}

func sameMiSTerPlan(left, right *MiSTerFinalizationPlan) bool {
	if left == nil || right == nil {
		return left == right
	}
	leftJSON, leftErr := json.Marshal(left)
	rightJSON, rightErr := json.Marshal(right)
	return leftErr == nil && rightErr == nil && string(leftJSON) == string(rightJSON)
}

func validateCaptureRunLane(key string, lane CaptureRunProgress) error {
	if lane.SchemaVersion != captureRunSchemaVersion || lane.Target != "mister" || strings.TrimSpace(lane.CaptureGeneration) == "" || lane.CaptureConvention != CaptureNativeNonRotatedRGB888 || strings.TrimSpace(lane.QualificationID) == "" {
		return fmt.Errorf("invalid capture run schema or qualification")
	}
	qualification := CaptureQualification{Target: lane.Target, Generation: lane.CaptureGeneration, Convention: lane.CaptureConvention, QualificationID: lane.QualificationID, Qualified: true}
	expectedKey, err := captureLaneKeyForKind(qualification, lane.FinalizationKind, lane.RunScopeID)
	if err != nil {
		return err
	}
	if key != expectedKey {
		return fmt.Errorf("capture run lane key does not match its identity")
	}
	if lane.FinalizationKind == "" {
		if lane.RunScopeID != "" || lane.SelectionSHA256 != "" || lane.SelectedArchiveSHA256 != "" || lane.Selected != nil || lane.Games != nil || lane.Current != "" || lane.Status != "" || lane.Complete {
			return fmt.Errorf("private-v1 lane contains serial result state")
		}
	} else if lane.FinalizationKind == miSTerSerialResultsKind {
		if strings.TrimSpace(lane.RunScopeID) == "" || !isSHA256Hex(lane.SelectionSHA256) || lane.SelectedArchiveSHA256 != "" && !isSHA256Hex(lane.SelectedArchiveSHA256) || lane.Selected == nil {
			return fmt.Errorf("serial result lane is missing scope or selection inventory")
		}
		if lane.Games == nil {
			for _, item := range lane.Finalizations {
				if item.State == CaptureFinalizationComplete {
					return fmt.Errorf("serial result lane is missing summaries for completed finalizations")
				}
			}
			if len(lane.Snapshot.Checkpoint.Completed) != 0 {
				return fmt.Errorf("serial result lane is missing summaries for completed pool results")
			}
			for _, result := range lane.Snapshot.Jobs {
				if result.State == PoolResultComplete {
					return fmt.Errorf("serial result lane is missing summaries for completed pool results")
				}
			}
		}
		selectionSHA, err := selectedMapDigest(lane.Selected)
		if err != nil || selectionSHA != lane.SelectionSHA256 {
			return fmt.Errorf("serial result lane selection digest mismatch")
		}
		if lane.Current != "" && lane.Selected[lane.Current] == "" {
			return fmt.Errorf("serial result current job is outside selected inventory")
		}
		switch lane.Status {
		case "", "running", "finalizing", "complete", "blocked":
		default:
			return fmt.Errorf("serial result lane has invalid status %q", lane.Status)
		}
		if lane.Status == "finalizing" && lane.Current == "" || lane.Status == "complete" && (!lane.Complete || lane.Current != "") {
			return fmt.Errorf("serial result lane status contradicts its current or completion state")
		}
		for gameKey, summary := range lane.Games {
			portableID, exists := lane.Selected[gameKey]
			if !exists || summary.PortableID != portableID || !isSHA256Hex(summary.OperationKey) || summary.Attempt.Board == "" || summary.Attempt.SessionID == "" || summary.Attempt.Nonce == "" || !isSHA256Hex(summary.OutputDigest) {
				return fmt.Errorf("serial result summary %s does not match selected inventory", gameKey)
			}
			if summary.Result != Pass && summary.Result != New && summary.Result != Fail {
				return fmt.Errorf("serial result summary %s has invalid outcome %q", gameKey, summary.Result)
			}
			jobKey, ok := parsePoolJobMapKey(gameKey)
			if !ok {
				return fmt.Errorf("serial result summary has invalid selected job key %q", gameKey)
			}
			operationKey := captureOperationKey(key, jobKey, summary.PortableID, summary.Attempt)
			finalization, ok := lane.Finalizations[operationKey]
			if !ok || finalization.State != CaptureFinalizationComplete || finalization.Plan == nil || finalization.Plan.Summary != summary {
				return fmt.Errorf("serial result summary %s has no exact complete finalization", gameKey)
			}
		}
		if lane.Complete {
			if lane.Status != "complete" || lane.Current != "" || len(lane.Games) != len(lane.Selected) {
				return fmt.Errorf("complete serial result lane does not cover its frozen selection")
			}
			for gameKey := range lane.Selected {
				if _, ok := lane.Games[gameKey]; !ok {
					return fmt.Errorf("complete serial result lane is missing %s", gameKey)
				}
			}
		}
	} else {
		return fmt.Errorf("unknown capture finalization kind %q", lane.FinalizationKind)
	}
	if _, err := validatePoolCheckpoint(lane.Snapshot.Checkpoint); err != nil {
		return fmt.Errorf("invalid capture pool checkpoint: %w", err)
	}
	for operationKey, item := range lane.Finalizations {
		if operationKey != captureOperationKey(key, item.JobKey, item.PortableID, item.Attempt) || item.JobKey.Core == "" || item.JobKey.Setname == "" || !isSHA256Hex(item.PortableID) || !isSHA256Hex(item.InputDigest) || item.Attempt.Board == "" || item.Attempt.SessionID == "" || item.Attempt.Nonce == "" {
			return fmt.Errorf("invalid capture finalization identity")
		}
		if lane.FinalizationKind == miSTerSerialResultsKind {
			if item.Plan == nil || item.Plan.Validate() != nil {
				return fmt.Errorf("serial result finalization %s has an invalid plan", operationKey)
			}
			planDigest, err := item.Plan.InputDigest()
			if err != nil || planDigest != item.InputDigest || item.Plan.Summary.PortableID != item.PortableID || item.Plan.Summary.Attempt != item.Attempt || item.Plan.Summary.OperationKey != operationKey {
				return fmt.Errorf("serial result finalization %s plan does not match identity/digest", operationKey)
			}
			if item.State == CaptureFinalizationComplete {
				summary, exists := lane.Games[poolJobMapKey(item.JobKey)]
				if !exists || summary != item.Plan.Summary {
					return fmt.Errorf("serial result finalization %s has no matching summary", operationKey)
				}
			}
		} else if item.Plan != nil {
			return fmt.Errorf("private finalization %s contains a serial result plan", operationKey)
		}
		switch item.State {
		case CaptureFinalizationPending:
			if item.ResultDigest != "" {
				return fmt.Errorf("pending capture finalization includes result digest")
			}
		case CaptureFinalizationComplete:
			if !isSHA256Hex(item.ResultDigest) {
				return fmt.Errorf("complete capture finalization has invalid result digest")
			}
		default:
			return fmt.Errorf("invalid capture finalization state %q", item.State)
		}
	}
	if err := requireFinalizationForCompleted(&lane); err != nil {
		return err
	}
	for _, result := range lane.Snapshot.Jobs {
		if result.State != PoolResultComplete {
			continue
		}
		operationKey := captureOperationKey(key, result.JobKey, result.PortableID, result.Attempt)
		item, ok := lane.Finalizations[operationKey]
		if !ok || item.State != CaptureFinalizationComplete || item.ResultDigest != result.ResultDigest {
			return fmt.Errorf("completed pool snapshot result has no matching private finalization")
		}
		matched := false
		for _, done := range lane.Snapshot.Checkpoint.Completed {
			if done.JobKey == result.JobKey && done.PortableID == result.PortableID && done.Attempt == result.Attempt && done.ResultDigest == result.ResultDigest {
				matched = true
				break
			}
		}
		if !matched {
			return fmt.Errorf("completed pool snapshot result has no matching completion checkpoint")
		}
	}
	return nil
}

func repairCaptureCompletion(lane *CaptureRunProgress) error {
	if lane == nil {
		return fmt.Errorf("capture lane is nil")
	}
	checkpoint, err := validatePoolCheckpoint(lane.Snapshot.Checkpoint)
	if err != nil {
		return err
	}
	for operationKey, item := range lane.Finalizations {
		if item.State != CaptureFinalizationComplete {
			continue
		}
		found := false
		for _, done := range checkpoint.Completed {
			if done.JobKey == item.JobKey && done.PortableID == item.PortableID && done.Attempt == item.Attempt && done.ResultDigest == item.ResultDigest {
				found = true
				break
			}
			if done.JobKey == item.JobKey && done.Attempt == item.Attempt {
				return fmt.Errorf("pool completion conflicts with private finalization %s", operationKey)
			}
		}
		if found {
			continue
		}
		attemptFound := false
		for index := range checkpoint.Attempts {
			if checkpoint.Attempts[index].Attempt == item.Attempt && checkpoint.Attempts[index].JobKey == item.JobKey && checkpoint.Attempts[index].PortableID == item.PortableID {
				if checkpoint.Attempts[index].State != PoolAttemptClean && checkpoint.Attempts[index].State != PoolAttemptComplete {
					return fmt.Errorf("private finalization %s conflicts with unresolved attempt state", operationKey)
				}
				checkpoint.Attempts[index].State = PoolAttemptComplete
				attemptFound = true
				break
			}
		}
		if !attemptFound {
			checkpoint.Attempts = append(checkpoint.Attempts, PoolAttemptRecord{JobKey: item.JobKey, PortableID: item.PortableID, Attempt: item.Attempt, Generation: lane.CaptureGeneration, State: PoolAttemptComplete})
		}
		checkpoint = setPoolCompleted(checkpoint, PoolCompleted{JobKey: item.JobKey, PortableID: item.PortableID, ResultDigest: item.ResultDigest, Attempt: item.Attempt})
	}
	validated, err := validatePoolCheckpoint(checkpoint)
	if err != nil {
		return fmt.Errorf("repair capture completion checkpoint: %w", err)
	}
	lane.Snapshot.Checkpoint = validated
	for _, item := range lane.Snapshot.Jobs {
		if item.State != PoolResultComplete {
			continue
		}
		matched := false
		for _, done := range validated.Completed {
			if done.JobKey == item.JobKey && done.PortableID == item.PortableID && done.Attempt == item.Attempt && done.ResultDigest == item.ResultDigest {
				matched = true
				break
			}
		}
		if !matched {
			return fmt.Errorf("pool snapshot completion has no matching private finalization")
		}
	}
	for _, item := range lane.Finalizations {
		if item.State != CaptureFinalizationComplete {
			continue
		}
		present := false
		for index := range lane.Snapshot.Jobs {
			result := &lane.Snapshot.Jobs[index]
			if result.JobKey == item.JobKey && result.PortableID == item.PortableID && result.Attempt == item.Attempt {
				if result.State == PoolResultComplete && result.ResultDigest == item.ResultDigest {
					present = true
				} else if result.State == PoolResultPending {
					result.State, result.ResultDigest, result.Message = PoolResultComplete, item.ResultDigest, ""
					present = true
				}
			}
		}
		if !present {
			lane.Snapshot.Jobs = append(lane.Snapshot.Jobs, PoolJobResult{JobKey: item.JobKey, PortableID: item.PortableID, State: PoolResultComplete, Attempt: item.Attempt, ResultDigest: item.ResultDigest})
		}
	}
	return nil
}

func requireFinalizationForCompleted(lane *CaptureRunProgress) error {
	for _, done := range lane.Snapshot.Checkpoint.Completed {
		key := captureOperationKey(laneKeyFromProgress(*lane), done.JobKey, done.PortableID, done.Attempt)
		item, exists := lane.Finalizations[key]
		if !exists || item.State != CaptureFinalizationComplete || item.InputDigest == "" || item.ResultDigest != done.ResultDigest {
			return fmt.Errorf("pool completion %s has no matching complete private finalization", done.JobKey)
		}
	}
	return nil
}

func laneKeyFromProgress(lane CaptureRunProgress) string {
	key, _ := captureLaneKeyForKind(CaptureQualification{Target: lane.Target, Generation: lane.CaptureGeneration, Convention: lane.CaptureConvention, QualificationID: lane.QualificationID, Qualified: true}, lane.FinalizationKind, lane.RunScopeID)
	return key
}

func captureOperationKey(laneKey string, job PoolJobKey, portableID string, attempt AttemptKey) string {
	identity := struct {
		Lane       string     `json:"lane"`
		Core       string     `json:"core"`
		Setname    string     `json:"setname"`
		PortableID string     `json:"portable_id"`
		Attempt    AttemptKey `json:"attempt"`
	}{laneKey, job.Core, job.Setname, portableID, attempt}
	encoded, _ := json.Marshal(identity)
	digest := sha256.Sum256(encoded)
	return hex.EncodeToString(digest[:])
}

func sync_capture_progress_dir(directory string) error {
	handle, err := os.Open(directory)
	if err != nil {
		return fmt.Errorf("open progress directory for sync: %w", err)
	}
	syncErr := handle.Sync()
	closeErr := handle.Close()
	return errors.Join(syncErr, closeErr)
}
