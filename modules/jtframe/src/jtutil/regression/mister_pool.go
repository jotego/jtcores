/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync/atomic"
	"time"
)

// PoolJob is one immutable prepared tuple and one caller-assigned attempt.
// SessionID and Nonce identify this attempt; neither participates in content
// identity or board selection.
type PoolJob struct {
	Session   PreparedSession
	SessionID string
	Nonce     string
}

// PoolBoard binds one unique physical host to its single session driver.
type PoolBoard struct {
	Key    BoardKey
	Host   string
	Driver SessionDriver
}

type PoolJobKey struct {
	Core    string
	Setname string
}

func (k PoolJobKey) String() string { return k.Core + "/" + k.Setname }

type PoolCompleted struct {
	JobKey         PoolJobKey
	PortableID     string
	ResultDigest   string
	Attempt        AttemptKey
	CleanupWarning string
}

type PoolAttemptRecord struct {
	JobKey       PoolJobKey
	PortableID   string
	Attempt      AttemptKey
	Generation   string
	State        PoolAttemptState
	CleanFailure *PoolCleanFailure `json:"clean_failure,omitempty"`
}

// PoolCleanFailure retains the driver's genuine keyed cleanup envelope when
// capture failed after cleanup succeeded. It is diagnostic/recovery evidence,
// not an image result and must never be passed to the image finalizer.
type PoolCleanFailure struct {
	Key     AttemptKey     `json:"key"`
	Capture SessionCapture `json:"capture"`
	Error   string         `json:"error"`
}

type PoolAttemptState string

const (
	PoolAttemptInFlight PoolAttemptState = "in-flight"
	PoolAttemptClean    PoolAttemptState = "clean"
	PoolAttemptUnknown  PoolAttemptState = "unknown"
	PoolAttemptComplete PoolAttemptState = "complete"
)

type PoolUnknownAttempt struct {
	JobKey     PoolJobKey
	PortableID string
	Attempt    AttemptKey
	Reason     string
}

type PoolBoardQuarantine struct {
	Board      BoardKey
	Host       string
	JobKey     PoolJobKey
	Attempt    AttemptKey
	Generation string
	Reason     string
	At         time.Time
}

// PoolCheckpoint is a caller-owned resumable inventory. Unknown attempts fence
// their tuple from redispatch until explicit real-reload reconciliation.
type PoolCheckpoint struct {
	Completed   []PoolCompleted
	Attempts    []PoolAttemptRecord
	Unknown     []PoolUnknownAttempt
	Quarantined []PoolBoardQuarantine
}

func (c PoolCheckpoint) Clone() PoolCheckpoint {
	c.Completed = append([]PoolCompleted(nil), c.Completed...)
	c.Attempts = append([]PoolAttemptRecord(nil), c.Attempts...)
	for i := range c.Attempts {
		if c.Attempts[i].CleanFailure != nil {
			failure := *c.Attempts[i].CleanFailure
			failure.Capture = failure.Capture.Clone()
			c.Attempts[i].CleanFailure = &failure
		}
	}
	c.Unknown = append([]PoolUnknownAttempt(nil), c.Unknown...)
	c.Quarantined = append([]PoolBoardQuarantine(nil), c.Quarantined...)
	return c
}

// RecoveryWitness is produced only after a real full-RBF reload and explicit
// reconciliation for the quarantined attempt. A health check or ping is not a
// recovery witness.
type RecoveryWitness struct {
	Board             BoardKey
	Attempt           AttemptKey
	CaptureGeneration string
	FullRBFReloaded   bool
	Reconciled        SessionCleanup
}

func (c *PoolCheckpoint) RecoverBoard(w RecoveryWitness) error {
	if c == nil {
		return fmt.Errorf("pool checkpoint is nil")
	}
	if !w.FullRBFReloaded || strings.TrimSpace(w.CaptureGeneration) == "" || !w.Reconciled.Confirmed || w.Reconciled.Required {
		return fmt.Errorf("recovery requires a full-RBF reload, generation and confirmed reconciliation")
	}
	index := -1
	for i, quarantine := range c.Quarantined {
		if quarantine.Board == w.Board {
			index = i
			if quarantine.Attempt != w.Attempt || quarantine.Generation != "" && quarantine.Generation != w.CaptureGeneration {
				return fmt.Errorf("recovery witness does not match quarantined attempt")
			}
			break
		}
	}
	if index < 0 {
		return fmt.Errorf("board %q is not quarantined", w.Board)
	}
	job := c.Quarantined[index].JobKey
	matchedUnknown := false
	for _, item := range c.Unknown {
		if item.JobKey == job && item.Attempt == w.Attempt {
			matchedUnknown = true
			break
		}
	}
	if !matchedUnknown {
		return fmt.Errorf("quarantine has no matching unknown attempt")
	}
	updated := false
	for i := range c.Attempts {
		if c.Attempts[i].Attempt == w.Attempt && c.Attempts[i].JobKey == job && c.Attempts[i].State == PoolAttemptUnknown {
			c.Attempts[i].State = PoolAttemptClean
			updated = true
			break
		}
	}
	if !updated {
		return fmt.Errorf("quarantined attempt has no matching unknown attempt record")
	}
	c.Quarantined = append(c.Quarantined[:index], c.Quarantined[index+1:]...)
	for i := range c.Unknown {
		if c.Unknown[i].JobKey == job && c.Unknown[i].Attempt == w.Attempt {
			c.Unknown = append(c.Unknown[:i], c.Unknown[i+1:]...)
			break
		}
	}
	return nil
}

type PoolResultState string

const (
	PoolResultComplete PoolResultState = "complete"
	PoolResultPending  PoolResultState = "pending"
	PoolResultBlocked  PoolResultState = "blocked"
)

type PoolJobResult struct {
	JobKey       PoolJobKey
	PortableID   string
	State        PoolResultState
	Attempt      AttemptKey
	ResultDigest string
	Message      string
}

type PoolBoardState string

const (
	PoolBoardIdle        PoolBoardState = "idle"
	PoolBoardActive      PoolBoardState = "active"
	PoolBoardUnavailable PoolBoardState = "unavailable"
	PoolBoardQuarantined PoolBoardState = "quarantined"
)

type PoolBoardStatus struct {
	Board   BoardKey
	Host    string
	State   PoolBoardState
	Attempt AttemptKey
	Message string
}

type PoolSnapshot struct {
	Jobs       []PoolJobResult
	Boards     []PoolBoardStatus
	Checkpoint PoolCheckpoint
}

func (s PoolSnapshot) Clone() PoolSnapshot {
	s.Jobs = append([]PoolJobResult(nil), s.Jobs...)
	s.Boards = append([]PoolBoardStatus(nil), s.Boards...)
	s.Checkpoint = s.Checkpoint.Clone()
	return s
}

type PoolEvent struct {
	At      time.Time
	Kind    string
	JobKey  PoolJobKey
	Attempt AttemptKey
	Message string
}

// PoolObserver is called only from SessionPool.Run's coordinator goroutine.
// Progress must durably record each snapshot before returning; in particular,
// the capture-start snapshot fences a board before the driver is called.
type PoolObserver interface {
	Progress(PoolSnapshot) error
}

// PoolEventSink receives optional coordinator-owned event logging.
type PoolEventSink interface {
	Event(PoolEvent) error
}

