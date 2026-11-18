/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	miSTerSessionWorkspaceMode = 0700
	miSTerStatusSeedBytes      = 16
	miSTerStatusPollDefault    = 100 * time.Millisecond
	miSTerFileLimit            = int64(64 << 20)
)

// MiSTerSessionInputs are attempt-local source locations and the config path
// verified from this exact RBF build's config/version metadata. Paths never
// participate in PreparedSession.PortableIdentity.
type MiSTerSessionInputs struct {
	FixturePaths     map[FixtureRole]string
	FixtureFiles     []MiSTerFixtureFile
	PackedCABPath    string
	NativeStatusPath string
	ProofDir         string
	RBFStem          string
	ExpectedCoreName string
	ExpectedRBFName  string
}

// MiSTerFixtureFile maps repeated prepared fixture roles (for example several
// split-ROM ZIPs) to local files by immutable role and SHA256.
type MiSTerFixtureFile struct {
	Role   FixtureRole
	SHA256 string
	Path   string
}

// MiSTerDriverConfig fixes the qualified Main identity and local ownership
// paths for one board. NativeStatusPath remains per-attempt input because the
// CFG suffix comes from the exact RBF build, not the current Go checkout.
type MiSTerDriverConfig struct {
	BoardKey   BoardKey
	HostName   string
	MainSHA256 string
	// MainINIPath is the qualified active Main INI path from the board
	// preflight. This driver supports only the default /media/fat/MiSTer.ini;
	// alternate FPGA-selected INI profiles are rejected before board mutation.
	MainINIPath         string
	LocalStateDir       string
	WorkspaceDir        string
	RestoreFiles        []string
	RestoreMRAPath      string
	RestoreRBFPath      string
	CommandTimeout      time.Duration
	LoadTimeout         time.Duration
	CaptureTimeout      time.Duration
	CleanupTimeout      time.Duration
	PollInterval        time.Duration
	MaxHoldMS           uint32
	ExpectedBridgeCount int
}

type miSTerOwnedRemoteFile struct {
	Path    string `json:"path"`
	SHA256  string `json:"sha256"`
	Owned   bool   `json:"owned"`
	Pending bool   `json:"pending,omitempty"`
}

type miSTerBoardLedger struct {
	Version                  uint32                         `json:"version"`
	Board                    BoardKey                       `json:"board"`
	SessionID                string                         `json:"session_id"`
	Nonce                    string                         `json:"nonce"`
	State                    string                         `json:"state"`
	Reason                   string                         `json:"reason,omitempty"`
	BeforePID                int                            `json:"before_pid"`
	Before                   MiSTerBoardSnapshot            `json:"before_state"`
	OriginalRBFPath          string                         `json:"original_rbf_path"`
	OriginalRBFArgv          string                         `json:"original_rbf_argv,omitempty"`
	OriginalRBFHash          string                         `json:"original_rbf_sha256"`
	OriginalLoaderKind       string                         `json:"original_loader_kind,omitempty"`
	OriginalMRAPath          string                         `json:"original_mra_path"`
	OriginalMRAHash          string                         `json:"original_mra_sha256"`
	OriginalMainConfigPath   string                         `json:"original_main_config_path"`
	OriginalMainConfigExists bool                           `json:"original_main_config_exists"`
	OriginalMainConfigHash   string                         `json:"original_main_config_sha256,omitempty"`
	OriginalMainPath         string                         `json:"original_main_path"`
	OriginalMainHash         string                         `json:"original_main_sha256"`
	ProgrammedPID            int                            `json:"programmed_pid,omitempty"`
	OriginalProgramWitnesses []miSTerOriginalProgramWitness `json:"original_program_witnesses,omitempty"`
	ExpectedRBFArgv          string                         `json:"expected_rbf_argv,omitempty"`
	ExpectedMRAArgv          string                         `json:"expected_mra_argv,omitempty"`
	SessionStarted           bool                           `json:"session_started,omitempty"`
	NVRAMPath                string                         `json:"nvram_path,omitempty"`
	NVRAMSeedSHA256          string                         `json:"nvram_seed_sha256,omitempty"`
	Backups                  []miSTerFileBackup             `json:"backups,omitempty"`
	StatusPath               string                         `json:"status_path"`
	RemoteLock               string                         `json:"remote_lock"`
	RemoteLockSHA            string                         `json:"remote_lock_sha256"`
	BackupDir                string                         `json:"backup_dir"`
	StagingRoot              string                         `json:"staging_root,omitempty"`
	StagingRootCreated       bool                           `json:"staging_root_created,omitempty"`
	ScreenshotDir            string                         `json:"screenshot_dir,omitempty"`
	OwnedDirs                []string                       `json:"owned_dirs,omitempty"`
	NativeStatusSeedSHA256   string                         `json:"native_status_seed_sha256,omitempty"`
	OwnedFiles               []miSTerOwnedRemoteFile        `json:"owned_files,omitempty"`
}

func cloneMiSTerBoardSnapshot(value MiSTerBoardSnapshot) MiSTerBoardSnapshot {
	states := value.BridgeStates
	value.BridgeStates = make(map[string]string, len(states))
	for key, state := range states {
		value.BridgeStates[key] = state
	}
	return value
}

type miSTerOriginalProgramWitness struct {
	RecoveryID         string              `json:"recovery_id"`
	ReceiptPath        string              `json:"receipt_path"`
	EvidencePath       string              `json:"evidence_path,omitempty"`
	ExpectedPID        int                 `json:"expected_pid"`
	ExpectedSnapshot   MiSTerBoardSnapshot `json:"expected_snapshot"`
	ExpectedMainPath   string              `json:"expected_main_path"`
	ExpectedMainSHA256 string              `json:"expected_main_sha256"`
	ExpectedRBFArgv    string              `json:"expected_rbf_argv"`
	ExpectedMRAArgv    string              `json:"expected_mra_argv"`
	OriginalRBFPath    string              `json:"original_rbf_path"`
	OriginalRBFHash    string              `json:"original_rbf_sha256"`
	OriginalMRAPath    string              `json:"original_mra_path,omitempty"`
	OriginalMRAHash    string              `json:"original_mra_sha256,omitempty"`
	ReceiptRawBase64   string              `json:"receipt_raw_base64,omitempty"`
	ReceiptSHA256      string              `json:"receipt_sha256,omitempty"`
	ReceiptReason      string              `json:"receipt_reason,omitempty"`
	ReceiptSuccess     bool                `json:"receipt_success,omitempty"`
	FPGAGeneration     uint32              `json:"fpga_generation,omitempty"`
	FullRBFWitness     bool                `json:"full_rbf_witness,omitempty"`
}

type miSTerFileBackup struct {
	Path   string `json:"path"`
	Exists bool   `json:"exists"`
	SHA256 string `json:"sha256,omitempty"`
	Local  string `json:"local,omitempty"`
}

type MiSTerSessionDriver struct {
	Config MiSTerDriverConfig
	Remote MiSTerRemote
	Inputs MiSTerSessionInputs
	Now    func() time.Time
	Sleep  func(context.Context, time.Duration) error

	// ledgerStageHook is a deterministic fault-injection seam used by tests.
	// Production leaves it nil; it never affects the remote transport.
	ledgerStageHook func(string, string) error

	mu         sync.Mutex
	active     *miSTerActiveSession
	lockFile   *os.File
	lockPath   string
	ledgerPath string
}

type miSTerActiveSession struct {
	key                  AttemptKey
	prepared             PreparedSession
	inputs               MiSTerSessionInputs
	cancel               context.CancelFunc
	done                 chan struct{}
	noMutation           bool
	remoteLeaseAttempted bool
	remoteLeaseAcquired  bool
	remoteLeaseOwned     bool
	loaded               bool
	loadSent             bool
	started              bool
	complete             bool
	ledger               miSTerBoardLedger
	backups              []miSTerFileBackup
	statusPath           string
	cabStatusPath        string
	manifestPath         string
	expectedRBF          string
	expectedMRA          string
	cleanupErr           error
}

// Capture implements SessionDriver with a private workspace and strict
// per-attempt ownership. All hardware operations pass through Remote.
func (d *MiSTerSessionDriver) Capture(ctx context.Context, key AttemptKey, prepared PreparedSession) (capture SessionCapture, runErr error) {
	return d.CapturePrepared(ctx, key, prepared, d.Inputs)
}

// CapturePrepared is the transport entry point until the shared coordinator
// carries attempt-local file paths. It retains the SessionDriver envelope and
// never mutates PreparedSession or coordinator-owned data.
func (d *MiSTerSessionDriver) CapturePrepared(ctx context.Context, key AttemptKey, prepared PreparedSession, inputs MiSTerSessionInputs) (capture SessionCapture, runErr error) {
	prepared, err := d.validatePreparedAttempt(key, prepared, inputs)
	if err != nil {
		return capture, fmt.Errorf("%w: %v", ErrCaptureNotStarted, err)
	}
	before, err := d.Remote.Probe(ctx)
	if err != nil {
		return capture, fmt.Errorf("%w: fresh MiSTer state guard: %v", ErrCaptureNotStarted, err)
	}
	if err := d.validateSnapshot(before); err != nil {
		return capture, fmt.Errorf("%w: %v", ErrCaptureNotStarted, err)
	}
	originalIdentity := miSTerBoardLedger{Before: before}
	if err = d.pinOriginalLoaderAssets(ctx, &originalIdentity); err != nil {
		return capture, fmt.Errorf("%w: pin original loader assets: %v", ErrCaptureNotStarted, err)
	}
	originalIdentity.OriginalMainConfigPath = d.Config.MainINIPath
	if err = d.pinOriginalMainExecutable(ctx, &originalIdentity); err != nil {
		return capture, fmt.Errorf("%w: pin original Main restart target: %v", ErrCaptureNotStarted, err)
	}
	lock, lockPath, ledgerPath, err := d.acquireAfterProbe(before)
	if err != nil {
		return capture, fmt.Errorf("%w: %v", ErrCaptureNotStarted, err)
	}
	workspace, err := os.MkdirTemp(d.Config.WorkspaceDir, "mister-"+key.SessionID+"-")
	if err != nil {
		_ = syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
		_ = lock.Close()
		return capture, fmt.Errorf("%w: create private workspace: %v", ErrCaptureNotStarted, err)
	}
	if err = os.Chmod(workspace, miSTerSessionWorkspaceMode); err != nil {
		_ = syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
		_ = lock.Close()
		return capture, fmt.Errorf("%w: secure private workspace: %v", ErrCaptureNotStarted, err)
	}
	commandCtx, cancel := context.WithCancel(ctx)
	active := &miSTerActiveSession{key: key, prepared: prepared, inputs: inputs, cancel: cancel, done: make(chan struct{}),
		noMutation: true,
		statusPath: "/tmp/jtframe-capture-" + key.SessionID + ".json", cabStatusPath: "/tmp/jtframe-cab-" + key.SessionID + ".json",
		manifestPath: "/tmp/jtframe-capture-" + key.SessionID + ".manifest.json"}
	active.ledger = miSTerBoardLedger{Version: 1, Board: key.Board, SessionID: key.SessionID, Nonce: key.Nonce,
		State: "preparing", BeforePID: before.MainPID, Before: before, StatusPath: active.statusPath,
		OriginalRBFPath: originalIdentity.OriginalRBFPath, OriginalRBFArgv: originalIdentity.OriginalRBFArgv,
		OriginalRBFHash: originalIdentity.OriginalRBFHash, OriginalLoaderKind: originalIdentity.OriginalLoaderKind,
		OriginalMRAPath: originalIdentity.OriginalMRAPath, OriginalMRAHash: originalIdentity.OriginalMRAHash,
		OriginalMainConfigPath:   originalIdentity.OriginalMainConfigPath,
		OriginalMainConfigExists: originalIdentity.OriginalMainConfigExists,
		OriginalMainConfigHash:   originalIdentity.OriginalMainConfigHash,
		OriginalMainPath:         originalIdentity.OriginalMainPath,
		OriginalMainHash:         originalIdentity.OriginalMainHash,
		BackupDir:                filepath.Join(workspace, "backup")}
	capture = SessionCapture{Key: key, Workspace: workspace, Cleanup: SessionCleanup{Required: true}}
	d.mu.Lock()
	d.active, d.lockFile, d.lockPath, d.ledgerPath = active, lock, lockPath, ledgerPath
	d.mu.Unlock()
	defer func() {
		if capture.Workspace == "" {
			capture.Workspace = workspace
		}
		capture.HostName = before.HostName
		capture.WorkspaceRoot = d.Config.WorkspaceDir
		cancel()
		cleanupCtx, cleanupCancel := context.WithTimeout(context.Background(), d.Config.CleanupTimeout)
		defer cleanupCancel()
		cleanupErr := d.cleanupAttempt(cleanupCtx, active, before, workspace)
		active.cleanupErr = cleanupErr
		if cleanupErr != nil {
			capture.Cleanup = SessionCleanup{Required: true, Confirmed: false, Message: cleanupErr.Error()}
			quarantineState := "quarantined"
			if active.noMutation && active.remoteLeaseAttempted {
				if active.remoteLeaseAcquired {
					quarantineState = "lease_only_quarantined"
				} else {
					quarantineState = "lease_claim_unknown"
				}
			}
			if ledgerErr := d.writeLedger(active.ledger, quarantineState, cleanupErr.Error()); ledgerErr != nil {
				cleanupErr = fmt.Errorf("%w; quarantine ledger durability failed: %v", cleanupErr, ledgerErr)
				active.cleanupErr = cleanupErr
				capture.Cleanup.Message = cleanupErr.Error()
			}
			if runErr == nil {
				runErr = fmt.Errorf("capture completed but board cleanup is unconfirmed: %w", cleanupErr)
			}
		} else {
			if removeErr := os.Remove(ledgerPath); removeErr != nil && !os.IsNotExist(removeErr) {
				cleanupErr = fmt.Errorf("remove completed session ledger: %w", removeErr)
			} else if syncErr := syncDirectory(d.Config.LocalStateDir); syncErr != nil {
				cleanupErr = fmt.Errorf("sync completed session ledger removal: %w", syncErr)
			}
			if cleanupErr != nil {
				active.cleanupErr = cleanupErr
				capture.Cleanup = SessionCleanup{Required: true, Confirmed: false, Message: cleanupErr.Error()}
				quarantineState := "quarantined"
				if active.noMutation && active.remoteLeaseAttempted {
					if active.remoteLeaseAcquired {
						quarantineState = "lease_only_quarantined"
					} else {
						quarantineState = "lease_claim_unknown"
					}
				}
				if ledgerErr := d.writeLedger(active.ledger, quarantineState, cleanupErr.Error()); ledgerErr != nil {
					cleanupErr = fmt.Errorf("%w; quarantine ledger durability failed: %v", cleanupErr, ledgerErr)
					active.cleanupErr = cleanupErr
					capture.Cleanup.Message = cleanupErr.Error()
				}
				if runErr == nil {
					runErr = fmt.Errorf("capture completed but cleanup journal is unconfirmed: %w", cleanupErr)
				}
			} else {
				capture.Cleanup = SessionCleanup{Required: false, Confirmed: true}
				d.releaseLock()
			}
		}
		d.mu.Lock()
		d.active = nil
		close(active.done)
		d.mu.Unlock()
	}()
	if err = d.writeLedger(active.ledger, "preparing", ""); err != nil {
		return capture, err
	}
	fresh, err := d.Remote.Probe(commandCtx)
	if err != nil || !sameMiSTerSnapshot(before, fresh) {
		if err == nil {
			err = fmt.Errorf("board state changed between guard and lock")
		}
		return capture, err
	}
	remoteLockPath := "/tmp/jtframe-regression-board-" + string(d.Config.BoardKey) + ".lock"
	lockPayload, _ := json.Marshal(struct {
		Board     BoardKey `json:"board"`
		SessionID string   `json:"session_id"`
		Nonce     string   `json:"nonce"`
	}{key.Board, key.SessionID, key.Nonce})
	active.ledger.RemoteLock = remoteLockPath
	active.ledger.RemoteLockSHA = digestBytes(lockPayload)
	if err = d.writeLedger(active.ledger, "lock_pending", ""); err != nil {
		return capture, err
	}
	active.remoteLeaseAttempted = true
	if err = d.Remote.CreateExclusive(commandCtx, remoteLockPath, lockPayload); err != nil {
		return capture, fmt.Errorf("acquire unique remote board lock: %w", err)
	}
	active.remoteLeaseAcquired = true
	active.remoteLeaseOwned = true
	if err = d.writeLedger(active.ledger, "locked", ""); err != nil {
		return capture, err
	}
	claimed, err := d.Remote.Probe(commandCtx)
	if err != nil {
		return capture, fmt.Errorf("post-lease MiSTer state probe: %w", err)
	}
	if !sameMiSTerSnapshot(before, claimed) {
		return capture, fmt.Errorf("board state changed between the admission probe and exclusive lease claim")
	}
	if err = d.verifyOriginalLoaderAssets(commandCtx, active.ledger); err != nil {
		return capture, fmt.Errorf("original loader assets changed before backup: %w", err)
	}
	if err = d.verifyOriginalMainConfigPreimage(commandCtx, active.ledger); err != nil {
		return capture, err
	}
	backups, err := d.backupFiles(commandCtx, active, inputs)
	if err != nil {
		return capture, err
	}
	active.backups = backups
	active.ledger.Backups = append([]miSTerFileBackup(nil), backups...)
	if err = d.checkPinnedMainConfigBackup(backups, active.ledger); err != nil {
		return capture, err
	}
	if err = d.writeLedger(active.ledger, "backed_up", ""); err != nil {
		return capture, err
	}
	if err = d.stageAndRun(commandCtx, active, workspace); err != nil {
		return capture, err
	}
	result, err := d.collectCapture(commandCtx, active, workspace)
	if err != nil {
		return capture, err
	}
	capture = result
	return capture, nil
}

