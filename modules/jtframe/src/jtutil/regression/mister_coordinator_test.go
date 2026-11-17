/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

type coordinatorTestDriver struct {
	mu           sync.Mutex
	healthyCalls int
	captureCalls int
	healthy      func(context.Context) error
	capture      func(context.Context, AttemptKey, PreparedSession) (SessionCapture, error)
	cancel       int
	reconcile    int
}

func (d *coordinatorTestDriver) Healthy(ctx context.Context) error {
	d.mu.Lock()
	d.healthyCalls++
	d.mu.Unlock()
	if d.healthy != nil {
		return d.healthy(ctx)
	}
	return nil
}

func (d *coordinatorTestDriver) Capture(ctx context.Context, key AttemptKey, session PreparedSession) (SessionCapture, error) {
	d.mu.Lock()
	d.captureCalls++
	d.mu.Unlock()
	if d.capture != nil {
		return d.capture(ctx, key, session)
	}
	capture := goodPoolCapture(key)
	capture.Receipt.Generation = session.Generation
	capture.Receipt.CaptureConvention = session.Convention
	return capture, nil
}

func (d *coordinatorTestDriver) Cancel(context.Context, AttemptKey) error {
	d.mu.Lock()
	d.cancel++
	d.mu.Unlock()
	return nil
}

func (d *coordinatorTestDriver) Reconcile(context.Context, AttemptKey) (SessionCleanup, error) {
	d.mu.Lock()
	d.reconcile++
	d.mu.Unlock()
	return SessionCleanup{Confirmed: true}, nil
}

func (d *coordinatorTestDriver) counts() (int, int) {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.healthyCalls, d.captureCalls
}

type coordinatorTestEffects struct {
	mu                  sync.Mutex
	committed           map[string]string
	verifyCalls         int
	commitCalls         int
	activeCommits       int
	maxCommits          int
	revalidateCalls     int
	reconcileCalls      int
	commitErrorAfter    bool
	verifyError         error
	commitError         error
	reconcileKnownEmpty bool
}

func newCoordinatorTestEffects() *coordinatorTestEffects {
	return &coordinatorTestEffects{committed: map[string]string{}}
}

func (f *coordinatorTestEffects) VerifyPrivate(_ context.Context, _ CaptureQualification, job PoolJobKey, portableID string, attempt AttemptKey, _ PreparedSession, capture SessionCapture) (string, error) {
	f.mu.Lock()
	f.verifyCalls++
	err := f.verifyError
	f.mu.Unlock()
	if err != nil {
		return "", err
	}
	return testDigest(job.String() + portableID + attempt.SessionID + attempt.Nonce + capture.Receipt.SessionID), nil
}

func (f *coordinatorTestEffects) CommitPrivate(_ context.Context, operationKey, inputDigest string, _ PreparedSession, _ SessionCapture) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.commitCalls++
	f.activeCommits++
	if f.activeCommits > f.maxCommits {
		f.maxCommits = f.activeCommits
	}
	defer func() { f.activeCommits-- }()
	result := testDigest(operationKey + inputDigest)
	f.committed[operationKey] = result
	if f.commitError != nil {
		return "", f.commitError
	}
	if f.commitErrorAfter {
		return "", errors.New("simulated interruption after private effect")
	}
	return result, nil
}

func (f *coordinatorTestEffects) RevalidatePrivate(_ context.Context, operationKey, inputDigest, resultDigest string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.revalidateCalls++
	if f.committed[operationKey] != resultDigest || resultDigest != testDigest(operationKey+inputDigest) {
		return errors.New("private result does not match recorded digest")
	}
	return nil
}

func (f *coordinatorTestEffects) ReconcilePrivate(_ context.Context, operationKey, inputDigest string) (string, bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.reconcileCalls++
	result, ok := f.committed[operationKey]
	if !ok && f.reconcileKnownEmpty {
		return "", false, nil
	}
	if !ok {
		return "", false, nil
	}
	if result != testDigest(operationKey+inputDigest) {
		return "", false, errors.New("private result changed during reconciliation")
	}
	return result, true, nil
}

func testDigest(value string) string {
	digest := sha256.Sum256([]byte(value))
	return hex.EncodeToString(digest[:])
}