// PoolFinalizer is the serial, single-writer boundary for later legacy
// regression integration. It is called only after a clean worker result.
type PoolFinalizer interface {
	Finalize(context.Context, PoolJobKey, string, AttemptKey, PreparedSession, SessionCapture) (resultDigest string, err error)
}

type PoolClock interface {
	Now() time.Time
	WithTimeout(context.Context, time.Duration) (context.Context, context.CancelFunc)
}

type realPoolClock struct{}

func (realPoolClock) Now() time.Time { return time.Now() }
func (realPoolClock) WithTimeout(parent context.Context, timeout time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(parent, timeout)
}

type PoolOptions struct {
	CaptureTimeout time.Duration
	CleanupTimeout time.Duration // driver cleanup budget; the pool adds a bounded return margin
	Clock          PoolClock
	Finalizer      PoolFinalizer
	Observer       PoolObserver
	EventSink      PoolEventSink
}

// poolPreflightFailureLimit is how many health checks in a row a board may
// fail before it sits out the rest of the run.
const poolPreflightFailureLimit = 3

// poolRecoveryAllowance covers a driver that reboots the board to recover it.
const poolRecoveryAllowance = 5 * time.Minute

func poolCleanupWait(driverBudget time.Duration) time.Duration {
	margin := driverBudget / 10
	if margin < 250*time.Millisecond {
		margin = 250 * time.Millisecond
	}
	if margin > 5*time.Second {
		margin = 5 * time.Second
	}
	return driverBudget + margin
}

type SessionPool struct {
	boards  []PoolBoard
	options PoolOptions
	running atomic.Bool
}

type normalizedPoolJob struct {
	job        PoolJob
	key        PoolJobKey
	portableID string
}

type poolMessageKind uint8

const (
	poolCaptureReturned poolMessageKind = iota + 1
	poolCaptureTimedOut
	poolCancelReturned
	poolReconcileReturned
	poolWorkerAbandoned
)

type poolMessage struct {
	kind             poolMessageKind
	attempt          AttemptKey
	capture          SessionCapture
	err              error
	preflightFailure bool
	cleanup          SessionCleanup
}

type poolActive struct {
	job              normalizedPoolJob
	board            PoolBoard
	attempt          AttemptKey
	captureCancel    context.CancelFunc
	workerReturned   bool
	capture          SessionCapture
	captureErr       error
	cleanupStarted   bool
	cancelReturned   bool
	cancelErr        error
	reconcileStarted bool
	cleanupCtx       context.Context
	cleanupCancel    context.CancelFunc
	cleanupReturned  bool
	cleanup          SessionCleanup
	cleanupErr       error
	cancelled        bool
	reconcileErr     error
	reason           string
	workerDone       chan struct{}
}

// NewSessionPool rejects duplicate board IDs or hosts before any driver call.
func NewSessionPool(boards []PoolBoard, options PoolOptions) (*SessionPool, error) {
	if len(boards) == 0 {
		return nil, fmt.Errorf("session pool requires at least one board")
	}
	if options.CaptureTimeout <= 0 || options.CleanupTimeout <= 0 {
		return nil, fmt.Errorf("pool capture and cleanup deadlines must be positive")
	}
	if options.Finalizer == nil {
		return nil, fmt.Errorf("session pool requires a serial finalizer")
	}
	if options.Observer == nil {
		return nil, fmt.Errorf("session pool requires a serial checkpoint observer")
	}
	if options.Clock == nil {
		options.Clock = realPoolClock{}
	}
	copyBoards := append([]PoolBoard(nil), boards...)
	seenKeys, seenHosts := map[BoardKey]bool{}, map[string]bool{}
	for index := range copyBoards {
		board := &copyBoards[index]
		key := BoardKey(strings.TrimSpace(string(board.Key)))
		host := strings.ToLower(strings.TrimSpace(board.Host))
		if key == "" || host == "" || board.Driver == nil {
			return nil, fmt.Errorf("pool board requires unique ID, host and session driver")
		}
		if seenKeys[key] {
			return nil, fmt.Errorf("duplicate pool board ID %q", key)
		}
		if seenHosts[host] {
			return nil, fmt.Errorf("duplicate pool board host %q", host)
		}
		seenKeys[key], seenHosts[host] = true, true
		board.Key, board.Host = key, host
	}
	sort.Slice(copyBoards, func(i, j int) bool { return copyBoards[i].Key < copyBoards[j].Key })
	return &SessionPool{boards: copyBoards, options: options}, nil
}

