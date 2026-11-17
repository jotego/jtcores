/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type poolFakeDriver struct {
	started      chan AttemptKey
	returned     chan struct{}
	gate         <-chan struct{}
	ignoreCancel bool
	result       func(AttemptKey, PreparedSession) (SessionCapture, error)
	cancel       func(context.Context, AttemptKey) error
	reconcile    func(context.Context, AttemptKey) (SessionCleanup, error)
	healthy      func(context.Context) error
	mutate       func(*PreparedSession)
}

func (d *poolFakeDriver) Healthy(ctx context.Context) error {
	if d.healthy != nil {
		return d.healthy(ctx)
	}
	return nil
}

func (d *poolFakeDriver) Capture(ctx context.Context, key AttemptKey, session PreparedSession) (SessionCapture, error) {
	if d.returned != nil {
		defer close(d.returned)
	}
	if d.started != nil {
		d.started <- key
	}
	if d.gate != nil {
		if d.ignoreCancel {
			<-d.gate
		} else {
			select {
			case <-d.gate:
			case <-ctx.Done():
				if d.result != nil {
					return d.result(key, session)
				}
				return SessionCapture{}, ctx.Err()
			}
		}
	}
	if d.result != nil {
		if d.mutate != nil {
			d.mutate(&session)
		}
		return d.result(key, session)
	}
	if d.mutate != nil {
		d.mutate(&session)
	}
	return goodPoolCapture(key), nil
}

func (d *poolFakeDriver) Cancel(ctx context.Context, key AttemptKey) error {
	if d.cancel != nil {
		return d.cancel(ctx, key)
	}
	return nil
}

func (d *poolFakeDriver) Reconcile(ctx context.Context, key AttemptKey) (SessionCleanup, error) {
	if d.reconcile != nil {
		return d.reconcile(ctx, key)
	}
	return SessionCleanup{Confirmed: true}, nil
}

func goodPoolCapture(key AttemptKey) SessionCapture {
	return SessionCapture{
		Key:       key,
		Workspace: "/private/" + key.Nonce,
		Receipt:   CaptureReceipt{SessionID: key.SessionID},
		Cleanup:   SessionCleanup{Confirmed: true},
	}
}

type poolFakeFinalizer struct {
	mu             sync.Mutex
	active         atomic.Int32
	max            atomic.Int32
	seen           []string
	fail           map[string]error
	finalized      chan string
	inspect        func(PreparedSession) error
	workspaceCheck func(SessionCapture) error
}

func (f *poolFakeFinalizer) Finalize(_ context.Context, job PoolJobKey, identity string, attempt AttemptKey, session PreparedSession, capture SessionCapture) (string, error) {
	if f.workspaceCheck != nil {
		if err := f.workspaceCheck(capture); err != nil {
			return "", err
		}
	}
	active := f.active.Add(1)
	defer f.active.Add(-1)
	defer func() {
		if f.finalized != nil {
			f.finalized <- job.Setname
		}
	}()
	for previous := f.max.Load(); active > previous && !f.max.CompareAndSwap(previous, active); previous = f.max.Load() {
	}
	f.mu.Lock()
	f.seen = append(f.seen, job.String()+"@"+string(attempt.Board))
	f.mu.Unlock()
	if capture.Key != attempt {
		return "", fmt.Errorf("finalizer saw mismatched capture")
	}
	if f.inspect != nil {
		if err := f.inspect(session); err != nil {
			return "", err
		}
	}
	result := identity[:16]
	var err error
	if f.fail != nil {
		err = f.fail[job.String()]
	}
	return result, err
}

func TestSessionPoolRemovesCaptureWorkspaceAfterFinalization(t *testing.T) {
	job := poolJob(t, "alpha", "session-workspace", "nonce-workspace")
	root := t.TempDir()
	workspace := filepath.Join(root, "mister-session-workspace")
	driver := &poolFakeDriver{result: func(key AttemptKey, _ PreparedSession) (SessionCapture, error) {
		if err := os.Mkdir(workspace, 0700); err != nil {
			return SessionCapture{}, err
		}
		capture := goodPoolCapture(key)
		capture.WorkspaceRoot, capture.Workspace = root, workspace
		return capture, nil
	}}
	finalizer := &poolFakeFinalizer{workspaceCheck: func(capture SessionCapture) error {
		if info, err := os.Stat(capture.Workspace); err != nil || !info.IsDir() {
			return fmt.Errorf("finalizer could not read capture workspace: %v", err)
		}
		return nil
	}}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "A.local", driver)}, finalizer, &poolFakeObserver{})
	if _, err := pool.Run(context.Background(), []PoolJob{job}, PoolCheckpoint{}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(workspace); !os.IsNotExist(err) {
		t.Fatalf("finalized task-owned workspace remains: %v", err)
	}
}