func coordinatorFixture(t *testing.T, opts CaptureCoordinatorOptions, qualification CaptureQualification, driver *coordinatorTestDriver, effects *coordinatorTestEffects) (*CommitLog, *CaptureCoordinator, string) {
	t.Helper()
	root := t.TempDir()
	if err := InitializeLog(root); err != nil {
		t.Fatal(err)
	}
	commit := strings.Repeat("a", 40)
	log, err := OpenCommitLog(root, commit)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = log.Close() })
	coordinator, err := NewCaptureCoordinator(log, qualification, []PoolBoard{poolBoard("board-a", "board-a.local", driver), poolBoard("board-b", "board-b.local", driver)}, effects, opts)
	if err != nil {
		t.Fatal(err)
	}
	return log, coordinator, root
}

func coordinatorQualification() CaptureQualification {
	return CaptureQualification{Target: "mister", Generation: "qualified-a039", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "reviewed-hdmi-proof-1", Qualified: true}
}

func coordinatorJobs(t *testing.T, qualification CaptureQualification, names ...string) []PoolJob {
	t.Helper()
	jobs := make([]PoolJob, 0, len(names))
	for index, name := range names {
		job := poolJob(t, name, "session-"+name, "nonce-"+name)
		job.Session.Generation = qualification.Generation
		job.Session.Convention = qualification.Convention
		jobs = append(jobs, job)
		_ = index
	}
	return jobs
}

func TestCaptureCoordinatorPersistsBeforeDriverAndPreservesLegacyProgress(t *testing.T) {
	qualification := coordinatorQualification()
	var log *CommitLog
	driver := &coordinatorTestDriver{}
	driver.healthy = func(context.Context) error {
		progress, err := ReadProgress(log.Root, log.Progress.Commit)
		if err != nil {
			return err
		}
		for _, lane := range progress.CaptureRuns {
			for _, record := range lane.Snapshot.Checkpoint.Attempts {
				if record.State == PoolAttemptInFlight {
					return nil
				}
			}
		}
		return errors.New("driver entered before durable in-flight checkpoint")
	}
	effects := newCoordinatorTestEffects()
	var err error
	log, _, _ = coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second}, qualification, driver, effects)
	log.Progress.Status = "legacy-interrupted"
	log.Progress.AutomaticComplete = true
	log.Progress.Current = "circus/circusc"
	log.Progress.Error = "legacy-error"
	log.Progress.RBFs["old.rbf"] = testDigest("legacy")
	log.Progress.Games["circus/circusc"] = ProgressGame{Result: Pass, Input: "legacy-input", Output: "legacy-output", Stage: "legacy-stage", Message: "legacy-message"}
	if err = log.Save(); err != nil {
		t.Fatal(err)
	}
	legacyRow := "2026-01-01 00:00:00 old PASS --------\n"
	history := filepath.Join(log.Root, "circus", "circusc", "log")
	if err = os.MkdirAll(filepath.Dir(history), 0750); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(history, []byte(legacyRow), 0640); err != nil {
		t.Fatal(err)
	}
	resultSentinels := map[string]string{}
	for _, slot := range []string{"ref", "new", "fail"} {
		filename := filepath.Join(log.Root, "circus", "circusc", slot, "sentinel")
		if err = os.MkdirAll(filepath.Dir(filename), 0750); err != nil {
			t.Fatal(err)
		}
		value := "legacy-" + slot
		if err = os.WriteFile(filename, []byte(value), 0640); err != nil {
			t.Fatal(err)
		}
		resultSentinels[filename] = value
	}
	coordinator, err := NewCaptureCoordinator(log, qualification, []PoolBoard{poolBoard("board-a", "board-a.local", driver)}, effects, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second})
	if err != nil {
		t.Fatal(err)
	}
	jobs := coordinatorJobs(t, qualification, "circusc")
	snapshot, err := coordinator.Run(context.Background(), jobs)
	if err != nil {
		t.Fatal(err)
	}
	if len(snapshot.Jobs) != 1 || snapshot.Jobs[0].State != PoolResultComplete {
		t.Fatalf("capture lane did not complete: %+v", snapshot.Jobs)
	}
	if healthy, captured := driver.counts(); healthy != 1 || captured != 1 {
		t.Fatalf("legacy AutomaticComplete skipped new lane: healthy=%d capture=%d", healthy, captured)
	}
	if log.Progress.Status != "legacy-interrupted" || !log.Progress.AutomaticComplete || log.Progress.Current != "circus/circusc" || log.Progress.Error != "legacy-error" || log.Progress.RBFs["old.rbf"] != testDigest("legacy") || log.Progress.Games["circus/circusc"].Input != "legacy-input" {
		t.Fatalf("legacy progress changed: %+v", log.Progress)
	}
	row, err := os.ReadFile(history)
	if err != nil || string(row) != legacyRow {
		t.Fatalf("legacy history changed: %q, %v", row, err)
	}
	for filename, expected := range resultSentinels {
		data, readErr := os.ReadFile(filename)
		if readErr != nil || string(data) != expected {
			t.Fatalf("legacy result slot changed at %s: %q, %v", filename, data, readErr)
		}
	}
	lane := log.Progress.CaptureRuns[coordinator.laneKey]
	if err = validateCaptureRunLane(coordinator.laneKey, lane); err != nil {
		t.Fatalf("saved lane invalid: %v", err)
	}
	if len(lane.Finalizations) != 1 || len(lane.Snapshot.Checkpoint.Completed) != 1 {
		t.Fatalf("completion journal/checkpoint mismatch: %+v", lane)
	}
}