// ValidatePreparedAttempt runs all local driver, immutable session, attempt,
// and runtime-input checks that CapturePrepared requires before its first
// Remote call. It may initialize local clock defaults and create/check the
// driver's private state/workspace directories through validateConfig. It
// never calls Remote or mutates the caller's session or input bundle.
func (d *MiSTerSessionDriver) ValidatePreparedAttempt(key AttemptKey, prepared PreparedSession, inputs MiSTerSessionInputs) error {
	_, err := d.validatePreparedAttempt(key, prepared, inputs)
	return err
}

func (d *MiSTerSessionDriver) validatePreparedAttempt(key AttemptKey, prepared PreparedSession, inputs MiSTerSessionInputs) (PreparedSession, error) {
	if d == nil {
		return PreparedSession{}, fmt.Errorf("MiSTer driver is nil")
	}
	if err := d.validateConfig(); err != nil {
		return PreparedSession{}, err
	}
	if err := prepared.Validate(); err != nil {
		return PreparedSession{}, err
	}
	if key.Board != d.Config.BoardKey || !validCaptureSessionID(key.SessionID) || !validAttemptNonce(key.Nonce) {
		return PreparedSession{}, fmt.Errorf("attempt does not identify this MiSTer board")
	}
	prepared = prepared.Clone()
	if err := validateMiSTerInputs(prepared, &inputs); err != nil {
		return PreparedSession{}, err
	}
	storageRoot, err := miSTerStorageRootFromStatusPath(inputs.NativeStatusPath)
	if err != nil || d.Config.MainINIPath != path.Join(storageRoot, "MiSTer.ini") {
		return PreparedSession{}, fmt.Errorf("driver requires the qualified default Main INI path; alternate INI selection is unsupported")
	}
	d.mu.Lock()
	busy := d.active != nil || d.lockFile != nil
	d.mu.Unlock()
	if busy {
		return PreparedSession{}, fmt.Errorf("MiSTer board already has an active or quarantined session")
	}
	return prepared, nil
}

// Cancel interrupts the in-flight SSH operation and waits for Capture's
// independent bounded CAB stop, restore and quarantine path to finish.
func (d *MiSTerSessionDriver) Cancel(ctx context.Context, key AttemptKey) error {
	d.mu.Lock()
	active := d.active
	if active == nil || active.key != key {
		d.mu.Unlock()
		return fmt.Errorf("no matching active MiSTer attempt")
	}
	active.cancel()
	d.mu.Unlock()
	cleanupCtx, cancel := context.WithTimeout(context.Background(), d.Config.CleanupTimeout)
	defer cancel()
	select {
	case <-active.done:
		return active.cleanupErr
	case <-cleanupCtx.Done():
		return fmt.Errorf("MiSTer cancellation cleanup timed out; board remains quarantined")
	case <-ctx.Done():
		return fmt.Errorf("caller stopped waiting; independent cleanup continues")
	}
}

// Reconcile clears only a persisted quarantine after an observed full Main
// program and the explicit fresh Main recovery receipt. A ping, process
// restart, or old session status alone cannot release the board.
func (d *MiSTerSessionDriver) Reconcile(ctx context.Context, key AttemptKey) (SessionCleanup, error) {
	if err := d.validateConfig(); err != nil {
		return SessionCleanup{}, err
	}
	if key.Board != d.Config.BoardKey {
		return SessionCleanup{}, fmt.Errorf("reconcile attempt belongs to another board")
	}
	d.mu.Lock()
	lock, lockPath, ledgerPath := d.lockFile, d.lockPath, d.ledgerPath
	d.mu.Unlock()
	if lock == nil {
		var err error
		lock, lockPath, ledgerPath, err = d.acquireLock()
		if err != nil {
			return SessionCleanup{}, err
		}
		d.mu.Lock()
		d.lockFile, d.lockPath, d.ledgerPath = lock, lockPath, ledgerPath
		d.mu.Unlock()
	}
	ledger, err := readMiSTerLedger(ledgerPath)
	if err != nil || ledger.Board != key.Board || ledger.SessionID != key.SessionID || ledger.Nonce != key.Nonce {
		return SessionCleanup{}, fmt.Errorf("no matching quarantined MiSTer attempt")
	}
	if leaseOnlyMiSTerLedger(ledger) {
		return d.reconcileLeaseOnly(ctx, ledger, ledgerPath)
	}
	if !reconcilableMiSTerLedgerState(ledger.State) {
		return SessionCleanup{}, fmt.Errorf("no matching quarantined MiSTer attempt")
	}
	if err = d.writeLedger(ledger, "quarantined", "reconciliation resumed"); err != nil {
		return SessionCleanup{}, fmt.Errorf("persist reconciliation ownership: %w", err)
	}
	backupDir, err := d.validLedgerBackupDir(ledger)
	if err != nil {
		return SessionCleanup{}, err
	}
	if ledger.ExpectedRBFArgv == "" || ledger.ExpectedMRAArgv == "" {
		return SessionCleanup{}, fmt.Errorf("quarantine ledger lacks the exact staged candidate identity")
	}
	restoreArg, err := originalLoaderCommand(ledger)
	if err != nil {
		return SessionCleanup{}, fmt.Errorf("quarantine has no verified original loader target: %w", err)
	}
	if err = d.verifyQuarantineLeaseAndStagedFiles(ctx, ledger); err != nil {
		return SessionCleanup{}, fmt.Errorf("quarantine lease or staged candidate changed: %w", err)
	}
	if err = d.verifyOriginalLoaderAssets(ctx, ledger); err != nil {
		return SessionCleanup{}, fmt.Errorf("original loader assets cannot be safely restored: %w", err)
	}
	snapshot, err := d.Remote.Probe(ctx)
	if err != nil {
		return SessionCleanup{}, fmt.Errorf("probe board before recovery reload: %w", err)
	}
	if !d.validQuarantineCurrentCore(snapshot, ledger) {
		return SessionCleanup{}, fmt.Errorf("current board state is outside the quarantined attempt's original/candidate cores")
	}
	if err = d.Remote.WriteFIFO(ctx, []byte("load_core "+ledger.ExpectedMRAArgv+"\n"), d.Config.CommandTimeout); err != nil {
		return SessionCleanup{}, fmt.Errorf("normal full-RBF recovery load was not confirmed; quarantine retained: %w", err)
	}
	loaded, err := d.waitForQuarantineFullLoad(ctx, snapshot, ledger)
	if err != nil {
		return SessionCleanup{}, fmt.Errorf("normal full-RBF recovery load was not confirmed; quarantine retained: %w", err)
	}
	ledger.ProgrammedPID = loaded.MainPID
	if err = d.writeLedger(ledger, "recovery_candidate_loaded", ""); err != nil {
		return SessionCleanup{}, fmt.Errorf("persist recovery candidate PID: %w", err)
	}
	if _, err = d.requestCaptureRecovery(ctx, loaded); err != nil {
		return SessionCleanup{}, fmt.Errorf("explicit Main capture recovery is unconfirmed; quarantine retained: %w", err)
	}
	// Main consumes configuration and persistence state during load_core. Restore
	// the exact pre-attempt files before programming the original core.
	if err = d.restoreBackups(ctx, ledger.Backups); err != nil {
		return SessionCleanup{}, fmt.Errorf("reconcile restoration incomplete: %w", err)
	}
	if err = d.verifyOriginalLoaderAssets(ctx, ledger); err != nil {
		return SessionCleanup{}, fmt.Errorf("original loader assets changed before restore: %w", err)
	}
	if err = d.writeLedger(ledger, "restoring_original", ""); err != nil {
		return SessionCleanup{}, fmt.Errorf("persist original restore intent: %w", err)
	}
	if err = d.Remote.WriteFIFO(ctx, []byte("load_core "+restoreArg+"\n"), d.Config.CommandTimeout); err != nil {
		return SessionCleanup{}, fmt.Errorf("restore original core during reconcile: %w", err)
	}
	original, err := d.waitForOriginalSnapshot(ctx, ledger)
	if err != nil {
		return SessionCleanup{}, err
	}
	if err = d.verifyOriginalLoaderAssets(ctx, ledger); err != nil {
		return SessionCleanup{}, fmt.Errorf("original loader assets changed after restore: %w", err)
	}
	if err = d.requestOriginalProgramWitness(ctx, &ledger, original); err != nil {
		_ = d.writeLedger(ledger, "quarantined", err.Error())
		return SessionCleanup{}, fmt.Errorf("original full-RBF programming witness is unconfirmed; quarantine retained: %w", err)
	}
	var restoreFailures []string
	for _, owned := range ledger.OwnedFiles {
		if owned.Owned && owned.SHA256 != "" {
			if removeErr := d.Remote.RemoveOwned(ctx, owned.Path, owned.SHA256); removeErr != nil {
				restoreFailures = append(restoreFailures, "remove owned "+path.Base(owned.Path)+": "+removeErr.Error())
			}
		}
	}
	if len(restoreFailures) != 0 {
		return SessionCleanup{}, fmt.Errorf("reconcile cleanup incomplete: %s", strings.Join(restoreFailures, "; "))
	}
	if err = validateMiSTerOwnedDirs(ledger); err != nil {
		return SessionCleanup{}, err
	}
	directories := append([]string(nil), ledger.OwnedDirs...)
	stagingRootRecorded := false
	for _, directory := range directories {
		if directory == ledger.StagingRoot {
			stagingRootRecorded = true
			break
		}
	}
	if ledger.StagingRootCreated && ledger.StagingRoot != "" && !stagingRootRecorded {
		directories = append(directories, ledger.StagingRoot)
	}
	for _, directory := range directories {
		if removeErr := d.Remote.RemoveEmptyDir(ctx, directory); removeErr != nil {
			restoreFailures = append(restoreFailures, "remove owned empty directory "+path.Base(directory)+": "+removeErr.Error())
		}
	}
	if len(restoreFailures) != 0 {
		return SessionCleanup{}, fmt.Errorf("reconcile cleanup incomplete: %s", strings.Join(restoreFailures, "; "))
	}
	if err = removeSessionWorkspace(d.Config.WorkspaceDir, filepath.Dir(backupDir)); err != nil {
		return SessionCleanup{}, err
	}
	if err = d.Remote.RemoveOwned(ctx, ledger.RemoteLock, ledger.RemoteLockSHA); err != nil {
		return SessionCleanup{}, err
	}
	if err = os.Remove(ledgerPath); err != nil && !os.IsNotExist(err) {
		return SessionCleanup{}, err
	}
	d.releaseLock()
	return SessionCleanup{Confirmed: true}, nil
}

func reconcilableMiSTerLedgerState(state string) bool {
	switch state {
	case "quarantined", "restoring_original", "original_program_witness_pending", "original_program_receipt", "original_program_evidence_pending", "original_program_verified", "recovery_candidate_loaded":
		return true
	default:
		return false
	}
}

func validateMiSTerOwnedDirs(ledger miSTerBoardLedger) error {
	expectedRoot := "/media/fat/_Arcade/jtreg-" + ledger.SessionID + "-" + ledger.Nonce
	for _, directory := range ledger.OwnedDirs {
		if validMiSTerRemotePath(directory) != nil ||
			!(ledger.StagingRootCreated && directory == expectedRoot && directory == ledger.StagingRoot) &&
				!(directory == ledger.ScreenshotDir && strings.HasPrefix(directory, "/media/fat/screenshots/") && safeComponent(path.Base(directory))) {
			return fmt.Errorf("quarantine ledger contains an unowned directory path")
		}
	}
	if ledger.StagingRootCreated && ledger.StagingRoot != expectedRoot {
		return fmt.Errorf("quarantine ledger staging directory does not match its attempt")
	}
	return nil
}

func leaseOnlyMiSTerLedger(ledger miSTerBoardLedger) bool {
	if ledger.State != "lock_pending" && ledger.State != "locked" && ledger.State != "backed_up" &&
		ledger.State != "lease_only_quarantined" && ledger.State != "lease_claim_unknown" {
		return false
	}
	expectedLock := "/tmp/jtframe-regression-board-" + string(ledger.Board) + ".lock"
	return ledger.RemoteLock == expectedLock && isSHA256Hex(ledger.RemoteLockSHA) && ledger.StagingRoot == "" &&
		ledger.ExpectedRBFArgv == "" && ledger.ExpectedMRAArgv == "" && len(ledger.OwnedFiles) == 0 &&
		!ledger.SessionStarted && ledger.ProgrammedPID == 0 && ledger.NVRAMPath == "" && ledger.NativeStatusSeedSHA256 == ""
}