// Run assigns each portable tuple at most once. Capture goroutines receive
// detached inputs and return private data; only this coordinator invokes the
// finalizer and observer. Failed but reconciled attempts remain pending for a
// later caller-supplied retry with a fresh session ID and nonce.
func (p *SessionPool) Run(ctx context.Context, jobs []PoolJob, resume PoolCheckpoint) (PoolSnapshot, error) {
	if ctx == nil {
		return PoolSnapshot{}, fmt.Errorf("pool context is nil")
	}
	if !p.running.CompareAndSwap(false, true) {
		return PoolSnapshot{}, fmt.Errorf("session pool Run already active")
	}
	defer p.running.Store(false)
	queue, err := normalizePoolJobs(jobs)
	if err != nil {
		return PoolSnapshot{}, err
	}
	checkpoint, err := validatePoolCheckpoint(resume)
	if err != nil {
		return PoolSnapshot{}, err
	}
	checkpoint, err = releaseInterruptedPoolAttempts(checkpoint)
	if err != nil {
		return PoolSnapshot{}, err
	}
	results := make(map[PoolJobKey]PoolJobResult, len(queue))
	for _, job := range queue {
		results[job.key] = PoolJobResult{JobKey: job.key, PortableID: job.portableID, State: PoolResultPending}
	}
	completed := make(map[PoolJobKey]PoolCompleted, len(checkpoint.Completed))
	for _, done := range checkpoint.Completed {
		if current, ok := results[done.JobKey]; ok && current.PortableID == done.PortableID {
			completed[done.JobKey] = done
			current.State = PoolResultComplete
			current.ResultDigest = done.ResultDigest
			current.Attempt = done.Attempt
			current.Message = done.CleanupWarning
			results[done.JobKey] = current
		}
	}
	unknown := make(map[PoolJobKey]PoolUnknownAttempt, len(checkpoint.Unknown))
	for _, item := range checkpoint.Unknown {
		unknown[item.JobKey] = item
		if current, ok := results[item.JobKey]; ok {
			current.State, current.Attempt, current.Message = PoolResultBlocked, item.Attempt, item.Reason
			results[item.JobKey] = current
		}
	}
	quarantined := make(map[BoardKey]PoolBoardQuarantine, len(checkpoint.Quarantined))
	for _, item := range checkpoint.Quarantined {
		quarantined[item.Board] = item
	}
	activeByBoard := make(map[BoardKey]*poolActive, len(p.boards))
	activeByKey := make(map[AttemptKey]*poolActive, len(p.boards))
	boardStatus := make(map[BoardKey]PoolBoardStatus, len(p.boards))
	for _, board := range p.boards {
		state := PoolBoardIdle
		message := ""
		if item, ok := quarantined[board.Key]; ok {
			state, message = PoolBoardQuarantined, item.Reason
		}
		boardStatus[board.Key] = PoolBoardStatus{Board: board.Key, Host: board.Host, State: state, Message: message}
	}
	tried := make(map[PoolJobKey]bool, len(queue))
	preflightFailures := make(map[BoardKey]int, len(p.boards))
	usedSession := make(map[string]bool, len(checkpoint.Attempts))
	usedNonce := make(map[string]bool, len(checkpoint.Attempts))
	for _, record := range checkpoint.Attempts {
		usedSession[record.Attempt.SessionID] = true
		usedNonce[record.Attempt.Nonce] = true
	}
	for _, job := range queue {
		if item, ok := completed[job.key]; ok && item.PortableID == job.portableID {
			tried[job.key] = true
		}
	}
	for _, item := range checkpoint.Unknown {
		tried[item.JobKey] = true
	}
	for _, job := range queue {
		if tried[job.key] {
			continue
		}
		if usedSession[job.job.SessionID] || usedNonce[job.job.Nonce] {
			tried[job.key] = true
			if result, ok := results[job.key]; ok && result.State == PoolResultPending {
				result.Message = "attempt identity was already used; retry requires both a fresh session ID and nonce"
				results[job.key] = result
			}
		}
	}
	messages := make(chan poolMessage, len(p.boards)*4+4)
	runCtx, cancelRun := context.WithCancel(ctx)
	defer cancelRun()
	parentDone := ctx.Done()
	stopDispatch := false
	var terminalErr error

	for {
		if !stopDispatch && terminalErr == nil && runCtx.Err() == nil {
			for _, board := range p.boards {
				if boardStatus[board.Key].State != PoolBoardIdle || activeByBoard[board.Key] != nil {
					continue
				}
				job, found := nextPoolJob(queue, tried, results, unknown, completed)
				if !found {
					break
				}
				tried[job.key] = true
				attempt := AttemptKey{Board: board.Key, SessionID: job.job.SessionID, Nonce: job.job.Nonce}
				checkpoint = setPoolAttempt(checkpoint, PoolAttemptRecord{JobKey: job.key, PortableID: job.portableID, Attempt: attempt, Generation: job.job.Session.Generation, State: PoolAttemptInFlight})
				captureCtx, captureCancel := p.options.Clock.WithTimeout(runCtx, p.options.CaptureTimeout)
				current := &poolActive{job: job, board: board, attempt: attempt, captureCancel: captureCancel}
				activeByBoard[board.Key], activeByKey[attempt] = current, current
				boardStatus[board.Key] = PoolBoardStatus{Board: board.Key, Host: board.Host, State: PoolBoardActive, Attempt: attempt}
				results[job.key] = PoolJobResult{JobKey: job.key, PortableID: job.portableID, State: PoolResultPending, Attempt: attempt}
				if err := p.emit(PoolEvent{At: p.options.Clock.Now(), Kind: "capture-start", JobKey: job.key, Attempt: attempt}, snapshotPool(results, boardStatus, checkpoint, unknown, quarantined)); err != nil {
					terminalErr = err
					stopDispatch = true
					current.captureCancel()
					checkpoint = setPoolAttemptState(checkpoint, attempt, PoolAttemptClean)
					p.releasePoolBoard(current, &activeByBoard, activeByKey, &boardStatus, "capture was not dispatched")
					results[job.key] = PoolJobResult{JobKey: job.key, PortableID: job.portableID, State: PoolResultPending, Message: terminalErr.Error()}
					cancelRun()
					break
				}
				p.startPoolCapture(captureCtx, current, messages)
				p.watchCaptureDeadline(captureCtx, current, messages)
			}
		}
		if len(activeByBoard) == 0 {
			if stopDispatch || runCtx.Err() != nil || terminalErr != nil || !hasEligiblePoolJob(queue, tried, results, unknown, completed) {
				break
			}
			idleBoard := false
			for _, status := range boardStatus {
				if status.State == PoolBoardIdle {
					idleBoard = true
					break
				}
			}
			if !idleBoard {
				terminalErr = errors.New("no available board for pending pool jobs")
				break
			}
		}
		select {
		case <-parentDone:
			parentDone = nil
			stopDispatch = true
			cancelRun()
			for _, current := range activeByBoard {
				current.cancelled, current.reason = true, "coordinator cancelled"
				current.captureCancel()
				p.beginPoolCleanup(context.WithoutCancel(ctx), current, messages)
			}
		case message := <-messages:
			current := activeByKey[message.attempt]
			if current == nil {
				continue
			}
			switch message.kind {
			case poolCaptureReturned:
				current.workerReturned = true
				current.captureCancel()
				if !message.preflightFailure {
					preflightFailures[current.board.Key] = 0
				}
				current.capture = message.capture.Clone()
				current.captureErr = message.err
				// A driver returns an empty capture only when it rejected the
				// attempt before taking ownership (for MiSTer this includes the
				// health probe and local validation before the lock/ledger). There
				// is nothing to cancel or reconcile, and persisting this synthetic
				// attempt would create an unrecoverable empty-key quarantine.
				if message.err != nil && message.preflightFailure {
					checkpoint = removePoolAttempt(checkpoint, current.attempt)
					results[current.job.key] = PoolJobResult{JobKey: current.job.key, PortableID: current.job.portableID, State: PoolResultPending, Message: message.err.Error()}
					p.releasePoolBoard(current, &activeByBoard, activeByKey, &boardStatus, message.err.Error())
					// The health check already tried to recover the board. Give the
					// game back to the queue; skip a board that keeps failing.
					tried[current.job.key] = false
					preflightFailures[current.board.Key]++
					if preflightFailures[current.board.Key] >= poolPreflightFailureLimit {
						boardStatus[current.board.Key] = PoolBoardStatus{Board: current.board.Key, Host: current.board.Host, State: PoolBoardUnavailable, Message: "board failed its health check repeatedly: " + message.err.Error()}
					}
					if err := p.emit(PoolEvent{At: p.options.Clock.Now(), Kind: "capture-preflight-failed", JobKey: current.job.key, Message: message.err.Error()}, snapshotPool(results, boardStatus, checkpoint, unknown, quarantined)); err != nil {
						terminalErr, stopDispatch = err, true
						cancelRun()
					}
					continue
				}
				if ctx.Err() != nil && !current.cleanupStarted {
					current.cancelled, current.reason = true, "coordinator cancelled"
					if poolCaptureConfirmsCleanCleanup(current) {
						p.finishCleanPoolAttempt(current, message.attempt, current.reason, &activeByBoard, activeByKey, &boardStatus, &results, &checkpoint, &unknown, &quarantined, &terminalErr, &stopDispatch, cancelRun)
						continue
					}
					p.beginPoolCleanup(context.WithoutCancel(ctx), current, messages)
				}
				if current.cleanupStarted {
					if current.cancelReturned {
						p.continuePoolCleanup(ctx, current, messages, &activeByBoard, activeByKey, &boardStatus, &results, &checkpoint, &unknown, &quarantined, &terminalErr, &stopDispatch, cancelRun)
					}
					continue
				}
				if message.err != nil {
					current.reason = message.err.Error()
					if poolCaptureConfirmsCleanCleanup(current) {
						p.finishCleanPoolAttempt(current, message.attempt, current.reason, &activeByBoard, activeByKey, &boardStatus, &results, &checkpoint, &unknown, &quarantined, &terminalErr, &stopDispatch, cancelRun)
						continue
					}
					p.beginPoolCleanup(ctx, current, messages)
					continue
				}
				capture := current.capture.Clone()
				if err := capture.ValidateEnvelope(current.attempt); err != nil {
					current.reason = err.Error()
					if poolCaptureConfirmsCleanCleanup(current) {
						p.finishCleanPoolAttempt(current, message.attempt, current.reason, &activeByBoard, activeByKey, &boardStatus, &results, &checkpoint, &unknown, &quarantined, &terminalErr, &stopDispatch, cancelRun)
						continue
					}
					p.beginPoolCleanup(ctx, current, messages)
					continue
				}
				if !capture.Cleanup.Confirmed || capture.Cleanup.Required {
					current.reason = "capture returned without confirmed clean ownership"
					p.beginPoolCleanup(ctx, current, messages)
					continue
				}
				checkpoint = setPoolAttemptState(checkpoint, current.attempt, PoolAttemptClean)
				if err := p.emit(PoolEvent{At: p.options.Clock.Now(), Kind: "capture-clean", JobKey: current.job.key, Attempt: current.attempt}, snapshotPool(results, boardStatus, checkpoint, unknown, quarantined)); err != nil {
					terminalErr, stopDispatch = err, true
					results[current.job.key] = PoolJobResult{JobKey: current.job.key, PortableID: current.job.portableID, State: PoolResultPending, Attempt: current.attempt, Message: err.Error()}
					p.releasePoolBoard(current, &activeByBoard, activeByKey, &boardStatus, err.Error())
					cancelRun()
					continue
				}
				if err := p.publishCaptureEvents(current.job.key, current.attempt, capture); err != nil {
					terminalErr, stopDispatch = err, true
					results[current.job.key] = PoolJobResult{JobKey: current.job.key, PortableID: current.job.portableID, State: PoolResultPending, Attempt: current.attempt, Message: err.Error()}
					p.releasePoolBoard(current, &activeByBoard, activeByKey, &boardStatus, err.Error())
					cancelRun()
					continue
				}
				if ctx.Err() != nil {
					current.cancelled, current.reason = true, "coordinator cancelled before finalization"
					p.finishCleanPoolAttempt(current, message.attempt, current.reason, &activeByBoard, activeByKey, &boardStatus, &results, &checkpoint, &unknown, &quarantined, &terminalErr, &stopDispatch, cancelRun)
					continue
				}
				digest, finalizeErr := p.options.Finalizer.Finalize(ctx, current.job.key, current.job.portableID, current.attempt, current.job.job.Session.Clone(), capture.Clone())
				if finalizeErr != nil {
					message.err = finalizeErr
				} else if strings.TrimSpace(digest) == "" {
					message.err = errors.New("serial finalizer returned an empty result digest")
				}
				if message.err != nil {
					results[current.job.key] = PoolJobResult{JobKey: current.job.key, PortableID: current.job.portableID, State: PoolResultPending, Attempt: current.attempt, Message: message.err.Error()}
				} else {
					results[current.job.key] = PoolJobResult{JobKey: current.job.key, PortableID: current.job.portableID, State: PoolResultComplete, Attempt: current.attempt, ResultDigest: digest}
					completed[current.job.key] = PoolCompleted{JobKey: current.job.key, PortableID: current.job.portableID, ResultDigest: digest, Attempt: current.attempt}
					checkpoint = setPoolAttemptState(checkpoint, current.attempt, PoolAttemptComplete)
					checkpoint = setPoolCompleted(checkpoint, completed[current.job.key])
				}
				if cleanupErr := removeSessionWorkspace(capture.WorkspaceRoot, capture.Workspace); cleanupErr != nil {
					warning := fmt.Sprintf("finalized result; local capture workspace cleanup pending: %v", cleanupErr)
					result := results[current.job.key]
					if result.State == PoolResultComplete {
						result.Message = warning
						results[current.job.key] = result
						done := completed[current.job.key]
						done.CleanupWarning = warning
						completed[current.job.key] = done
						checkpoint = setPoolCompleted(checkpoint, done)
					} else {
						result.Message = strings.TrimSpace(result.Message + "; local capture workspace cleanup pending: " + cleanupErr.Error())
						results[current.job.key] = result
					}
				}
				p.releasePoolBoard(current, &activeByBoard, activeByKey, &boardStatus, results[current.job.key].Message)
				if err := p.emit(PoolEvent{At: p.options.Clock.Now(), Kind: "capture-finished", JobKey: current.job.key, Attempt: current.attempt, Message: results[current.job.key].Message}, snapshotPool(results, boardStatus, checkpoint, unknown, quarantined)); err != nil {
					terminalErr, stopDispatch = err, true
					cancelRun()
				}
			case poolCaptureTimedOut:
				if current.workerReturned || current.cleanupStarted {
					continue
				}
				current.cancelled, current.reason = true, "capture deadline expired"
				current.captureCancel()
				p.beginPoolCleanup(context.WithoutCancel(ctx), current, messages)
			case poolCancelReturned:
				current.cancelReturned, current.cancelErr = true, message.err
				current.cleanupErr = errors.Join(current.cleanupErr, message.err)
				if message.err != nil {
					current.reason += ": " + message.err.Error()
				}
				if current.workerReturned {
					p.continuePoolCleanup(ctx, current, messages, &activeByBoard, activeByKey, &boardStatus, &results, &checkpoint, &unknown, &quarantined, &terminalErr, &stopDispatch, cancelRun)
				} else if message.err != nil {
					// The worker runs its own bounded cleanup. Wait for it, then
					// reconcile; give up on the board only if it never returns.
					p.watchAbandonedWorker(current, messages)
				}
			case poolWorkerAbandoned:
				if !current.workerReturned {
					p.quarantinePoolAttempt(current, &activeByBoard, activeByKey, &boardStatus, &results, &checkpoint, &unknown, &quarantined, "capture worker did not return after cleanup")
				}
			case poolReconcileReturned:
				current.cleanupReturned, current.cleanup = true, message.cleanup
				current.reconcileErr = message.err
				current.cleanupErr = errors.Join(current.cleanupErr, message.err)
				if message.err != nil {
					current.reason += ": " + message.err.Error()
				}
				if current.workerReturned {
					p.finishPoolCleanup(current, message.attempt, &activeByBoard, activeByKey, &boardStatus, &results, &checkpoint, &unknown, &quarantined, &terminalErr, &stopDispatch, cancelRun)
				} else {
					p.quarantinePoolAttempt(current, &activeByBoard, activeByKey, &boardStatus, &results, &checkpoint, &unknown, &quarantined, "cleanup ended while capture worker remained live")
				}
			}
		}
	}

	for _, current := range activeByBoard {
		p.quarantinePoolAttempt(current, &activeByBoard, activeByKey, &boardStatus, &results, &checkpoint, &unknown, &quarantined, "coordinator stopped before attempt closed")
	}
	for key, result := range results {
		if result.State == PoolResultPending && result.Message == "" {
			if item, ok := unknown[key]; ok {
				result.State, result.Attempt, result.Message = PoolResultBlocked, item.Attempt, item.Reason
			} else if existing, ok := completed[key]; ok && existing.PortableID == result.PortableID {
				result.State, result.Attempt, result.ResultDigest = PoolResultComplete, existing.Attempt, existing.ResultDigest
			}
			results[key] = result
		}
	}
	final := snapshotPool(results, boardStatus, checkpoint, unknown, quarantined)
	if p.options.Observer != nil {
		if err := p.options.Observer.Progress(final.Clone()); err != nil && terminalErr == nil {
			terminalErr = err
		}
	}
	if terminalErr == nil && ctx.Err() != nil {
		terminalErr = ctx.Err()
	}
	return final, terminalErr
}