func TestCaptureCoordinatorRequiresQualificationAndDurableDirectoryFence(t *testing.T) {
	qualification := coordinatorQualification()
	driver := &coordinatorTestDriver{}
	effects := newCoordinatorTestEffects()
	log, _, _ := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second}, qualification, driver, effects)
	badQualification := qualification
	badQualification.Qualified = false
	if _, err := NewCaptureCoordinator(log, badQualification, []PoolBoard{poolBoard("board-a", "a", driver)}, effects, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second}); err == nil {
		t.Fatal("unqualified generation accepted")
	}
	coordinator, err := NewCaptureCoordinator(log, qualification, []PoolBoard{poolBoard("board-a", "a", driver)}, effects, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second, SyncDirectory: func(string) error { return errors.New("injected directory sync failure") }})
	if err != nil {
		t.Fatal(err)
	}
	if _, err = coordinator.Run(context.Background(), coordinatorJobs(t, qualification, "circusc")); err == nil {
		t.Fatal("directory sync failure was ignored")
	}
	if healthy, captured := driver.counts(); healthy != 0 || captured != 0 {
		t.Fatalf("driver ran before directory durability fence: healthy=%d capture=%d", healthy, captured)
	}
}

func TestCaptureCoordinatorStartDirectoryFenceFailurePreventsDriverEntry(t *testing.T) {
	qualification := coordinatorQualification()
	driver := &coordinatorTestDriver{}
	effects := newCoordinatorTestEffects()
	syncCount := 0
	_, coordinator, _ := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second, SyncDirectory: func(path string) error {
		syncCount++
		if syncCount == 2 {
			return errors.New("injected start checkpoint directory sync failure")
		}
		return sync_capture_progress_dir(path)
	}}, qualification, driver, effects)
	if _, err := coordinator.Run(context.Background(), coordinatorJobs(t, qualification, "circusc")); err == nil {
		t.Fatal("start checkpoint directory sync failure was ignored")
	}
	if healthy, captured := driver.counts(); healthy != 0 || captured != 0 {
		t.Fatalf("driver entered despite failed start fence: healthy=%d capture=%d", healthy, captured)
	}
	if effects.verifyCalls != 0 || effects.commitCalls != 0 {
		t.Fatal("private finalizer ran before capture driver")
	}
}