func (d *MiSTerSessionDriver) reconcileLeaseOnly(ctx context.Context, ledger miSTerBoardLedger, ledgerPath string) (SessionCleanup, error) {
	if err := d.writeLedger(ledger, "lease_only_quarantined", "releasing confirmed pre-mutation lease only"); err != nil {
		return SessionCleanup{}, fmt.Errorf("persist lease-only reconciliation: %w", err)
	}
	var backupDir string
	if ledger.BackupDir != "" {
		if _, err := os.Lstat(ledger.BackupDir); err == nil {
			var backupErr error
			backupDir, backupErr = d.validLedgerBackupDir(ledger)
			if backupErr != nil {
				return SessionCleanup{}, backupErr
			}
		} else if !os.IsNotExist(err) {
			return SessionCleanup{}, err
		}
	}
	if err := d.Remote.RemoveOwned(ctx, ledger.RemoteLock, ledger.RemoteLockSHA); err != nil {
		return SessionCleanup{}, fmt.Errorf("release confirmed lease-only quarantine: %w", err)
	}
	if backupDir != "" {
		if err := os.RemoveAll(backupDir); err != nil {
			return SessionCleanup{}, fmt.Errorf("remove lease-only local backups: %w", err)
		}
	}
	if err := os.Remove(ledgerPath); err != nil && !os.IsNotExist(err) {
		return SessionCleanup{}, err
	}
	if err := syncDirectory(d.Config.LocalStateDir); err != nil {
		return SessionCleanup{}, err
	}
	d.releaseLock()
	return SessionCleanup{Confirmed: true}, nil
}

func (d *MiSTerSessionDriver) requestOriginalProgramWitness(ctx context.Context, ledger *miSTerBoardLedger, expected MiSTerBoardSnapshot) error {
	if ledger == nil || expected.MainPID <= 0 || expected.MainPID == ledger.BeforePID || expected.MainPID == ledger.ProgrammedPID ||
		expected.MainExePath != ledger.OriginalMainPath || expected.MainSHA256 != ledger.OriginalMainHash || !originalLoaderMatches(expected, *ledger) ||
		expected.FPGAState != "operating" || !bridgesEnabled(expected.BridgeStates, d.Config.ExpectedBridgeCount) {
		return fmt.Errorf("original program event snapshot is not the exact newly loaded process")
	}
	var witness miSTerOriginalProgramWitness
	evidence, err := d.requestCaptureRecoveryEvidence(ctx, expected, func(id, receiptPath string) error {
		witness = miSTerOriginalProgramWitness{RecoveryID: id, ReceiptPath: receiptPath, ExpectedPID: expected.MainPID,
			ExpectedSnapshot: cloneMiSTerBoardSnapshot(expected),
			ExpectedMainPath: expected.MainExePath, ExpectedMainSHA256: expected.MainSHA256, ExpectedRBFArgv: expected.ArgvRBF,
			ExpectedMRAArgv: expected.ArgvMRA, OriginalRBFPath: ledger.OriginalRBFPath, OriginalRBFHash: ledger.OriginalRBFHash,
			OriginalMRAPath: ledger.OriginalMRAPath, OriginalMRAHash: ledger.OriginalMRAHash}
		ledger.OriginalProgramWitnesses = append(ledger.OriginalProgramWitnesses, witness)
		return d.writeLedger(*ledger, "original_program_witness_pending", "")
	})
	if len(ledger.OriginalProgramWitnesses) > 0 {
		idx := len(ledger.OriginalProgramWitnesses) - 1
		if len(evidence.Raw) > 0 {
			ledger.OriginalProgramWitnesses[idx].ReceiptRawBase64 = base64.StdEncoding.EncodeToString(evidence.Raw)
			ledger.OriginalProgramWitnesses[idx].ReceiptSHA256 = digestBytes(evidence.Raw)
		}
		if evidence.Receipt.RecoveryID != "" {
			ledger.OriginalProgramWitnesses[idx].ReceiptReason = evidence.Receipt.Reason
			ledger.OriginalProgramWitnesses[idx].ReceiptSuccess = evidence.Receipt.Success
			ledger.OriginalProgramWitnesses[idx].FPGAGeneration = evidence.Receipt.FPGAGeneration
			ledger.OriginalProgramWitnesses[idx].FullRBFWitness = evidence.Receipt.FullRBFWitness
		}
		if len(evidence.Raw) > 0 {
			if persistErr := d.writeLedger(*ledger, "original_program_receipt", ""); persistErr != nil && err == nil {
				err = fmt.Errorf("persist original program receipt: %w", persistErr)
			}
		}
	}
	if err != nil {
		return err
	}
	receipt := evidence.Receipt
	if receipt.FPGAGeneration == 0 || !receipt.FullRBFWitness {
		return fmt.Errorf("original program receipt lacks a nonzero generation or full-RBF witness")
	}
	if !receipt.Success && (receipt.Reason != "caps_invalid" || receipt.CAPSValid) {
		return fmt.Errorf("original program failure is not the permitted unsupported-core CAPS result")
	}
	if err = d.persistOriginalProgramWitnessEvidence(ledger, len(ledger.OriginalProgramWitnesses)-1); err != nil {
		return fmt.Errorf("persist original program receipt evidence: %w", err)
	}
	if err = d.writeLedger(*ledger, "original_program_verified", ""); err != nil {
		return fmt.Errorf("persist verified original program witness: %w", err)
	}
	return nil
}

func (d *MiSTerSessionDriver) persistOriginalProgramWitnessEvidence(ledger *miSTerBoardLedger, index int) error {
	if index < 0 || index >= len(ledger.OriginalProgramWitnesses) {
		return fmt.Errorf("original program receipt evidence is missing")
	}
	witness := &ledger.OriginalProgramWitnesses[index]
	raw, err := base64.StdEncoding.DecodeString(witness.ReceiptRawBase64)
	if err != nil || len(raw) == 0 || !isSHA256Hex(witness.ReceiptSHA256) || digestBytes(raw) != witness.ReceiptSHA256 {
		return fmt.Errorf("original program receipt evidence is incomplete or changed")
	}
	name := "mister-" + string(ledger.Board) + "-restore-witness-" + ledger.SessionID + "-" + ledger.Nonce + "-" + witness.RecoveryID + ".json"
	if !safeLocalComponent(name) {
		return fmt.Errorf("original program evidence filename is invalid")
	}
	witness.EvidencePath = filepath.Join(d.Config.LocalStateDir, name)
	if err = d.writeLedger(*ledger, "original_program_evidence_pending", ""); err != nil {
		return fmt.Errorf("persist original program evidence path: %w", err)
	}
	data, err := json.Marshal(*witness)
	if err != nil {
		return err
	}
	if _, err = os.Lstat(witness.EvidencePath); err == nil {
		return fmt.Errorf("original program evidence path already exists")
	} else if !os.IsNotExist(err) {
		return err
	}
	return atomicReplaceSynced(witness.EvidencePath, append(data, '\n'), nil)
}

func (d *MiSTerSessionDriver) validLedgerBackupDir(ledger miSTerBoardLedger) (string, error) {
	backupDir := filepath.Clean(ledger.BackupDir)
	if !filepath.IsAbs(backupDir) || filepath.Base(backupDir) != "backup" {
		return "", fmt.Errorf("quarantine backup directory path is invalid")
	}
	workspace := filepath.Dir(backupDir)
	relative, err := filepath.Rel(d.Config.WorkspaceDir, workspace)
	if err != nil || relative == "." || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) ||
		!safeLocalComponent(filepath.Base(workspace)) || !strings.HasPrefix(filepath.Base(workspace), "mister-"+ledger.SessionID+"-") {
		return "", fmt.Errorf("quarantine backup directory escapes the attempt workspace")
	}
	for _, directory := range []string{workspace, backupDir} {
		info, statErr := os.Lstat(directory)
		if statErr != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
			return "", fmt.Errorf("quarantine backup directory is missing or unsafe")
		}
	}
	return backupDir, nil
}

func (d *MiSTerSessionDriver) verifyQuarantineLeaseAndStagedFiles(ctx context.Context, ledger miSTerBoardLedger) error {
	if ledger.RemoteLock == "" || ledger.RemoteLockSHA == "" || validMiSTerRemotePath(ledger.RemoteLock) != nil {
		return fmt.Errorf("quarantine ledger has no valid owned remote lock")
	}
	lockHash, lockExists, err := d.Remote.Hash(ctx, ledger.RemoteLock)
	if err != nil || !lockExists || lockHash != ledger.RemoteLockSHA {
		return fmt.Errorf("remote board lock is missing or its bytes changed")
	}
	if validMiSTerRemotePath(ledger.ExpectedRBFArgv) != nil || validMiSTerRemotePath(ledger.ExpectedMRAArgv) != nil {
		return fmt.Errorf("staged candidate path is invalid")
	}
	var rbfSHA, mraSHA string
	var mraOwned bool
	for _, owned := range ledger.OwnedFiles {
		if owned.Path == ledger.ExpectedRBFArgv {
			rbfSHA = owned.SHA256
		}
		if owned.Path == ledger.ExpectedMRAArgv {
			mraSHA, mraOwned = owned.SHA256, owned.Owned
		}
	}
	if !isSHA256Hex(rbfSHA) || !isSHA256Hex(mraSHA) || !mraOwned {
		return fmt.Errorf("candidate RBF/MRA ownership hashes are absent")
	}
	for _, file := range []struct{ path, sha string }{{ledger.ExpectedRBFArgv, rbfSHA}, {ledger.ExpectedMRAArgv, mraSHA}} {
		actual, exists, hashErr := d.Remote.Hash(ctx, file.path)
		if hashErr != nil || !exists || actual != file.sha {
			return fmt.Errorf("staged candidate %s is missing or changed", path.Base(file.path))
		}
	}
	return nil
}

// CORENAME and RBFNAME come from Main's SetUARTMode cache and may lag a full
// load. The exact argv paths, Main identity, FPGA state and bridge states are
// the authoritative loader evidence; cached names remain diagnostic only.
func (d *MiSTerSessionDriver) validQuarantineCurrentCore(snapshot MiSTerBoardSnapshot, ledger miSTerBoardLedger) bool {
	if snapshot.MainPID <= 0 || snapshot.MainSHA256 != d.Config.MainSHA256 || snapshot.MainExePath != ledger.Before.MainExePath ||
		snapshot.FPGAState != "operating" || !bridgesEnabled(snapshot.BridgeStates, d.Config.ExpectedBridgeCount) {
		return false
	}
	candidate := snapshot.ArgvRBF == ledger.ExpectedRBFArgv && snapshot.ArgvMRA == ledger.ExpectedMRAArgv
	original := originalLoaderMatches(snapshot, ledger)
	return candidate || original
}

func (d *MiSTerSessionDriver) waitForQuarantineFullLoad(ctx context.Context, before MiSTerBoardSnapshot, ledger miSTerBoardLedger) (MiSTerBoardSnapshot, error) {
	deadline := d.Now().Add(d.Config.LoadTimeout)
	for {
		if err := ctx.Err(); err != nil {
			return MiSTerBoardSnapshot{}, err
		}
		snapshot, err := d.Remote.Probe(ctx)
		if err == nil && snapshot.MainPID != before.MainPID && snapshot.MainSHA256 == d.Config.MainSHA256 &&
			snapshot.MainExePath == ledger.Before.MainExePath && snapshot.ArgvRBF == ledger.ExpectedRBFArgv &&
			snapshot.ArgvMRA == ledger.ExpectedMRAArgv && snapshot.FPGAState == "operating" &&
			bridgesEnabled(snapshot.BridgeStates, d.Config.ExpectedBridgeCount) {
			return snapshot, nil
		}
		if d.Now().After(deadline) {
			return MiSTerBoardSnapshot{}, fmt.Errorf("new Main PID/RBF/MRA/bridge identity was not observed")
		}
		if err = d.Sleep(ctx, d.pollInterval()); err != nil {
			return MiSTerBoardSnapshot{}, err
		}
	}
}

func (d *MiSTerSessionDriver) Healthy(ctx context.Context) error {
	if err := d.validateConfig(); err != nil {
		return err
	}
	if _, err := os.Lstat(d.ledgerName()); err == nil {
		return fmt.Errorf("MiSTer board has a persisted quarantine ledger")
	} else if !os.IsNotExist(err) {
		return err
	}
	snapshot, err := d.Remote.Probe(ctx)
	if err != nil {
		return err
	}
	return d.validateSnapshot(snapshot)
}

// ValidateLocalConfig applies the same local driver checks used by Healthy and
// Capture without calling Remote. It may initialize the driver's default clock
// and create/check its private local state and workspace directories.
func (d *MiSTerSessionDriver) ValidateLocalConfig() error {
	return d.validateConfig()
}

func (d *MiSTerSessionDriver) validateConfig() error {
	if d.Remote == nil || d.Config.BoardKey == "" || !isSHA256Hex(d.Config.MainSHA256) || validMiSTerRemotePath(d.Config.MainINIPath) != nil ||
		d.Config.LocalStateDir == "" || d.Config.WorkspaceDir == "" || !filepath.IsAbs(d.Config.LocalStateDir) || !filepath.IsAbs(d.Config.WorkspaceDir) {
		return fmt.Errorf("MiSTer driver requires board, qualified Main hash, remote and absolute local state/workspace paths")
	}
	if d.Config.CommandTimeout <= 0 || d.Config.CommandTimeout > 2*time.Minute || d.Config.LoadTimeout <= 0 || d.Config.LoadTimeout > 5*time.Minute ||
		d.Config.CaptureTimeout <= 0 || d.Config.CaptureTimeout > 30*time.Minute || d.Config.CleanupTimeout <= 0 || d.Config.CleanupTimeout > 5*time.Minute ||
		d.Config.MaxHoldMS < capturePlanMinHoldMS || d.Config.MaxHoldMS > capturePlanMaxHoldMS || d.Config.ExpectedBridgeCount < 1 {
		return fmt.Errorf("MiSTer driver timeouts, capture hold or bridge count are invalid")
	}
	if d.Now == nil {
		d.Now = time.Now
	}
	if d.Sleep == nil {
		d.Sleep = contextSleep
	}
	if err := os.MkdirAll(d.Config.LocalStateDir, 0700); err != nil {
		return err
	}
	if err := os.MkdirAll(d.Config.WorkspaceDir, 0700); err != nil {
		return err
	}
	for _, directory := range []string{d.Config.LocalStateDir, d.Config.WorkspaceDir} {
		info, err := os.Lstat(directory)
		if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 || info.Mode().Perm()&0077 != 0 {
			return fmt.Errorf("MiSTer local state/workspace directory must be a private nonsymlink directory")
		}
	}
	return nil
}

func (d *MiSTerSessionDriver) validateSnapshot(snapshot MiSTerBoardSnapshot) error {
	if snapshot.MainPID <= 0 || snapshot.MainSHA256 != d.Config.MainSHA256 || snapshot.FPGAState != "operating" ||
		!bridgesEnabled(snapshot.BridgeStates, d.Config.ExpectedBridgeCount) {
		return fmt.Errorf("MiSTer Main/FPGA identity is not qualified")
	}
	return nil
}

