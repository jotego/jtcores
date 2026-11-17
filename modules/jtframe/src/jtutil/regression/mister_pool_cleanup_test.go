/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

var poolReadChanged = errors.New("remote file changed during bounded read")

type poolChangingStatusRemote struct {
	*fakeMiSTerRemote
	statusPath string
	failed     bool
}

type poolCleanupDeadlineClock struct {
	cleanup time.Duration
	first   time.Time
	renewed atomic.Bool
}

func (c *poolCleanupDeadlineClock) Now() time.Time { return time.Now() }
func (c *poolCleanupDeadlineClock) WithTimeout(parent context.Context, timeout time.Duration) (context.Context, context.CancelFunc) {
	next, cancel := context.WithTimeout(parent, timeout)
	if timeout == poolCleanupWait(c.cleanup) {
		deadline, _ := next.Deadline()
		if c.first.IsZero() {
			c.first = deadline
		} else if deadline.After(c.first) {
			c.renewed.Store(true)
		}
	}
	return next, cancel
}

func (r *poolChangingStatusRemote) File(ctx context.Context, name string, bound int64) ([]byte, bool, error) {
	if name == r.statusPath && !r.failed {
		if _, exists := r.files[name]; exists {
			r.failed = true
			return nil, true, poolReadChanged
		}
	}
	return r.fakeMiSTerRemote.File(ctx, name, bound)
}

func poolReadErrorDriver(t *testing.T, remote *fakeMiSTerRemote) (*MiSTerSessionDriver, PreparedSession, AttemptKey, *poolChangingStatusRemote) {
	t.Helper()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	driver.Inputs = inputs
	statusPath := "/tmp/jtframe-capture-" + key.SessionID + ".json"
	status, err := decodeMiSTerCaptureStatusV2(remote.startFiles[statusPath])
	if err != nil {
		t.Fatal(err)
	}
	status.State, status.ScheduleState = "cancelled", "cancelled"
	status.CleanupConfirmed, status.ReloadRequired, status.EncoderBusy = true, false, false
	remote.stopStatus, err = json.Marshal(status)
	if err != nil {
		t.Fatal(err)
	}
	wrapped := &poolChangingStatusRemote{fakeMiSTerRemote: remote, statusPath: statusPath}
	driver.Remote = wrapped
	return driver, prepared, key, wrapped
}