func TestSessionPoolKeepsFinalizedResultWhenWorkspaceCleanupFailsAndResumeSkipsCapture(t *testing.T) {
	job := poolJob(t, "alpha", "session-cleanup-warning", "nonce-cleanup-warning")
	root := t.TempDir()
	workspace := filepath.Join(root, "capture-evidence")
	if err := os.Mkdir(workspace, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(workspace, "receipt.json"), []byte("receipt"), 0600); err != nil {
		t.Fatal(err)
	}
	var captures atomic.Int32
	driver := &poolFakeDriver{result: func(key AttemptKey, _ PreparedSession) (SessionCapture, error) {
		captures.Add(1)
		capture := goodPoolCapture(key)
		capture.WorkspaceRoot, capture.Workspace = root, workspace
		return capture, nil
	}}
	finalizer := &poolFakeFinalizer{workspaceCheck: func(capture SessionCapture) error {
		if info, err := os.Stat(capture.Workspace); err != nil || !info.IsDir() {
			return fmt.Errorf("finalizer could not read capture workspace: %v", err)
		}
		return nil
	}}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "A.local", driver)}, finalizer, &poolFakeObserver{})
	first, err := pool.Run(context.Background(), []PoolJob{job}, PoolCheckpoint{})
	if err != nil {
		t.Fatal(err)
	}
	if first.Jobs[0].State != PoolResultComplete || !strings.Contains(first.Jobs[0].Message, "cleanup pending") || len(first.Checkpoint.Completed) != 1 || first.Checkpoint.Completed[0].CleanupWarning == "" {
		t.Fatalf("workspace cleanup failure downgraded or lost finalized state: %+v", first)
	}
	second, err := pool.Run(context.Background(), []PoolJob{job}, first.Checkpoint)
	if err != nil {
		t.Fatal(err)
	}
	if second.Jobs[0].State != PoolResultComplete || second.Jobs[0].Message != first.Jobs[0].Message || captures.Load() != 1 || len(finalizer.seen) != 1 {
		t.Fatalf("resume repeated a finalized capture or dropped its cleanup warning: jobs=%+v captures=%d finalizers=%d", second.Jobs, captures.Load(), len(finalizer.seen))
	}
	if _, err := os.Stat(filepath.Join(workspace, "receipt.json")); err != nil {
		t.Fatalf("failed cleanup did not preserve workspace recovery evidence: %v", err)
	}
}

type poolFakeObserver struct {
	mu           sync.Mutex
	active       atomic.Int32
	max          atomic.Int32
	events       []PoolEvent
	progress     []PoolSnapshot
	progressHook func(PoolSnapshot) error
}

func (o *poolFakeObserver) Event(event PoolEvent) error {
	active := o.active.Add(1)
	for previous := o.max.Load(); active > previous && !o.max.CompareAndSwap(previous, active); previous = o.max.Load() {
	}
	o.mu.Lock()
	o.events = append(o.events, event)
	o.mu.Unlock()
	o.active.Add(-1)
	return nil
}

func (o *poolFakeObserver) Progress(snapshot PoolSnapshot) error {
	active := o.active.Add(1)
	for previous := o.max.Load(); active > previous && !o.max.CompareAndSwap(previous, active); previous = o.max.Load() {
	}
	o.mu.Lock()
	copy := snapshot.Clone()
	o.progress = append(o.progress, copy)
	o.mu.Unlock()
	o.active.Add(-1)
	if o.progressHook != nil {
		return o.progressHook(copy)
	}
	return nil
}

func poolJob(t *testing.T, setname, id, nonce string) PoolJob {
	t.Helper()
	session := preparedSessionFixture().Clone()
	session.Setname = setname
	session.Profile.Setname = setname
	identity, err := session.PortableIdentity()
	if err != nil {
		t.Fatal(err)
	}
	if identity == "" {
		t.Fatal("empty fixture identity")
	}
	return PoolJob{Session: session, SessionID: id, Nonce: nonce}
}

func poolBoard(key BoardKey, host string, driver SessionDriver) PoolBoard {
	return PoolBoard{Key: key, Host: host, Driver: driver}
}

func newTestPool(t *testing.T, boards []PoolBoard, finalizer PoolFinalizer, observer *poolFakeObserver) *SessionPool {
	t.Helper()
	if observer == nil {
		observer = &poolFakeObserver{}
	}
	pool, err := NewSessionPool(boards, PoolOptions{
		CaptureTimeout: time.Minute,
		CleanupTimeout: time.Second,
		Finalizer:      finalizer,
		Observer:       observer,
		EventSink:      observer,
	})
	if err != nil {
		t.Fatal(err)
	}
	return pool
}