func (d *MiSTerSessionDriver) pinOriginalLoaderAssets(ctx context.Context, ledger *miSTerBoardLedger) error {
	if ledger == nil {
		return fmt.Errorf("original loader identity ledger is nil")
	}
	if ledger.Before.ArgvRBF == "menu.rbf" && ledger.Before.ArgvMRA == "" {
		if (d.Config.RestoreRBFPath != "" && d.Config.RestoreRBFPath != "/media/fat/menu.rbf") || d.Config.RestoreMRAPath != "" {
			return fmt.Errorf("configured restoration paths do not match the exact MENU RBF-only startup")
		}
		ledger.OriginalLoaderKind = "menu-rbf"
		ledger.OriginalRBFArgv = "menu.rbf"
		ledger.OriginalRBFPath = "/media/fat/menu.rbf"
		ledger.OriginalMRAPath = ""
	} else {
		if ledger.Before.ArgvRBF == "" || ledger.Before.ArgvMRA == "" || validMiSTerRemotePath(ledger.Before.ArgvRBF) != nil || validMiSTerRemotePath(ledger.Before.ArgvMRA) != nil {
			return fmt.Errorf("current board has no supported exact loaded-core RBF/MRA argv; only exact menu.rbf RBF-only startup is additionally supported")
		}
		if (d.Config.RestoreRBFPath != "" && d.Config.RestoreRBFPath != ledger.Before.ArgvRBF) ||
			(d.Config.RestoreMRAPath != "" && d.Config.RestoreMRAPath != ledger.Before.ArgvMRA) {
			return fmt.Errorf("configured restoration paths differ from the observed original loaded-core argv")
		}
		ledger.OriginalLoaderKind = "mra"
		ledger.OriginalRBFArgv = ledger.Before.ArgvRBF
		ledger.OriginalRBFPath = ledger.Before.ArgvRBF
		ledger.OriginalMRAPath = ledger.Before.ArgvMRA
	}
	assets := []struct {
		name string
		path string
		set  func(string)
	}{{"RBF", ledger.OriginalRBFPath, func(value string) { ledger.OriginalRBFHash = value }}}
	if originalLoaderKind(*ledger) == "mra" {
		assets = append(assets, struct {
			name string
			path string
			set  func(string)
		}{"MRA", ledger.OriginalMRAPath, func(value string) { ledger.OriginalMRAHash = value }})
	}
	for _, asset := range assets {
		if err := validMiSTerRemotePath(asset.path); err != nil {
			return fmt.Errorf("original %s path is unavailable or unsafe", asset.name)
		}
		digest, exists, err := d.Remote.Hash(ctx, asset.path)
		if err != nil || !exists || !isSHA256Hex(digest) {
			return fmt.Errorf("original %s bytes are unavailable for identity pinning", asset.name)
		}
		asset.set(digest)
	}
	return nil
}

func (d *MiSTerSessionDriver) verifyOriginalLoaderAssets(ctx context.Context, ledger miSTerBoardLedger) error {
	if _, err := originalLoaderCommand(ledger); err != nil {
		return fmt.Errorf("original loader mode is absent or unsupported: %w", err)
	}
	assets := []struct {
		name   string
		path   string
		digest string
	}{{"RBF", ledger.OriginalRBFPath, ledger.OriginalRBFHash}}
	if originalLoaderKind(ledger) == "mra" {
		assets = append(assets, struct {
			name   string
			path   string
			digest string
		}{"MRA", ledger.OriginalMRAPath, ledger.OriginalMRAHash})
	}
	for _, asset := range assets {
		if validMiSTerRemotePath(asset.path) != nil || !isSHA256Hex(asset.digest) {
			return fmt.Errorf("original %s path/hash is missing from the durable ledger", asset.name)
		}
		actual, exists, err := d.Remote.Hash(ctx, asset.path)
		if err != nil || !exists || actual != asset.digest {
			return fmt.Errorf("original %s bytes at %s are missing or changed", asset.name, path.Base(asset.path))
		}
	}
	if validMiSTerRemotePath(ledger.OriginalMainPath) != nil || !isSHA256Hex(ledger.OriginalMainHash) {
		return fmt.Errorf("original Main executable identity is missing from the durable ledger")
	}
	resolved, exists, err := d.Remote.ResolvePath(ctx, ledger.OriginalMainPath)
	if err != nil || !exists || resolved != ledger.OriginalMainPath {
		return fmt.Errorf("original Main executable path is missing or no longer resolves identically")
	}
	actual, exists, err := d.Remote.Hash(ctx, ledger.OriginalMainPath)
	if err != nil || !exists || actual != ledger.OriginalMainHash {
		return fmt.Errorf("original Main executable bytes are missing or changed")
	}
	return nil
}

func configuredMiSTerMain(data []byte) (string, error) {
	const defaultName = "MiSTer"
	if len(data) > miSTerRemoteOutputLimit {
		return "", fmt.Errorf("original MiSTer INI exceeds the bounded parser size")
	}
	var values []string
	for _, raw := range strings.Split(string(data), "\n") {
		line := strings.TrimSuffix(raw, "\r")
		if comment := strings.IndexByte(line, ';'); comment >= 0 {
			line = line[:comment]
		}
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "[") || strings.HasPrefix(line, "+[") {
			continue
		}
		separator := strings.IndexAny(line, "= \t")
		if separator < 0 || !strings.EqualFold(strings.TrimSpace(line[:separator]), "MAIN") {
			continue
		}
		value := strings.TrimSpace(strings.TrimLeft(line[separator:], "= \t"))
		if value == "" || len(value) > 255 || strings.ContainsAny(value, "\r\n\x00") {
			return "", fmt.Errorf("original MiSTer INI contains an invalid MAIN value")
		}
		values = append(values, value)
	}
	if len(values) == 0 {
		return defaultName, nil
	}
	for _, value := range values[1:] {
		if value != values[0] {
			return "", fmt.Errorf("original MiSTer INI has ambiguous MAIN values across sections")
		}
	}
	return values[0], nil
}

func miSTerStorageRootFromStatusPath(statusPath string) (string, error) {
	if validMiSTerRemotePath(statusPath) != nil || path.Base(path.Dir(statusPath)) != "config" {
		return "", fmt.Errorf("native status path does not identify a supported MiSTer config directory")
	}
	root := path.Dir(path.Dir(statusPath))
	if root != "/media/fat" {
		return "", fmt.Errorf("only the qualified /media/fat storage root is supported")
	}
	return root, nil
}

func bridgesEnabled(states map[string]string, expected int) bool {
	if len(states) != expected {
		return false
	}
	for fullPath, state := range states {
		if !strings.HasPrefix(fullPath, "/sys/class/fpga_bridge/") || !strings.HasSuffix(fullPath, "/state") || state != "enabled" {
			return false
		}
	}
	return true
}

func sameMiSTerSnapshot(a, b MiSTerBoardSnapshot) bool {
	if a.MainPID != b.MainPID || a.HostName != b.HostName || a.MainSHA256 != b.MainSHA256 ||
		a.MainExePath != b.MainExePath || a.ArgvRBF != b.ArgvRBF || a.ArgvMRA != b.ArgvMRA || a.FPGAState != b.FPGAState || len(a.BridgeStates) != len(b.BridgeStates) {
		return false
	}
	for key, value := range a.BridgeStates {
		if b.BridgeStates[key] != value {
			return false
		}
	}
	return true
}

func (d *MiSTerSessionDriver) acquireAfterProbe(before MiSTerBoardSnapshot) (*os.File, string, string, error) {
	lock, lockPath, ledgerPath, err := d.acquireLock()
	if err != nil {
		return nil, "", "", err
	}
	if _, err = os.Lstat(ledgerPath); err == nil {
		_ = syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
		_ = lock.Close()
		return nil, "", "", fmt.Errorf("MiSTer board has a persisted quarantine ledger")
	} else if !os.IsNotExist(err) {
		_ = syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
		_ = lock.Close()
		return nil, "", "", err
	}
	return lock, lockPath, ledgerPath, nil
}

func (d *MiSTerSessionDriver) acquireLock() (*os.File, string, string, error) {
	key := string(d.Config.BoardKey)
	if !safeLocalComponent(key) {
		return nil, "", "", fmt.Errorf("board key is not a safe local component")
	}
	lockPath := filepath.Join(d.Config.LocalStateDir, "mister-"+key+".lock")
	ledgerPath := filepath.Join(d.Config.LocalStateDir, "mister-"+key+".ledger.json")
	file, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR|syscall.O_NOFOLLOW, 0600)
	if err != nil {
		return nil, "", "", err
	}
	if err = syscall.Flock(int(file.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		_ = file.Close()
		return nil, "", "", fmt.Errorf("MiSTer board lock is already owned")
	}
	return file, lockPath, ledgerPath, nil
}

func (d *MiSTerSessionDriver) releaseLock() {
	d.mu.Lock()
	file := d.lockFile
	d.lockFile, d.lockPath = nil, ""
	d.mu.Unlock()
	if file != nil {
		_ = syscall.Flock(int(file.Fd()), syscall.LOCK_UN)
		_ = file.Close()
	}
}

func (d *MiSTerSessionDriver) ledgerName() string {
	return filepath.Join(d.Config.LocalStateDir, "mister-"+string(d.Config.BoardKey)+".ledger.json")
}

func (d *MiSTerSessionDriver) writeLedger(ledger miSTerBoardLedger, state, reason string) error {
	ledger.State, ledger.Reason = state, reason
	data, err := json.Marshal(ledger)
	if err != nil {
		return err
	}
	path := d.ledgerName()
	return atomicReplaceSynced(path, append(data, '\n'), func(stage string) error {
		if d.ledgerStageHook == nil {
			return nil
		}
		return d.ledgerStageHook(state, stage)
	})
}

func atomicReplaceSynced(filename string, data []byte, stageHook func(string) error) error {
	directory := filepath.Dir(filename)
	temporary := filename + ".tmp-" + randomNonce()
	file, err := os.OpenFile(temporary, os.O_WRONLY|os.O_CREATE|os.O_EXCL|syscall.O_NOFOLLOW, 0600)
	if err != nil {
		return err
	}
	keepTemporary := false
	defer func() {
		_ = file.Close()
		if !keepTemporary {
			_ = os.Remove(temporary)
		}
	}()
	for len(data) > 0 {
		written, writeErr := file.Write(data)
		if writeErr != nil {
			return writeErr
		}
		if written == 0 {
			return io.ErrShortWrite
		}
		data = data[written:]
	}
	if err = file.Sync(); err != nil {
		return fmt.Errorf("sync temporary ledger file: %w", err)
	}
	if stageHook != nil {
		if err = stageHook("file-sync"); err != nil {
			return err
		}
	}
	if err = file.Close(); err != nil {
		return fmt.Errorf("close temporary ledger file: %w", err)
	}
	if stageHook != nil {
		if err = stageHook("rename"); err != nil {
			return err
		}
	}
	if err = os.Rename(temporary, filename); err != nil {
		return fmt.Errorf("atomically replace ledger: %w", err)
	}
	keepTemporary = true
	dir, err := os.Open(directory)
	if err != nil {
		return fmt.Errorf("open ledger directory for sync: %w", err)
	}
	syncErr := dir.Sync()
	closeErr := dir.Close()
	if syncErr != nil {
		return fmt.Errorf("sync ledger directory: %w", syncErr)
	}
	if closeErr != nil {
		return fmt.Errorf("close ledger directory: %w", closeErr)
	}
	if stageHook != nil {
		if err = stageHook("directory-sync"); err != nil {
			return err
		}
	}
	return nil
}

func readMiSTerLedger(filename string) (miSTerBoardLedger, error) {
	var ledger miSTerBoardLedger
	info, err := os.Lstat(filename)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 || info.Size() < 1 || info.Size() > 1<<20 {
		return ledger, fmt.Errorf("MiSTer ledger is missing, unsafe or oversized")
	}
	data, err := os.ReadFile(filename)
	if err != nil {
		return ledger, err
	}
	if len(data) == 0 || len(data) > 1<<20 {
		return ledger, fmt.Errorf("MiSTer ledger size is invalid")
	}
	err = json.Unmarshal(data, &ledger)
	return ledger, err
}

func validateMiSTerInputs(prepared PreparedSession, inputs *MiSTerSessionInputs) error {
	if inputs == nil || len(inputs.FixturePaths) != 3 || !IsContentAddressedStem(inputs.RBFStem, prepared.RBF.SHA256) {
		return fmt.Errorf("MiSTer attempt inputs omit immutable fixtures or content-addressed RBF mapping")
	}
	for _, role := range []FixtureRole{FixtureOriginalMRA, FixtureLaunchMRA, FixtureRBF} {
		if inputs.FixturePaths[role] == "" {
			return fmt.Errorf("MiSTer attempt omits base fixture path %s", role)
		}
	}
	if prepared.Paths.OriginalMRA != inputs.FixturePaths[FixtureOriginalMRA] || prepared.Paths.LaunchMRA != inputs.FixturePaths[FixtureLaunchMRA] {
		return fmt.Errorf("local MRA paths differ from immutable prepared provenance")
	}
	if inputs.ExpectedCoreName == "" || !safeLocalComponent(inputs.ExpectedCoreName) || inputs.ExpectedRBFName == "" ||
		!safeLocalComponent(inputs.ExpectedRBFName) || validMiSTerRemotePath(inputs.NativeStatusPath) != nil {
		return fmt.Errorf("MiSTer core name or exact-RBF native status path is invalid")
	}
	if !strings.HasSuffix(strings.ToLower(inputs.NativeStatusPath), ".cfg") {
		return fmt.Errorf("native video status path must be the source-derived .CFG file")
	}
	if _, err := readVerifyLocal(inputs.FixturePaths[FixtureRBF], prepared.RBF.SHA256, 64<<20); err != nil {
		return fmt.Errorf("verify prepared RBF: %w", err)
	}
	for _, fixture := range []FixtureDigest{prepared.OriginalMRA, prepared.LaunchMRA} {
		if _, err := readVerifyLocal(inputs.FixturePaths[fixture.Role], fixture.SHA256, 16<<20); err != nil {
			return fmt.Errorf("verify prepared %s: %w", fixture.Role, err)
		}
	}
	for _, fixture := range prepared.Fixtures {
		fixturePath, pathErr := preparedFixturePath(prepared, inputs, fixture)
		if pathErr != nil {
			return pathErr
		}
		if _, err := readVerifyLocal(fixturePath, fixture.SHA256, miSTerFileLimit); err != nil {
			return fmt.Errorf("verify prepared %s: %w", fixture.Role, err)
		}
	}
	if err := validateFixtureFileMap(prepared, inputs); err != nil {
		return err
	}
	packed, err := readVerifyLocal(inputs.PackedCABPath, prepared.CAB.PackedSHA256, misterCABMaxBytes)
	if err != nil {
		return fmt.Errorf("verify packed CAB: %w", err)
	}
	if _, err = inspectPackedCAB(packed); err != nil {
		return err
	}
	original, _ := os.ReadFile(inputs.FixturePaths[FixtureOriginalMRA])
	launch, _ := os.ReadFile(inputs.FixturePaths[FixtureLaunchMRA])
	originalCanon, _, err := canonicalMRA(original)
	if err != nil {
		return fmt.Errorf("parse original MRA: %w", err)
	}
	launchCanon, launchStem, err := canonicalMRA(launch)
	if err != nil || string(originalCanon) != string(launchCanon) || launchStem != inputs.RBFStem {
		return fmt.Errorf("launch MRA is not a verified path-only RBF derivative")
	}
	if err = verifyMRAArchives(launch, prepared, inputs); err != nil {
		return err
	}
	if _, err := mraHasNVRAM(launch); err != nil {
		return err
	}
	hasDefaultRAM := false
	for _, fixture := range prepared.Fixtures {
		if fixture.Role == FixtureDefaultRAM {
			if hasDefaultRAM {
				return fmt.Errorf("prepared inputs contain multiple default NVRAM seeds")
			}
			hasDefaultRAM = true
		}
	}
	return nil
}