func TestSessionPoolPersistsActualDriverCleanErrorBeforeBoardReuse(t *testing.T) {
	remote := newFakeMiSTerRemote()
	actual, firstSession, firstKey, wrapped := poolReadErrorDriver(t, remote)
	firstSession.Setname = "circusc"
	firstSession.Profile.Setname = "circusc"
	first := PoolJob{Session: firstSession, SessionID: firstKey.SessionID, Nonce: firstKey.Nonce}
	second := poolJob(t, "alpha", "second-session", "second-nonce")

	observer := &poolFakeObserver{}
	var persisted atomic.Bool
	var cleanupCalls atomic.Int32
	observer.progressHook = func(snapshot PoolSnapshot) error {
		for _, attempt := range snapshot.Checkpoint.Attempts {
			if attempt.Attempt == firstKey && attempt.State == PoolAttemptClean && attempt.CleanFailure != nil &&
				attempt.CleanFailure.Key == firstKey && attempt.CleanFailure.Capture.Key == firstKey &&
				attempt.CleanFailure.Error == poolReadChanged.Error() && attempt.CleanFailure.Capture.Cleanup.Confirmed && !attempt.CleanFailure.Capture.Cleanup.Required {
				persisted.Store(true)
			}
		}
		return nil
	}
	finalizer := &poolFakeFinalizer{}
	driver := &poolFakeDriver{}
	driver.result = func(key AttemptKey, session PreparedSession) (SessionCapture, error) {
		if key == firstKey {
			return actual.Capture(context.Background(), key, session)
		}
		if !persisted.Load() {
			return SessionCapture{}, errors.New("board reused before clean checkpoint persistence")
		}
		return goodPoolCapture(key), nil
	}
	driver.cancel = func(context.Context, AttemptKey) error { cleanupCalls.Add(1); return nil }
	driver.reconcile = func(context.Context, AttemptKey) (SessionCleanup, error) {
		cleanupCalls.Add(1)
		return SessionCleanup{Confirmed: true}, nil
	}
	// Delegate the first capture to the actual driver and use an ordinary
	// successful capture for the next tuple on the same board.
	pool := newTestPool(t, []PoolBoard{poolBoard(firstKey.Board, "host-a", driver)}, finalizer, observer)
	snapshot, err := pool.Run(context.Background(), []PoolJob{first, second}, PoolCheckpoint{})
	if err != nil {
		t.Fatal(err)
	}
	if !wrapped.failed || !persisted.Load() {
		t.Fatalf("the bounded read failure or its durable clean checkpoint was not observed (failed=%v persisted=%v first=%+v attempts=%+v)", wrapped.failed, persisted.Load(), firstKey, snapshot.Checkpoint.Attempts)
	}
	if cleanupCalls.Load() != 0 {
		t.Fatalf("pool performed redundant Cancel/Reconcile after the actual clean envelope: %d", cleanupCalls.Load())
	}
	if len(finalizer.seen) != 1 || !strings.Contains(finalizer.seen[0], "alpha@") {
		t.Fatalf("only the successful second tuple may be finalized: %v jobs=%+v", finalizer.seen, snapshot.Jobs)
	}
	if len(snapshot.Checkpoint.Unknown) != 0 || len(snapshot.Checkpoint.Quarantined) != 0 {
		t.Fatalf("actual clean error envelope caused a false quarantine: %+v", snapshot.Checkpoint)
	}
	var failed *PoolAttemptRecord
	for i := range snapshot.Checkpoint.Attempts {
		if snapshot.Checkpoint.Attempts[i].Attempt == firstKey {
			failed = &snapshot.Checkpoint.Attempts[i]
		}
	}
	if failed == nil || failed.CleanFailure == nil || failed.CleanFailure.Key != firstKey || failed.CleanFailure.Capture.Key != firstKey || failed.CleanFailure.Error != poolReadChanged.Error() || !failed.CleanFailure.Capture.Cleanup.Confirmed || failed.CleanFailure.Capture.Cleanup.Required {
		t.Fatalf("checkpoint did not retain the exact typed clean failure envelope: %+v", failed)
	}
	roundTrip, marshalErr := json.Marshal(snapshot.Checkpoint)
	if marshalErr != nil {
		t.Fatal(marshalErr)
	}
	var decoded PoolCheckpoint
	if err := json.Unmarshal(roundTrip, &decoded); err != nil {
		t.Fatal(err)
	}
	validated, err := validatePoolCheckpoint(decoded)
	decodedFailure := false
	for _, attempt := range validated.Attempts {
		decodedFailure = decodedFailure || attempt.Attempt == firstKey && attempt.CleanFailure != nil
	}
	if err != nil || len(validated.Attempts) != 2 || !decodedFailure {
		t.Fatalf("typed failure envelope did not survive checkpoint serialization: %+v, %v", validated, err)
	}
	detached := snapshot.Checkpoint.Clone()
	for i := range detached.Attempts {
		if detached.Attempts[i].Attempt == firstKey {
			detached.Attempts[i].CleanFailure.Capture.Events = append(detached.Attempts[i].CleanFailure.Capture.Events, SessionEvent{Stage: "detached"})
		}
	}
	if len(failed.CleanFailure.Capture.Events) != 0 {
		t.Fatal("checkpoint clone aliases the typed capture envelope")
	}
	states := map[string]PoolResultState{}
	for _, job := range snapshot.Jobs {
		states[job.JobKey.Setname] = job.State
	}
	if states["circusc"] != PoolResultPending || states["alpha"] != PoolResultComplete {
		t.Fatalf("unexpected job states: %+v", snapshot.Jobs)
	}
	if _, err := os.Stat(actual.ledgerName()); !os.IsNotExist(err) {
		t.Fatalf("actual driver did not finish and remove its ledger: %v", err)
	}
}