func TestSessionPoolRunsBoardsConcurrentlyAndFinalizesSerially(t *testing.T) {
	first := poolJob(t, "alpha", "session-1", "nonce-1")
	second := poolJob(t, "beta", "session-2", "nonce-2")
	var baseline []PoolJobResult
	for _, reverse := range []bool{false, true} {
		release := map[string]chan struct{}{"nonce-1": make(chan struct{}), "nonce-2": make(chan struct{})}
		started := make(chan AttemptKey, 2)
		driver := &poolFakeDriver{started: started, result: func(key AttemptKey, _ PreparedSession) (SessionCapture, error) {
			<-release[key.Nonce]
			return goodPoolCapture(key), nil
		}}
		finalizer := &poolFakeFinalizer{finalized: make(chan string, 2)}
		observer := &poolFakeObserver{}
		pool := newTestPool(t, []PoolBoard{
			poolBoard("board-a", "A.local", driver),
			poolBoard("board-b", "B.local", driver),
		}, finalizer, observer)
		result := make(chan struct {
			snapshot PoolSnapshot
			err      error
		}, 1)
		go func() {
			snapshot, err := pool.Run(context.Background(), []PoolJob{first, second}, PoolCheckpoint{})
			result <- struct {
				snapshot PoolSnapshot
				err      error
			}{snapshot, err}
		}()
		startedAttempts := []AttemptKey{<-started, <-started}
		if startedAttempts[0].Board == startedAttempts[1].Board {
			t.Fatalf("two jobs ran on one board: %+v", startedAttempts)
		}
		order := []string{"alpha", "beta"}
		if reverse {
			order = []string{"beta", "alpha"}
		}
		for _, setname := range order {
			nonce := "nonce-1"
			if setname == "beta" {
				nonce = "nonce-2"
			}
			close(release[nonce])
			if got := <-finalizer.finalized; got != setname {
				t.Fatalf("released %s first, coordinator finalized %s first", setname, got)
			}
		}
		completed := <-result
		if completed.err != nil {
			t.Fatal(completed.err)
		}
		if len(completed.snapshot.Jobs) != 2 || completed.snapshot.Jobs[0].State != PoolResultComplete || completed.snapshot.Jobs[1].State != PoolResultComplete {
			t.Fatalf("unexpected final job states: %+v", completed.snapshot.Jobs)
		}
		if finalizer.max.Load() != 1 || observer.max.Load() != 1 {
			t.Fatalf("coordinator sinks overlapped: finalizer=%d observer=%d", finalizer.max.Load(), observer.max.Load())
		}
		if len(finalizer.seen) != 2 {
			t.Fatalf("finalized %d attempts, want 2", len(finalizer.seen))
		}
		if baseline == nil {
			baseline = append([]PoolJobResult(nil), completed.snapshot.Jobs...)
		} else if !reflect.DeepEqual(baseline, completed.snapshot.Jobs) {
			t.Fatalf("completion order changed final outcomes:\n%+v\n%+v", baseline, completed.snapshot.Jobs)
		}
		for _, status := range completed.snapshot.Boards {
			if status.State != PoolBoardIdle {
				t.Fatalf("board not released: %+v", status)
			}
		}
		if reverse && completed.snapshot.Jobs[0].ResultDigest == "" {
			t.Fatal("reverse completion lost a finalized digest")
		}
	}
}

func TestSessionPoolRejectsDuplicateTupleBoardAndHost(t *testing.T) {
	job := poolJob(t, "alpha", "session-1", "nonce-1")
	driver := &poolFakeDriver{}
	if _, err := normalizePoolJobs([]PoolJob{job, job}); err == nil || !strings.Contains(err.Error(), "duplicate pool tuple") {
		t.Fatalf("duplicate tuple accepted: %v", err)
	}
	observer := &poolFakeObserver{}
	options := PoolOptions{CaptureTimeout: time.Second, CleanupTimeout: time.Second, Finalizer: &poolFakeFinalizer{}, Observer: observer, EventSink: observer}
	withoutObserver := options
	withoutObserver.Observer = nil
	if _, err := NewSessionPool([]PoolBoard{poolBoard("board-a", "host", driver)}, withoutObserver); err == nil {
		t.Fatal("session pool allowed dispatch without a checkpoint sink")
	}
	if _, err := NewSessionPool([]PoolBoard{poolBoard("board-a", "same", driver), poolBoard("board-a", "other", driver)}, options); err == nil {
		t.Fatal("duplicate board ID accepted")
	}
	if _, err := NewSessionPool([]PoolBoard{poolBoard("board-a", "Board.Local", driver), poolBoard("board-b", "board.local", driver)}, options); err == nil {
		t.Fatal("duplicate normalized host accepted")
	}
}

func TestSessionPoolRejectsQueueWithReusedSessionOrNonce(t *testing.T) {
	cases := []struct {
		name string
		id1  string
		n1   string
		id2  string
		n2   string
	}{
		{name: "same session", id1: "shared-session", n1: "nonce-1", id2: "shared-session", n2: "nonce-2"},
		{name: "same nonce", id1: "session-1", n1: "shared-nonce", id2: "session-2", n2: "shared-nonce"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var calls atomic.Int32
			driver := &poolFakeDriver{healthy: func(context.Context) error {
				calls.Add(1)
				return nil
			}}
			pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver), poolBoard("board-b", "b", driver)}, &poolFakeFinalizer{}, nil)
			jobs := []PoolJob{poolJob(t, "alpha", tc.id1, tc.n1), poolJob(t, "beta", tc.id2, tc.n2)}
			if _, err := pool.Run(context.Background(), jobs, PoolCheckpoint{}); err == nil {
				t.Fatal("queue with a reused attempt identity component was accepted")
			}
			if calls.Load() != 0 {
				t.Fatalf("driver entered %d times for an invalid queue", calls.Load())
			}
		})
	}
}