func normalizePoolJobs(jobs []PoolJob) ([]normalizedPoolJob, error) {
	queue := make([]normalizedPoolJob, 0, len(jobs))
	byKey := make(map[PoolJobKey]normalizedPoolJob, len(jobs))
	usedSessionIDs := make(map[string]bool, len(jobs))
	usedNonces := make(map[string]bool, len(jobs))
	for _, input := range jobs {
		job := PoolJob{Session: input.Session.Clone(), SessionID: strings.TrimSpace(input.SessionID), Nonce: strings.TrimSpace(input.Nonce)}
		if err := job.Session.Validate(); err != nil {
			return nil, fmt.Errorf("validate %s/%s: %w", job.Session.Core, job.Session.Setname, err)
		}
		if job.SessionID == "" || job.Nonce == "" || strings.ContainsAny(job.SessionID+job.Nonce, "\x00\r\n") {
			return nil, fmt.Errorf("pool job %s/%s requires a session ID and attempt nonce", job.Session.Core, job.Session.Setname)
		}
		key := PoolJobKey{Core: job.Session.Core, Setname: job.Session.Setname}
		identity, err := job.Session.PortableIdentity()
		if err != nil {
			return nil, fmt.Errorf("identify %s: %w", key, err)
		}
		if _, ok := byKey[key]; ok {
			return nil, fmt.Errorf("duplicate pool tuple %s", key)
		}
		if usedSessionIDs[job.SessionID] {
			return nil, fmt.Errorf("duplicate pool session ID %q", job.SessionID)
		}
		if usedNonces[job.Nonce] {
			return nil, fmt.Errorf("duplicate pool attempt nonce %q", job.Nonce)
		}
		usedSessionIDs[job.SessionID] = true
		usedNonces[job.Nonce] = true
		item := normalizedPoolJob{job: job, key: key, portableID: identity}
		byKey[key] = item
		queue = append(queue, item)
	}
	return queue, nil
}