func TestCaptureCoordinatorCapturesConcurrentlyButCommitsSerially(t *testing.T) {
	qualification := coordinatorQualification()
	started := make(chan struct{}, 2)
	release := make(chan struct{})
	driver := &coordinatorTestDriver{capture: func(_ context.Context, key AttemptKey, session PreparedSession) (SessionCapture, error) {
		session.Profile.Options["worker_mutation"] = "changed"
		started <- struct{}{}
		<-release
		capture := goodPoolCapture(key)
		capture.Receipt.Generation = session.Generation
		capture.Receipt.CaptureConvention = session.Convention
		return capture, nil
	}}
	effects := newCoordinatorTestEffects()
	_, coordinator, _ := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: 3 * time.Second, CleanupTimeout: time.Second}, qualification, driver, effects)
	jobs := coordinatorJobs(t, qualification, "circusc", "circus2")
	done := make(chan error, 1)
	go func() {
		_, err := coordinator.Run(context.Background(), jobs)
		done <- err
	}()
	for range 2 {
		select {
		case <-started:
		case <-time.After(time.Second):
			close(release)
			t.Fatal("second board did not enter capture while first was active")
		}
	}
	close(release)
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("coordinator did not finish both captures")
	}
	effects.mu.Lock()
	maxCommits := effects.maxCommits
	effects.mu.Unlock()
	if maxCommits != 1 {
		t.Fatalf("private finalizer was not single-writer: max=%d", maxCommits)
	}
	for _, job := range jobs {
		if _, changed := job.Session.Profile.Options["worker_mutation"]; changed {
			t.Fatal("worker mutated caller-owned prepared job")
		}
	}
}

func TestCaptureCoordinatorSaveFailureHasZeroDriverCalls(t *testing.T) {
	qualification := coordinatorQualification()
	driver := &coordinatorTestDriver{}
	effects := newCoordinatorTestEffects()
	log, coordinator, root := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second}, qualification, driver, effects)
	filename := filepath.Join(root, "log", LogKey(log.Progress.Commit, false)+".json")
	if err := os.Mkdir(filename, 0750); err != nil {
		t.Fatal(err)
	}
	if _, err := coordinator.Run(context.Background(), coordinatorJobs(t, qualification, "circusc")); err == nil {
		t.Fatal("blocked progress replacement did not fail")
	}
	if healthy, captured := driver.counts(); healthy != 0 || captured != 0 {
		t.Fatalf("driver ran after CommitLog.Save failure: healthy=%d capture=%d", healthy, captured)
	}
	if effects.commitCalls != 0 {
		t.Fatal("private effect ran after progress Save failure")
	}
}

func TestCaptureCoordinatorReconcilesPendingEffectWithoutRepeatingIt(t *testing.T) {
	qualification := coordinatorQualification()
	driver := &coordinatorTestDriver{}
	effects := newCoordinatorTestEffects()
	effects.commitErrorAfter = true
	log, coordinator, root := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second}, qualification, driver, effects)
	jobs := coordinatorJobs(t, qualification, "circusc")
	snapshot, err := coordinator.Run(context.Background(), jobs)
	if err == nil {
		t.Fatal("incomplete private effect was reported successful")
	}
	if len(snapshot.Jobs) != 1 || snapshot.Jobs[0].State != PoolResultPending {
		t.Fatalf("interrupted private effect was reported complete: %+v", snapshot.Jobs)
	}
	if len(log.Progress.CaptureRuns[coordinator.laneKey].Finalizations) != 1 {
		t.Fatal("pending private intent was not retained")
	}
	if err := log.Close(); err != nil {
		t.Fatal(err)
	}
	log, err = OpenCommitLog(root, strings.Repeat("a", 40))
	if err != nil {
		t.Fatal(err)
	}
	defer log.Close()
	coordinator, err = NewCaptureCoordinator(log, qualification, []PoolBoard{poolBoard("board-a", "board-a.local", driver)}, effects, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second})
	if err != nil {
		t.Fatal(err)
	}
	snapshot, err = coordinator.Run(context.Background(), jobs)
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Jobs[0].State != PoolResultComplete {
		t.Fatalf("reconciled private result was not completed: %+v", snapshot.Jobs)
	}
	if _, captured := driver.counts(); captured != 1 {
		t.Fatalf("pending private result caused duplicate capture: %d", captured)
	}
	if effects.commitCalls != 1 || effects.reconcileCalls != 1 {
		t.Fatalf("private effect was repeated or not reconciled: commits=%d reconciles=%d", effects.commitCalls, effects.reconcileCalls)
	}
}