func TestPoolCheckpointRejectsCleanFailurePromotedToComplete(t *testing.T) {
	key := AttemptKey{Board: "board-a", SessionID: "session-a", Nonce: "nonce-a"}
	job := PoolJobKey{Core: "circus", Setname: "circusc"}
	failure := &PoolCleanFailure{Key: key, Capture: SessionCapture{Key: key, Cleanup: SessionCleanup{Confirmed: true}}, Error: "capture failed"}
	checkpoint := PoolCheckpoint{
		Attempts:  []PoolAttemptRecord{{JobKey: job, PortableID: strings.Repeat("a", 64), Attempt: key, State: PoolAttemptClean, CleanFailure: failure}},
		Completed: []PoolCompleted{{JobKey: job, PortableID: strings.Repeat("a", 64), Attempt: key, ResultDigest: "image-result"}},
	}
	if _, err := validatePoolCheckpoint(checkpoint); err == nil {
		t.Fatal("failed clean capture was promoted to completed image output")
	}
}

func TestSessionPoolCleanupUsesOneDeadlineThroughReconcile(t *testing.T) {
	job := poolJob(t, "circusc", "session-budget", "nonce-budget")
	clock := &poolCleanupDeadlineClock{cleanup: time.Second}
	driver := &poolFakeDriver{
		result: func(AttemptKey, PreparedSession) (SessionCapture, error) {
			return SessionCapture{}, errors.New("capture failed")
		},
		reconcile: func(ctx context.Context, _ AttemptKey) (SessionCleanup, error) {
			deadline, ok := ctx.Deadline()
			if !ok || deadline.After(clock.first) {
				clock.renewed.Store(true)
			}
			return SessionCleanup{Confirmed: true}, nil
		},
	}
	pool, err := NewSessionPool([]PoolBoard{poolBoard("board-a", "host-a", driver)}, PoolOptions{
		CaptureTimeout: time.Minute,
		CleanupTimeout: clock.cleanup,
		Clock:          clock,
		Finalizer:      &poolFakeFinalizer{},
		Observer:       &poolFakeObserver{},
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Run(context.Background(), []PoolJob{job}, PoolCheckpoint{}); err != nil {
		t.Fatal(err)
	}
	if clock.renewed.Load() {
		t.Fatal("Reconcile received a fresh deadline instead of the original cleanup budget")
	}
}

func TestSessionPoolCancellationWaitsForActualDriverCleanEnvelope(t *testing.T) {
	remote := newFakeMiSTerRemote()
	remote.started = make(chan struct{}, 1)
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	driver.Inputs = inputs
	statusPath := "/tmp/jtframe-capture-" + key.SessionID + ".json"
	status, err := decodeMiSTerCaptureStatusV2(remote.startFiles[statusPath])
	if err != nil {
		t.Fatal(err)
	}
	status.State, status.ScheduleState = "cancelled", "cancelled"
	status.CleanupConfirmed, status.ReloadRequired, status.EncoderBusy = true, false, false
	remote.stopStatus, err = json.Marshal(status)
	if err != nil {
		t.Fatal(err)
	}
	finalizer := &poolFakeFinalizer{}
	observer := &poolFakeObserver{}
	pool := newTestPool(t, []PoolBoard{poolBoard(key.Board, "host-a", driver)}, finalizer, observer)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct {
		snapshot PoolSnapshot
		err      error
	}, 1)
	go func() {
		snapshot, runErr := pool.Run(ctx, []PoolJob{{Session: prepared, SessionID: key.SessionID, Nonce: key.Nonce}}, PoolCheckpoint{})
		done <- struct {
			snapshot PoolSnapshot
			err      error
		}{snapshot, runErr}
	}()
	select {
	case <-remote.started:
	case <-time.After(5 * time.Second):
		cancel()
		t.Fatal("actual MiSTer capture did not start")
	}
	cancel()
	select {
	case result := <-done:
		if !errors.Is(result.err, context.Canceled) {
			t.Fatalf("expected cancellation, got %v", result.err)
		}
		if len(finalizer.seen) != 0 || len(result.snapshot.Checkpoint.Unknown) != 0 || len(result.snapshot.Checkpoint.Quarantined) != 0 {
			t.Fatalf("canceled capture finalized or was falsely quarantined: %+v", result.snapshot)
		}
		if len(result.snapshot.Checkpoint.Attempts) != 1 || result.snapshot.Checkpoint.Attempts[0].State != PoolAttemptClean || result.snapshot.Jobs[0].State != PoolResultPending {
			t.Fatalf("actual cancellation cleanup was not preserved: %+v", result.snapshot)
		}
		stops := 0
		for _, record := range remote.fifos {
			if strings.HasPrefix(string(record), "cab_stop ") {
				stops++
			}
		}
		if stops != 1 {
			t.Fatalf("actual cancellation should send one stop command, got %d: %q", stops, remote.fifos)
		}
	case <-time.After(8 * time.Second):
		cancel()
		t.Fatal("pool did not wait for actual cancellation cleanup")
	}
}

func TestSessionPoolWaitCoversSlow32ImageCleanupAfter4000FramePlan(t *testing.T) {
	cleanupBudget := 60 * time.Millisecond
	job := poolJob(t, "circusc", "slow-32-image-session", "slow-32-image-nonce")
	started := make(chan AttemptKey, 1)
	gate := make(chan struct{})
	var release sync.Once
	driver := &poolFakeDriver{
		started: started, gate: gate, ignoreCancel: true,
		result: func(key AttemptKey, _ PreparedSession) (SessionCapture, error) {
			capture := goodPoolCapture(key)
			capture.Receipt.Images = make([]ImageReceipt, 32)
			return capture, nil
		},
		cancel: func(_ context.Context, _ AttemptKey) error {
			// Models the last SSH batch completing just beyond the old shared
			// driver/pool deadline, with the worker's return envelope in flight.
			time.Sleep(cleanupBudget + 40*time.Millisecond)
			release.Do(func() { close(gate) })
			return nil
		},
	}
	pool, err := NewSessionPool([]PoolBoard{poolBoard("board-a", "host-a", driver)}, PoolOptions{
		CaptureTimeout: time.Minute, CleanupTimeout: cleanupBudget,
		Finalizer: &poolFakeFinalizer{}, Observer: &poolFakeObserver{},
	})
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct {
		snapshot PoolSnapshot
		err      error
	}, 1)
	go func() {
		snapshot, runErr := pool.Run(ctx, []PoolJob{job}, PoolCheckpoint{})
		done <- struct {
			snapshot PoolSnapshot
			err      error
		}{snapshot, runErr}
	}()
	select {
	case <-started:
	case <-time.After(2 * time.Second):
		cancel()
		t.Fatal("slow cleanup capture did not start")
	}
	cancel()
	select {
	case result := <-done:
		if !errors.Is(result.err, context.Canceled) {
			t.Fatalf("expected caller cancellation, got %v", result.err)
		}
		if len(result.snapshot.Checkpoint.Unknown) != 0 || len(result.snapshot.Checkpoint.Quarantined) != 0 ||
			len(result.snapshot.Checkpoint.Attempts) != 1 || result.snapshot.Checkpoint.Attempts[0].State != PoolAttemptClean {
			t.Fatalf("32-image clean worker return just after the old budget was falsely quarantined: %+v", result.snapshot)
		}
	case <-time.After(2 * time.Second):
		cancel()
		release.Do(func() { close(gate) })
		t.Fatal("pool exceeded its bounded cleanup return window")
	}
}