func TestSessionPoolPersistsInFlightCheckpointBeforeDriverEntry(t *testing.T) {
	job := poolJob(t, "alpha", "session-1", "nonce-1")
	persisted := make(chan struct{})
	observer := &poolFakeObserver{progressHook: func(snapshot PoolSnapshot) error {
		select {
		case <-persisted:
			return nil
		default:
		}
		for _, board := range snapshot.Boards {
			if board.State != PoolBoardActive {
				continue
			}
			if len(snapshot.Checkpoint.Attempts) != 1 || snapshot.Checkpoint.Attempts[0].State != PoolAttemptInFlight {
				return fmt.Errorf("capture-start progress lacks in-flight attempt fence: %+v", snapshot.Checkpoint)
			}
			close(persisted)
			return nil
		}
		return nil
	}}
	driver := &poolFakeDriver{healthy: func(context.Context) error {
		select {
		case <-persisted:
			return nil
		default:
			return fmt.Errorf("driver entered before capture-start checkpoint committed")
		}
	}}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, &poolFakeFinalizer{}, observer)
	snapshot, err := pool.Run(context.Background(), []PoolJob{job}, PoolCheckpoint{})
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Jobs[0].State != PoolResultComplete {
		t.Fatalf("capture did not complete after checkpoint commit: %+v", snapshot.Jobs)
	}
}

func TestSessionPoolPreflightFailureDoesNotQuarantineBoard(t *testing.T) {
	job := poolJob(t, "alpha", "session-1", "nonce-1")
	var unhealthy atomic.Bool
	unhealthy.Store(true)
	var cancels, reconciles atomic.Int32
	driver := &poolFakeDriver{
		healthy: func(context.Context) error {
			if unhealthy.Load() {
				return errors.New("transient SSH timeout before board lock")
			}
			return nil
		},
		cancel: func(context.Context, AttemptKey) error { cancels.Add(1); return nil },
		reconcile: func(context.Context, AttemptKey) (SessionCleanup, error) {
			reconciles.Add(1)
			return SessionCleanup{Confirmed: true}, nil
		},
	}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, &poolFakeFinalizer{}, nil)
	snapshot, err := pool.Run(context.Background(), []PoolJob{job}, PoolCheckpoint{})
	if err != nil {
		t.Fatal(err)
	}
	if len(snapshot.Checkpoint.Attempts) != 0 || len(snapshot.Checkpoint.Unknown) != 0 || len(snapshot.Checkpoint.Quarantined) != 0 {
		t.Fatalf("preflight failure created ownership/quarantine: %+v", snapshot.Checkpoint)
	}
	if cancels.Load() != 0 || reconciles.Load() != 0 {
		t.Fatalf("preflight failure attempted cleanup/reconcile: cancels=%d reconciles=%d", cancels.Load(), reconciles.Load())
	}
	unhealthy.Store(false)
	pool = newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, &poolFakeFinalizer{}, nil)
	snapshot, err = pool.Run(context.Background(), []PoolJob{job}, PoolCheckpoint{})
	if err != nil || snapshot.Jobs[0].State != PoolResultComplete {
		t.Fatalf("healthy retry did not complete after preflight failure: snapshot=%+v err=%v", snapshot.Jobs, err)
	}
}

func TestSessionPoolDoesNotCallDriverWhenStartCheckpointFails(t *testing.T) {
	job := poolJob(t, "alpha", "session-1", "nonce-1")
	observer := &poolFakeObserver{progressHook: func(snapshot PoolSnapshot) error {
		for _, board := range snapshot.Boards {
			for _, attempt := range snapshot.Checkpoint.Attempts {
				if board.State == PoolBoardActive && attempt.State == PoolAttemptInFlight {
					return errors.New("injected checkpoint write failure")
				}
			}
		}
		return nil
	}}
	var calls atomic.Int32
	driver := &poolFakeDriver{result: func(key AttemptKey, _ PreparedSession) (SessionCapture, error) {
		calls.Add(1)
		return goodPoolCapture(key), nil
	}}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, &poolFakeFinalizer{}, observer)
	if _, err := pool.Run(context.Background(), []PoolJob{job}, PoolCheckpoint{}); err == nil {
		t.Fatal("checkpoint write error was ignored")
	}
	if calls.Load() != 0 {
		t.Fatalf("driver was called %d times after start checkpoint failed", calls.Load())
	}
}

func TestSessionPoolDetachesPreparedJobFromWorkerMutation(t *testing.T) {
	job := poolJob(t, "alpha", "session-1", "nonce-1")
	finalizer := &poolFakeFinalizer{inspect: func(session PreparedSession) error {
		if session.Checkpoints[0] != 100 || session.Profile.Options["dipsw"].(map[string]interface{})["banks"].([]interface{})[0] != 1 {
			return fmt.Errorf("worker mutation reached coordinator-owned prepared data")
		}
		return nil
	}}
	driver := &poolFakeDriver{
		mutate: func(session *PreparedSession) {
			session.Checkpoints[0] = 999
			session.Profile.Options["dipsw"].(map[string]interface{})["banks"].([]interface{})[0] = 9
		},
	}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, finalizer, nil)
	snapshot, err := pool.Run(context.Background(), []PoolJob{job}, PoolCheckpoint{})
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Jobs[0].State != PoolResultComplete || job.Session.Checkpoints[0] != 100 {
		t.Fatalf("worker-mutated job escaped isolation: %+v", snapshot.Jobs)
	}
}