func TestCaptureCoordinatorCompleteMarkerRepairsMissingPoolCompletion(t *testing.T) {
	qualification := coordinatorQualification()
	driver := &coordinatorTestDriver{}
	effects := newCoordinatorTestEffects()
	var syncs atomicCounter
	log, coordinator, root := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second, SyncDirectory: func(path string) error {
		count := syncs.Add(1)
		if count == 5 {
			return errors.New("simulated crash after complete marker")
		}
		return sync_capture_progress_dir(path)
	}}, qualification, driver, effects)
	jobs := coordinatorJobs(t, qualification, "circusc")
	snapshot, err := coordinator.Run(context.Background(), jobs)
	if err == nil {
		t.Fatal("complete marker with an unsynced pool completion was reported successful")
	}
	if len(snapshot.Checkpoint.Completed) != 0 || snapshot.Jobs[0].State != PoolResultPending {
		t.Fatalf("failed final pool checkpoint was reported complete: %+v", snapshot)
	}
	if syncs.Load() < 6 {
		t.Fatalf("did not reach injected completion boundary: %d syncs", syncs.Load())
	}
	if err := log.Close(); err != nil {
		t.Fatal(err)
	}
	log, err = OpenCommitLog(root, strings.Repeat("a", 40))
	if err != nil {
		t.Fatal(err)
	}
	defer log.Close()
	coordinator, err = NewCaptureCoordinator(log, qualification, []PoolBoard{poolBoard("board-a", "board-a.local", driver)}, effects, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second})
	if err != nil {
		t.Fatal(err)
	}
	snapshot, err = coordinator.Run(context.Background(), jobs)
	if err != nil {
		t.Fatal(err)
	}
	if len(snapshot.Checkpoint.Completed) != 1 || len(snapshot.Jobs) != 1 || snapshot.Jobs[0].State != PoolResultComplete {
		t.Fatalf("complete private marker was not repaired: %+v", snapshot)
	}
	if _, captured := driver.counts(); captured != 1 || effects.commitCalls != 1 {
		t.Fatalf("repair repeated effects: captures=%d commits=%d", captured, effects.commitCalls)
	}
}

type atomicCounter struct{ value int }

func (c *atomicCounter) Add(delta int) int { c.value += delta; return c.value }
func (c *atomicCounter) Load() int         { return c.value }

func TestCaptureCoordinatorBlocksPendingUnknownAndRetiredCrossLaneFences(t *testing.T) {
	qualification := coordinatorQualification()
	driver := &coordinatorTestDriver{}
	effects := newCoordinatorTestEffects()
	log, _, _ := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second}, qualification, driver, effects)
	otherQualification := qualification
	otherQualification.Generation = "qualified-previous"
	other := CaptureRunProgress{SchemaVersion: captureRunSchemaVersion, Target: otherQualification.Target, CaptureGeneration: otherQualification.Generation, CaptureConvention: otherQualification.Convention, QualificationID: otherQualification.QualificationID, Finalizations: map[string]CaptureFinalizationProgress{}}
	previousKey := captureLaneKey(otherQualification)
	job := PoolJobKey{Core: "circus", Setname: "circusc"}
	attempt := AttemptKey{Board: "board-a", SessionID: "retired-session", Nonce: "retired-nonce"}
	portableID := testDigest("portable")
	other.Snapshot.Checkpoint = PoolCheckpoint{
		Attempts:    []PoolAttemptRecord{{JobKey: job, PortableID: portableID, Attempt: attempt, Generation: otherQualification.Generation, State: PoolAttemptUnknown}},
		Unknown:     []PoolUnknownAttempt{{JobKey: job, PortableID: portableID, Attempt: attempt, Reason: "old ownership unknown"}},
		Quarantined: []PoolBoardQuarantine{{Board: attempt.Board, Host: "board-a.local", JobKey: job, Attempt: attempt, Generation: otherQualification.Generation, Reason: "old ownership unknown", At: time.Now()}},
	}
	log.Progress.CaptureRuns = map[string]CaptureRunProgress{previousKey: other}
	if err := log.Save(); err != nil {
		t.Fatal(err)
	}
	coordinator, err := NewCaptureCoordinator(log, qualification, []PoolBoard{poolBoard("board-a", "board-a.local", driver)}, effects, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second})
	if err != nil {
		t.Fatal(err)
	}
	jobInput := coordinatorJobs(t, qualification, "circusc")
	jobInput[0].SessionID, jobInput[0].Nonce = "fresh-session", "fresh-nonce"
	if _, err = coordinator.Run(context.Background(), jobInput); err == nil || !strings.Contains(err.Error(), "unresolved attempt") {
		t.Fatalf("selected board crossed an older quarantine: %v", err)
	}
	if healthy, captured := driver.counts(); healthy != 0 || captured != 0 {
		t.Fatalf("driver ran despite older quarantine: healthy=%d capture=%d", healthy, captured)
	}
	otherBoard, err := NewCaptureCoordinator(log, qualification, []PoolBoard{poolBoard("board-b", "board-b.local", driver)}, effects, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second})
	if err != nil {
		t.Fatal(err)
	}
	if _, err = otherBoard.Run(context.Background(), jobInput); err == nil || !strings.Contains(err.Error(), "unresolved attempt") {
		t.Fatalf("same tuple crossed an older board quarantine: %v", err)
	}
}