func mraHasNVRAM(mra []byte) (bool, error) {
	_, hasNVRAM, err := mraNVRAMSeedSize(mra)
	return hasNVRAM, err
}

func mraNVRAMSeedSize(mra []byte) (uint32, bool, error) {
	decoder := xml.NewDecoder(strings.NewReader(string(mra)))
	var size uint32
	count := 0
	for {
		token, err := decoder.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			return 0, false, err
		}
		start, ok := token.(xml.StartElement)
		if ok && start.Name.Local == "nvram" {
			count++
			for _, attr := range start.Attr {
				if strings.EqualFold(attr.Name.Local, "size") {
					parsed, parseErr := strconv.ParseUint(attr.Value, 0, 32)
					if parseErr != nil {
						return 0, false, fmt.Errorf("launch MRA NVRAM size is invalid")
					}
					size = uint32(parsed)
				}
			}
		}
	}
	if count > 1 {
		return 0, false, fmt.Errorf("launch MRA contains multiple nvram entries")
	}
	return size, count == 1, nil
}

func candidateNVRAMPath(mra []byte, launchMRAPath string) (string, bool, error) {
	if err := validMiSTerRemotePath(launchMRAPath); err != nil || !strings.HasSuffix(strings.ToLower(launchMRAPath), ".mra") {
		return "", false, fmt.Errorf("unsafe candidate MRA path for NVRAM identity")
	}
	hasNVRAM, err := mraHasNVRAM(mra)
	if err != nil || !hasNVRAM {
		return "", hasNVRAM, err
	}
	basename := filepath.Base(launchMRAPath)
	stem := basename[:len(basename)-len(filepath.Ext(basename))]
	if !safeMRAStem(stem) {
		return "", false, fmt.Errorf("unsafe candidate MRA basename for NVRAM identity")
	}
	return "/media/fat/config/nvram/" + stem + ".nvm", true, nil
}

func IsContentAddressedStem(stem, digest string) bool {
	return strings.HasPrefix(stem, "jt224-") && safeLocalComponent(stem) && isSHA256Hex(digest)
}

func readVerifyLocal(filename, wantSHA string, maxBytes int64) ([]byte, error) {
	info, err := os.Lstat(filename)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 || info.Size() < 1 || info.Size() > maxBytes {
		return nil, fmt.Errorf("source must be a bounded regular nonsymlink file")
	}
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	digest := sha256.Sum256(data)
	if hex.EncodeToString(digest[:]) != wantSHA {
		return nil, fmt.Errorf("source SHA256 differs from immutable prepared identity")
	}
	return data, nil
}

func canonicalMRA(data []byte) ([]byte, string, error) {
	decoder := xml.NewDecoder(strings.NewReader(string(data)))
	var canonical strings.Builder
	var rbf strings.Builder
	depth, rbfDepth, rbfCount := 0, -1, 0
	for {
		token, err := decoder.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, "", err
		}
		switch value := token.(type) {
		case xml.StartElement:
			depth++
			if value.Name.Local == "rbf" {
				rbfCount++
				if rbfCount != 1 || rbfDepth != -1 {
					return nil, "", fmt.Errorf("MRA must contain exactly one simple rbf element")
				}
				rbfDepth = depth
			}
			attrs := append([]xml.Attr(nil), value.Attr...)
			sort.Slice(attrs, func(i, j int) bool {
				if attrs[i].Name.Local == attrs[j].Name.Local {
					return attrs[i].Value < attrs[j].Value
				}
				return attrs[i].Name.Local < attrs[j].Name.Local
			})
			fmt.Fprintf(&canonical, "<%s", value.Name.Local)
			for _, attr := range attrs {
				fmt.Fprintf(&canonical, " %s=%q", attr.Name.Local, attr.Value)
			}
			canonical.WriteByte('>')
		case xml.EndElement:
			if rbfDepth == depth {
				rbfDepth = -1
			}
			fmt.Fprintf(&canonical, "</%s>", value.Name.Local)
			depth--
		case xml.CharData:
			text := strings.TrimSpace(string(value))
			if rbfDepth == depth && text != "" {
				rbf.WriteString(text)
				canonical.WriteString("<rbf-path>")
			} else if text != "" {
				canonical.WriteString(text)
			}
		case xml.Directive, xml.ProcInst, xml.Comment:
			// These do not change MRA semantics used by the loader.
		}
	}
	stem := strings.TrimSpace(rbf.String())
	if rbfCount != 1 || stem == "" || !safeMRAStem(stem) {
		return nil, "", fmt.Errorf("MRA rbf field is missing or unsafe")
	}
	return []byte(canonical.String()), stem, nil
}

func safeMRAStem(value string) bool {
	if value == "" || strings.ContainsAny(value, "\\\r\n\t \x00") || strings.Contains(value, "..") {
		return false
	}
	for _, r := range value {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || strings.ContainsRune("_-", r)) {
			return false
		}
	}
	return true
}

func verifyMRAArchives(mra []byte, prepared PreparedSession, inputs *MiSTerSessionInputs) error {
	want := make(map[string]bool)
	var inventory mraInventory
	if err := xml.Unmarshal(mra, &inventory); err != nil {
		return fmt.Errorf("decode MRA ROM archive reads: %w", err)
	}
	reads, err := effectiveMRAArchiveReads(inventory)
	if err != nil {
		return err
	}
	for _, read := range reads {
		for _, candidate := range read.candidates {
			if !safeMRAArchiveName(candidate) {
				return fmt.Errorf("MRA contains an unsafe or unsupported ROM archive name")
			}
			want[candidate] = true
		}
	}
	suppliedCandidates := map[string]bool{}
	for _, fixture := range prepared.Fixtures {
		if fixture.Role != FixtureROMArchive {
			continue
		}
		localPath, err := preparedFixturePath(prepared, inputs, fixture)
		if err != nil {
			return err
		}
		name := filepath.Base(localPath)
		if !want[name] {
			return fmt.Errorf("prepared ROM archive %q is not referenced by the MRA", name)
		}
		suppliedCandidates[name] = true
		delete(want, name)
	}
	for _, read := range reads {
		covered := false
		for _, candidate := range read.candidates {
			if suppliedCandidates[candidate] {
				covered = true
				break
			}
		}
		if !covered {
			return fmt.Errorf("MRA named part %q has no included archive candidate in %q", read.part.Name, read.candidates)
		}
	}
	return nil
}

func preparedFixturePath(prepared PreparedSession, inputs *MiSTerSessionInputs, fixture FixtureDigest) (string, error) {
	if inputs == nil {
		return "", fmt.Errorf("MiSTer fixture path map is missing")
	}
	if fixture.Role == FixtureOriginalMRA || fixture.Role == FixtureLaunchMRA || fixture.Role == FixtureRBF {
		if path := inputs.FixturePaths[fixture.Role]; path != "" {
			return path, nil
		}
		return "", fmt.Errorf("MiSTer base fixture path %s is missing", fixture.Role)
	}
	var match string
	for _, item := range inputs.FixtureFiles {
		if item.Role == fixture.Role && item.SHA256 == fixture.SHA256 {
			if match != "" {
				return "", fmt.Errorf("duplicate MiSTer fixture file mapping for %s/%s", fixture.Role, fixture.SHA256)
			}
			match = item.Path
		}
	}
	if match == "" && len(inputs.FixtureFiles) == 0 {
		match = inputs.FixturePaths[fixture.Role]
	}
	if match == "" {
		return "", fmt.Errorf("MiSTer fixture path %s/%s is missing", fixture.Role, fixture.SHA256)
	}
	return match, nil
}

func validateFixtureFileMap(prepared PreparedSession, inputs *MiSTerSessionInputs) error {
	if len(inputs.FixtureFiles) == 0 {
		for _, fixture := range prepared.Fixtures {
			if inputs.FixturePaths[fixture.Role] == "" {
				return fmt.Errorf("MiSTer fixture role %s has no local path", fixture.Role)
			}
		}
		return nil
	}
	if len(inputs.FixtureFiles) != len(prepared.Fixtures) {
		return fmt.Errorf("MiSTer repeated-fixture map does not match the prepared fixture count")
	}
	seen := make(map[string]bool, len(inputs.FixtureFiles))
	for _, fixture := range prepared.Fixtures {
		local, err := preparedFixturePath(prepared, inputs, fixture)
		if err != nil {
			return err
		}
		key := string(fixture.Role) + ":" + fixture.SHA256
		if seen[key] || !filepath.IsAbs(local) {
			return fmt.Errorf("duplicate or nonabsolute MiSTer fixture path mapping")
		}
		seen[key] = true
	}
	for _, item := range inputs.FixtureFiles {
		if item.Path == "" || item.SHA256 == "" {
			return fmt.Errorf("MiSTer fixture map has an empty source or digest")
		}
		found := false
		for _, fixture := range prepared.Fixtures {
			if item.Role == fixture.Role && item.SHA256 == fixture.SHA256 {
				found = true
			}
		}
		if !found {
			return fmt.Errorf("MiSTer fixture map contains an unprepared role/digest")
		}
	}
	return nil
}

func safeMRAArchiveName(value string) bool {
	if value == "" || value == "." || value == ".." || filepath.Base(value) != value || strings.ContainsAny(value, "/\\|\r\n\t\x00") {
		return false
	}
	for _, r := range value {
		if r < 0x20 || r == 0x7f {
			return false
		}
	}
	return true
}

func (d *MiSTerSessionDriver) backupFiles(ctx context.Context, active *miSTerActiveSession, inputs MiSTerSessionInputs) ([]miSTerFileBackup, error) {
	paths := append([]string(nil), d.Config.RestoreFiles...)
	paths = append(paths, inputs.NativeStatusPath)
	paths = append(paths, active.ledger.OriginalMainConfigPath)
	launchMRA, err := os.ReadFile(inputs.FixturePaths[FixtureLaunchMRA])
	if err != nil {
		return nil, err
	}
	if nvramPath, hasNVRAM, nvramErr := candidateNVRAMPath(launchMRA, attemptLaunchMRAPath(active.key)); nvramErr != nil {
		return nil, nvramErr
	} else if hasNVRAM {
		paths = append(paths, nvramPath)
	}
	seen := make(map[string]bool)
	if err := os.Mkdir(active.ledger.BackupDir, 0700); err != nil {
		return nil, err
	}
	if err := syncDirectory(filepath.Dir(active.ledger.BackupDir)); err != nil {
		return nil, fmt.Errorf("sync private backup parent: %w", err)
	}
	var backups []miSTerFileBackup
	for index, remotePath := range paths {
		if seen[remotePath] {
			continue
		}
		seen[remotePath] = true
		if err := validMiSTerRemotePath(remotePath); err != nil {
			return nil, err
		}
		data, exists, err := d.Remote.File(ctx, remotePath, miSTerRemoteOutputLimit)
		if err != nil {
			return nil, err
		}
		backup := miSTerFileBackup{Path: remotePath, Exists: exists}
		if exists {
			if remotePath == inputs.NativeStatusPath && len(data) != 16 {
				return nil, fmt.Errorf("existing native status CFG must be absent or exactly 16 bytes")
			}
			digest := sha256.Sum256(data)
			backup.SHA256 = hex.EncodeToString(digest[:])
			backup.Local = filepath.Join(active.ledger.BackupDir, fmt.Sprintf("file-%02d.bin", index))
			if err = atomicReplaceSynced(backup.Local, data, nil); err != nil {
				return nil, err
			}
		}
		backups = append(backups, backup)
	}
	active.backups = backups
	return backups, nil
}

func syncDirectory(directory string) error {
	file, err := os.Open(directory)
	if err != nil {
		return err
	}
	syncErr := file.Sync()
	closeErr := file.Close()
	if syncErr != nil {
		return syncErr
	}
	return closeErr
}

func (d *MiSTerSessionDriver) restoreBackups(ctx context.Context, backups []miSTerFileBackup) error {
	var failures []string
	for _, backup := range backups {
		if backup.Exists {
			data, err := os.ReadFile(backup.Local)
			if err == nil && digestBytes(data) != backup.SHA256 {
				err = fmt.Errorf("local backup hash changed")
			}
			if err == nil {
				current, exists, readErr := d.Remote.File(ctx, backup.Path, miSTerRemoteOutputLimit)
				if readErr != nil {
					err = readErr
				} else if !exists || !bytes.Equal(current, data) {
					err = d.Remote.WriteFile(ctx, backup.Path, data)
				}
			}
			if err == nil {
				var restored []byte
				var exists bool
				restored, exists, err = d.Remote.File(ctx, backup.Path, miSTerRemoteOutputLimit)
				if err == nil && (!exists || digestBytes(restored) != backup.SHA256) {
					err = fmt.Errorf("remote bytes differ from exact backup")
				}
			}
			if err != nil {
				failures = append(failures, "restore "+path.Base(backup.Path)+": "+err.Error())
			}
		} else {
			data, exists, err := d.Remote.File(ctx, backup.Path, miSTerRemoteOutputLimit)
			if err == nil && exists {
				err = d.Remote.RemoveOwned(ctx, backup.Path, digestBytes(data))
			}
			if err != nil {
				failures = append(failures, "restore absent "+path.Base(backup.Path)+": "+err.Error())
			}
		}
	}
	if len(failures) != 0 {
		return fmt.Errorf("%s", strings.Join(failures, "; "))
	}
	return nil
}

func (d *MiSTerSessionDriver) pinOriginalMainExecutable(ctx context.Context, ledger *miSTerBoardLedger) error {
	if ledger == nil || validMiSTerRemotePath(ledger.OriginalMainConfigPath) != nil {
		return fmt.Errorf("original Main INI path is unavailable")
	}
	ini, configExists, err := d.Remote.File(ctx, ledger.OriginalMainConfigPath, miSTerRemoteOutputLimit)
	if err != nil {
		return fmt.Errorf("read qualified original Main INI: %w", err)
	}
	ledger.OriginalMainConfigExists = configExists
	if configExists {
		ledger.OriginalMainConfigHash = digestBytes(ini)
	} else {
		ledger.OriginalMainConfigHash = ""
	}
	name, err := configuredMiSTerMain(ini)
	if err != nil {
		return err
	}
	root := path.Dir(ledger.OriginalMainConfigPath)
	configuredPath := name
	if !strings.HasPrefix(configuredPath, "/") {
		configuredPath = path.Join(root, configuredPath)
	}
	if validMiSTerRemotePath(configuredPath) != nil || !strings.HasPrefix(configuredPath, root+"/") {
		return fmt.Errorf("configured original Main path is unsafe")
	}
	resolved, exists, err := d.Remote.ResolvePath(ctx, configuredPath)
	if err != nil {
		return fmt.Errorf("resolve configured original Main path: %w", err)
	}
	if !exists {
		if configuredPath != ledger.Before.MainExePath {
			return fmt.Errorf("configured original Main is absent and does not match the currently running executable")
		}
		resolved = ledger.Before.MainExePath
		if validMiSTerRemotePath(resolved) != nil || !isSHA256Hex(ledger.Before.MainSHA256) {
			return fmt.Errorf("configured Main is absent and the current Main identity is unusable")
		}
	}
	digest, exists, err := d.Remote.Hash(ctx, resolved)
	if err != nil || !exists || !isSHA256Hex(digest) {
		return fmt.Errorf("original Main executable bytes cannot be pinned")
	}
	if resolved == ledger.Before.MainExePath && digest != ledger.Before.MainSHA256 {
		return fmt.Errorf("running Main bytes changed before original identity was pinned")
	}
	if digest != d.Config.MainSHA256 {
		return fmt.Errorf("INI-selected original Main is not the qualified recovery-capable firmware")
	}
	if exists {
		canonical, canonicalExists, resolveErr := d.Remote.ResolvePath(ctx, configuredPath)
		if resolveErr != nil || !canonicalExists || canonical != resolved {
			return fmt.Errorf("configured original Main resolution changed while being pinned")
		}
	}
	ledger.OriginalMainPath, ledger.OriginalMainHash = resolved, digest
	return nil
}