func TestSessionPoolStuckCleanupStillBecomesBoundedUnknown(t *testing.T) {
	cleanupBudget := 50 * time.Millisecond
	job := poolJob(t, "circusc", "stuck-cleanup-session", "stuck-cleanup-nonce")
	started := make(chan AttemptKey, 1)
	gate := make(chan struct{})
	driver := &poolFakeDriver{
		started: started, gate: gate, ignoreCancel: true,
		cancel: func(ctx context.Context, _ AttemptKey) error {
			<-ctx.Done()
			return ctx.Err()
		},
	}
	pool, err := NewSessionPool([]PoolBoard{poolBoard("board-a", "host-a", driver)}, PoolOptions{
		CaptureTimeout: time.Minute, CleanupTimeout: cleanupBudget,
		Finalizer: &poolFakeFinalizer{}, Observer: &poolFakeObserver{},
	})
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct {
		snapshot PoolSnapshot
		err      error
	}, 1)
	startedAt := time.Now()
	go func() {
		snapshot, runErr := pool.Run(ctx, []PoolJob{job}, PoolCheckpoint{})
		done <- struct {
			snapshot PoolSnapshot
			err      error
		}{snapshot, runErr}
	}()
	select {
	case <-started:
	case <-time.After(2 * time.Second):
		cancel()
		close(gate)
		t.Fatal("stuck cleanup capture did not start")
	}
	cancel()
	select {
	case result := <-done:
		if time.Since(startedAt) > 2*time.Second {
			t.Fatal("stuck cleanup exceeded the bounded pool wait")
		}
		if len(result.snapshot.Checkpoint.Unknown) != 1 || len(result.snapshot.Checkpoint.Quarantined) != 1 || result.snapshot.Jobs[0].State != PoolResultBlocked {
			t.Fatalf("genuinely stuck cleanup was not retained as unknown: %+v", result.snapshot)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("stuck cleanup did not terminate within the pool bound")
	}
	close(gate)
}