func TestSessionPoolContinuesAfterOneBoardFailure(t *testing.T) {
	bad := poolJob(t, "alpha", "session-bad", "nonce-bad")
	good := poolJob(t, "beta", "session-good", "nonce-good")
	failedBoard := &poolFakeDriver{
		result: func(AttemptKey, PreparedSession) (SessionCapture, error) {
			return SessionCapture{}, errors.New("capture failed")
		},
		reconcile: func(context.Context, AttemptKey) (SessionCleanup, error) {
			return SessionCleanup{Confirmed: true}, nil
		},
	}
	goodBoard := &poolFakeDriver{}
	finalizer := &poolFakeFinalizer{}
	pool := newTestPool(t, []PoolBoard{
		poolBoard("board-a", "a", failedBoard),
		poolBoard("board-b", "b", goodBoard),
	}, finalizer, nil)
	snapshot, err := pool.Run(context.Background(), []PoolJob{bad, good}, PoolCheckpoint{})
	if err != nil {
		t.Fatal(err)
	}
	states := map[string]PoolResultState{}
	for _, result := range snapshot.Jobs {
		states[result.JobKey.Setname] = result.State
	}
	if states["alpha"] != PoolResultPending || states["beta"] != PoolResultComplete {
		t.Fatalf("one board failure blocked unrelated work: %+v", snapshot.Jobs)
	}
	if len(finalizer.seen) != 1 || !strings.Contains(finalizer.seen[0], "beta") {
		t.Fatalf("failed job was finalized or good job was skipped: %+v", finalizer.seen)
	}
}

func TestSessionPoolRequiresFreshAttemptAfterCleanFailure(t *testing.T) {
	first := poolJob(t, "alpha", "session-1", "nonce-1")
	failingDriver := &poolFakeDriver{result: func(AttemptKey, PreparedSession) (SessionCapture, error) {
		return SessionCapture{}, errors.New("injected capture failure")
	}}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", failingDriver)}, &poolFakeFinalizer{}, nil)
	failed, err := pool.Run(context.Background(), []PoolJob{first}, PoolCheckpoint{})
	if err != nil {
		t.Fatal(err)
	}
	if len(failed.Checkpoint.Attempts) != 1 || failed.Jobs[0].State != PoolResultPending {
		t.Fatalf("safe failure did not retain attempt inventory: %+v", failed)
	}
	secondDriver := &poolFakeDriver{}
	pool = newTestPool(t, []PoolBoard{poolBoard("board-a", "a", secondDriver)}, &poolFakeFinalizer{}, nil)
	reused, err := pool.Run(context.Background(), []PoolJob{first}, failed.Checkpoint)
	if err != nil {
		t.Fatal(err)
	}
	if len(secondDriver.started) != 0 || reused.Jobs[0].State != PoolResultPending || !strings.Contains(reused.Jobs[0].Message, "fresh session ID and nonce") {
		t.Fatalf("retired attempt identity was reused: %+v", reused)
	}
	fresh := poolJob(t, "alpha", "session-2", "nonce-2")
	retried, err := pool.Run(context.Background(), []PoolJob{fresh}, failed.Checkpoint)
	if err != nil {
		t.Fatal(err)
	}
	if retried.Jobs[0].State != PoolResultComplete || len(retried.Checkpoint.Attempts) != 2 {
		t.Fatalf("fresh attempt did not resume pending tuple: %+v", retried)
	}
	if _, err := validatePoolCheckpoint(retried.Checkpoint); err != nil {
		t.Fatalf("returned checkpoint cannot be normalized for resume: %v", err)
	}
}

func TestSessionPoolQuarantinesWhenReconcileReportsError(t *testing.T) {
	job := poolJob(t, "alpha", "session-1", "nonce-1")
	driver := &poolFakeDriver{
		result: func(AttemptKey, PreparedSession) (SessionCapture, error) {
			return SessionCapture{}, errors.New("capture failed")
		},
		reconcile: func(context.Context, AttemptKey) (SessionCleanup, error) {
			return SessionCleanup{Confirmed: true}, errors.New("reconciliation transport failed")
		},
	}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, &poolFakeFinalizer{}, nil)
	snapshot, err := pool.Run(context.Background(), []PoolJob{job}, PoolCheckpoint{})
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Jobs[0].State != PoolResultBlocked || len(snapshot.Checkpoint.Quarantined) != 1 {
		t.Fatalf("cleanup error released a board as safe: %+v", snapshot)
	}
}