func (d *MiSTerSessionDriver) checkPinnedMainConfigBackup(backups []miSTerFileBackup, ledger miSTerBoardLedger) error {
	for _, backup := range backups {
		if backup.Path != ledger.OriginalMainConfigPath {
			continue
		}
		if backup.Exists != ledger.OriginalMainConfigExists || backup.SHA256 != ledger.OriginalMainConfigHash {
			return fmt.Errorf("original Main INI changed between identity pinning and backup")
		}
		return nil
	}
	return fmt.Errorf("original Main INI was not included in the backed-up settings")
}

func (d *MiSTerSessionDriver) verifyOriginalMainConfigPreimage(ctx context.Context, ledger miSTerBoardLedger) error {
	if validMiSTerRemotePath(ledger.OriginalMainConfigPath) != nil {
		return fmt.Errorf("original Main INI path is unavailable after lease claim")
	}
	data, exists, err := d.Remote.File(ctx, ledger.OriginalMainConfigPath, miSTerRemoteOutputLimit)
	if err != nil {
		return fmt.Errorf("read original Main INI after lease claim: %w", err)
	}
	if exists != ledger.OriginalMainConfigExists || (exists && digestBytes(data) != ledger.OriginalMainConfigHash) {
		return fmt.Errorf("original Main INI changed after the admission probe and before backup")
	}
	return nil
}

func (d *MiSTerSessionDriver) stageAndRun(ctx context.Context, active *miSTerActiveSession, workspace string) error {
	prepared, inputs, key := active.prepared, active.inputs, active.key
	packedCAB, err := os.ReadFile(inputs.PackedCABPath)
	if err != nil {
		return err
	}
	plan, err := EncodeCapturePlan(packedCAB, capturePlanForPrepared(prepared, d.Config.MaxHoldMS))
	if err != nil {
		return err
	}
	root := "/media/fat/_Arcade/jtreg-" + key.SessionID + "-" + key.Nonce
	if len(root) > 180 {
		return fmt.Errorf("attempt staging path is too long")
	}
	active.ledger.StagingRoot = root
	if err = d.writeLedger(active.ledger, "staging_root", ""); err != nil {
		return fmt.Errorf("persist staging directory intent: %w", err)
	}
	active.noMutation = false
	if err = d.Remote.MakeDir(ctx, root); err != nil {
		return err
	}
	active.ledger.StagingRootCreated = true
	active.ledger.OwnedDirs = append(active.ledger.OwnedDirs, root)
	if safeComponent(prepared.Setname) {
		screenshotDir := "/media/fat/screenshots/" + prepared.Setname
		if exists, probeErr := d.Remote.PathExists(ctx, screenshotDir); probeErr != nil {
			return fmt.Errorf("probe screenshot directory ownership: %w", probeErr)
		} else if !exists {
			active.ledger.ScreenshotDir = screenshotDir
			active.ledger.OwnedDirs = append(active.ledger.OwnedDirs, screenshotDir)
		}
	}
	if err = d.writeLedger(active.ledger, "staging_root_created", ""); err != nil {
		return fmt.Errorf("persist owned attempt directories: %w", err)
	}
	rbfPath := "/media/fat/_Arcade/cores/" + inputs.RBFStem + ".rbf"
	mraPath := attemptLaunchMRAPath(key)
	active.expectedRBF, active.expectedMRA = rbfPath, mraPath
	active.ledger.ExpectedRBFArgv, active.ledger.ExpectedMRAArgv = rbfPath, mraPath
	if _, exists, statErr := d.Remote.File(ctx, mraPath, 1); statErr != nil {
		return statErr
	} else if exists {
		return fmt.Errorf("attempt-unique launch MRA path already exists")
	}
	for _, item := range []struct {
		role          FixtureRole
		dest          string
		allowExisting bool
	}{
		{FixtureRBF, rbfPath, true}, {FixtureOriginalMRA, root + "/original.mra", false}, {FixtureLaunchMRA, mraPath, false},
	} {
		if err = d.stageFixtureUpload(ctx, active, inputs.FixturePaths[item.role], item.dest, fixtureDigest(prepared, item.role), item.allowExisting); err != nil {
			return err
		}
	}
	for _, fixture := range prepared.Fixtures {
		local, pathErr := preparedFixturePath(prepared, &inputs, fixture)
		if pathErr != nil {
			return pathErr
		}
		if fixture.Role == FixtureDefaultRAM {
			continue // Main loads the verified default from the candidate MRA.
		}
		remotePath := root + "/" + filepath.Base(local)
		if fixture.Role == FixtureROMArchive {
			remotePath = "/media/fat/games/mame/" + filepath.Base(local)
		}
		if err = d.stageFixtureUpload(ctx, active, local, remotePath, fixture.SHA256, fixture.Role == FixtureROMArchive); err != nil {
			return err
		}
	}
	launchMRABytes, err := os.ReadFile(inputs.FixturePaths[FixtureLaunchMRA])
	if err != nil {
		return err
	}
	if nvramPath, hasNVRAM, nvramErr := candidateNVRAMPath(launchMRABytes, mraPath); nvramErr != nil {
		return nvramErr
	} else if hasNVRAM {
		active.ledger.NVRAMPath = nvramPath
		active.ledger.NVRAMSeedSHA256 = ""
		if err = d.writeLedger(active.ledger, "staging_nvram", ""); err != nil {
			return err
		}
		if err = d.clearBackedUpFile(ctx, active, nvramPath); err != nil {
			return err
		}
	}
	cabRemote, planRemote := root+"/input.jtcab", root+"/schedule.jtcp"
	for _, file := range []struct {
		name string
		data []byte
	}{{cabRemote, packedCAB}, {planRemote, plan}} {
		if err = d.stageOwnedBytes(ctx, active, file.name, file.data, "staging"); err != nil {
			return err
		}
	}
	for _, remotePath := range []string{active.statusPath, active.cabStatusPath, active.manifestPath} {
		if _, exists, statErr := d.Remote.File(ctx, remotePath, 1); statErr != nil {
			return statErr
		} else if exists {
			return fmt.Errorf("unique MiSTer attempt status path already exists")
		}
	}
	seed := CanonicalNativeVideoStatusSeed()
	active.ledger.NativeStatusSeedSHA256 = digestBytes(seed[:])
	if err = d.writeLedger(active.ledger, "staging_native_status", ""); err != nil {
		return fmt.Errorf("persist native status seed intent: %w", err)
	}
	if err = d.Remote.WriteFile(ctx, inputs.NativeStatusPath, seed[:]); err != nil {
		return fmt.Errorf("write native status seed with durable backup intent: %w", err)
	}
	seedReadback, seedExists, seedErr := d.Remote.File(ctx, inputs.NativeStatusPath, miSTerStatusSeedBytes)
	if seedErr != nil || !seedExists || len(seedReadback) != miSTerStatusSeedBytes || string(seedReadback) != string(seed[:]) {
		return fmt.Errorf("native video status seed readback did not match the canonical 16 bytes")
	}
	if err = d.writeLedger(active.ledger, "staging_native_status", ""); err != nil {
		return err
	}
	active.ledger.OwnedFiles = append(active.ledger.OwnedFiles,
		miSTerOwnedRemoteFile{Path: active.statusPath, Owned: true},
		miSTerOwnedRemoteFile{Path: active.cabStatusPath, Owned: true},
		miSTerOwnedRemoteFile{Path: active.manifestPath, Owned: true})
	if err = d.writeLedger(active.ledger, "loading", ""); err != nil {
		return err
	}
	loadCommand := []byte("load_core " + mraPath + "\n")
	active.loadSent = true
	if err = d.Remote.WriteFIFO(ctx, loadCommand, d.Config.CommandTimeout); err != nil {
		return fmt.Errorf("normal load_core FIFO delivery uncertain: %w", err)
	}
	loaded, err := d.waitLoaded(ctx, active, mraPath, rbfPath)
	if err != nil {
		return err
	}
	active.loaded = true
	active.ledger.ProgrammedPID = loaded.MainPID
	if err = d.writeLedger(active.ledger, "loaded", ""); err != nil {
		return err
	}
	active.ledger.SessionStarted = true
	if err = d.writeLedger(active.ledger, "starting", ""); err != nil {
		return err
	}
	active.started = true
	if err = d.Remote.WriteFIFO(ctx, []byte("cab_session_start "+key.SessionID+" "+cabRemote+" "+planRemote+"\n"), d.Config.CommandTimeout); err != nil {
		return fmt.Errorf("combined session FIFO delivery uncertain: %w", err)
	}
	return d.writeLedger(active.ledger, "running", "")
}

// stageFixtureUpload records a durable ownership intent before an upload can
// create bytes remotely. A matching content-addressed file that was already
// present is recorded as shared and is never removed by this attempt.
func (d *MiSTerSessionDriver) stageFixtureUpload(ctx context.Context, active *miSTerActiveSession, localPath, remotePath, expectedSHA string, allowExisting bool) error {
	info, err := os.Lstat(localPath)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("staging source %s is not a regular nonsymlink file", path.Base(localPath))
	}
	localSHA, err := FileSHA256(localPath)
	if err != nil || localSHA != expectedSHA {
		return fmt.Errorf("staging source %s no longer matches its prepared hash", path.Base(localPath))
	}
	actual, exists, err := d.Remote.Hash(ctx, remotePath)
	if err != nil {
		return fmt.Errorf("inspect staging destination %s: %w", path.Base(remotePath), err)
	}
	if exists {
		if !allowExisting || actual != expectedSHA {
			return fmt.Errorf("attempt staging path already exists or has different bytes: %s", path.Base(remotePath))
		}
		active.ledger.OwnedFiles = append(active.ledger.OwnedFiles, miSTerOwnedRemoteFile{Path: remotePath, SHA256: expectedSHA})
		return d.writeLedger(active.ledger, "staging", "")
	}
	entry := miSTerOwnedRemoteFile{Path: remotePath, SHA256: expectedSHA, Owned: true, Pending: true}
	active.ledger.OwnedFiles = append(active.ledger.OwnedFiles, entry)
	if err = d.writeLedger(active.ledger, "staging", ""); err != nil {
		return fmt.Errorf("persist upload ownership intent for %s: %w", path.Base(remotePath), err)
	}
	created, err := d.Remote.Upload(ctx, localPath, remotePath, expectedSHA)
	if err != nil {
		return fmt.Errorf("upload %s with durable pending ownership: %w", path.Base(remotePath), err)
	}
	actual, exists, err = d.Remote.Hash(ctx, remotePath)
	if err != nil || !exists || actual != expectedSHA {
		return fmt.Errorf("uploaded %s failed exact readback", path.Base(remotePath))
	}
	entryAt := len(active.ledger.OwnedFiles) - 1
	active.ledger.OwnedFiles[entryAt].Owned = created
	active.ledger.OwnedFiles[entryAt].Pending = false
	if err = d.writeLedger(active.ledger, "staging", ""); err != nil {
		return fmt.Errorf("persist completed upload ownership for %s: %w", path.Base(remotePath), err)
	}
	return nil
}

// stageOwnedBytes performs an attempt-unique remote write only after the
// durable ledger has recorded its intended path and expected contents.
func (d *MiSTerSessionDriver) stageOwnedBytes(ctx context.Context, active *miSTerActiveSession, remotePath string, data []byte, state string) error {
	actual, exists, err := d.Remote.Hash(ctx, remotePath)
	if err != nil {
		return fmt.Errorf("inspect staging destination %s: %w", path.Base(remotePath), err)
	}
	if exists {
		return fmt.Errorf("attempt-owned staging path already exists: %s", path.Base(remotePath))
	}
	digest := digestBytes(data)
	active.ledger.OwnedFiles = append(active.ledger.OwnedFiles, miSTerOwnedRemoteFile{Path: remotePath, SHA256: digest, Owned: true, Pending: true})
	if err = d.writeLedger(active.ledger, state, ""); err != nil {
		return fmt.Errorf("persist remote write intent for %s: %w", path.Base(remotePath), err)
	}
	if err = d.Remote.WriteFile(ctx, remotePath, data); err != nil {
		return fmt.Errorf("write %s with durable pending ownership: %w", path.Base(remotePath), err)
	}
	actual, exists, err = d.Remote.Hash(ctx, remotePath)
	if err != nil || !exists || actual != digest {
		return fmt.Errorf("remote write %s failed exact readback", path.Base(remotePath))
	}
	active.ledger.OwnedFiles[len(active.ledger.OwnedFiles)-1].Pending = false
	return d.writeLedger(active.ledger, state, "")
}

func attemptLaunchMRAPath(key AttemptKey) string {
	return "/media/fat/_Arcade/jtreg-" + string(key.SessionID) + "-" + key.Nonce + "/jtcap-" + string(key.SessionID) + "-" + key.Nonce + ".mra"
}

func (d *MiSTerSessionDriver) clearBackedUpFile(ctx context.Context, active *miSTerActiveSession, remotePath string) error {
	for _, backup := range active.backups {
		if backup.Path != remotePath {
			continue
		}
		if !backup.Exists {
			_, exists, err := d.Remote.File(ctx, remotePath, miSTerRemoteOutputLimit)
			if err != nil || exists {
				return fmt.Errorf("candidate NVRAM path changed after an absent backup")
			}
			return nil
		}
		data, err := os.ReadFile(backup.Local)
		if err != nil || digestBytes(data) != backup.SHA256 {
			return fmt.Errorf("cannot verify backed-up candidate NVRAM file")
		}
		return d.Remote.RemoveOwned(ctx, remotePath, backup.SHA256)
	}
	return fmt.Errorf("candidate NVRAM path was not included in the backup ledger")
}

func capturePlanForPrepared(prepared PreparedSession, hold uint32) []CapturePlanEntry {
	entries := make([]CapturePlanEntry, len(prepared.Checkpoints))
	for index, checkpoint := range prepared.Checkpoints {
		entries[index] = CapturePlanEntry{Checkpoint: checkpoint, MaxHoldMS: hold}
	}
	return entries
}

func fixtureDigest(prepared PreparedSession, role FixtureRole) string {
	switch role {
	case FixtureRBF:
		return prepared.RBF.SHA256
	case FixtureOriginalMRA:
		return prepared.OriginalMRA.SHA256
	case FixtureLaunchMRA:
		return prepared.LaunchMRA.SHA256
	default:
		for _, fixture := range prepared.Fixtures {
			if fixture.Role == role {
				return fixture.SHA256
			}
		}
	}
	return ""
}