func validatePoolCheckpoint(checkpoint PoolCheckpoint) (PoolCheckpoint, error) {
	copy := checkpoint.Clone()
	type completedIdentity struct {
		job      PoolJobKey
		identity string
	}
	completed := make(map[completedIdentity]bool, len(copy.Completed))
	for _, item := range copy.Completed {
		identity := completedIdentity{job: item.JobKey, identity: item.PortableID}
		if item.JobKey.Core == "" || item.JobKey.Setname == "" || item.Attempt.Board == "" || item.Attempt.SessionID == "" || item.Attempt.Nonce == "" || !isSHA256Hex(item.PortableID) || strings.TrimSpace(item.ResultDigest) == "" || completed[identity] {
			return PoolCheckpoint{}, fmt.Errorf("invalid or duplicate completed pool tuple")
		}
		completed[identity] = true
	}
	attemptIndex := make(map[AttemptKey]int, len(copy.Attempts)+len(copy.Completed)+len(copy.Unknown))
	for index := range copy.Attempts {
		item := &copy.Attempts[index]
		if item.JobKey.Core == "" || item.JobKey.Setname == "" || item.Attempt.SessionID == "" || item.Attempt.Nonce == "" || item.Attempt.Board == "" || !isSHA256Hex(item.PortableID) {
			return PoolCheckpoint{}, fmt.Errorf("invalid pool attempt record")
		}
		if item.State == "" { // Older capture-start snapshots conservatively mean in-flight.
			item.State = PoolAttemptInFlight
		}
		if item.State != PoolAttemptInFlight && item.State != PoolAttemptClean && item.State != PoolAttemptUnknown && item.State != PoolAttemptComplete {
			return PoolCheckpoint{}, fmt.Errorf("invalid pool attempt state %q", item.State)
		}
		if failure := item.CleanFailure; failure != nil {
			if item.State != PoolAttemptClean || failure.Key != item.Attempt || failure.Capture.Key != item.Attempt || !failure.Capture.Cleanup.Confirmed || failure.Capture.Cleanup.Required || strings.TrimSpace(failure.Error) == "" {
				return PoolCheckpoint{}, fmt.Errorf("clean capture failure envelope does not match its clean attempt")
			}
		}
		if _, exists := attemptIndex[item.Attempt]; exists {
			return PoolCheckpoint{}, fmt.Errorf("duplicate pool attempt record")
		}
		attemptIndex[item.Attempt] = index
	}
	for _, item := range copy.Completed {
		if index, ok := attemptIndex[item.Attempt]; ok {
			record := &copy.Attempts[index]
			if record.JobKey != item.JobKey || record.PortableID != item.PortableID {
				return PoolCheckpoint{}, fmt.Errorf("completed tuple conflicts with its attempt record")
			}
			record.State = PoolAttemptComplete
		} else {
			copy.Attempts = append(copy.Attempts, PoolAttemptRecord{JobKey: item.JobKey, PortableID: item.PortableID, Attempt: item.Attempt, State: PoolAttemptComplete})
			attemptIndex[item.Attempt] = len(copy.Attempts) - 1
		}
	}
	unknown := make(map[PoolJobKey]AttemptKey, len(copy.Unknown))
	for _, item := range copy.Unknown {
		if item.JobKey.Core == "" || item.JobKey.Setname == "" || item.Attempt.SessionID == "" || item.Attempt.Nonce == "" || item.Attempt.Board == "" || !isSHA256Hex(item.PortableID) || unknown[item.JobKey].SessionID != "" {
			return PoolCheckpoint{}, fmt.Errorf("invalid or duplicate unknown pool attempt")
		}
		unknown[item.JobKey] = item.Attempt
		if index, ok := attemptIndex[item.Attempt]; ok {
			record := &copy.Attempts[index]
			if record.JobKey != item.JobKey || record.PortableID != item.PortableID || record.State != PoolAttemptUnknown && record.State != PoolAttemptInFlight {
				return PoolCheckpoint{}, fmt.Errorf("unknown tuple conflicts with its attempt record")
			}
			record.State = PoolAttemptUnknown
		} else {
			generation := ""
			if q, ok := findPoolQuarantine(copy.Quarantined, item.Attempt.Board); ok {
				generation = q.Generation
			}
			copy.Attempts = append(copy.Attempts, PoolAttemptRecord{JobKey: item.JobKey, PortableID: item.PortableID, Attempt: item.Attempt, Generation: generation, State: PoolAttemptUnknown})
			attemptIndex[item.Attempt] = len(copy.Attempts) - 1
		}
	}
	boards := make(map[BoardKey]bool, len(copy.Quarantined))
	for _, item := range copy.Quarantined {
		if item.Board == "" || item.Attempt.Board != item.Board || boards[item.Board] {
			return PoolCheckpoint{}, fmt.Errorf("invalid or duplicate quarantined pool board")
		}
		boards[item.Board] = true
	}
	for _, item := range copy.Unknown {
		quarantine, ok := findPoolQuarantine(copy.Quarantined, item.Attempt.Board)
		if !ok || quarantine.JobKey != item.JobKey || quarantine.Attempt != item.Attempt {
			return PoolCheckpoint{}, fmt.Errorf("unknown attempt %s has no matching board quarantine", item.JobKey)
		}
	}
	for _, item := range copy.Quarantined {
		unknownItem, ok := unknownPoolAttempt(copy.Unknown, item.Attempt)
		if !ok || unknownItem.JobKey != item.JobKey {
			return PoolCheckpoint{}, fmt.Errorf("quarantined board %s has no matching unknown attempt", item.Board)
		}
		if index, ok := attemptIndex[item.Attempt]; !ok || copy.Attempts[index].State != PoolAttemptUnknown || copy.Attempts[index].JobKey != item.JobKey || item.Generation != "" && copy.Attempts[index].Generation != "" && item.Generation != copy.Attempts[index].Generation {
			return PoolCheckpoint{}, fmt.Errorf("quarantined board %s has inconsistent attempt provenance", item.Board)
		}
	}
	for _, item := range copy.Attempts {
		unknownItem, hasUnknown := unknownPoolAttempt(copy.Unknown, item.Attempt)
		quarantine, hasQuarantine := findPoolQuarantine(copy.Quarantined, item.Attempt.Board)
		hasExactQuarantine := hasQuarantine && quarantine.Attempt == item.Attempt
		switch item.State {
		case PoolAttemptInFlight:
			if hasUnknown || hasQuarantine {
				return PoolCheckpoint{}, fmt.Errorf("in-flight attempt conflicts with an unknown ownership fence")
			}
		case PoolAttemptClean:
			if hasUnknown || hasExactQuarantine {
				return PoolCheckpoint{}, fmt.Errorf("clean attempt is also marked unknown")
			}
		case PoolAttemptUnknown:
			if !hasUnknown || unknownItem.JobKey != item.JobKey || !hasExactQuarantine || quarantine.JobKey != item.JobKey {
				return PoolCheckpoint{}, fmt.Errorf("unknown attempt is missing its tuple or board fence")
			}
		case PoolAttemptComplete:
			if item.CleanFailure != nil {
				return PoolCheckpoint{}, fmt.Errorf("failed clean capture cannot be marked complete")
			}
			found := false
			for _, done := range copy.Completed {
				if done.JobKey == item.JobKey && done.PortableID == item.PortableID && done.Attempt == item.Attempt && strings.TrimSpace(done.ResultDigest) != "" {
					found = true
					break
				}
			}
			if !found {
				return PoolCheckpoint{}, fmt.Errorf("completed attempt has no valid finalization record")
			}
		}
	}
	usedSession, usedNonce := map[string]AttemptKey{}, map[string]AttemptKey{}
	for _, item := range copy.Attempts {
		if previous, ok := usedSession[item.Attempt.SessionID]; ok && previous != item.Attempt {
			return PoolCheckpoint{}, fmt.Errorf("session ID was reused across attempt history")
		}
		if previous, ok := usedNonce[item.Attempt.Nonce]; ok && previous != item.Attempt {
			return PoolCheckpoint{}, fmt.Errorf("attempt nonce was reused across attempt history")
		}
		usedSession[item.Attempt.SessionID] = item.Attempt
		usedNonce[item.Attempt.Nonce] = item.Attempt
	}
	return copy, nil
}