func TestSessionPoolDoesNotTrustWrongKeyOrUnconfirmedCaptureCleanup(t *testing.T) {
	for _, test := range []struct {
		name string
		edit func(AttemptKey, SessionCapture) SessionCapture
	}{
		{name: "wrong key", edit: func(key AttemptKey, capture SessionCapture) SessionCapture {
			capture.Key.Nonce = "other"
			return capture
		}},
		{name: "unconfirmed", edit: func(_ AttemptKey, capture SessionCapture) SessionCapture {
			capture.Cleanup.Confirmed = false
			return capture
		}},
	} {
		t.Run(test.name, func(t *testing.T) {
			job := poolJob(t, "circusc", "session-"+strings.ReplaceAll(test.name, " ", "-"), "nonce-"+strings.ReplaceAll(test.name, " ", "-"))
			driver := &poolFakeDriver{
				result: func(key AttemptKey, _ PreparedSession) (SessionCapture, error) {
					return test.edit(key, goodPoolCapture(key)), errors.New("capture failed")
				},
				reconcile: func(context.Context, AttemptKey) (SessionCleanup, error) {
					return SessionCleanup{}, errors.New("reconciliation remains uncertain")
				},
			}
			pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "host-a", driver)}, &poolFakeFinalizer{}, nil)
			snapshot, err := pool.Run(context.Background(), []PoolJob{job}, PoolCheckpoint{})
			if err != nil {
				t.Fatal(err)
			}
			if len(snapshot.Checkpoint.Unknown) != 1 || len(snapshot.Checkpoint.Quarantined) != 1 || snapshot.Jobs[0].State != PoolResultBlocked {
				t.Fatalf("untrusted cleanup envelope was accepted: %+v", snapshot)
			}
		})
	}
}