func TestSessionPoolQuarantinesUnknownAttemptAndRequiresRecoveryWitness(t *testing.T) {
	job := poolJob(t, "alpha", "session-1", "nonce-1")
	started, release, returned := make(chan AttemptKey, 1), make(chan struct{}), make(chan struct{})
	driver := &poolFakeDriver{
		started:      started,
		returned:     returned,
		gate:         release,
		ignoreCancel: true,
		cancel: func(ctx context.Context, _ AttemptKey) error {
			if ctx.Err() != nil {
				return fmt.Errorf("cleanup context was not live at start")
			}
			return nil
		},
		reconcile: func(ctx context.Context, _ AttemptKey) (SessionCleanup, error) {
			<-ctx.Done()
			return SessionCleanup{Required: true, Message: "cleanup deadline"}, ctx.Err()
		},
	}
	clock := newManualPoolClock()
	finalizer := &poolFakeFinalizer{}
	observer := &poolFakeObserver{}
	pool, err := NewSessionPool([]PoolBoard{poolBoard("board-a", "a", driver)}, PoolOptions{
		CaptureTimeout: time.Second,
		CleanupTimeout: time.Second,
		Clock:          clock,
		Finalizer:      finalizer,
		Observer:       observer,
		EventSink:      observer,
	})
	if err != nil {
		t.Fatal(err)
	}
	result := make(chan PoolSnapshot, 1)
	go func() {
		snapshot, _ := pool.Run(context.Background(), []PoolJob{job}, PoolCheckpoint{})
		result <- snapshot
	}()
	attempt := <-started
	clock.waitTimer(t).fire()
	clock.waitTimer(t).fire()
	snapshot := <-result
	startsBeforeResume := len(started)
	blocked, err := pool.Run(context.Background(), []PoolJob{job}, snapshot.Checkpoint)
	if err != nil {
		t.Fatal(err)
	}
	if len(started) != startsBeforeResume || blocked.Jobs[0].State != PoolResultBlocked {
		t.Fatalf("unknown live attempt was redispatched: starts=%d snapshot=%+v", len(started), blocked)
	}
	close(release)
	<-returned
	if len(finalizer.seen) != 0 {
		t.Fatalf("late worker reply reached the finalizer: %+v", finalizer.seen)
	}
	if len(snapshot.Checkpoint.Unknown) != 1 || len(snapshot.Checkpoint.Quarantined) != 1 || snapshot.Jobs[0].State != PoolResultBlocked {
		t.Fatalf("unknown attempt was not fenced: %+v", snapshot)
	}
	checkpoint := snapshot.Checkpoint.Clone()
	if err := checkpoint.RecoverBoard(RecoveryWitness{Board: "board-a", Attempt: attempt, CaptureGeneration: job.Session.Generation, Reconciled: SessionCleanup{Confirmed: true}}); err == nil {
		t.Fatal("ping-like reconciliation without full RBF reload cleared quarantine")
	}
	if err := checkpoint.RecoverBoard(RecoveryWitness{Board: "board-a", Attempt: attempt, CaptureGeneration: job.Session.Generation, FullRBFReloaded: true, Reconciled: SessionCleanup{Confirmed: true}}); err != nil {
		t.Fatal(err)
	}
	if len(checkpoint.Unknown) != 0 || len(checkpoint.Quarantined) != 0 {
		t.Fatalf("real reload witness did not clear matching attempt: %+v", checkpoint)
	}
}

func TestSessionPoolCancellationUsesIndependentCleanupAndIgnoresLateResult(t *testing.T) {
	job := poolJob(t, "alpha", "session-1", "nonce-1")
	started, release, returned := make(chan AttemptKey, 1), make(chan struct{}), make(chan struct{})
	cleanupCalled := make(chan struct{}, 1)
	driver := &poolFakeDriver{
		started:      started,
		returned:     returned,
		gate:         release,
		ignoreCancel: true,
		result:       func(key AttemptKey, _ PreparedSession) (SessionCapture, error) { return goodPoolCapture(key), nil },
		cancel: func(ctx context.Context, _ AttemptKey) error {
			if ctx.Err() != nil {
				return fmt.Errorf("cleanup inherited canceled parent: %w", ctx.Err())
			}
			cleanupCalled <- struct{}{}
			return nil
		},
		reconcile: func(context.Context, AttemptKey) (SessionCleanup, error) { return SessionCleanup{Required: true}, nil },
	}
	finalizer := &poolFakeFinalizer{}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, finalizer, nil)
	ctx, cancel := context.WithCancel(context.Background())
	result := make(chan struct {
		snapshot PoolSnapshot
		err      error
	}, 1)
	go func() {
		snapshot, err := pool.Run(ctx, []PoolJob{job}, PoolCheckpoint{})
		result <- struct {
			snapshot PoolSnapshot
			err      error
		}{snapshot, err}
	}()
	<-started
	cancel()
	outcome := <-result
	<-cleanupCalled
	close(release)
	<-returned
	if !errors.Is(outcome.err, context.Canceled) {
		t.Fatalf("Run did not report caller cancellation: %v", outcome.err)
	}
	if outcome.snapshot.Jobs[0].State != PoolResultBlocked || len(finalizer.seen) != 0 {
		t.Fatalf("late success escaped attempt fence: %+v / %+v", outcome.snapshot, finalizer.seen)
	}
}