func findPoolQuarantine(items []PoolBoardQuarantine, board BoardKey) (PoolBoardQuarantine, bool) {
	for _, item := range items {
		if item.Board == board {
			return item, true
		}
	}
	return PoolBoardQuarantine{}, false
}

func unknownPoolAttempt(items []PoolUnknownAttempt, attempt AttemptKey) (PoolUnknownAttempt, bool) {
	for _, item := range items {
		if item.Attempt == attempt {
			return item, true
		}
	}
	return PoolUnknownAttempt{}, false
}

// releaseInterruptedPoolAttempts closes attempts that an earlier run left in
// flight, unknown or quarantined. Boards are never fenced across runs: the
// driver's health check recovers a board, rebooting it if needed, before its
// next capture. The released games stay pending.
func releaseInterruptedPoolAttempts(checkpoint PoolCheckpoint) (PoolCheckpoint, error) {
	for index := range checkpoint.Attempts {
		record := &checkpoint.Attempts[index]
		if record.State == PoolAttemptInFlight || record.State == PoolAttemptUnknown {
			record.State = PoolAttemptClean
		}
	}
	checkpoint.Unknown, checkpoint.Quarantined = nil, nil
	return validatePoolCheckpoint(checkpoint)
}

func nextPoolJob(queue []normalizedPoolJob, tried map[PoolJobKey]bool, results map[PoolJobKey]PoolJobResult, unknown map[PoolJobKey]PoolUnknownAttempt, completed map[PoolJobKey]PoolCompleted) (normalizedPoolJob, bool) {
	for _, job := range queue {
		if tried[job.key] || unknown[job.key].Attempt.SessionID != "" {
			continue
		}
		if done, ok := completed[job.key]; ok && done.PortableID == job.portableID {
			continue
		}
		if result, ok := results[job.key]; ok && result.State == PoolResultComplete {
			continue
		}
		return job, true
	}
	return normalizedPoolJob{}, false
}

func hasEligiblePoolJob(queue []normalizedPoolJob, tried map[PoolJobKey]bool, results map[PoolJobKey]PoolJobResult, unknown map[PoolJobKey]PoolUnknownAttempt, completed map[PoolJobKey]PoolCompleted) bool {
	_, ok := nextPoolJob(queue, tried, results, unknown, completed)
	return ok
}

func (p *SessionPool) startPoolCapture(ctx context.Context, current *poolActive, messages chan<- poolMessage) {
	done := make(chan struct{})
	current.workerDone = done
	go func() {
		defer close(done)
		var capture SessionCapture
		err := current.board.Driver.Healthy(ctx)
		preflightFailure := err != nil
		if err == nil {
			capture, err = current.board.Driver.Capture(ctx, current.attempt, current.job.job.Session.Clone())
			preflightFailure = errors.Is(err, ErrCaptureNotStarted)
		}
		messages <- poolMessage{kind: poolCaptureReturned, attempt: current.attempt, capture: capture.Clone(), err: err, preflightFailure: preflightFailure}
	}()
}

func (p *SessionPool) watchCaptureDeadline(ctx context.Context, current *poolActive, messages chan<- poolMessage) {
	go func() {
		select {
		case <-current.workerDone:
			return
		case <-ctx.Done():
			select {
			case <-current.workerDone:
				return
			default:
				messages <- poolMessage{kind: poolCaptureTimedOut, attempt: current.attempt, err: ctx.Err()}
			}
		}
	}()
}

func (p *SessionPool) beginPoolCleanup(parent context.Context, current *poolActive, messages chan<- poolMessage) {
	if current.cleanupStarted {
		return
	}
	current.cleanupStarted = true
	current.cancelled = true
	if current.reason == "" {
		current.reason = "capture did not finish with confirmed cleanup"
	}
	ctx, cancel := p.options.Clock.WithTimeout(context.WithoutCancel(parent), poolCleanupWait(p.options.CleanupTimeout))
	current.cleanupCtx, current.cleanupCancel = ctx, cancel
	go func() {
		select {
		case <-current.workerDone:
			messages <- poolMessage{kind: poolCancelReturned, attempt: current.attempt}
			return
		default:
		}
		cancelDone := make(chan error, 1)
		go func() { cancelDone <- current.board.Driver.Cancel(ctx, current.attempt) }()
		var cancelErr error
		select {
		case cancelErr = <-cancelDone:
			if cancelErr == nil {
				select {
				case <-current.workerDone:
				case <-ctx.Done():
					cancelErr = ctx.Err()
				}
			}
		case <-ctx.Done():
			cancelErr = ctx.Err()
		}
		messages <- poolMessage{kind: poolCancelReturned, attempt: current.attempt, err: cancelErr}
	}()
}