func TestCaptureCoordinatorRejectsRetiredIdentityAndIncompleteMarkers(t *testing.T) {
	qualification := coordinatorQualification()
	driver := &coordinatorTestDriver{}
	effects := newCoordinatorTestEffects()
	log, coordinator, _ := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second}, qualification, driver, effects)
	log.Progress.CaptureRuns = map[string]CaptureRunProgress{}
	otherQualification := qualification
	otherQualification.Generation = "qualified-previous"
	key := captureLaneKey(otherQualification)
	job := PoolJobKey{Core: "circus", Setname: "circusc"}
	log.Progress.CaptureRuns[coordinator.laneKey] = CaptureRunProgress{SchemaVersion: captureRunSchemaVersion, Target: qualification.Target, CaptureGeneration: qualification.Generation, CaptureConvention: qualification.Convention, QualificationID: qualification.QualificationID, Finalizations: map[string]CaptureFinalizationProgress{}}
	attempt := AttemptKey{Board: "board-old", SessionID: "retired-session", Nonce: "retired-nonce"}
	log.Progress.CaptureRuns[key] = CaptureRunProgress{SchemaVersion: captureRunSchemaVersion, Target: "mister", CaptureGeneration: otherQualification.Generation, CaptureConvention: otherQualification.Convention, QualificationID: otherQualification.QualificationID, Snapshot: PoolSnapshot{Checkpoint: PoolCheckpoint{Attempts: []PoolAttemptRecord{{JobKey: job, PortableID: testDigest("old"), Attempt: attempt, Generation: otherQualification.Generation, State: PoolAttemptClean}}}}, Finalizations: map[string]CaptureFinalizationProgress{}}
	if err := log.Save(); err != nil {
		t.Fatal(err)
	}
	jobs := coordinatorJobs(t, qualification, "circusc")
	jobs[0].SessionID = attempt.SessionID
	if _, err := coordinator.Run(context.Background(), jobs); err == nil || !strings.Contains(err.Error(), "reuses a retired") {
		t.Fatalf("retired session ID reused: %v", err)
	}
	jobs[0].SessionID, jobs[0].Nonce = "fresh-session", attempt.Nonce
	if _, err := coordinator.Run(context.Background(), jobs); err == nil || !strings.Contains(err.Error(), "reuses a retired") {
		t.Fatalf("retired nonce reused: %v", err)
	}
	if healthy, captured := driver.counts(); healthy != 0 || captured != 0 {
		t.Fatalf("driver ran with retired identity: healthy=%d capture=%d", healthy, captured)
	}
	bad := log.Progress.CaptureRuns[coordinator.laneKey]
	bad.Finalizations = map[string]CaptureFinalizationProgress{}
	portableID := testDigest("done")
	completedAttempt := AttemptKey{Board: "board-a", SessionID: "session-done", Nonce: "nonce-done"}
	bad.Snapshot.Checkpoint.Completed = []PoolCompleted{{JobKey: job, PortableID: portableID, ResultDigest: testDigest("result"), Attempt: completedAttempt}}
	log.Progress.CaptureRuns[coordinator.laneKey] = bad
	if err := log.Save(); err != nil {
		t.Fatal(err)
	}
	if _, err := coordinator.Run(context.Background(), coordinatorJobs(t, qualification, "circusc")); err == nil || !strings.Contains(err.Error(), "no matching complete private finalization") {
		t.Fatalf("completed checkpoint without journal was accepted: %v", err)
	}
}