func (d *MiSTerSessionDriver) waitLoaded(ctx context.Context, active *miSTerActiveSession, mraPath, rbfPath string) (MiSTerBoardSnapshot, error) {
	ctx, cancel := context.WithTimeout(ctx, d.Config.LoadTimeout)
	defer cancel()
	deadline := d.Now().Add(d.Config.LoadTimeout)
	for {
		if err := ctx.Err(); err != nil {
			return MiSTerBoardSnapshot{}, err
		}
		snapshot, err := d.Remote.Probe(ctx)
		if err == nil && snapshot.MainPID != active.ledger.BeforePID && snapshot.MainSHA256 == d.Config.MainSHA256 &&
			snapshot.MainExePath == active.ledger.Before.MainExePath && snapshot.ArgvRBF == rbfPath &&
			snapshot.ArgvMRA == mraPath && snapshot.FPGAState == "operating" && bridgesEnabled(snapshot.BridgeStates, d.Config.ExpectedBridgeCount) {
			ready, readyErr := d.Remote.FIFOReady(ctx, snapshot.MainPID)
			if readyErr != nil {
				return snapshot, readyErr
			}
			if ready && d.Now().Before(deadline) && ctx.Err() == nil {
				return snapshot, nil
			}
		}
		if d.Now().After(deadline) {
			return snapshot, fmt.Errorf("normal load_core did not produce the exact Main/RBF/MRA full-program witness with a ready FIFO")
		}
		if err := d.Sleep(ctx, d.pollInterval()); err != nil {
			return snapshot, err
		}
	}
}

func (d *MiSTerSessionDriver) collectCapture(ctx context.Context, active *miSTerActiveSession, workspace string) (SessionCapture, error) {
	var status MiSTerCaptureStatus
	var statusBytes []byte
	deadline := d.Now().Add(d.Config.CaptureTimeout)
	for {
		if err := ctx.Err(); err != nil {
			return SessionCapture{}, err
		}
		data, exists, err := d.Remote.File(ctx, active.statusPath, maxCaptureStatusJSONBytes)
		if err != nil {
			return SessionCapture{}, err
		}
		if exists {
			status, err = decodeLiveMiSTerCaptureStatus(data)
			if err != nil {
				return SessionCapture{}, err
			}
			if status.SessionID != active.key.SessionID {
				return SessionCapture{}, fmt.Errorf("stale capture status belongs to another session")
			}
			statusBytes = data
			if mainMiSTerCaptureOperationFailed(status.State) {
				return SessionCapture{}, fmt.Errorf("Main capture operation failed in state %s/%s fault=%d", status.State, status.ScheduleState, status.Fault)
			}
			if status.State == "complete" && status.ScheduleState == "complete" {
				break
			}
			if terminalCaptureState(status.State, status.ScheduleState) || status.ReloadRequired || status.Fault != 0 {
				return SessionCapture{}, fmt.Errorf("Main capture session ended in state %s/%s fault=%d", status.State, status.ScheduleState, status.Fault)
			}
		}
		if d.Now().After(deadline) {
			return SessionCapture{}, fmt.Errorf("Main capture session acknowledgement timed out")
		}
		if err = d.Sleep(ctx, d.pollInterval()); err != nil {
			return SessionCapture{}, err
		}
	}
	if err := d.recordRemoteFileHash(ctx, active, active.statusPath, statusBytes); err != nil {
		return SessionCapture{}, err
	}
	if status.ManifestPath != active.manifestPath {
		return SessionCapture{}, fmt.Errorf("Main manifest path does not match the attempt-owned path")
	}
	manifestBytes, exists, err := d.Remote.File(ctx, status.ManifestPath, maxCaptureManifestBytes)
	if err != nil || !exists {
		return SessionCapture{}, fmt.Errorf("complete Main manifest is unavailable")
	}
	type captureReference struct {
		Checkpoint  uint32
		Sequence    uint32
		ReceiptPath string
	}
	var manifest MiSTerCaptureManifest
	var manifestV2 miSTerCaptureManifestV2
	var refs []captureReference
	var decodeErr error
	manifestV2, decodeErr = decodeMiSTerCaptureManifestV2(manifestBytes)
	if decodeErr != nil {
		return SessionCapture{}, decodeErr
	}
	manifest = MiSTerCaptureManifest{SessionID: manifestV2.SessionID, State: manifestV2.State,
		FPGAGeneration: manifestV2.FPGAGeneration, PlanCRC32: manifestV2.PlanCRC32,
		PackedCABCRC32: manifestV2.PackedCABCRC32, PlanTotalFrames: manifestV2.PlanTotalFrames,
		ExpectedCount: manifestV2.ExpectedCount, PlannedCheckpoints: manifestV2.PlannedCheckpoints,
		CompletedCount: manifestV2.CompletedCount}
	for _, ref := range manifestV2.Images {
		expectedReceipt := fmt.Sprintf("/tmp/jtframe-capture-%s-checkpoint-%05x.receipt.json", active.key.SessionID, ref.Checkpoint)
		if ref.ReceiptPath != expectedReceipt {
			return SessionCapture{}, fmt.Errorf("Main receipt path %q does not match expected attempt sequence path %q", ref.ReceiptPath, expectedReceipt)
		}
		refs = append(refs, captureReference{Checkpoint: ref.Checkpoint, ReceiptPath: ref.ReceiptPath})
	}
	if err = d.recordRemoteFileHash(ctx, active, status.ManifestPath, manifestBytes); err != nil {
		return SessionCapture{}, err
	}
	cabBytes, cabExists, err := d.Remote.File(ctx, active.cabStatusPath, 64<<10)
	if err != nil || !cabExists {
		return SessionCapture{}, fmt.Errorf("terminal CAB status is unavailable")
	}
	err = validateMiSTerCABStatusV2(cabBytes, active.key.SessionID, manifestV2)
	if err != nil {
		return SessionCapture{}, err
	}
	if err = d.recordRemoteFileHash(ctx, active, active.cabStatusPath, cabBytes); err != nil {
		return SessionCapture{}, err
	}
	files := MiSTerRetrievedFiles{ReceiptJSON: make(map[string][]byte), ReceiptLocal: make(map[string]string), PNGLocal: make(map[string]string)}
	// RawRGBLocal is populated from receipt paths supplied by Main, which can
	// be enabled independently of the host-side proof directory.
	files.RawRGBLocal = make(map[string]string)
	for _, ref := range refs {
		if err = validMiSTerRemotePath(ref.ReceiptPath); err != nil {
			return SessionCapture{}, err
		}
		receiptBytes, receiptExists, readErr := d.Remote.File(ctx, ref.ReceiptPath, maxCaptureReceiptBytes)
		if readErr != nil || !receiptExists {
			return SessionCapture{}, fmt.Errorf("manifest-listed image receipt is unavailable")
		}
		var pngPath, rawPath string
		receipt, decodeErr := decodeMiSTerCaptureImageReceiptV2(receiptBytes)
		if decodeErr != nil {
			return SessionCapture{}, decodeErr
		}
		pngPath, rawPath = receipt.PNGPath, receipt.RawRGBPath
		pngDir := "/media/fat/screenshots/" + active.prepared.Setname
		if err = validMainCapturePNGPath(pngPath, pngDir, active.key.SessionID, ref.Checkpoint); err != nil {
			return SessionCapture{}, fmt.Errorf("Main PNG path: %w", err)
		}
		if rawPath != "" {
			if err = validMainCaptureRawPath(rawPath, active.key.SessionID, ref.Checkpoint); err != nil {
				return SessionCapture{}, fmt.Errorf("Main raw RGB path: %w", err)
			}
		}
		if err = d.recordRemoteFileHash(ctx, active, ref.ReceiptPath, receiptBytes); err != nil {
			return SessionCapture{}, err
		}
		localReceipt := filepath.Join(workspace, fmt.Sprintf("receipt_%08d.json", ref.Checkpoint))
		if err = os.WriteFile(localReceipt, receiptBytes, 0600); err != nil {
			return SessionCapture{}, err
		}
		files.ReceiptJSON[ref.ReceiptPath], files.ReceiptLocal[ref.ReceiptPath] = receiptBytes, localReceipt
		localPNG := filepath.Join(workspace, CapturePNGLocalName(ref.Checkpoint))
		if err = d.Remote.Download(ctx, pngPath, localPNG, miSTerPNGMaxBytes); err != nil {
			return SessionCapture{}, err
		}
		pngSHA, hashErr := FileSHA256(localPNG)
		if hashErr != nil {
			return SessionCapture{}, hashErr
		}
		if err = d.recordRemoteFileHash(ctx, active, pngPath, nil, pngSHA); err != nil {
			return SessionCapture{}, err
		}
		files.PNGLocal[pngPath] = localPNG
		if rawPath != "" {
			localRaw := filepath.Join(workspace, fmt.Sprintf("proof_%08d.rgb", ref.Checkpoint))
			if err = d.Remote.Download(ctx, rawPath, localRaw, 8<<20); err != nil {
				return SessionCapture{}, err
			}
			rawSHA, hashErr := FileSHA256(localRaw)
			if hashErr != nil {
				return SessionCapture{}, hashErr
			}
			if err = d.recordRemoteFileHash(ctx, active, rawPath, nil, rawSHA); err != nil {
				return SessionCapture{}, err
			}
			files.RawRGBLocal[rawPath] = localRaw
		}
	}
	prepared := active.prepared
	packedCAB, err := os.ReadFile(active.inputs.PackedCABPath)
	if err != nil {
		return SessionCapture{}, err
	}
	plan, err := EncodeCapturePlan(packedCAB, capturePlanForPrepared(prepared, d.Config.MaxHoldMS))
	if err != nil {
		return SessionCapture{}, err
	}
	planCRC := uint32(plan[len(plan)-4]) | uint32(plan[len(plan)-3])<<8 | uint32(plan[len(plan)-2])<<16 | uint32(plan[len(plan)-1])<<24
	expected := MiSTerReceiptExpectation{Prepared: prepared, PackedCAB: packedCAB, Attempt: active.key,
		FPGAGeneration: manifest.FPGAGeneration, PlanCRC32: planCRC, MaxHoldMS: d.Config.MaxHoldMS,
		RequireCaptureV2: true}
	validated, err := ValidateMiSTerCapture(expected, statusBytes, manifestBytes, files, workspace)
	if err != nil {
		return SessionCapture{}, err
	}
	active.complete = true
	capture := SessionCapture{Key: active.key, Workspace: workspace, Cleanup: SessionCleanup{Required: true}}
	capture.Receipt = CaptureReceipt{SessionID: active.key.SessionID, Generation: prepared.Generation,
		CaptureConvention: prepared.Convention, CaptureProtocol: validated.CaptureProtocol,
		Epoch: validated.Epoch, PlanSHA256: digestBytes(plan), CABPayloadCRC32: prepared.CAB.PayloadCRC32}
	for _, image := range validated.Images {
		capture.Receipt.Images = append(capture.Receipt.Images, ImageReceipt{Sequence: image.Sequence,
			RequestedFrame: image.Checkpoint, ActualFrame: image.Checkpoint - 1, Checkpoint: image.Checkpoint,
			Width: image.Width, Height: image.Height, Pitch: image.RowPitch, Slot: image.Slot,
			Mode: image.Mode, DescriptorCRC32: image.DescriptorCRC32,
			Released: true, PNGPath: files.PNGLocal[image.PNGPath], PNGBytes: int64(image.PNGSize), PNGComplete: true})
		capture.PNGPaths = append(capture.PNGPaths, files.PNGLocal[image.PNGPath])
	}
	return capture, nil
}

func validMainNamedPath(value, parent string) error {
	if err := validMiSTerRemotePath(value); err != nil {
		return err
	}
	if path.Dir(value) != parent || !safeLocalComponent(path.Base(value)) {
		return fmt.Errorf("path %q is outside expected output directory %q", value, parent)
	}
	return nil
}

func validMainCapturePNGPath(value, parent, sessionID string, checkpoint uint32) error {
	if err := validMainNamedPath(value, parent); err != nil {
		return err
	}
	base := path.Base(value)
	token := fmt.Sprintf("cabcap_%s_%04x", sessionID, checkpoint)
	noDatePrefix := "NODATE-" + token + "_"
	if strings.HasPrefix(base, noDatePrefix) && strings.HasSuffix(base, ".png") {
		ordinal := strings.TrimSuffix(strings.TrimPrefix(base, noDatePrefix), ".png")
		if len(ordinal) == 4 {
			validDigits := true
			for _, digit := range ordinal {
				if digit < '0' || digit > '9' {
					validDigits = false
					break
				}
			}
			if validDigits {
				if value, err := strconv.Atoi(ordinal); err == nil && value >= 1 && value <= 9999 {
					return nil
				}
			}
		}
	}
	dateSuffix := "-" + token + ".png"
	if strings.HasSuffix(base, dateSuffix) {
		timestamp := strings.TrimSuffix(base, dateSuffix)
		parsed, err := time.Parse("20060102_150405", timestamp)
		if err == nil && parsed.Format("20060102_150405") == timestamp {
			return nil
		}
	}
	return fmt.Errorf("PNG filename does not match Main's dated or NODATE session-checkpoint format")
}

func validMainCaptureRawPath(value, sessionID string, checkpoint uint32) error {
	if err := validMiSTerRemotePath(value); err != nil {
		return err
	}
	parent := path.Dir(value)
	proofPrefix := "/tmp/jtframe-capture-proof"
	if !(parent == proofPrefix || strings.HasPrefix(parent, proofPrefix+"/") || strings.HasPrefix(parent, proofPrefix+"-")) {
		return fmt.Errorf("raw RGB path is outside the Main proof root")
	}
	want := fmt.Sprintf("%s-%05x.rgb", sessionID, checkpoint)
	if path.Base(value) != want {
		return fmt.Errorf("raw RGB filename is not bound to this session checkpoint")
	}
	return nil
}

func (d *MiSTerSessionDriver) recordRemoteFileHash(ctx context.Context, active *miSTerActiveSession, remotePath string, content []byte, localSHA ...string) error {
	want := ""
	if len(localSHA) != 0 {
		want = localSHA[0]
	} else {
		want = digestBytes(content)
	}
	actual, exists, err := d.Remote.Hash(ctx, remotePath)
	if err != nil || !exists || actual != want {
		return fmt.Errorf("owned remote output %s changed or is unavailable", path.Base(remotePath))
	}
	for index := range active.ledger.OwnedFiles {
		if active.ledger.OwnedFiles[index].Path == remotePath {
			active.ledger.OwnedFiles[index].SHA256 = want
			return d.writeLedger(active.ledger, "collecting", "")
		}
	}
	active.ledger.OwnedFiles = append(active.ledger.OwnedFiles, miSTerOwnedRemoteFile{Path: remotePath, SHA256: want, Owned: true})
	return d.writeLedger(active.ledger, "collecting", "")
}

type miSTerCABProgress struct {
	Protocol          string `json:"protocol"`
	Session           string `json:"session"`
	State             string `json:"state"`
	Reason            string `json:"reason"`
	Epoch             uint32 `json:"epoch"`
	Frame             uint32 `json:"frame"`
	FramesTotal       uint32 `json:"frames_total"`
	EventsAccepted    uint32 `json:"events_accepted"`
	EventsApplied     uint32 `json:"events_applied"`
	EventsTotal       uint32 `json:"events_total"`
	NextEvent         uint32 `json:"next_event"`
	FreeCredits       uint32 `json:"free_credits"`
	CleanupConfirmed  bool   `json:"cleanup_confirmed"`
	StatusWriteFailed bool   `json:"status_write_failed"`
	Error             string `json:"error"`
}

var miSTerCABProgressKeys = []string{"protocol", "session", "state", "reason", "epoch", "frame", "frames_total", "events_accepted", "events_applied", "events_total", "next_event", "free_credits", "cleanup_confirmed", "status_write_failed", "error"}