func (p *SessionPool) continuePoolCleanup(ctx context.Context, current *poolActive, messages chan<- poolMessage, activeByBoard *map[BoardKey]*poolActive, activeByKey map[AttemptKey]*poolActive, boardStatus *map[BoardKey]PoolBoardStatus, results *map[PoolJobKey]PoolJobResult, checkpoint *PoolCheckpoint, unknown *map[PoolJobKey]PoolUnknownAttempt, quarantined *map[BoardKey]PoolBoardQuarantine, terminalErr *error, stopDispatch *bool, cancelRun context.CancelFunc) {
	if !current.workerReturned || !current.cancelReturned {
		return
	}
	if poolCaptureConfirmsCleanCleanup(current) {
		message := current.reason
		if current.cancelErr != nil {
			message = strings.TrimSpace(message + "; driver capture worker reported clean cleanup after cancel-wait error: " + current.cancelErr.Error())
		}
		if message == "" {
			message = "capture ended cleanly after coordinator cancellation"
		}
		p.finishCleanPoolAttempt(current, current.attempt, message, activeByBoard, activeByKey, boardStatus, results, checkpoint, unknown, quarantined, terminalErr, stopDispatch, cancelRun)
		return
	}
	if current.reconcileStarted {
		return
	}
	current.reconcileStarted = true
	// Reconcile may reboot the board, which takes longer than the frozen
	// cleanup budget, so it gets its own deadline.
	reconcileCtx, reconcileCancel := p.options.Clock.WithTimeout(context.WithoutCancel(ctx), poolCleanupWait(p.options.CleanupTimeout)+poolRecoveryAllowance)
	if current.cleanupCancel != nil {
		current.cleanupCancel()
	}
	current.cleanupCtx, current.cleanupCancel = reconcileCtx, reconcileCancel
	go func() {
		done := make(chan struct {
			cleanup SessionCleanup
			err     error
		}, 1)
		go func() {
			cleanup, err := current.board.Driver.Reconcile(reconcileCtx, current.attempt)
			done <- struct {
				cleanup SessionCleanup
				err     error
			}{cleanup, err}
		}()
		select {
		case result := <-done:
			messages <- poolMessage{kind: poolReconcileReturned, attempt: current.attempt, cleanup: result.cleanup, err: result.err}
		case <-reconcileCtx.Done():
			messages <- poolMessage{kind: poolReconcileReturned, attempt: current.attempt, err: reconcileCtx.Err()}
		}
	}()
}

// watchAbandonedWorker reports a capture worker that is still running long
// after cancel gave up. The worker first finishes its current board command,
// then runs a cleanup bounded by the cleanup budget, so only a hung driver
// takes four budgets.
func (p *SessionPool) watchAbandonedWorker(current *poolActive, messages chan<- poolMessage) {
	ctx, cancel := p.options.Clock.WithTimeout(context.Background(), 4*poolCleanupWait(p.options.CleanupTimeout))
	go func() {
		defer cancel()
		select {
		case <-current.workerDone:
		case <-ctx.Done():
			messages <- poolMessage{kind: poolWorkerAbandoned, attempt: current.attempt}
		}
	}()
}

func poolCaptureConfirmsCleanCleanup(current *poolActive) bool {
	return current.capture.Key == current.attempt && current.capture.Cleanup.Confirmed && !current.capture.Cleanup.Required
}

func (p *SessionPool) finishCleanPoolAttempt(current *poolActive, attempt AttemptKey, reason string, activeByBoard *map[BoardKey]*poolActive, activeByKey map[AttemptKey]*poolActive, boardStatus *map[BoardKey]PoolBoardStatus, results *map[PoolJobKey]PoolJobResult, checkpoint *PoolCheckpoint, unknown *map[PoolJobKey]PoolUnknownAttempt, quarantined *map[BoardKey]PoolBoardQuarantine, terminalErr *error, stopDispatch *bool, cancelRun context.CancelFunc) {
	if err := removeSessionWorkspace(current.capture.WorkspaceRoot, current.capture.Workspace); err != nil {
		reason = strings.TrimSpace(reason + "; remove local capture workspace: " + err.Error())
	}
	if strings.TrimSpace(reason) == "" {
		reason = "capture failed after confirmed driver cleanup"
	}
	*checkpoint = setPoolAttemptState(*checkpoint, attempt, PoolAttemptClean)
	if current.captureErr != nil && poolCaptureConfirmsCleanCleanup(current) {
		*checkpoint = setPoolCleanFailure(*checkpoint, attempt, PoolCleanFailure{
			Key: attempt, Capture: current.capture.Clone(), Error: current.captureErr.Error(),
		})
	}
	(*results)[current.job.key] = PoolJobResult{JobKey: current.job.key, PortableID: current.job.portableID, State: PoolResultPending, Attempt: attempt, Message: reason}
	if err := p.emit(PoolEvent{At: p.options.Clock.Now(), Kind: "capture-clean", JobKey: current.job.key, Attempt: attempt, Message: reason}, snapshotPool(*results, *boardStatus, *checkpoint, *unknown, *quarantined)); err != nil {
		*terminalErr, *stopDispatch = err, true
		p.releasePoolBoard(current, activeByBoard, activeByKey, boardStatus, reason)
		cancelRun()
		return
	}
	p.releasePoolBoard(current, activeByBoard, activeByKey, boardStatus, reason)
	if err := p.emit(PoolEvent{At: p.options.Clock.Now(), Kind: "capture-finished", JobKey: current.job.key, Attempt: attempt, Message: reason}, snapshotPool(*results, *boardStatus, *checkpoint, *unknown, *quarantined)); err != nil {
		*terminalErr, *stopDispatch = err, true
		cancelRun()
	}
}

func (p *SessionPool) publishCaptureEvents(job PoolJobKey, attempt AttemptKey, capture SessionCapture) error {
	if p.options.EventSink == nil {
		return nil
	}
	for _, event := range capture.Events {
		if err := p.options.EventSink.Event(PoolEvent{At: time.Unix(0, event.AtUnixNano), Kind: event.Stage, JobKey: job, Attempt: attempt, Message: event.Message}); err != nil {
			return err
		}
	}
	return nil
}

func (p *SessionPool) emit(event PoolEvent, snapshot PoolSnapshot) error {
	if p.options.EventSink != nil {
		if err := p.options.EventSink.Event(event); err != nil {
			return err
		}
	}
	return p.options.Observer.Progress(snapshot.Clone())
}

func (p *SessionPool) releasePoolBoard(current *poolActive, activeByBoard *map[BoardKey]*poolActive, activeByKey map[AttemptKey]*poolActive, boardStatus *map[BoardKey]PoolBoardStatus, message string) {
	if current.cleanupCancel != nil {
		current.cleanupCancel()
		current.cleanupCancel = nil
	}
	delete(*activeByBoard, current.board.Key)
	delete(activeByKey, current.attempt)
	(*boardStatus)[current.board.Key] = PoolBoardStatus{Board: current.board.Key, Host: current.board.Host, State: PoolBoardIdle, Message: message}
}