func TestCaptureCoordinatorRetiresForeignCompletedOnlyPoolHistory(t *testing.T) {
	for _, reuse := range []string{"session", "nonce", "none", "missing-marker"} {
		t.Run(reuse, func(t *testing.T) {
			qualification := coordinatorQualification()
			driver := &coordinatorTestDriver{}
			effects := newCoordinatorTestEffects()
			log, _, root := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second}, qualification, driver, effects)
			oldQualification := qualification
			oldQualification.Generation = "qualified-previous"
			oldJob := poolJob(t, "old-game", "retired-session", "retired-nonce")
			oldJob.Session.Generation = oldQualification.Generation
			oldKey := PoolJobKey{Core: oldJob.Session.Core, Setname: oldJob.Session.Setname}
			portableID, err := oldJob.Session.PortableIdentity()
			if err != nil {
				t.Fatal(err)
			}
			attempt := AttemptKey{Board: "board-a", SessionID: "retired-session", Nonce: "retired-nonce"}
			resultDigest := testDigest("old-result")
			lane := CaptureRunProgress{SchemaVersion: captureRunSchemaVersion, Target: oldQualification.Target, CaptureGeneration: oldQualification.Generation, CaptureConvention: oldQualification.Convention, QualificationID: oldQualification.QualificationID, Snapshot: PoolSnapshot{Checkpoint: PoolCheckpoint{Completed: []PoolCompleted{{JobKey: oldKey, PortableID: portableID, ResultDigest: resultDigest, Attempt: attempt}}}}, Finalizations: map[string]CaptureFinalizationProgress{}}
			if reuse != "missing-marker" {
				laneKey := captureLaneKey(oldQualification)
				operationKey := captureOperationKey(laneKey, oldKey, portableID, attempt)
				lane.Finalizations[operationKey] = CaptureFinalizationProgress{JobKey: oldKey, PortableID: portableID, Attempt: attempt, InputDigest: testDigest("old-input"), State: CaptureFinalizationComplete, ResultDigest: resultDigest}
			}
			log.Progress.CaptureRuns = map[string]CaptureRunProgress{captureLaneKey(oldQualification): lane}
			if err = log.Save(); err != nil {
				t.Fatal(err)
			}
			if err = log.Close(); err != nil {
				t.Fatal(err)
			}
			log, err = OpenCommitLog(root, strings.Repeat("a", 40))
			if err != nil {
				t.Fatal(err)
			}
			defer log.Close()
			coordinator, err := NewCaptureCoordinator(log, qualification, []PoolBoard{poolBoard("board-a", "board-a.local", driver)}, effects, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second})
			if err != nil {
				t.Fatal(err)
			}
			jobs := coordinatorJobs(t, qualification, "fresh-game")
			if reuse == "session" {
				jobs[0].SessionID = attempt.SessionID
			}
			if reuse == "nonce" {
				jobs[0].Nonce = attempt.Nonce
			}
			snapshot, runErr := coordinator.Run(context.Background(), jobs)
			if reuse == "none" {
				if runErr != nil || len(snapshot.Jobs) != 1 || snapshot.Jobs[0].State != PoolResultComplete {
					t.Fatalf("valid foreign completed history blocked fresh work: snapshot=%+v err=%v", snapshot.Jobs, runErr)
				}
				effects.mu.Lock()
				commits := effects.commitCalls
				effects.mu.Unlock()
				if healthy, captured := driver.counts(); healthy != 1 || captured != 1 || commits != 1 {
					t.Fatalf("fresh qualified work did not run once: healthy=%d capture=%d commits=%d", healthy, captured, commits)
				}
				return
			}
			if runErr == nil {
				t.Fatalf("foreign completion identity %q was accepted: %+v", reuse, snapshot.Jobs)
			}
			if healthy, captured := driver.counts(); healthy != 0 || captured != 0 {
				t.Fatalf("driver called with foreign completion identity %q: healthy=%d capture=%d", reuse, healthy, captured)
			}
		})
	}
}