func validateMiSTerCABStatus(data []byte, sessionID string, manifest MiSTerCaptureManifest) error {
	var progress miSTerCABProgress
	if err := strictJSONDecode(data, 64<<10, miSTerCABProgressKeys, &progress); err != nil {
		return fmt.Errorf("decode CAB progress: %w", err)
	}
	terminal := manifest.CABTerminal
	if progress.Protocol != "jtframe-cab-host-v1" || progress.Session != sessionID || progress.State != "done" ||
		!progress.CleanupConfirmed || progress.StatusWriteFailed || progress.Error != "" || progress.Epoch != terminal.Epoch ||
		progress.Frame != terminal.Frames || progress.FramesTotal != terminal.FramesTotal ||
		progress.EventsAccepted != terminal.EventsAccepted || progress.EventsApplied != terminal.EventsApplied || progress.EventsTotal != terminal.EventsTotal {
		return fmt.Errorf("terminal CAB progress does not match the clean capture manifest")
	}
	return nil
}

func (d *MiSTerSessionDriver) cleanupAttempt(ctx context.Context, active *miSTerActiveSession, before MiSTerBoardSnapshot, workspace string) error {
	if active.noMutation {
		if active.remoteLeaseAttempted && !active.remoteLeaseOwned {
			return fmt.Errorf("remote lease acquisition is unconfirmed; lease-only quarantine retained")
		}
		if active.remoteLeaseOwned {
			if err := d.Remote.RemoveOwned(ctx, active.ledger.RemoteLock, active.ledger.RemoteLockSHA); err != nil {
				return fmt.Errorf("pre-mutation lease release is unconfirmed; lease-only quarantine retained: %w", err)
			}
			active.remoteLeaseOwned = false
		}
		_ = os.RemoveAll(filepath.Join(workspace, "backup"))
		return nil
	}
	var failures []string
	if active.started && !active.complete {
		if err := d.Remote.WriteFIFO(ctx, []byte("cab_stop "+active.key.SessionID+"\n"), d.Config.CommandTimeout); err != nil {
			return fmt.Errorf("cab_stop was not confirmed; quarantine retained: %w", err)
		} else if err := d.waitCleanStop(ctx, active); err != nil {
			return fmt.Errorf("%w; quarantine retained", err)
		}
	}
	current, probeErr := d.Remote.Probe(ctx)
	if probeErr != nil {
		failures = append(failures, "probe before restoration: "+probeErr.Error())
	} else if active.loadSent && !active.loaded {
		loaded, loadErr := d.waitLoaded(ctx, active, active.expectedMRA, active.expectedRBF)
		if loadErr != nil {
			return fmt.Errorf("load outcome is uncertain; quarantine retained: %w", loadErr)
		}
		active.loaded = true
		active.ledger.ProgrammedPID = loaded.MainPID
		if err := d.writeLedger(active.ledger, "loaded", ""); err != nil {
			return err
		}
		current = loaded
	}
	if err := d.restoreBackups(ctx, active.backups); err != nil {
		return fmt.Errorf("restore pre-attempt configuration before original core load: %w", err)
	}
	if err := d.verifyOriginalLoaderAssets(ctx, active.ledger); err != nil {
		return fmt.Errorf("original loader assets changed; quarantine retained: %w", err)
	}
	if probeErr == nil && active.loaded && current.MainPID != before.MainPID {
		restoreArg, restoreErr := originalLoaderCommand(active.ledger)
		if restoreErr != nil {
			return fmt.Errorf("original loader target is unavailable; quarantine retained: %w", restoreErr)
		}
		if err := d.writeLedger(active.ledger, "restoring_original", ""); err != nil {
			return fmt.Errorf("persist original restore intent: %w", err)
		} else if err := d.Remote.WriteFIFO(ctx, []byte("load_core "+restoreArg+"\n"), d.Config.CommandTimeout); err != nil {
			failures = append(failures, "restore original core: "+err.Error())
		} else if original, err := d.waitForOriginalSnapshot(ctx, active.ledger); err != nil {
			failures = append(failures, err.Error())
		} else if err := d.verifyOriginalLoaderAssets(ctx, active.ledger); err != nil {
			failures = append(failures, "verify original loader assets after restore: "+err.Error())
		} else if err := d.requestOriginalProgramWitness(ctx, &active.ledger, original); err != nil {
			failures = append(failures, "original full-RBF programming witness is unconfirmed: "+err.Error())
		}
	}
	// Retain the candidate, lease and backups until the original loader's
	// process/argv/FPGA witness is complete. Reconcile needs these bytes to retry
	// a failed restore; deleting them here would make quarantine unrecoverable.
	if len(failures) != 0 {
		return fmt.Errorf("%s", strings.Join(failures, "; "))
	}
	if err := removeOwnedMiSTerFiles(ctx, d.Remote, active.ledger.OwnedFiles); err != nil {
		failures = append(failures, err.Error())
	}
	if len(failures) != 0 {
		return fmt.Errorf("%s", strings.Join(failures, "; "))
	}
	for _, directory := range active.ledger.OwnedDirs {
		if err := d.Remote.RemoveEmptyDir(ctx, directory); err != nil {
			failures = append(failures, "remove owned empty directory "+path.Base(directory)+": "+err.Error())
		}
	}
	if len(failures) != 0 {
		return fmt.Errorf("%s", strings.Join(failures, "; "))
	}
	if active.ledger.RemoteLock != "" && active.ledger.RemoteLockSHA != "" {
		if err := d.Remote.RemoveOwned(ctx, active.ledger.RemoteLock, active.ledger.RemoteLockSHA); err != nil {
			return fmt.Errorf("release remote board lock: %w", err)
		}
	}
	return nil
}

func removeOwnedMiSTerFiles(ctx context.Context, remote MiSTerRemote, files []miSTerOwnedRemoteFile) error {
	var known []miSTerOwnedRemoteFile
	for _, file := range files {
		if !file.Owned {
			continue
		}
		if err := validMiSTerRemotePath(file.Path); err != nil {
			return fmt.Errorf("owned remote path is invalid: %w", err)
		}
		sha := file.SHA256
		if sha == "" {
			var exists bool
			var err error
			sha, exists, err = remote.Hash(ctx, file.Path)
			if err != nil {
				return fmt.Errorf("inspect owned output %s: %w", path.Base(file.Path), err)
			}
			if !exists {
				continue
			}
		}
		if !isSHA256Hex(sha) {
			return fmt.Errorf("owned output %s has no valid expected SHA256", path.Base(file.Path))
		}
		known = append(known, miSTerOwnedRemoteFile{Path: file.Path, SHA256: sha, Owned: true})
	}
	if len(known) == 0 {
		return nil
	}
	if batch, ok := remote.(miSTerOwnedFileBatchRemover); ok {
		if err := batch.RemoveOwnedBatch(ctx, known); err != nil {
			return err
		}
		return nil
	}
	for _, file := range known {
		if err := remote.RemoveOwned(ctx, file.Path, file.SHA256); err != nil {
			return fmt.Errorf("remove owned %s: %w", path.Base(file.Path), err)
		}
	}
	return nil
}

func removeSessionWorkspace(root, workspace string) error {
	if root == "" || workspace == "" {
		return nil
	}
	root, err := filepath.Abs(root)
	if err != nil {
		return err
	}
	workspace, err = filepath.Abs(workspace)
	if err != nil {
		return err
	}
	relative, err := filepath.Rel(root, workspace)
	if err != nil || relative == "." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) || !strings.HasPrefix(filepath.Base(workspace), "mister-") {
		return fmt.Errorf("workspace path is outside the configured attempt root")
	}
	info, err := os.Lstat(workspace)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("workspace is not a task-owned directory")
	}
	if err = os.RemoveAll(workspace); err != nil {
		return err
	}
	return syncDirectory(root)
}

func (d *MiSTerSessionDriver) waitCleanStop(ctx context.Context, active *miSTerActiveSession) error {
	deadline := d.Now().Add(d.Config.CleanupTimeout)
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		data, exists, err := d.Remote.File(ctx, active.statusPath, maxCaptureStatusJSONBytes)
		if err == nil && exists {
			status, decodeErr := decodeLiveMiSTerCaptureStatus(data)
			if decodeErr == nil && status.SessionID == active.key.SessionID && status.CleanupConfirmed && !status.ReloadRequired && !status.EncoderBusy && terminalCaptureState(status.State, status.ScheduleState) {
				return nil
			}
		}
		if d.Now().After(deadline) {
			return fmt.Errorf("capture cleanup is unconfirmed")
		}
		if err := d.Sleep(ctx, d.pollInterval()); err != nil {
			return err
		}
	}
}

func originalLoaderKind(ledger miSTerBoardLedger) string {
	if ledger.OriginalLoaderKind != "" {
		return ledger.OriginalLoaderKind
	}
	// Version-one ledgers written before the explicit kind field only describe
	// the established absolute-path MRA restore mode.
	if ledger.OriginalRBFPath != "" && ledger.OriginalMRAPath != "" {
		return "mra"
	}
	return ""
}

func originalLoaderCommand(ledger miSTerBoardLedger) (string, error) {
	switch originalLoaderKind(ledger) {
	case "mra":
		if validMiSTerRemotePath(ledger.OriginalRBFPath) != nil || validMiSTerRemotePath(ledger.OriginalMRAPath) != nil ||
			(ledger.OriginalRBFArgv != "" && ledger.OriginalRBFArgv != ledger.OriginalRBFPath) {
			return "", fmt.Errorf("invalid original MRA loader identity")
		}
		return ledger.OriginalMRAPath, nil
	case "menu-rbf":
		if ledger.OriginalRBFPath != "/media/fat/menu.rbf" || ledger.OriginalRBFArgv != "menu.rbf" || ledger.OriginalMRAPath != "" || !isSHA256Hex(ledger.OriginalRBFHash) {
			return "", fmt.Errorf("invalid pinned MENU RBF-only loader identity")
		}
		return "menu.rbf", nil
	default:
		return "", fmt.Errorf("unknown original loader kind")
	}
}

func originalLoaderMatches(snapshot MiSTerBoardSnapshot, ledger miSTerBoardLedger) bool {
	expectedRBF := ledger.OriginalRBFArgv
	if expectedRBF == "" {
		expectedRBF = ledger.OriginalRBFPath
	}
	if snapshot.ArgvRBF != expectedRBF {
		return false
	}
	switch originalLoaderKind(ledger) {
	case "mra":
		return snapshot.ArgvMRA == ledger.OriginalMRAPath
	case "menu-rbf":
		return snapshot.ArgvMRA == ""
	default:
		return false
	}
}

func (d *MiSTerSessionDriver) waitForOriginalSnapshot(ctx context.Context, ledger miSTerBoardLedger) (MiSTerBoardSnapshot, error) {
	deadline := d.Now().Add(d.Config.LoadTimeout)
	for {
		if err := ctx.Err(); err != nil {
			return MiSTerBoardSnapshot{}, err
		}
		snapshot, err := d.Remote.Probe(ctx)
		if err == nil && snapshot.MainPID != ledger.BeforePID && snapshot.MainPID != ledger.ProgrammedPID && snapshot.MainSHA256 == ledger.OriginalMainHash &&
			snapshot.MainExePath == ledger.OriginalMainPath && originalLoaderMatches(snapshot, ledger) &&
			snapshot.FPGAState == "operating" && bridgesEnabled(snapshot.BridgeStates, d.Config.ExpectedBridgeCount) {
			return cloneMiSTerBoardSnapshot(snapshot), nil
		}
		if d.Now().After(deadline) {
			return MiSTerBoardSnapshot{}, fmt.Errorf("original core restoration witness was not observed")
		}
		if err := d.Sleep(ctx, d.pollInterval()); err != nil {
			return MiSTerBoardSnapshot{}, err
		}
	}
}

func (d *MiSTerSessionDriver) waitForSnapshot(ctx context.Context, ledger miSTerBoardLedger) error {
	_, err := d.waitForOriginalSnapshot(ctx, ledger)
	return err
}

func (d *MiSTerSessionDriver) pollInterval() time.Duration {
	if d.Config.PollInterval > 0 {
		return d.Config.PollInterval
	}
	return miSTerStatusPollDefault
}

func contextSleep(ctx context.Context, duration time.Duration) error {
	if duration <= 0 {
		return nil
	}
	timer := time.NewTimer(duration)
	defer timer.Stop()
	select {
	case <-timer.C:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func terminalCaptureState(state, schedule string) bool {
	stateTerminal := false
	scheduledFailure := false
	switch state {
	case "idle", "done", "complete", "error", "rejected", "cancelled", "cleanup_unconfirmed", "interrupted", "deadline_expired",
		"reload_required", "unsupported", "bridge_busy", "invalid_target", "start_failed", "encode_error", "receipt_error",
		"first_capture_preflight_failed", "capture_target_late", "capture_arm_failed", "capture_session_error", "capture_manifest_publish_failed",
		"capture_recovery_required", "capture_manifest_start_failed", "cab_session_start_failed":
		stateTerminal = true
	case "cab_failed_before_first_capture_arm", "cab_ended_before_first_capture_arm", "first_capture_arm_timeout",
		"capture_start_gate_rejected", "first_capture_arm_failed", "capture_target_failed", "capture_receipt_error",
		"capture_encoder_error", "capture_generation_changed", "cab_terminal_session_mismatch", "cab_terminal_receipt_invalid",
		"capture_playback_deadline_expired":
		stateTerminal = true
		scheduledFailure = true
	default:
		if state != "" {
			return false
		}
	}
	if scheduledFailure && schedule != "error" {
		return false
	}
	scheduleTerminal := false
	switch schedule {
	case "", "complete", "error", "rejected", "cancelled", "cleanup_unconfirmed", "blocked", "interrupted":
		scheduleTerminal = true
	default:
		return false
	}
	return stateTerminal && scheduleTerminal
}

func mainMiSTerCaptureOperationFailed(state string) bool {
	switch state {
	case "error", "encode_error", "receipt_error", "deadline_expired", "reload_required",
		"first_capture_preflight_failed", "capture_target_late", "capture_arm_failed", "capture_session_error",
		"capture_manifest_publish_failed", "capture_recovery_required", "unsupported", "bridge_busy", "invalid_target",
		"start_failed", "encoder_busy", "capture_manifest_start_failed", "cab_session_start_failed",
		"cab_failed_before_first_capture_arm", "cab_ended_before_first_capture_arm", "first_capture_arm_timeout",
		"capture_start_gate_rejected", "first_capture_arm_failed", "capture_target_failed", "capture_receipt_error",
		"capture_encoder_error", "capture_generation_changed", "cab_terminal_session_mismatch", "cab_terminal_receipt_invalid",
		"capture_playback_deadline_expired":
		return true
	default:
		return false
	}
}

func safeLocalComponent(value string) bool {
	if value == "" || value == "." || value == ".." {
		return false
	}
	for _, r := range value {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || strings.ContainsRune("_-.", r)) {
			return false
		}
	}
	return true
}

func validAttemptNonce(value string) bool {
	return len(value) >= 8 && len(value) <= 48 && safeLocalComponent(value)
}

func digestBytes(data []byte) string {
	digest := sha256.Sum256(data)
	return hex.EncodeToString(digest[:])
}

func randomNonce() string {
	var data [12]byte
	if _, err := rand.Read(data[:]); err != nil {
		return fmt.Sprintf("fallback-%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(data[:])
}