type manualPoolClock struct {
	mu      sync.Mutex
	created chan *manualPoolTimer
	now     time.Time
}

type manualPoolTimer struct {
	cancel context.CancelFunc
	used   sync.Once
}

func newManualPoolClock() *manualPoolClock {
	return &manualPoolClock{created: make(chan *manualPoolTimer, 8), now: time.Unix(100, 0)}
}

func (c *manualPoolClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.now
}

func (c *manualPoolClock) WithTimeout(parent context.Context, _ time.Duration) (context.Context, context.CancelFunc) {
	ctx, cancel := context.WithCancel(parent)
	c.created <- &manualPoolTimer{cancel: cancel}
	return ctx, cancel
}

func (c *manualPoolClock) waitTimer(t *testing.T) *manualPoolTimer {
	t.Helper()
	select {
	case timer := <-c.created:
		return timer
	case <-time.After(2 * time.Second):
		t.Fatal("expected deadline context was not created")
		return nil
	}
}

func (timer *manualPoolTimer) fire() { timer.used.Do(timer.cancel) }

func TestSessionPoolResumeUsesPortableIdentityAndRetainsOldGeneration(t *testing.T) {
	old := poolJob(t, "alpha", "old-session", "old-nonce")
	newer := poolJob(t, "alpha", "new-session", "new-nonce")
	newer.Session.Generation = "generation-v2"
	oldID, _ := old.Session.PortableIdentity()
	newID, _ := newer.Session.PortableIdentity()
	if oldID == newID {
		t.Fatal("fixture mutation did not alter portable identity")
	}
	checkpoint := PoolCheckpoint{Completed: []PoolCompleted{{JobKey: PoolJobKey{"circus", "alpha"}, PortableID: oldID, ResultDigest: "old-result", Attempt: AttemptKey{Board: "old-board", SessionID: old.SessionID, Nonce: old.Nonce}}}}
	driver := &poolFakeDriver{}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, &poolFakeFinalizer{}, nil)
	snapshot, err := pool.Run(context.Background(), []PoolJob{newer}, checkpoint)
	if err != nil {
		t.Fatal(err)
	}
	if len(snapshot.Checkpoint.Completed) != 2 || snapshot.Jobs[0].State != PoolResultComplete {
		t.Fatalf("new portable identity did not run while old completion remained: %+v", snapshot)
	}
	identities := []string{snapshot.Checkpoint.Completed[0].PortableID, snapshot.Checkpoint.Completed[1].PortableID}
	sort.Strings(identities)
	want := []string{oldID, newID}
	sort.Strings(want)
	if !reflect.DeepEqual(identities, want) {
		t.Fatalf("checkpoint lost a completed generation: %v", identities)
	}
}

func TestSessionPoolActiveCheckpointResumeQuarantinesBeforeAnyDriverCall(t *testing.T) {
	job := poolJob(t, "alpha", "fresh-session", "fresh-nonce")
	portableID, _ := job.Session.PortableIdentity()
	checkpoint := PoolCheckpoint{Attempts: []PoolAttemptRecord{{
		JobKey:     PoolJobKey{Core: job.Session.Core, Setname: job.Session.Setname},
		PortableID: portableID,
		Attempt:    AttemptKey{Board: "board-a", SessionID: "old-session", Nonce: "old-nonce"},
		// Empty state is the legacy capture-start shape and must be treated as in-flight.
	}}}
	var calls atomic.Int32
	driver := &poolFakeDriver{result: func(key AttemptKey, _ PreparedSession) (SessionCapture, error) {
		calls.Add(1)
		return goodPoolCapture(key), nil
	}}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, &poolFakeFinalizer{}, nil)
	snapshot, err := pool.Run(context.Background(), []PoolJob{job}, checkpoint)
	if err != nil {
		t.Fatal(err)
	}
	if calls.Load() != 0 || snapshot.Jobs[0].State != PoolResultBlocked || len(snapshot.Checkpoint.Unknown) != 1 || len(snapshot.Checkpoint.Quarantined) != 1 {
		t.Fatalf("in-flight checkpoint was reused without reconciliation: calls=%d snapshot=%+v", calls.Load(), snapshot)
	}
}

func TestSessionPoolRequiresBothAttemptIdentifiersFresh(t *testing.T) {
	for _, tc := range []struct {
		name    string
		session string
		nonce   string
	}{
		{name: "old session", session: "old-session", nonce: "new-nonce"},
		{name: "old nonce", session: "new-session", nonce: "old-nonce"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			job := poolJob(t, "alpha", tc.session, tc.nonce)
			portableID, _ := job.Session.PortableIdentity()
			checkpoint := PoolCheckpoint{Attempts: []PoolAttemptRecord{{
				JobKey:     PoolJobKey{Core: job.Session.Core, Setname: job.Session.Setname},
				PortableID: portableID,
				Attempt:    AttemptKey{Board: "old-board", SessionID: "old-session", Nonce: "old-nonce"},
				State:      PoolAttemptClean,
			}}}
			var calls atomic.Int32
			driver := &poolFakeDriver{result: func(key AttemptKey, _ PreparedSession) (SessionCapture, error) {
				calls.Add(1)
				return goodPoolCapture(key), nil
			}}
			pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, &poolFakeFinalizer{}, nil)
			snapshot, err := pool.Run(context.Background(), []PoolJob{job}, checkpoint)
			if err != nil {
				t.Fatal(err)
			}
			if calls.Load() != 0 || snapshot.Jobs[0].State != PoolResultPending || !strings.Contains(snapshot.Jobs[0].Message, "both a fresh session ID and nonce") {
				t.Fatalf("attempt reused one retired identity component: %+v", snapshot.Jobs)
			}
		})
	}
}