func TestCaptureCoordinatorBlocksUnresolvedPendingPrivateResult(t *testing.T) {
	qualification := coordinatorQualification()
	driver := &coordinatorTestDriver{}
	effects := newCoordinatorTestEffects()
	effects.commitErrorAfter = true
	_, coordinator, _ := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second}, qualification, driver, effects)
	jobs := coordinatorJobs(t, qualification, "circusc")
	snapshot, err := coordinator.Run(context.Background(), jobs)
	if err == nil {
		t.Fatal("unknown private outcome was reported successful")
	}
	if snapshot.Jobs[0].State != PoolResultPending {
		t.Fatalf("private effect with unknown outcome was reported complete: %+v", snapshot.Jobs)
	}
	effects.mu.Lock()
	effects.committed = map[string]string{}
	effects.commitErrorAfter = false
	effects.mu.Unlock()
	if _, err := coordinator.Run(context.Background(), jobs); err == nil || !strings.Contains(err.Error(), "remains unresolved") {
		t.Fatalf("unknown private outcome was not blocked: %v", err)
	}
	if _, captured := driver.counts(); captured != 1 {
		t.Fatalf("unresolved private result triggered another capture: %d", captured)
	}
}

func TestCaptureCoordinatorRejectsMismatchedReceiptAndRevalidatedDigest(t *testing.T) {
	qualification := coordinatorQualification()
	driver := &coordinatorTestDriver{capture: func(_ context.Context, key AttemptKey, session PreparedSession) (SessionCapture, error) {
		capture := goodPoolCapture(key)
		capture.Receipt.Generation = "wrong-generation"
		capture.Receipt.CaptureConvention = session.Convention
		return capture, nil
	}}
	effects := newCoordinatorTestEffects()
	_, coordinator, _ := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second}, qualification, driver, effects)
	snapshot, err := coordinator.Run(context.Background(), coordinatorJobs(t, qualification, "circusc"))
	if err == nil {
		t.Fatal("mismatched generation was reported successful")
	}
	if snapshot.Jobs[0].State != PoolResultPending || effects.verifyCalls != 0 || effects.commitCalls != 0 {
		t.Fatalf("mismatched generation reached private finalizer: %+v verify=%d commit=%d", snapshot.Jobs, effects.verifyCalls, effects.commitCalls)
	}

	driver = &coordinatorTestDriver{}
	effects = newCoordinatorTestEffects()
	log, coordinator, _ := coordinatorFixture(t, CaptureCoordinatorOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second}, qualification, driver, effects)
	jobs := coordinatorJobs(t, qualification, "circusc")
	if _, err = coordinator.Run(context.Background(), jobs); err != nil {
		t.Fatal(err)
	}
	for key := range log.Progress.CaptureRuns[coordinator.laneKey].Finalizations {
		effects.mu.Lock()
		effects.committed[key] = testDigest("tampered-result")
		effects.mu.Unlock()
		break
	}
	if _, err = coordinator.Run(context.Background(), jobs); err == nil || !strings.Contains(err.Error(), "revalidate private capture") {
		t.Fatalf("tampered private result was trusted: %v", err)
	}
	if _, captured := driver.counts(); captured != 1 {
		t.Fatalf("tampered result triggered another capture: %d", captured)
	}
}

func TestCaptureRunProgressAdditiveLegacyJSON(t *testing.T) {
	legacy := Progress{Commit: strings.Repeat("b", 40), Status: "complete", AutomaticComplete: true, Games: map[string]ProgressGame{"circus/circusc": {Result: Pass, Input: "old"}}}
	data, err := json.Marshal(legacy)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "capture_runs") {
		t.Fatalf("nil additive field changed legacy JSON: %s", data)
	}
	var decoded Progress
	if err := json.Unmarshal(data, &decoded); err != nil || decoded.CaptureRuns != nil || !decoded.AutomaticComplete {
		t.Fatalf("legacy progress did not retain its old interpretation: %+v, %v", decoded, err)
	}
}

func captureLaneKey(qualification CaptureQualification) string {
	identity := struct {
		Version         int               `json:"version"`
		Target          string            `json:"target"`
		Generation      string            `json:"generation"`
		Convention      CaptureConvention `json:"convention"`
		QualificationID string            `json:"qualification_id"`
	}{captureRunSchemaVersion, qualification.Target, qualification.Generation, qualification.Convention, qualification.QualificationID}
	encoded, _ := json.Marshal(identity)
	digest := sha256.Sum256(encoded)
	return "v1-" + hex.EncodeToString(digest[:])
}