func (p *SessionPool) finishPoolCleanup(current *poolActive, attempt AttemptKey, activeByBoard *map[BoardKey]*poolActive, activeByKey map[AttemptKey]*poolActive, boardStatus *map[BoardKey]PoolBoardStatus, results *map[PoolJobKey]PoolJobResult, checkpoint *PoolCheckpoint, unknown *map[PoolJobKey]PoolUnknownAttempt, quarantined *map[BoardKey]PoolBoardQuarantine, terminalErr *error, stopDispatch *bool, cancelRun context.CancelFunc) {
	// A confirmed Reconcile settles the board even if cancel failed earlier.
	if current.cleanup.Confirmed && !current.cleanup.Required && current.reconcileErr == nil {
		p.finishCleanPoolAttempt(current, attempt, current.reason, activeByBoard, activeByKey, boardStatus, results, checkpoint, unknown, quarantined, terminalErr, stopDispatch, cancelRun)
		return
	}
	p.quarantinePoolAttempt(current, activeByBoard, activeByKey, boardStatus, results, checkpoint, unknown, quarantined, current.reason)
}

// quarantinePoolAttempt benches the board for the rest of this run when its
// attempt could not be recovered, even by reboot. Nothing is persisted that
// would fence the board or the game in later runs; the game is reported as
// failed for this run.
func (p *SessionPool) quarantinePoolAttempt(current *poolActive, activeByBoard *map[BoardKey]*poolActive, activeByKey map[AttemptKey]*poolActive, boardStatus *map[BoardKey]PoolBoardStatus, results *map[PoolJobKey]PoolJobResult, checkpoint *PoolCheckpoint, unknown *map[PoolJobKey]PoolUnknownAttempt, quarantined *map[BoardKey]PoolBoardQuarantine, reason string) {
	if current.cleanupCancel != nil {
		current.cleanupCancel()
		current.cleanupCancel = nil
	}
	if strings.TrimSpace(reason) == "" {
		reason = "attempt cleanup is unknown"
	}
	reason = "board recovery failed; board skipped for the rest of this run: " + reason
	*checkpoint = setPoolAttemptState(*checkpoint, current.attempt, PoolAttemptClean)
	(*results)[current.job.key] = PoolJobResult{JobKey: current.job.key, PortableID: current.job.portableID, State: PoolResultPending, Attempt: current.attempt, Message: reason}
	(*boardStatus)[current.board.Key] = PoolBoardStatus{Board: current.board.Key, Host: current.board.Host, State: PoolBoardUnavailable, Attempt: current.attempt, Message: reason}
	delete(*activeByBoard, current.board.Key)
	delete(activeByKey, current.attempt)
}

func setPoolCompleted(checkpoint PoolCheckpoint, item PoolCompleted) PoolCheckpoint {
	for i := range checkpoint.Completed {
		if checkpoint.Completed[i].JobKey == item.JobKey && checkpoint.Completed[i].PortableID == item.PortableID {
			checkpoint.Completed[i] = item
			return checkpoint
		}
	}
	checkpoint.Completed = append(checkpoint.Completed, item)
	return checkpoint
}

func setPoolAttempt(checkpoint PoolCheckpoint, item PoolAttemptRecord) PoolCheckpoint {
	for _, existing := range checkpoint.Attempts {
		if existing.Attempt == item.Attempt {
			return checkpoint
		}
	}
	checkpoint.Attempts = append(checkpoint.Attempts, item)
	return checkpoint
}

func setPoolAttemptState(checkpoint PoolCheckpoint, attempt AttemptKey, state PoolAttemptState) PoolCheckpoint {
	for index := range checkpoint.Attempts {
		if checkpoint.Attempts[index].Attempt == attempt {
			checkpoint.Attempts[index].State = state
			if state != PoolAttemptUnknown {
				checkpoint.Unknown = removePoolUnknown(checkpoint.Unknown, attempt)
				checkpoint.Quarantined = removePoolQuarantine(checkpoint.Quarantined, attempt)
			}
			return checkpoint
		}
	}
	return checkpoint
}

func setPoolCleanFailure(checkpoint PoolCheckpoint, attempt AttemptKey, failure PoolCleanFailure) PoolCheckpoint {
	for index := range checkpoint.Attempts {
		if checkpoint.Attempts[index].Attempt == attempt {
			copy := failure
			copy.Capture = failure.Capture.Clone()
			checkpoint.Attempts[index].CleanFailure = &copy
			return checkpoint
		}
	}
	return checkpoint
}

func removePoolUnknown(items []PoolUnknownAttempt, attempt AttemptKey) []PoolUnknownAttempt {
	for index := range items {
		if items[index].Attempt == attempt {
			return append(items[:index], items[index+1:]...)
		}
	}
	return items
}

func removePoolQuarantine(items []PoolBoardQuarantine, attempt AttemptKey) []PoolBoardQuarantine {
	for index := range items {
		if items[index].Attempt == attempt {
			return append(items[:index], items[index+1:]...)
		}
	}
	return items
}

func removePoolAttempt(checkpoint PoolCheckpoint, attempt AttemptKey) PoolCheckpoint {
	for index := range checkpoint.Attempts {
		if checkpoint.Attempts[index].Attempt == attempt {
			checkpoint.Attempts = append(checkpoint.Attempts[:index], checkpoint.Attempts[index+1:]...)
			break
		}
	}
	return checkpoint
}

func setPoolUnknown(checkpoint PoolCheckpoint, item PoolUnknownAttempt) PoolCheckpoint {
	for i := range checkpoint.Unknown {
		if checkpoint.Unknown[i].JobKey == item.JobKey {
			checkpoint.Unknown[i] = item
			return checkpoint
		}
	}
	checkpoint.Unknown = append(checkpoint.Unknown, item)
	return checkpoint
}

func setPoolQuarantine(checkpoint PoolCheckpoint, item PoolBoardQuarantine) PoolCheckpoint {
	for i := range checkpoint.Quarantined {
		if checkpoint.Quarantined[i].Board == item.Board {
			checkpoint.Quarantined[i] = item
			return checkpoint
		}
	}
	checkpoint.Quarantined = append(checkpoint.Quarantined, item)
	return checkpoint
}

func snapshotPool(results map[PoolJobKey]PoolJobResult, boards map[BoardKey]PoolBoardStatus, checkpoint PoolCheckpoint, unknown map[PoolJobKey]PoolUnknownAttempt, quarantined map[BoardKey]PoolBoardQuarantine) PoolSnapshot {
	snapshot := PoolSnapshot{Checkpoint: checkpoint.Clone()}
	for _, result := range results {
		snapshot.Jobs = append(snapshot.Jobs, result)
	}
	sort.Slice(snapshot.Jobs, func(i, j int) bool { return snapshot.Jobs[i].JobKey.String() < snapshot.Jobs[j].JobKey.String() })
	for _, board := range boards {
		snapshot.Boards = append(snapshot.Boards, board)
	}
	sort.Slice(snapshot.Boards, func(i, j int) bool { return snapshot.Boards[i].Board < snapshot.Boards[j].Board })
	for key, item := range unknown {
		if _, ok := results[key]; ok {
			snapshot.Checkpoint = setPoolUnknown(snapshot.Checkpoint, item)
		}
	}
	for _, item := range quarantined {
		snapshot.Checkpoint = setPoolQuarantine(snapshot.Checkpoint, item)
	}
	return snapshot
}