func TestSessionPoolCompletedOnlyHistoryRetiresAttemptIDs(t *testing.T) {
	job := poolJob(t, "alpha", "old-session", "old-nonce")
	oldID, _ := job.Session.PortableIdentity()
	job.Session.Generation = "capture-v2"
	checkpoint := PoolCheckpoint{Completed: []PoolCompleted{{
		JobKey:       PoolJobKey{Core: job.Session.Core, Setname: job.Session.Setname},
		PortableID:   oldID,
		ResultDigest: "valid-result-digest",
		Attempt:      AttemptKey{Board: "old-board", SessionID: "old-session", Nonce: "old-nonce"},
	}}}
	var calls atomic.Int32
	driver := &poolFakeDriver{result: func(key AttemptKey, _ PreparedSession) (SessionCapture, error) {
		calls.Add(1)
		return goodPoolCapture(key), nil
	}}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, &poolFakeFinalizer{}, nil)
	snapshot, err := pool.Run(context.Background(), []PoolJob{job}, checkpoint)
	if err != nil {
		t.Fatal(err)
	}
	if calls.Load() != 0 || snapshot.Jobs[0].State != PoolResultPending {
		t.Fatalf("new content reused completed-only attempt IDs: %+v", snapshot.Jobs)
	}
}

func TestSessionPoolRejectsIncompleteCompletionCheckpoint(t *testing.T) {
	job := poolJob(t, "alpha", "new-session", "new-nonce")
	portableID, _ := job.Session.PortableIdentity()
	checkpoint := PoolCheckpoint{Completed: []PoolCompleted{{
		JobKey:     PoolJobKey{Core: job.Session.Core, Setname: job.Session.Setname},
		PortableID: portableID,
		Attempt:    AttemptKey{Board: "board-a", SessionID: "old-session", Nonce: "old-nonce"},
	}}}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", &poolFakeDriver{})}, &poolFakeFinalizer{}, nil)
	if _, err := pool.Run(context.Background(), []PoolJob{job}, checkpoint); err == nil {
		t.Fatal("accepted completed checkpoint without finalizer digest")
	}
}

func TestSessionPoolRejectsQuarantineWithoutTupleFence(t *testing.T) {
	job := poolJob(t, "alpha", "new-session", "new-nonce")
	checkpoint := PoolCheckpoint{Quarantined: []PoolBoardQuarantine{{
		Board:      "board-a",
		Host:       "a",
		JobKey:     PoolJobKey{Core: job.Session.Core, Setname: job.Session.Setname},
		Attempt:    AttemptKey{Board: "board-a", SessionID: "old-session", Nonce: "old-nonce"},
		Generation: job.Session.Generation,
	}}}
	var calls atomic.Int32
	driver := &poolFakeDriver{result: func(key AttemptKey, _ PreparedSession) (SessionCapture, error) {
		calls.Add(1)
		return goodPoolCapture(key), nil
	}}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver), poolBoard("board-b", "b", driver)}, &poolFakeFinalizer{}, nil)
	if _, err := pool.Run(context.Background(), []PoolJob{job}, checkpoint); err == nil || calls.Load() != 0 {
		t.Fatalf("accepted inconsistent quarantine or dispatched work: calls=%d err=%v", calls.Load(), err)
	}
}

func TestSessionPoolRejectsConcurrentRunOnSamePool(t *testing.T) {
	started, release := make(chan AttemptKey, 2), make(chan struct{})
	driver := &poolFakeDriver{started: started, gate: release}
	pool := newTestPool(t, []PoolBoard{poolBoard("board-a", "a", driver)}, &poolFakeFinalizer{}, nil)
	firstJob := poolJob(t, "alpha", "session-1", "nonce-1")
	firstDone := make(chan error, 1)
	go func() {
		_, err := pool.Run(context.Background(), []PoolJob{firstJob}, PoolCheckpoint{})
		firstDone <- err
	}()
	<-started
	secondJob := poolJob(t, "beta", "session-2", "nonce-2")
	if _, err := pool.Run(context.Background(), []PoolJob{secondJob}, PoolCheckpoint{}); err == nil {
		close(release)
		<-firstDone
		t.Fatal("same pool accepted a concurrent Run")
	}
	close(release)
	if err := <-firstDone; err != nil {
		t.Fatal(err)
	}
}
