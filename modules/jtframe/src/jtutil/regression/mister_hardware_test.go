/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"hash/crc32"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

// Captured from the native Main mock bundle at producer commit 9604de712792b25c50c964dc9d5899c5326da43a.
const mainMockCaptureStatusV2JSON = `{"protocol":"jtframe-capture-session-v2","session_id":"scheduled-2362604","state":"complete","checkpoint":20,"max_hold_ms":500,"fault":0,"cleanup_confirmed":true,"reload_required":false,"status_write_failed":false,"receipt_write_failed":false,"copied_bytes":256,"encoder_busy":false,"output":"/tmp/jtframe-storage-root-PnhrfX/screenshots/2362604-cabcap_scheduled-2362604_0014-\"quoted\".png","scheduled":true,"schedule_crc32":"7ae09d84","packed_cab_crc32":"12345678","schedule_count":2,"schedule_index":2,"schedule_state":"complete","capture_protocol":"jtframe-capture-v2","receipt_protocol":"jtframe-capture-image-v2","manifest_path":"/tmp/jtframe-capture-scheduled-2362604.manifest.json","completed_count":2}`
const mainMockCABStatusV2JSON = `{"protocol":"jtframe-cab-host-v2","session":"test-ZuJDy8-v2","state":"done","reason":"complete","frame":4,"frames_total":4,"events_accepted":2,"events_applied":2,"events_total":2,"next_event":2,"free_credits":8,"cleanup_confirmed":true,"status_write_failed":false,"error":""}`
const mainMockCheckpoint100DescriptorHex = "4a54433202004000640063000000202000002000570009000002000000120000010d0000040000000400000000000000000000000000000036856bfa52445932"

type forbiddenPreparedAttemptRemote struct{ MiSTerRemote }

func TestValidatePreparedAttemptUsesCaptureAdmissionWithoutRemoteOrMutation(t *testing.T) {
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, newFakeMiSTerRemote())
	driver.Remote = forbiddenPreparedAttemptRemote{}
	preparedBefore := prepared.Clone()
	inputsBefore := cloneTestMiSTerSessionInputs(inputs)
	if err := driver.ValidatePreparedAttempt(key, prepared, inputs); err != nil {
		t.Fatalf("valid runtime inputs rejected: %v", err)
	}
	if !reflect.DeepEqual(prepared, preparedBefore) || !reflect.DeepEqual(inputs, inputsBefore) {
		t.Fatal("offline validation mutated caller-owned prepared session or inputs")
	}

	tests := []struct {
		name      string
		stem      string
		wantError string
	}{
		{name: "preserved raw A02 mapping", stem: "jtcircus", wantError: "immutable fixtures or content-addressed RBF mapping"},
		{name: "raw MRA with content-addressed stem", stem: "jt224-" + prepared.RBF.SHA256[:24], wantError: "verified path-only RBF derivative"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			badPrepared := prepared.Clone()
			badInputs := cloneTestMiSTerSessionInputs(inputs)
			badInputs.RBFStem = test.stem
			badInputs.FixturePaths[FixtureLaunchMRA] = badInputs.FixturePaths[FixtureOriginalMRA]
			badPrepared.Paths.LaunchMRA = badInputs.FixturePaths[FixtureOriginalMRA]
			badPrepared.LaunchMRA.SHA256 = badPrepared.OriginalMRA.SHA256
			if err := driver.ValidatePreparedAttempt(key, badPrepared, badInputs); err == nil || !strings.Contains(err.Error(), test.wantError) {
				t.Fatalf("invalid launch mapping error=%v, want containing %q", err, test.wantError)
			}
			if !reflect.DeepEqual(badPrepared.Paths.LaunchMRA, badInputs.FixturePaths[FixtureOriginalMRA]) {
				t.Fatal("test setup did not preserve raw MRA as launch input")
			}
		})
	}

	badKey := key
	badKey.Board = "another-board"
	if err := driver.ValidatePreparedAttempt(badKey, prepared, inputs); err == nil || !strings.Contains(err.Error(), "does not identify this MiSTer board") {
		t.Fatalf("wrong-board attempt error=%v", err)
	}
}

func cloneTestMiSTerSessionInputs(inputs MiSTerSessionInputs) MiSTerSessionInputs {
	clone := inputs
	clone.FixturePaths = make(map[FixtureRole]string, len(inputs.FixturePaths))
	for role, path := range inputs.FixturePaths {
		clone.FixturePaths[role] = path
	}
	clone.FixtureFiles = append([]MiSTerFixtureFile(nil), inputs.FixtureFiles...)
	return clone
}

type fakeMiSTerRemote struct {
	files                     map[string][]byte
	probe                     MiSTerBoardSnapshot
	before                    MiSTerBoardSnapshot
	loaded                    MiSTerBoardSnapshot
	loadMRA                   string
	loadRBF                   string
	loadStem                  string
	restoreCommand            string
	loadCount                 int
	nvramPath                 string
	nvramAtLoad               []byte
	nvramAtRestoreLoad        []byte
	nativeStatusAtLoad        []byte
	nativeStatusAtRestoreLoad []byte
	restoreWatchedPaths       []string
	restoreWatchedAtLoad      map[string][]byte
	tamperOriginalPath        string
	tamperOriginalBytes       []byte
	startFiles                map[string][]byte
	fifos                     [][]byte
	mutations                 []string
	fileReads                 []string
	probeCalls                int
	probeErrAt                int
	afterCreate               func(string, []byte)
	removeErrPath             string
	failStop                  bool
	ignoreLoad                bool
	withholdStatus            bool
	stopStatus                []byte
	recoveryReceipt           func(string, MiSTerBoardSnapshot) []byte
	originalProgramReceipt    func(string, MiSTerBoardSnapshot) []byte
	originalLoaded            bool
	afterRecovery             func(*fakeMiSTerRemote)
	ledgerPath                string
	originalIntentAtRequest   bool
	recoveryWrites            int
	recoveryWriteErr          bool
	recoveryHold              bool
	recoveryReadErr           bool
	loadRBFName               string
	restoreRBFName            string
	restoreCoreName           string
	recoveryCoreName          string
	recoveryRBFName           string
	restoreMainPath           string
	restoreMainHash           string
	started                   chan struct{}
	stopSent                  chan struct{}
}

func newFakeMiSTerRemote() *fakeMiSTerRemote {
	state := MiSTerBoardSnapshot{MainPID: 100, HostName: "mister-real", MainExePath: "/media/fat/Main", MainSHA256: strings.Repeat("a", 64),
		CoreName: "menu", RBFName: "MENU", ArgvRBF: "/media/fat/menu.rbf", ArgvMRA: "/media/fat/menu.mra",
		FPGAState: "operating", BridgeStates: map[string]string{"/sys/class/fpga_bridge/br0/state": "enabled"}}
	return &fakeMiSTerRemote{files: make(map[string][]byte), probe: cloneSnapshot(state), before: cloneSnapshot(state)}
}

func cloneSnapshot(value MiSTerBoardSnapshot) MiSTerBoardSnapshot {
	states := value.BridgeStates
	value.BridgeStates = make(map[string]string, len(states))
	for key, state := range states {
		value.BridgeStates[key] = state
	}
	return value
}

func (f *fakeMiSTerRemote) Probe(context.Context) (MiSTerBoardSnapshot, error) {
	f.probeCalls++
	if f.probeErrAt == f.probeCalls {
		return MiSTerBoardSnapshot{}, fmt.Errorf("simulated board probe failure")
	}
	return cloneSnapshot(f.probe), nil
}
func (f *fakeMiSTerRemote) ResolvePath(_ context.Context, name string) (string, bool, error) {
	if _, exists := f.files[name]; !exists {
		return "", false, nil
	}
	return name, true, nil
}
func (f *fakeMiSTerRemote) PathExists(_ context.Context, name string) (bool, error) {
	_, exists := f.files[name]
	return exists, nil
}
func (f *fakeMiSTerRemote) MakeDir(_ context.Context, name string) error {
	f.mutations = append(f.mutations, "mkdir "+name)
	return nil
}
func (f *fakeMiSTerRemote) RemoveEmptyDir(_ context.Context, name string) error {
	f.mutations = append(f.mutations, "rmdir "+name)
	return nil
}
func (f *fakeMiSTerRemote) CreateExclusive(_ context.Context, name string, data []byte) error {
	if _, exists := f.files[name]; exists {
		return fmt.Errorf("already exists")
	}
	f.files[name] = append([]byte(nil), data...)
	f.mutations = append(f.mutations, "create "+name)
	if f.afterCreate != nil {
		f.afterCreate(name, data)
	}
	return nil
}
func (f *fakeMiSTerRemote) Hash(_ context.Context, name string) (string, bool, error) {
	data, exists := f.files[name]
	if !exists {
		return "", false, nil
	}
	return digestBytes(data), true, nil
}
func (f *fakeMiSTerRemote) File(_ context.Context, name string, max int64) ([]byte, bool, error) {
	f.fileReads = append(f.fileReads, name)
	if f.recoveryReadErr && f.recoveryWrites > 0 && strings.HasPrefix(name, "/tmp/jtframe-capture-recovery-") {
		return nil, false, fmt.Errorf("simulated SSH receipt read timeout")
	}
	data, exists := f.files[name]
	if exists && int64(len(data)) > max {
		return nil, true, fmt.Errorf("file over bound")
	}
	return append([]byte(nil), data...), exists, nil
}
func (f *fakeMiSTerRemote) WriteFile(_ context.Context, name string, data []byte) error {
	f.files[name] = append([]byte(nil), data...)
	f.mutations = append(f.mutations, "write "+name)
	return nil
}
func (f *fakeMiSTerRemote) Upload(_ context.Context, local, remote, expected string) (bool, error) {
	data, err := os.ReadFile(local)
	if err != nil || digestBytes(data) != expected {
		return false, fmt.Errorf("local hash mismatch")
	}
	if existing, ok := f.files[remote]; ok {
		if digestBytes(existing) == expected {
			return false, nil
		}
		return false, fmt.Errorf("remote collision")
	}
	f.files[remote] = data
	f.mutations = append(f.mutations, "upload "+remote)
	return true, nil
}
func (f *fakeMiSTerRemote) Download(_ context.Context, remote, local string, max int64) error {
	data, ok := f.files[remote]
	if !ok || int64(len(data)) > max {
		return fmt.Errorf("missing or oversized download")
	}
	if err := os.MkdirAll(filepath.Dir(local), 0700); err != nil {
		return err
	}
	return os.WriteFile(local, data, 0600)
}
func (f *fakeMiSTerRemote) RemoveOwned(_ context.Context, name, expected string) error {
	if !isSHA256Hex(expected) {
		return fmt.Errorf("owned removal requires expected SHA256")
	}
	if f.removeErrPath == name {
		return fmt.Errorf("simulated owned-file release failure")
	}
	data, exists := f.files[name]
	if !exists {
		return nil
	}
	if digestBytes(data) != expected {
		return fmt.Errorf("hash changed")
	}
	delete(f.files, name)
	f.mutations = append(f.mutations, "remove "+name)
	return nil
}
func (f *fakeMiSTerRemote) WriteFIFO(_ context.Context, record []byte, _ time.Duration) error {
	f.fifos = append(f.fifos, append([]byte(nil), record...))
	text := string(record)
	if strings.HasPrefix(text, "load_core ") {
		mra := strings.TrimSuffix(strings.TrimPrefix(text, "load_core "), "\n")
		if mra == f.loadMRA {
			f.originalLoaded = false
			f.nvramAtLoad = append([]byte(nil), f.files[f.nvramPath]...)
			f.nativeStatusAtLoad = append([]byte(nil), f.files["/media/fat/config/circusc.CFG"]...)
			if f.ignoreLoad {
				return nil
			}
			f.loadCount++
			f.probe = cloneSnapshot(f.loaded)
			if f.tamperOriginalPath != "" {
				f.files[f.tamperOriginalPath] = append([]byte(nil), f.tamperOriginalBytes...)
			}
			if f.loadCount > 1 {
				f.probe.MainPID += f.loadCount - 1 // Each normal full load restarts Main with a new PID.
			}
			if f.loadRBFName != "" {
				f.probe.RBFName = f.loadRBFName
			}
		} else if (f.restoreCommand != "" && mra == f.restoreCommand) || (f.restoreCommand == "" && mra == f.before.ArgvMRA) {
			f.originalLoaded = true
			f.nvramAtRestoreLoad = append([]byte(nil), f.files[f.nvramPath]...)
			f.nativeStatusAtRestoreLoad = append([]byte(nil), f.files["/media/fat/config/circusc.CFG"]...)
			f.restoreWatchedAtLoad = make(map[string][]byte, len(f.restoreWatchedPaths))
			for _, path := range f.restoreWatchedPaths {
				f.restoreWatchedAtLoad[path] = append([]byte(nil), f.files[path]...)
			}
			f.probe = cloneSnapshot(f.before)
			f.probe.MainPID = 200
			if f.restoreMainPath != "" {
				f.probe.MainExePath = f.restoreMainPath
				f.probe.MainSHA256 = f.restoreMainHash
			}
			if f.restoreCoreName != "" {
				f.probe.CoreName = f.restoreCoreName
			}
			if f.restoreRBFName != "" {
				f.probe.RBFName = f.restoreRBFName
			}
		}
		return nil
	}
	if strings.HasPrefix(text, "cab_session_start ") {
		for name, data := range f.startFiles {
			if f.withholdStatus && strings.Contains(name, "/jtframe-capture-") && !strings.Contains(name, ".manifest.") {
				continue
			}
			f.files[name] = append([]byte(nil), data...)
		}
		if f.started != nil {
			select {
			case f.started <- struct{}{}:
			default:
			}
		}
		return nil
	}
	if strings.HasPrefix(text, "cab_stop ") {
		if f.stopSent != nil {
			select {
			case f.stopSent <- struct{}{}:
			default:
			}
		}
		if f.failStop {
			return fmt.Errorf("simulated FIFO timeout")
		}
		if len(f.stopStatus) != 0 {
			id := strings.TrimSpace(strings.TrimPrefix(text, "cab_stop "))
			f.files["/tmp/jtframe-capture-"+id+".json"] = append([]byte(nil), f.stopStatus...)
		}
		return nil
	}
	if strings.HasPrefix(text, "cab_capture_recover ") {
		id := strings.TrimSpace(strings.TrimPrefix(text, "cab_capture_recover "))
		if !validRecoveryID(id) || strings.Contains(id, " ") {
			return fmt.Errorf("invalid recovery command")
		}
		if f.originalLoaded && f.ledgerPath != "" {
			ledger, err := readMiSTerLedger(f.ledgerPath)
			f.originalIntentAtRequest = err == nil && ledger.State == "original_program_witness_pending" && len(ledger.OriginalProgramWitnesses) > 0 &&
				ledger.OriginalProgramWitnesses[len(ledger.OriginalProgramWitnesses)-1].RecoveryID == id && ledger.OriginalProgramWitnesses[len(ledger.OriginalProgramWitnesses)-1].ExpectedPID == f.probe.MainPID
		}
		f.recoveryWrites++
		if f.recoveryWriteErr {
			return fmt.Errorf("simulated recovery FIFO timeout")
		}
		receiptFn := f.recoveryReceipt
		if f.originalLoaded && f.originalProgramReceipt != nil {
			receiptFn = f.originalProgramReceipt
		}
		if !f.recoveryHold {
			if receiptFn != nil {
				f.files[miSTerRecoveryReceiptPath(id)] = receiptFn(id, cloneSnapshot(f.probe))
			} else if f.originalLoaded {
				data, _ := json.Marshal(validRecoveryReceipt(id, f.probe.MainPID))
				f.files[miSTerRecoveryReceiptPath(id)] = data
			}
			if f.afterRecovery != nil {
				f.afterRecovery(f)
			}
		}
		if f.recoveryCoreName != "" {
			f.probe.CoreName = f.recoveryCoreName
		}
		if f.recoveryRBFName != "" {
			f.probe.RBFName = f.recoveryRBFName
		}
		return nil
	}
	return fmt.Errorf("unexpected FIFO record")
}

type stagingIntentMiSTerRemote struct {
	*fakeMiSTerRemote
	ledgerPath string
	uploads    []string
	writes     []string
	dirs       []string
}

func (r *stagingIntentMiSTerRemote) MakeDir(ctx context.Context, remote string) error {
	ledger, err := readMiSTerLedger(r.ledgerPath)
	if err != nil || ledger.StagingRoot != remote {
		return fmt.Errorf("staging directory %s was created without durable path intent", remote)
	}
	r.dirs = append(r.dirs, remote)
	return r.fakeMiSTerRemote.MakeDir(ctx, remote)
}

func (r *stagingIntentMiSTerRemote) Upload(ctx context.Context, local, remote, expected string) (bool, error) {
	ledger, err := readMiSTerLedger(r.ledgerPath)
	if err != nil {
		return false, fmt.Errorf("read durable ledger before upload: %w", err)
	}
	if _, alreadyThere := r.files[remote]; alreadyThere {
		return false, fmt.Errorf("test expected absent upload path %s", remote)
	}
	found := false
	for _, entry := range ledger.OwnedFiles {
		if entry.Path == remote && entry.SHA256 == expected && entry.Owned && entry.Pending {
			found = true
			break
		}
	}
	if !found {
		return false, fmt.Errorf("upload %s started without durable pending ownership intent", remote)
	}
	r.uploads = append(r.uploads, remote)
	return r.fakeMiSTerRemote.Upload(ctx, local, remote, expected)
}

func (r *stagingIntentMiSTerRemote) WriteFile(ctx context.Context, remote string, data []byte) error {
	ledger, err := readMiSTerLedger(r.ledgerPath)
	if err != nil {
		return err
	}
	if strings.HasSuffix(remote, ".jtcab") || strings.HasSuffix(remote, ".jtcp") {
		found := false
		for _, entry := range ledger.OwnedFiles {
			if entry.Path == remote && entry.SHA256 == digestBytes(data) && entry.Owned && entry.Pending {
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("staging write %s started without durable pending ownership intent", remote)
		}
		r.writes = append(r.writes, remote)
	}
	if remote == "/media/fat/config/circusc.CFG" && ledger.NativeStatusSeedSHA256 != digestBytes(data) {
		return fmt.Errorf("native status write started without durable seed hash intent")
	}
	if remote == ledger.NVRAMPath && ledger.State == "staging_nvram" && ledger.NVRAMSeedSHA256 != digestBytes(data) {
		return fmt.Errorf("NVRAM write started without durable seed path/hash intent")
	}
	return r.fakeMiSTerRemote.WriteFile(ctx, remote, data)
}

type failOriginalMiSTerLoadRemote struct {
	*fakeMiSTerRemote
	failRestore bool
}

func (r *failOriginalMiSTerLoadRemote) WriteFIFO(ctx context.Context, record []byte, timeout time.Duration) error {
	restoreArg := r.restoreCommand
	if restoreArg == "" {
		restoreArg = r.before.ArgvMRA
	}
	if r.failRestore && string(record) == "load_core "+restoreArg+"\n" {
		return fmt.Errorf("simulated original core restore failure")
	}
	return r.fakeMiSTerRemote.WriteFIFO(ctx, record, timeout)
}

func setFakeMiSTerMenuStartup(remote *fakeMiSTerRemote, driver *MiSTerSessionDriver) {
	remote.before.ArgvRBF, remote.before.ArgvMRA = "menu.rbf", ""
	remote.probe.ArgvRBF, remote.probe.ArgvMRA = "menu.rbf", ""
	remote.before.CoreName, remote.probe.CoreName = "MENU", "MENU"
	remote.before.RBFName, remote.probe.RBFName = "MENU", "MENU"
	remote.files["/media/fat/menu.rbf"] = []byte("exact observed original menu image")
	remote.restoreCommand = "menu.rbf"
	driver.Config.RestoreRBFPath = "/media/fat/menu.rbf"
	driver.Config.RestoreMRAPath = ""
}

func TestMiSTerDriverRestoresExactObservedMenuRBFOnSuccess(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	setFakeMiSTerMenuStartup(remote, driver)
	original := append([]byte(nil), remote.files["/media/fat/menu.rbf"]...)
	if result, err := driver.CapturePrepared(context.Background(), key, prepared, inputs); err != nil || !result.Cleanup.Confirmed {
		t.Fatalf("exact MENU RBF restore failed: result=%+v err=%v", result.Cleanup, err)
	}
	if got := string(remote.fifos[len(remote.fifos)-2]); got != "load_core menu.rbf\n" || !strings.HasPrefix(string(remote.fifos[len(remote.fifos)-1]), "cab_capture_recover ") {
		t.Fatalf("restore did not preserve MENU argv before the original program witness: %q", remote.fifos)
	}
	if string(remote.files["/media/fat/menu.rbf"]) != string(original) || remote.probe.ArgvRBF != "menu.rbf" || remote.probe.ArgvMRA != "" || remote.probe.FPGAState != "operating" {
		t.Fatalf("MENU restoration did not preserve pinned RBF bytes and exact argv: %+v", remote.probe)
	}
}

func TestMiSTerDriverCancelDuringCaptureRestoresMenuRBF(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	setFakeMiSTerMenuStartup(remote, driver)
	driver.Config.CaptureTimeout = 2 * time.Second
	remote.withholdStatus = true
	remote.started = make(chan struct{}, 1)
	remote.stopSent = make(chan struct{}, 1)
	status, err := decodeMiSTerCaptureStatusV2(remote.startFiles["/tmp/jtframe-capture-"+key.SessionID+".json"])
	if err != nil {
		t.Fatal(err)
	}
	status.State, status.ScheduleState = "cancelled", "cancelled"
	remote.stopStatus, err = json.Marshal(status)
	if err != nil {
		t.Fatal(err)
	}
	type result struct {
		capture SessionCapture
		err     error
	}
	done := make(chan result, 1)
	go func() {
		capture, captureErr := driver.CapturePrepared(context.Background(), key, prepared, inputs)
		done <- result{capture: capture, err: captureErr}
	}()
	select {
	case <-remote.started:
	case <-time.After(time.Second):
		t.Fatal("combined session start was not sent")
	}
	if err = driver.Cancel(context.Background(), key); err != nil {
		t.Fatalf("bounded independent cancel failed: %v", err)
	}
	select {
	case <-remote.stopSent:
	case <-time.After(time.Second):
		t.Fatal("CAB STOP was not sent independently during capture wait")
	}
	completed := <-done
	if completed.err == nil || !completed.capture.Cleanup.Confirmed {
		t.Fatalf("cancel did not return interrupted work with confirmed cleanup: %+v %v", completed.capture.Cleanup, completed.err)
	}
	if got := string(remote.fifos[len(remote.fifos)-2]); got != "load_core menu.rbf\n" || remote.probe.ArgvMRA != "" {
		t.Fatalf("cancel did not restore exact MENU RBF-only argv before program witness: previous=%q snapshot=%+v", got, remote.probe)
	}
}

func TestMiSTerDriverReconcilesFailedMenuRBFRestore(t *testing.T) {
	base := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, base)
	setFakeMiSTerMenuStartup(base, driver)
	remote := &failOriginalMiSTerLoadRemote{fakeMiSTerRemote: base, failRestore: true}
	driver.Remote = remote
	result, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err == nil || result.Cleanup.Confirmed {
		t.Fatalf("failed MENU restoration was reported clean: result=%+v err=%v", result.Cleanup, err)
	}
	ledger, err := readMiSTerLedger(driver.ledgerName())
	if err != nil || ledger.OriginalLoaderKind != "menu-rbf" || ledger.OriginalRBFArgv != "menu.rbf" || ledger.OriginalRBFPath != "/media/fat/menu.rbf" || ledger.OriginalMRAPath != "" {
		t.Fatalf("quarantine did not retain explicit MENU identity: %+v %v", ledger, err)
	}
	if err = driver.verifyQuarantineLeaseAndStagedFiles(context.Background(), ledger); err != nil {
		t.Fatalf("MENU restore quarantine lost its candidate assets: %v", err)
	}
	remote.failRestore = false
	remote.recoveryReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
		return marshalRecoveryReceipt(t, validRecoveryReceipt(id, snapshot.MainPID))
	}
	if cleanup, err := driver.Reconcile(context.Background(), key); err != nil || !cleanup.Confirmed {
		t.Fatalf("MENU restoration did not recover through normal Reconcile: %+v %v", cleanup, err)
	}
	if got := string(remote.fifos[len(remote.fifos)-2]); got != "load_core menu.rbf\n" || !strings.HasPrefix(string(remote.fifos[len(remote.fifos)-1]), "cab_capture_recover ") {
		t.Fatalf("Reconcile did not restore MENU before the original program witness: %q", remote.fifos)
	}
}

func TestMiSTerDriverRetainsQuarantineWhenPinnedMenuRBFChanges(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	setFakeMiSTerMenuStartup(remote, driver)
	original := append([]byte(nil), remote.files["/media/fat/menu.rbf"]...)
	remote.tamperOriginalPath = "/media/fat/menu.rbf"
	remote.tamperOriginalBytes = []byte("changed menu RBF")
	result, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err == nil || result.Cleanup.Confirmed {
		t.Fatalf("changed menu RBF was accepted as original: result=%+v err=%v", result.Cleanup, err)
	}
	ledger, err := readMiSTerLedger(driver.ledgerName())
	if err != nil || ledger.State != "quarantined" || ledger.OriginalRBFHash != digestBytes(original) {
		t.Fatalf("changed menu RBF did not retain its pinned identity/quarantine: %+v %v", ledger, err)
	}
	remote.files["/media/fat/menu.rbf"] = original
	remote.tamperOriginalPath = ""
	remote.recoveryReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
		return marshalRecoveryReceipt(t, validRecoveryReceipt(id, snapshot.MainPID))
	}
	if cleanup, err := driver.Reconcile(context.Background(), key); err != nil || !cleanup.Confirmed {
		t.Fatalf("exact original MENU RBF bytes did not allow Reconcile: %+v %v", cleanup, err)
	}
}

func TestMiSTerDriverRejectsUnsupportedRBFOnlyStartupContexts(t *testing.T) {
	for _, test := range []struct {
		name string
		rbf  string
		mra  string
	}{
		{name: "executable only"},
		{name: "other bare rbf", rbf: "other.rbf"},
		{name: "absolute menu path", rbf: "/media/fat/menu.rbf"},
		{name: "menu with mra", rbf: "menu.rbf", mra: "/media/fat/menu.mra"},
	} {
		t.Run(test.name, func(t *testing.T) {
			remote := newFakeMiSTerRemote()
			driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
			remote.before.ArgvRBF, remote.before.ArgvMRA = test.rbf, test.mra
			remote.probe.ArgvRBF, remote.probe.ArgvMRA = test.rbf, test.mra
			remote.files["/media/fat/menu.rbf"] = []byte("menu bytes")
			if _, err := driver.CapturePrepared(context.Background(), key, prepared, inputs); err == nil {
				t.Fatal("unsupported RBF-only startup was accepted")
			}
			if len(remote.mutations) != 0 || len(remote.fifos) != 0 {
				t.Fatalf("unsupported startup mutated board: mutations=%v fifo=%q", remote.mutations, remote.fifos)
			}
		})
	}
}

func TestMiSTerDriverPersistsStagingOwnershipBeforeMutation(t *testing.T) {
	base := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, base)
	remote := &stagingIntentMiSTerRemote{fakeMiSTerRemote: base, ledgerPath: driver.ledgerName()}
	driver.Remote = remote
	if _, err := driver.CapturePrepared(context.Background(), key, prepared, inputs); err != nil {
		t.Fatal(err)
	}
	if len(remote.uploads) != 4 || len(remote.writes) != 2 || len(remote.dirs) != 1 {
		t.Fatalf("durable intent checks covered %d uploads/%d staging writes/%d dirs, want 4/2/1; uploads=%v writes=%v dirs=%v", len(remote.uploads), len(remote.writes), len(remote.dirs), remote.uploads, remote.writes, remote.dirs)
	}
}

func TestMiSTerDriverDoesNotUploadWhenOwnershipIntentIsNotDurable(t *testing.T) {
	base := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, base)
	remote := &stagingIntentMiSTerRemote{fakeMiSTerRemote: base, ledgerPath: driver.ledgerName()}
	driver.Remote = remote
	injected := false
	driver.ledgerStageHook = func(state, stage string) error {
		if !injected && state == "staging" && stage == "directory-sync" {
			injected = true
			return fmt.Errorf("simulated loss after durable ownership-intent rename")
		}
		return nil
	}
	if _, err := driver.CapturePrepared(context.Background(), key, prepared, inputs); err == nil || !injected {
		t.Fatalf("durability failure was not injected: %v", err)
	}
	if len(remote.uploads) != 0 {
		t.Fatalf("upload ran after ownership-intent durability failure: %v", remote.uploads)
	}
}

func TestMiSTerDriverRetainsCandidateWhenOriginalRestoreFails(t *testing.T) {
	base := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, base)
	remote := &failOriginalMiSTerLoadRemote{fakeMiSTerRemote: base, failRestore: true}
	driver.Remote = remote
	if result, err := driver.CapturePrepared(context.Background(), key, prepared, inputs); err == nil || result.Cleanup.Confirmed {
		t.Fatalf("failed original load was reported as clean: result=%+v err=%v", result.Cleanup, err)
	}
	ledger, err := readMiSTerLedger(driver.ledgerName())
	if err != nil || ledger.State != "quarantined" {
		t.Fatalf("failed original load did not retain quarantine: %+v %v", ledger, err)
	}
	if err = driver.verifyQuarantineLeaseAndStagedFiles(context.Background(), ledger); err != nil {
		t.Fatalf("quarantine cannot retry the original load: %v", err)
	}
	for _, candidate := range []string{ledger.ExpectedRBFArgv, ledger.ExpectedMRAArgv} {
		if _, exists := base.files[candidate]; !exists {
			t.Errorf("failed restoration deleted candidate recovery asset %s", candidate)
		}
	}
	remote.failRestore = false
	remote.recoveryReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
		return marshalRecoveryReceipt(t, validRecoveryReceipt(id, snapshot.MainPID))
	}
	cleanup, err := driver.Reconcile(context.Background(), key)
	if err != nil || !cleanup.Confirmed {
		t.Fatalf("retained candidate did not reconcile after restore recovered: %+v %v", cleanup, err)
	}
}

func TestMiSTerDriverRejectsBadFirmwareBeforeMutation(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	remote.probe.MainSHA256 = strings.Repeat("b", 64)
	_, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err == nil || len(remote.mutations) != 0 || len(remote.fifos) != 0 {
		t.Fatalf("bad Main firmware was not rejected before mutation: err=%v mutations=%v fifo=%q", err, remote.mutations, remote.fifos)
	}
}

func TestMiSTerDriverRejectsUnqualifiedINISelectedRestoreMainBeforeMutation(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	remote.files["/media/fat/OriginalMain"] = []byte("stock Main without recovery RPC")
	_, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err == nil || !strings.Contains(err.Error(), "not the qualified recovery-capable firmware") {
		t.Fatalf("unqualified selected restoration Main was not rejected clearly: %v", err)
	}
	if len(remote.mutations) != 0 || len(remote.fifos) != 0 {
		t.Fatalf("unqualified original Main was rejected only after board mutation: mutations=%v fifos=%q", remote.mutations, remote.fifos)
	}
	if _, exists := remote.files["/tmp/jtframe-regression-board-mister-home.lock"]; exists {
		t.Fatal("preflight incompatibility left a remote board lease")
	}
}

func TestMiSTerDriverRunsOneBoundedSessionAndRestoresOriginalState(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, originalCFG := fakeMiSTerDriverFixture(t, remote)
	remote.files[inputs.NativeStatusPath] = append([]byte(nil), originalCFG...)
	result, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err != nil {
		t.Fatal(err)
	}
	if result.Key != key || len(result.PNGPaths) != len(prepared.Checkpoints) || !result.Cleanup.Confirmed {
		t.Fatalf("incomplete fake capture result: %+v", result)
	}
	if !remote.originalIntentAtRequest {
		t.Fatal("original program recovery command was issued before its ID/PID intent was durable")
	}
	if len(remote.fifos) != 4 || !strings.HasPrefix(string(remote.fifos[0]), "load_core ") ||
		!strings.HasPrefix(string(remote.fifos[1]), "cab_session_start ") || !strings.HasPrefix(string(remote.fifos[2]), "load_core ") ||
		!strings.HasPrefix(string(remote.fifos[3]), "cab_capture_recover ") {
		t.Fatalf("expected candidate loader, session start, original restore, and program witness: %q", remote.fifos)
	}
	if !strings.HasSuffix(string(remote.fifos[0]), "jtcap-"+key.SessionID+"-"+key.Nonce+".mra\n") {
		t.Fatalf("unexpected loader command: %q", remote.fifos[0])
	}
	if !strings.Contains(string(remote.fifos[1]), "/input.jtcab /media/fat/_Arcade/jtreg-") {
		t.Fatalf("combined start did not bind staged CAB and plan paths: %q", remote.fifos[1])
	}
	if got := remote.files[inputs.NativeStatusPath]; string(got) != string(originalCFG) {
		t.Fatalf("native status seed was not restored byte-for-byte: %x", got)
	}
	if string(remote.nvramAtLoad) != string([]byte{0x12, 0x34, 0x56, 0x78}) {
		t.Fatalf("candidate MRA did not consume the hashed default NVRAM seed: %x", remote.nvramAtLoad)
	}
	nativeSeed := CanonicalNativeVideoStatusSeed()
	if string(remote.nativeStatusAtLoad) != string(nativeSeed[:]) {
		t.Fatalf("candidate Main did not consume the canonical native status seed: %x", remote.nativeStatusAtLoad)
	}
	if string(remote.nativeStatusAtRestoreLoad) != string(originalCFG) {
		t.Fatalf("original Main consumed candidate status instead of the original CFG: %x", remote.nativeStatusAtRestoreLoad)
	}
	if got := remote.files[remote.nvramPath]; string(got) != string([]byte{0xa1, 0xb2, 0xc3, 0xd4}) {
		t.Fatalf("candidate NVRAM path was not restored byte-for-byte: %x", got)
	}
	if string(remote.nvramAtRestoreLoad) != string([]byte{0xa1, 0xb2, 0xc3, 0xd4}) {
		t.Fatalf("original Main consumed candidate NVRAM instead of the original bytes: %x", remote.nvramAtRestoreLoad)
	}
	if string(remote.restoreWatchedAtLoad["/media/fat/config/arcade.ini"]) != "original arcade settings\n" ||
		string(remote.restoreWatchedAtLoad["/media/fat/config/arcade.dip"]) != string([]byte{0x05, 0x06, 0x07}) ||
		string(remote.restoreWatchedAtLoad["/media/fat/MiSTer.ini"]) != "[MiSTer]\nMAIN=OriginalMain\n" {
		t.Fatalf("original Main loaded before configured mutable files were restored: %v", remote.restoreWatchedAtLoad)
	}
	if remote.probe.MainPID == remote.before.MainPID || remote.probe.MainExePath != remote.restoreMainPath ||
		remote.probe.MainSHA256 != remote.restoreMainHash || remote.probe.ArgvMRA != remote.before.ArgvMRA {
		t.Fatalf("original core restoration was not observed: %+v", remote.probe)
	}
	if _, exists := remote.files["/tmp/jtframe-regression-board-mister-home.lock"]; exists {
		t.Fatal("successful cleanup left the owned remote board lock")
	}
	stagingRoot := "/media/fat/_Arcade/jtreg-" + string(key.SessionID) + "-" + key.Nonce
	for _, path := range []string{"/media/fat/_Arcade/cores/" + inputs.RBFStem + ".rbf", stagingRoot + "/original.mra", stagingRoot + "/jtcap-" + string(key.SessionID) + "-" + key.Nonce + ".mra", "/media/fat/games/mame/circus.zip"} {
		if _, exists := remote.files[path]; exists {
			t.Errorf("owned staged file was not removed: %s", path)
		}
		if !contains(remote.mutations, "upload "+path) || !contains(remote.mutations, "remove "+path) {
			t.Errorf("staged file was not actually created then removed by the test: %s mutations=%v", path, remote.mutations)
		}
	}
	for _, want := range []string{"rmdir /media/fat/_Arcade/jtreg-" + string(key.SessionID) + "-" + key.Nonce, "rmdir /media/fat/screenshots/circusc"} {
		if !contains(remote.mutations, want) {
			t.Errorf("task-owned empty directory was not removed: want %q in %v", want, remote.mutations)
		}
	}
}

func TestMiSTerRestoreBackupsSkipsUnchangedBytesAndVerifiesChangedRestore(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, _, _, _, _ := fakeMiSTerDriverFixture(t, remote)
	path := "/media/fat/MiSTer.ini"
	original := []byte("[MiSTer]\nMAIN=OriginalMain\n")
	local := filepath.Join(t.TempDir(), "MiSTer.ini")
	if err := os.WriteFile(local, original, 0600); err != nil {
		t.Fatal(err)
	}
	remote.files[path] = append([]byte(nil), original...)
	backup := miSTerFileBackup{Path: path, Exists: true, SHA256: digestBytes(original), Local: local}
	remote.mutations = nil
	if err := driver.restoreBackups(context.Background(), []miSTerFileBackup{backup}); err != nil {
		t.Fatal(err)
	}
	if len(remote.mutations) != 0 {
		t.Fatalf("unchanged MiSTer.ini caused remote writes: %v", remote.mutations)
	}
	remote.files[path] = []byte("[MiSTer]\nMAIN=CandidateMain\n")
	if err := driver.restoreBackups(context.Background(), []miSTerFileBackup{backup}); err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(remote.files[path], original) || !contains(remote.mutations, "write "+path) {
		t.Fatalf("changed MiSTer.ini was not restored and verified: bytes=%q mutations=%v", remote.files[path], remote.mutations)
	}
}

func TestValidMainNamedPathRejectsOutOfScopeAndInjectedPaths(t *testing.T) {
	for _, candidate := range []string{"/media/fat/screenshots/other/unrelated.png", "/media/fat/screenshots/circusc/owned.png;touch /tmp/nope", "/tmp/jtframe-capture-proof-session/../../etc/passwd"} {
		if err := validMainNamedPath(candidate, "/media/fat/screenshots/circusc"); err == nil {
			t.Errorf("unsafe Main-named output path accepted: %q", candidate)
		}
	}
	if err := validMainNamedPath("/media/fat/screenshots/circusc/cap_00001.png", "/media/fat/screenshots/circusc"); err != nil {
		t.Fatalf("valid Main output path rejected: %v", err)
	}
	for _, candidate := range []string{
		"/media/fat/screenshots/circusc/unrelated.png",
		"/media/fat/screenshots/circusc/20261117_123456-cabcap_other_0001.png",
		"/media/fat/screenshots/circusc/20261117_123456-cabcap_session_0001-extra.png",
		"/media/fat/screenshots/circusc/20261340_123456-cabcap_session_0001.png",
		"/media/fat/screenshots/circusc/NODATE-cabcap_session_0001_0000.png",
	} {
		if err := validMainCapturePNGPath(candidate, "/media/fat/screenshots/circusc", "session", 1); err == nil {
			t.Errorf("PNG path not bound to the attempt was accepted: %q", candidate)
		}
	}
	for _, candidate := range []string{
		"/media/fat/screenshots/circusc/20261117_123456-cabcap_session_0001.png",
		"/media/fat/screenshots/circusc/NODATE-cabcap_session_0001_0042.png",
	} {
		if err := validMainCapturePNGPath(candidate, "/media/fat/screenshots/circusc", "session", 1); err != nil {
			t.Errorf("Main-generated PNG name was rejected: %q: %v", candidate, err)
		}
	}
	if err := validMainCaptureRawPath("/tmp/jtframe-capture-proof/session-other-00001.rgb", "session", 1); err == nil {
		t.Fatal("raw RGB path for another session was accepted")
	}
}

func TestMiSTerOwnedDirectoryLedgerAcceptsOnlyAttemptPaths(t *testing.T) {
	root := "/media/fat/_Arcade/jtreg-session-nonce"
	ledger := miSTerBoardLedger{SessionID: "session", Nonce: "nonce", StagingRoot: root, StagingRootCreated: true,
		ScreenshotDir: "/media/fat/screenshots/circusc", OwnedDirs: []string{root, "/media/fat/screenshots/circusc"}}
	if err := validateMiSTerOwnedDirs(ledger); err != nil {
		t.Fatalf("valid attempt-owned directories rejected: %v", err)
	}
	ledger.OwnedDirs = append(ledger.OwnedDirs, "/media/fat/screenshots/other")
	if err := validateMiSTerOwnedDirs(ledger); err == nil {
		t.Fatal("quarantine ledger authorized removal of an unrelated directory")
	}
}

func TestRemoveSessionWorkspaceDeletesOnlyContainedAttemptDirectory(t *testing.T) {
	root := t.TempDir()
	workspace := filepath.Join(root, "mister-session-nonce")
	if err := os.Mkdir(workspace, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(workspace, "receipt.json"), []byte("receipt"), 0600); err != nil {
		t.Fatal(err)
	}
	sibling := filepath.Join(root, "keep")
	if err := os.WriteFile(sibling, []byte("preserve"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := removeSessionWorkspace(root, workspace); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(workspace); !os.IsNotExist(err) {
		t.Fatalf("completed local workspace remains: %v", err)
	}
	if data, err := os.ReadFile(sibling); err != nil || string(data) != "preserve" {
		t.Fatalf("cleanup changed an unrelated sibling: data=%q err=%v", data, err)
	}
	if err := removeSessionWorkspace(root, sibling); err == nil {
		t.Fatal("cleanup accepted a workspace without the owned attempt prefix")
	}
}

func TestMiSTerDriverRevalidatesBoardAfterClaimBeforeMutation(t *testing.T) {
	for _, test := range []struct {
		name   string
		mutate func(*fakeMiSTerRemote)
		probe  int
	}{
		{name: "snapshot changed", mutate: func(remote *fakeMiSTerRemote) {
			remote.probe.MainPID++
			remote.probe.ArgvRBF = "/media/fat/other.rbf"
		}},
		{name: "Main INI changed", mutate: func(remote *fakeMiSTerRemote) {
			remote.files["/media/fat/MiSTer.ini"] = []byte("[MiSTer]\nMAIN=OtherMain\n")
		}},
		{name: "loader asset changed", mutate: func(remote *fakeMiSTerRemote) {
			remote.files[remote.before.ArgvRBF] = []byte("concurrent RBF replacement")
		}},
		{name: "post-claim probe failed", probe: 3},
	} {
		t.Run(test.name, func(t *testing.T) {
			remote := newFakeMiSTerRemote()
			driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
			if test.mutate != nil {
				remote.afterCreate = func(string, []byte) { test.mutate(remote) }
			}
			remote.probeErrAt = test.probe
			capture, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
			if err == nil {
				t.Fatal("post-claim change or probe failure was accepted")
			}
			if !capture.Cleanup.Confirmed {
				t.Fatalf("owned lease cleanup was not confirmed: %+v", capture.Cleanup)
			}
			if len(remote.fifos) != 0 {
				t.Fatalf("capture/control FIFO writes occurred before post-claim validation: %q", remote.fifos)
			}
			if got := remote.mutations; len(got) != 2 || !strings.HasPrefix(got[0], "create /tmp/jtframe-regression-board-") || got[1] != "remove "+strings.TrimPrefix(got[0], "create ") {
				t.Fatalf("unexpected pre-mutation remote writes: %v", got)
			}
			if _, exists := remote.files["/tmp/jtframe-regression-board-mister-home.lock"]; exists {
				t.Fatal("owned board lease remained after confirmed cleanup")
			}
			for _, name := range remote.fileReads {
				if name == inputs.NativeStatusPath || name == "/media/fat/config/circusc.CFG" {
					t.Fatalf("configuration backup/read occurred before admission validation: %s", name)
				}
			}
			entries, readErr := os.ReadDir(capture.Workspace)
			if readErr != nil {
				t.Fatal(readErr)
			}
			for _, entry := range entries {
				if entry.Name() == "backup" {
					t.Fatal("local backup directory was created before admission validation")
				}
			}
			if _, statErr := os.Stat(filepath.Join(capture.Workspace, "backup")); !os.IsNotExist(statErr) {
				t.Fatalf("backup directory exists before admission validation: %v", statErr)
			}
		})
	}
}

func TestMiSTerDriverLeaseOnlyQuarantineNeverProgramsDuringRecovery(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	var ownedLease []byte
	remote.afterCreate = func(_ string, data []byte) {
		ownedLease = append([]byte(nil), data...)
		remote.probe.MainPID++
	}
	remote.removeErrPath = "/tmp/jtframe-regression-board-mister-home.lock"
	capture, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err == nil {
		t.Fatal("changed post-claim snapshot was accepted")
	}
	if capture.Cleanup.Confirmed || ownedLease == nil {
		t.Fatalf("expected durable lease-only quarantine, capture=%+v ownedLease=%t", capture.Cleanup, ownedLease != nil)
	}
	ledger, err := readMiSTerLedger(driver.ledgerPath)
	if err != nil {
		t.Fatal(err)
	}
	if ledger.State != "lease_only_quarantined" || !leaseOnlyMiSTerLedger(ledger) {
		t.Fatalf("pre-mutation failure did not persist lease-only recovery state: %+v", ledger)
	}
	if len(remote.fifos) != 0 || len(remote.mutations) != 1 || !strings.HasPrefix(remote.mutations[0], "create /tmp/jtframe-regression-board-") {
		t.Fatalf("pre-mutation quarantine caused writes/control: mutations=%v fifo=%q", remote.mutations, remote.fifos)
	}
	driver.releaseLock() // Model process loss: recovery must rely on the durable ledger.
	driver = &MiSTerSessionDriver{Config: driver.Config, Remote: remote}

	remote.files[ledger.RemoteLock] = []byte("foreign operator lease")
	reads := len(remote.fileReads)
	if _, err = driver.Reconcile(context.Background(), key); err == nil {
		t.Fatal("recovery removed a foreign lease")
	}
	if string(remote.files[ledger.RemoteLock]) != "foreign operator lease" {
		t.Fatal("foreign lease was changed")
	}
	if len(remote.fifos) != 0 || len(remote.mutations) != 1 || len(remote.fileReads) != reads {
		t.Fatalf("foreign-lease rejection probed/restored/programmed: mutations=%v fifo=%q reads=%d->%d", remote.mutations, remote.fifos, reads, len(remote.fileReads))
	}

	remote.files[ledger.RemoteLock] = ownedLease
	remote.removeErrPath = ""
	if cleanup, reconcileErr := driver.Reconcile(context.Background(), key); reconcileErr != nil || !cleanup.Confirmed {
		t.Fatalf("owned lease-only recovery failed: cleanup=%+v err=%v", cleanup, reconcileErr)
	}
	if len(remote.fifos) != 0 || len(remote.mutations) != 2 || remote.mutations[1] != "remove "+ledger.RemoteLock {
		t.Fatalf("lease-only recovery performed unrelated writes: mutations=%v fifo=%q", remote.mutations, remote.fifos)
	}
}

func TestMiSTerDriverRecoversClaimBeforeLockedLedgerSaveWithoutProgramming(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, _, _, key, _ := fakeMiSTerDriverFixture(t, remote)
	if err := driver.validateConfig(); err != nil {
		t.Fatal(err)
	}
	lockPath := "/tmp/jtframe-regression-board-" + string(key.Board) + ".lock"
	lockPayload, err := json.Marshal(struct {
		Board     BoardKey `json:"board"`
		SessionID string   `json:"session_id"`
		Nonce     string   `json:"nonce"`
	}{key.Board, key.SessionID, key.Nonce})
	if err != nil {
		t.Fatal(err)
	}
	remote.files[lockPath] = append([]byte(nil), lockPayload...)
	ledger := miSTerBoardLedger{Version: 1, Board: key.Board, SessionID: key.SessionID, Nonce: key.Nonce,
		RemoteLock: lockPath, RemoteLockSHA: digestBytes(lockPayload)}
	// A crash after CreateExclusive but before the subsequent "locked" ledger
	// write leaves the durable state at lock_pending. Reconcile must infer that
	// staging has not begun and release only the hash-matched lease.
	if err = driver.writeLedger(ledger, "lock_pending", ""); err != nil {
		t.Fatal(err)
	}
	driver.releaseLock()
	restarted := &MiSTerSessionDriver{Config: driver.Config, Remote: remote}
	cleanup, err := restarted.Reconcile(context.Background(), key)
	if err != nil || !cleanup.Confirmed {
		t.Fatalf("lock_pending lease-only recovery failed: cleanup=%+v err=%v", cleanup, err)
	}
	if _, exists := remote.files[lockPath]; exists || len(remote.fifos) != 0 || len(remote.mutations) != 1 || remote.mutations[0] != "remove "+lockPath || remote.probeCalls != 0 {
		t.Fatalf("lock_pending recovery did more than guarded lease removal: lease=%t mutations=%v fifo=%q probes=%d", remote.files[lockPath] != nil, remote.mutations, remote.fifos, remote.probeCalls)
	}
}

func TestMiSTerDriverRejectsAlternateMainINISelectionBeforeMutation(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	driver.Config.MainINIPath = "/media/fat/MiSTer_alt.ini"
	if _, err := driver.CapturePrepared(context.Background(), key, prepared, inputs); err == nil {
		t.Fatal("unsupported alternate Main INI selection was accepted")
	}
	if len(remote.mutations) != 0 || len(remote.fifos) != 0 {
		t.Fatalf("alternate INI rejection mutated the board: mutations=%v fifos=%q", remote.mutations, remote.fifos)
	}
}

func TestMiSTerDriverRejectsMenuOnlyArgvWithoutInferringCoreFromCaches(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	remote.before.ArgvRBF, remote.before.ArgvMRA = "", ""
	remote.probe.ArgvRBF, remote.probe.ArgvMRA = "", ""
	remote.before.CoreName, remote.probe.CoreName = "MENU", "MENU"
	remote.before.RBFName, remote.probe.RBFName = "MENU", "MENU"
	if _, err := driver.CapturePrepared(context.Background(), key, prepared, inputs); err == nil {
		t.Fatal("MENU-only startup without RBF/MRA argv was accepted using diagnostic cache names")
	}
	if len(remote.mutations) != 0 || len(remote.fifos) != 0 {
		t.Fatalf("unsupported MENU-only startup mutated the board: mutations=%v fifos=%q", remote.mutations, remote.fifos)
	}
}

func TestMiSTerDriverRejectsAmbiguousMainSelectionBeforeMutation(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	remote.files["/media/fat/MiSTer.ini"] = []byte("[MiSTer]\nMAIN=One\n[Alt]\nMAIN=Two\n")
	if _, err := driver.CapturePrepared(context.Background(), key, prepared, inputs); err == nil {
		t.Fatal("ambiguous original Main executable selection was accepted")
	}
	if len(remote.mutations) != 0 || len(remote.fifos) != 0 {
		t.Fatalf("ambiguous Main selection mutated the board: mutations=%v fifos=%q", remote.mutations, remote.fifos)
	}
}

func TestConfiguredMiSTerMainUsesDefaultOrExplicitSettingAndRejectsAmbiguity(t *testing.T) {
	for _, test := range []struct {
		name string
		ini  string
		want string
		bad  bool
	}{
		{name: "default", ini: "[MiSTer]\n", want: "MiSTer"},
		{name: "explicit", ini: "; MAIN=ignored\n[MiSTer]\nMAIN = OriginalMain ; comment\n", want: "OriginalMain"},
		{name: "same value in sections", ini: "MAIN=MiSTer\n[alt]\nMAIN=MiSTer\n", want: "MiSTer"},
		{name: "ambiguous values", ini: "MAIN=MiSTer\n[alt]\nMAIN=OtherMain\n", bad: true},
	} {
		t.Run(test.name, func(t *testing.T) {
			got, err := configuredMiSTerMain([]byte(test.ini))
			if test.bad {
				if err == nil {
					t.Fatalf("accepted ambiguous MAIN values: %q", got)
				}
				return
			}
			if err != nil || got != test.want {
				t.Fatalf("configured Main = %q, %v; want %q", got, err, test.want)
			}
		})
	}
}

func TestMiSTerDriverLedgerFailuresPrecedeProgramOrSessionCommands(t *testing.T) {
	for _, test := range []struct {
		name  string
		state string
		stage string
	}{
		{name: "initial file sync", state: "preparing", stage: "file-sync"},
		{name: "remote lock intent rename", state: "lock_pending", stage: "rename"},
		{name: "program intent directory sync", state: "loading", stage: "directory-sync"},
		{name: "session start intent directory sync", state: "starting", stage: "directory-sync"},
	} {
		t.Run(test.name, func(t *testing.T) {
			remote := newFakeMiSTerRemote()
			driver, prepared, inputs, key, originalCFG := fakeMiSTerDriverFixture(t, remote)
			remote.files[inputs.NativeStatusPath] = append([]byte(nil), originalCFG...)
			injected := false
			driver.ledgerStageHook = func(state, stage string) error {
				if !injected && state == test.state && stage == test.stage {
					injected = true
					return fmt.Errorf("simulated durable ledger stage failure")
				}
				return nil
			}
			result, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
			if err == nil || !injected {
				t.Fatalf("ledger failure was not observed: err=%v injected=%v", err, injected)
			}
			for _, command := range remote.fifos {
				text := string(command)
				if strings.HasPrefix(text, "cab_session_start ") {
					t.Fatal("session start was sent after its durable intent failed")
				}
				if test.state == "loading" && strings.HasPrefix(text, "load_core ") {
					t.Fatal("candidate programming began after its durable intent failed")
				}
			}
			if test.state == "starting" && strings.HasPrefix(string(remote.fifos[len(remote.fifos)-1]), "cab_stop ") {
				t.Fatal("CAB stop was sent although the durable start intent failed before START")
			}
			if !result.Cleanup.Confirmed {
				t.Fatalf("ledger pre-side-effect failure did not restore cleanly: %+v", result.Cleanup)
			}
			if (test.state == "preparing" || test.state == "lock_pending") && len(remote.mutations) != 0 {
				t.Fatalf("pre-side-effect ledger failure mutated the board: %v", remote.mutations)
			}
		})
	}
}

func TestAtomicLedgerReplaceSyncsFileThenRenameThenParentDirectory(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "board.ledger.json")
	var stages []string
	if err := atomicReplaceSynced(path, []byte("durable ledger\n"), func(stage string) error {
		stages = append(stages, stage)
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if got, err := os.ReadFile(path); err != nil || string(got) != "durable ledger\n" {
		t.Fatalf("ledger content after replacement = %q, %v", got, err)
	}
	want := []string{"file-sync", "rename", "directory-sync"}
	if fmt.Sprint(stages) != fmt.Sprint(want) {
		t.Fatalf("ledger durability order = %v, want %v", stages, want)
	}
	entries, err := os.ReadDir(dir)
	if err != nil || len(entries) != 1 || entries[0].Name() != filepath.Base(path) {
		t.Fatalf("temporary ledger files were left behind: %v %v", entries, err)
	}
}

func TestMiSTerDriverPinsAndRechecksOriginalLoaderHashes(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, originalCFG := fakeMiSTerDriverFixture(t, remote)
	remote.files[inputs.NativeStatusPath] = append([]byte(nil), originalCFG...)
	originalRBF := append([]byte(nil), remote.files[remote.before.ArgvRBF]...)
	remote.tamperOriginalPath = remote.before.ArgvRBF
	remote.tamperOriginalBytes = []byte("changed original RBF")
	result, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err == nil || result.Cleanup.Confirmed {
		t.Fatalf("changed original RBF was treated as safely restored: result=%+v err=%v", result, err)
	}
	ledger, err := readMiSTerLedger(driver.ledgerName())
	if err != nil || ledger.State != "quarantined" || ledger.OriginalRBFHash != digestBytes(originalRBF) {
		t.Fatalf("quarantine lacks the original loader hash: %+v %v", ledger, err)
	}
	fifoCount := len(remote.fifos)
	if _, err = driver.Reconcile(context.Background(), key); err == nil || len(remote.fifos) != fifoCount {
		t.Fatalf("reconcile used a changed original loader asset: fifo count %d→%d, err=%v", fifoCount, len(remote.fifos), err)
	}
	remote.files[remote.before.ArgvRBF] = originalRBF
	remote.tamperOriginalPath = ""
	remote.recoveryReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
		data, marshalErr := json.Marshal(validRecoveryReceipt(id, snapshot.MainPID))
		if marshalErr != nil {
			t.Fatal(marshalErr)
		}
		return data
	}
	if cleanup, err := driver.Reconcile(context.Background(), key); err != nil || !cleanup.Confirmed {
		t.Fatalf("restore did not recover after exact original asset bytes returned: %+v %v", cleanup, err)
	}
}

func TestMiSTerDriverClearsPriorAttemptNVRAMWhenNoSeedIsPrepared(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	filteredFiles := inputs.FixtureFiles[:0]
	for _, file := range inputs.FixtureFiles {
		if file.Role != FixtureDefaultRAM {
			filteredFiles = append(filteredFiles, file)
		}
	}
	inputs.FixtureFiles = filteredFiles
	filtered := prepared.Fixtures[:0]
	for _, fixture := range prepared.Fixtures {
		if fixture.Role != FixtureDefaultRAM {
			filtered = append(filtered, fixture)
		}
	}
	prepared.Fixtures = filtered
	if _, err := driver.CapturePrepared(context.Background(), key, prepared, inputs); err != nil {
		t.Fatal(err)
	}
	if len(remote.nvramAtLoad) != 0 {
		t.Fatalf("unprepared previous-session NVRAM leaked into candidate: %x", remote.nvramAtLoad)
	}
	if got := remote.files[remote.nvramPath]; string(got) != string([]byte{0xa1, 0xb2, 0xc3, 0xd4}) {
		t.Fatalf("original NVRAM was not restored after clearing it: %x", got)
	}
}

func TestVerifyMRAArchivesSupportsSplitZIPFixtures(t *testing.T) {
	remote := newFakeMiSTerRemote()
	_, prepared, inputs, _, _ := fakeMiSTerDriverFixture(t, remote)
	first := []byte("first split archive")
	second := []byte("second split archive")
	firstPath := filepath.Join(t.TempDir(), "split one.zip")
	secondPath := filepath.Join(t.TempDir(), "split-two.zip")
	if err := os.WriteFile(firstPath, first, 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(secondPath, second, 0600); err != nil {
		t.Fatal(err)
	}
	prepared.Fixtures = []FixtureDigest{
		{Role: FixtureROMArchive, SHA256: digestBytes(first)},
		{Role: FixtureROMArchive, SHA256: digestBytes(second)},
	}
	inputs.FixtureFiles = []MiSTerFixtureFile{
		{Role: FixtureROMArchive, SHA256: digestBytes(first), Path: firstPath},
		{Role: FixtureROMArchive, SHA256: digestBytes(second), Path: secondPath},
	}
	launch := []byte(`<mister><rom zip="split one.zip|split-two.zip"><part name="split.bin"/></rom></mister>`)
	if err := verifyMRAArchives(launch, prepared, &inputs); err != nil {
		t.Fatalf("valid split MRA dependencies rejected: %v", err)
	}
	inputs.FixtureFiles = inputs.FixtureFiles[:1]
	prepared.Fixtures = prepared.Fixtures[:1]
	if err := verifyMRAArchives(launch, prepared, &inputs); err != nil {
		t.Fatalf("a present first-success candidate was rejected because another fallback was absent: %v", err)
	}
	inputs.FixtureFiles = nil
	prepared.Fixtures = nil
	if err := verifyMRAArchives(launch, prepared, &inputs); err == nil {
		t.Fatal("MRA with no available candidate archive was accepted")
	}
	inputs.FixtureFiles = []MiSTerFixtureFile{{Role: FixtureROMArchive, SHA256: digestBytes(first), Path: firstPath}}
	prepared.Fixtures = []FixtureDigest{{Role: FixtureROMArchive, SHA256: digestBytes(first)}}
	inputs.FixtureFiles = append(inputs.FixtureFiles, MiSTerFixtureFile{Role: FixtureROMArchive, SHA256: digestBytes(second), Path: secondPath})
	prepared.Fixtures = append(prepared.Fixtures, FixtureDigest{Role: FixtureROMArchive, SHA256: digestBytes(second)})
	extraPath := filepath.Join(t.TempDir(), "extra.zip")
	if err := os.WriteFile(extraPath, []byte("extra"), 0600); err != nil {
		t.Fatal(err)
	}
	inputs.FixtureFiles = append(inputs.FixtureFiles, MiSTerFixtureFile{Role: FixtureROMArchive, SHA256: digestBytes([]byte("extra")), Path: extraPath})
	prepared.Fixtures = append(prepared.Fixtures, FixtureDigest{Role: FixtureROMArchive, SHA256: digestBytes([]byte("extra"))})
	if err := verifyMRAArchives(launch, prepared, &inputs); err == nil {
		t.Fatal("undeclared archive fixture was accepted")
	}
}

func TestVerifyMRAArchivesRequiresCandidateForEveryROMGroup(t *testing.T) {
	remote := newFakeMiSTerRemote()
	_, prepared, inputs, _, _ := fakeMiSTerDriverFixture(t, remote)
	root := t.TempDir()
	aPath := filepath.Join(root, "a.zip")
	cPath := filepath.Join(root, "c.zip")
	aData, cData := []byte("fixture A"), []byte("fixture C")
	if err := os.WriteFile(aPath, aData, 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(cPath, cData, 0600); err != nil {
		t.Fatal(err)
	}
	prepared.Fixtures = []FixtureDigest{{Role: FixtureROMArchive, SHA256: digestBytes(aData)}}
	inputs.FixtureFiles = []MiSTerFixtureFile{{Role: FixtureROMArchive, SHA256: digestBytes(aData), Path: aPath}}
	oneGroup := []byte(`<mister><rom zip="a.zip|b.zip"><part name="cpu.bin"/></rom></mister>`)
	twoGroups := []byte(`<mister><rom zip="a.zip|b.zip"><part name="cpu.bin"/></rom><rom zip="c.zip|d.zip"><part name="sound.bin"/></rom></mister>`)
	if err := verifyMRAArchives(oneGroup, prepared, &inputs); err != nil {
		t.Fatalf("valid missing fallback rejected: %v", err)
	}
	if err := verifyMRAArchives(twoGroups, prepared, &inputs); err == nil {
		t.Fatal("one supplied candidate made a second, unrelated ROM group acceptable")
	}
	prepared.Fixtures = append(prepared.Fixtures, FixtureDigest{Role: FixtureROMArchive, SHA256: digestBytes(cData)})
	inputs.FixtureFiles = append(inputs.FixtureFiles, MiSTerFixtureFile{Role: FixtureROMArchive, SHA256: digestBytes(cData), Path: cPath})
	if err := verifyMRAArchives(twoGroups, prepared, &inputs); err != nil {
		t.Fatalf("one usable candidate per ROM group rejected: %v", err)
	}
}

func TestVerifyMRAArchivesUsesEffectiveNamedPartReads(t *testing.T) {
	remote := newFakeMiSTerRemote()
	_, prepared, inputs, _, _ := fakeMiSTerDriverFixture(t, remote)
	archivePath := filepath.Join(t.TempDir(), "a.zip")
	archiveBytes := []byte("fixture A")
	if err := os.WriteFile(archivePath, archiveBytes, 0600); err != nil {
		t.Fatal(err)
	}
	prepared.Fixtures = []FixtureDigest{{Role: FixtureROMArchive, SHA256: digestBytes(archiveBytes)}}
	inputs.FixtureFiles = []MiSTerFixtureFile{{Role: FixtureROMArchive, SHA256: digestBytes(archiveBytes), Path: archivePath}}

	inlineOnly := []byte(`<mister><rom index="0" zip="a.zip|b.zip"><part name="cpu.bin"/></rom><rom index="1" zip="unused.zip"><part>01 02 FF</part></rom></mister>`)
	if err := verifyMRAArchives(inlineOnly, prepared, &inputs); err != nil {
		t.Fatalf("inline-only ROM incorrectly required its unused ZIP default: %v", err)
	}

	partOverride := []byte(`<mister><rom index="0" zip="unused-rom.zip"><part name="cpu.bin" zip="a.zip|b.zip"/></rom></mister>`)
	if err := verifyMRAArchives(partOverride, prepared, &inputs); err != nil {
		t.Fatalf("part-level candidate override was not used: %v", err)
	}

	missing := []byte(`<mister><rom index="0"><part name="missing.bin"/></rom></mister>`)
	if err := verifyMRAArchives(missing, PreparedSession{}, &MiSTerSessionInputs{}); err == nil || !strings.Contains(err.Error(), "no effective ZIP candidates") {
		t.Fatalf("named part without candidates should fail closed, got %v", err)
	}
}

func TestMiSTerDriverRestoresOriginallyAbsentNativeStatusFile(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	if _, exists := remote.files[inputs.NativeStatusPath]; exists {
		t.Fatal("fixture unexpectedly pre-created original CFG")
	}
	capture, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err != nil {
		t.Fatal(err)
	}
	manifest, err := decodeMiSTerCaptureManifestV2(remote.startFiles["/tmp/jtframe-capture-"+key.SessionID+".manifest.json"])
	if err != nil || len(manifest.Images) == 0 || len(capture.Receipt.Images) == 0 {
		t.Fatalf("capture image metadata missing: manifest=%+v receipt=%+v err=%v", manifest, capture.Receipt.Images, err)
	}
	firstRaw, err := decodeMiSTerCaptureImageReceiptV2(remote.startFiles[manifest.Images[0].ReceiptPath])
	if err != nil {
		t.Fatal(err)
	}
	wantMode, err := parseHex32(firstRaw.Mode)
	if err != nil {
		t.Fatal(err)
	}
	wantCRC, err := parseHex32(firstRaw.DescriptorCRC32)
	if err != nil {
		t.Fatal(err)
	}
	got := capture.Receipt.Images[0]
	if got.Mode != wantMode || got.DescriptorCRC32 != wantCRC {
		t.Fatalf("driver receipt descriptor metadata = mode %08x CRC %08x, want %08x/%08x", got.Mode, got.DescriptorCRC32, wantMode, wantCRC)
	}
	if _, exists := remote.files[inputs.NativeStatusPath]; exists {
		t.Fatal("temporary canonical status CFG remained after original path was absent")
	}
}

func TestMiSTerDriverQuarantinesUnverifiedLoaderOutcome(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	remote.loaded.ArgvRBF = "/media/fat/_Arcade/cores/wrong.rbf"
	driver.Config.LoadTimeout = 5 * time.Millisecond
	capture, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err == nil {
		t.Fatal("wrong loaded-core identity was accepted")
	}
	if capture.Key != key || errors.Is(err, ErrCaptureNotStarted) {
		t.Fatalf("post-lock loader failure was misclassified as preflight: capture=%+v err=%v", capture, err)
	}
	for _, record := range remote.fifos {
		if strings.HasPrefix(string(record), "cab_session_start ") {
			t.Fatal("capture started before the exact loader witness")
		}
	}
	if _, exists := remote.files["/tmp/jtframe-regression-board-mister-home.lock"]; !exists {
		t.Fatal("uncertain loader outcome released the remote lock")
	}
}

func TestMiSTerDriverCancelDuringCaptureUsesIndependentCleanup(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	driver.Config.CaptureTimeout = 2 * time.Second
	remote.withholdStatus = true
	remote.started = make(chan struct{}, 1)
	remote.stopSent = make(chan struct{}, 1)
	status, err := decodeMiSTerCaptureStatusV2(remote.startFiles["/tmp/jtframe-capture-"+key.SessionID+".json"])
	if err != nil {
		t.Fatal(err)
	}
	status.State, status.ScheduleState = "cancelled", "cancelled"
	remote.stopStatus, err = json.Marshal(status)
	if err != nil {
		t.Fatal(err)
	}
	type result struct {
		capture SessionCapture
		err     error
	}
	done := make(chan result, 1)
	go func() {
		capture, captureErr := driver.CapturePrepared(context.Background(), key, prepared, inputs)
		done <- result{capture: capture, err: captureErr}
	}()
	select {
	case <-remote.started:
	case <-time.After(time.Second):
		t.Fatal("combined session start was not sent")
	}
	if err = driver.Cancel(context.Background(), key); err != nil {
		t.Fatalf("bounded independent cancel failed: %v", err)
	}
	select {
	case <-remote.stopSent:
	case <-time.After(time.Second):
		t.Fatal("CAB STOP was not sent independently during capture wait")
	}
	completed := <-done
	if completed.err == nil || !completed.capture.Cleanup.Confirmed {
		t.Fatalf("cancel did not return interrupted work with confirmed cleanup: %+v %v", completed.capture.Cleanup, completed.err)
	}
}

func TestMiSTerDriverDoesNotOverwriteConflictingROMArchive(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	conflict := []byte("different content at the referenced ZIP name")
	remote.files["/media/fat/games/mame/circus.zip"] = append([]byte(nil), conflict...)
	if _, err := driver.CapturePrepared(context.Background(), key, prepared, inputs); err == nil {
		t.Fatal("different preexisting ROM archive content was overwritten or accepted")
	}
	if string(remote.files["/media/fat/games/mame/circus.zip"]) != string(conflict) {
		t.Fatal("conflicting preexisting ROM archive changed")
	}
	for _, record := range remote.fifos {
		if strings.HasPrefix(string(record), "load_core ") || strings.HasPrefix(string(record), "cab_session_start ") {
			t.Fatal("board programming began despite a staging collision")
		}
	}
	if _, exists := remote.files["/tmp/jtframe-regression-board-mister-home.lock"]; exists {
		t.Fatal("clean pre-load collision left the remote lock owned")
	}
}

func TestMiSTerDriverRejectsStaleSessionStatusBeforeLoad(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	statusPath := "/tmp/jtframe-capture-" + key.SessionID + ".json"
	stale := []byte(`{"protocol":"old-session"}`)
	remote.files[statusPath] = append([]byte(nil), stale...)
	if _, err := driver.CapturePrepared(context.Background(), key, prepared, inputs); err == nil {
		t.Fatal("preexisting same-session status path was accepted")
	}
	if string(remote.files[statusPath]) != string(stale) {
		t.Fatal("foreign preexisting status file was overwritten or removed")
	}
	for _, record := range remote.fifos {
		if strings.HasPrefix(string(record), "load_core ") || strings.HasPrefix(string(record), "cab_session_start ") {
			t.Fatal("board was programmed despite a stale status-path collision")
		}
	}
}

func TestMiSTerDriverKeepsQuarantineIfStopIsUnconfirmed(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, originalCFG := fakeMiSTerDriverFixture(t, remote)
	remote.files[inputs.NativeStatusPath] = append([]byte(nil), originalCFG...)
	remote.failStop = true
	statusPath := "/tmp/jtframe-capture-" + key.SessionID + ".json"
	status, err := decodeMiSTerCaptureStatusV2(remote.startFiles[statusPath])
	if err != nil {
		t.Fatal(err)
	}
	status.Fault = 10
	remote.startFiles[statusPath], err = json.Marshal(status)
	if err != nil {
		t.Fatal(err)
	}
	capture, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err == nil || capture.Cleanup.Confirmed || !capture.Cleanup.Required {
		t.Fatalf("expected failed cleanup and quarantine, got capture=%+v err=%v", capture.Cleanup, err)
	}
	if _, exists := remote.files["/tmp/jtframe-regression-board-mister-home.lock"]; !exists {
		t.Fatal("uncertain cleanup removed the remote board lock")
	}
	ledger, readErr := readMiSTerLedger(driver.ledgerName())
	if readErr != nil || ledger.State != "quarantined" || ledger.RemoteLock == "" {
		t.Fatalf("uncertain cleanup did not persist quarantine ownership: %+v %v", ledger, readErr)
	}
	if ledger.NVRAMPath != remote.nvramPath || ledger.NVRAMSeedSHA256 != digestBytes([]byte{0x12, 0x34, 0x56, 0x78}) {
		t.Fatalf("quarantine ledger did not separate candidate NVRAM path and seed identity: %+v", ledger)
	}
	foundBackup := false
	for _, backup := range ledger.Backups {
		if backup.Path == remote.nvramPath && backup.Exists && backup.SHA256 == digestBytes([]byte{0xa1, 0xb2, 0xc3, 0xd4}) {
			foundBackup = true
		}
	}
	if !foundBackup {
		t.Fatal("quarantine ledger omitted exact original NVRAM bytes/identity")
	}
	remote.failStop = false
	driver.Config.LoadTimeout = 5 * time.Millisecond
	rbfBytes := append([]byte(nil), remote.files[ledger.ExpectedRBFArgv]...)
	remote.files[ledger.ExpectedRBFArgv] = []byte("tampered staged RBF")
	fifoCount := len(remote.fifos)
	if _, err = driver.Reconcile(context.Background(), key); err == nil {
		t.Fatal("changed staged RBF was loaded during reconciliation")
	}
	if len(remote.fifos) != fifoCount {
		t.Fatal("loader was invoked before staged RBF hash validation")
	}
	remote.files[ledger.ExpectedRBFArgv] = rbfBytes
	remote.ignoreLoad = true
	if _, err = driver.Reconcile(context.Background(), key); err == nil {
		t.Fatal("unobserved normal full-RBF load cleared the quarantine")
	}
	for _, record := range remote.fifos[fifoCount:] {
		if strings.HasPrefix(string(record), "cab_capture_recover ") {
			t.Fatal("recovery command was sent without a new full-load witness")
		}
	}
	remote.ignoreLoad = false
	remote.recoveryReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
		receipt := validRecoveryReceipt(id, snapshot.MainPID)
		receipt.CAPSWords[3] = 1
		data, marshalErr := json.Marshal(receipt)
		if marshalErr != nil {
			t.Fatal(marshalErr)
		}
		return data
	}
	if _, err = driver.Reconcile(context.Background(), key); err == nil {
		t.Fatal("dirty recovery CAPS receipt cleared the quarantine")
	}
	if _, exists := remote.files[ledger.RemoteLock]; !exists {
		t.Fatal("failed recovery proof released the owned remote board lock")
	}
	if _, err = os.Stat(driver.ledgerName()); err != nil {
		t.Fatal("failed recovery proof removed the quarantine ledger")
	}
	remote.recoveryReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
		data, marshalErr := json.Marshal(validRecoveryReceipt(id, snapshot.MainPID))
		if marshalErr != nil {
			t.Fatal(marshalErr)
		}
		return data
	}
	remote.recoveryCoreName, remote.recoveryRBFName = "stale-cached-core", "stale-cached-rbf"
	remote.restoreCoreName = "restored-core-cache"
	remote.restoreRBFName = "JTFLSTORY" // RBFNAME still names the candidate after the restore command.
	if cleanup, err := driver.Reconcile(context.Background(), key); err != nil || !cleanup.Confirmed {
		t.Fatalf("stale cached RBFNAME blocked exact argv-based restoration: %+v %v", cleanup, err)
	}
	if string(remote.nativeStatusAtRestoreLoad) != string(originalCFG) {
		t.Fatalf("Reconcile loaded original core before restoring its CFG: %x", remote.nativeStatusAtRestoreLoad)
	}
	if string(remote.nvramAtRestoreLoad) != string([]byte{0xa1, 0xb2, 0xc3, 0xd4}) {
		t.Fatalf("Reconcile loaded original core before restoring NVRAM: %x", remote.nvramAtRestoreLoad)
	}
	if _, exists := remote.files[ledger.RemoteLock]; exists {
		t.Fatal("verified original argv/hash/bridge restoration retained the board lock due to stale cache")
	}
}

func fakeMiSTerDriverFixture(t *testing.T, remote *fakeMiSTerRemote) (*MiSTerSessionDriver, PreparedSession, MiSTerSessionInputs, AttemptKey, []byte) {
	t.Helper()
	assertNativeMainMockDescriptor(t)
	// The native Main v2 mock outputs under artifacts/main-protocol-v2-mock-fixtures
	// define the live schema and descriptor layout. Keep this fixture on the same
	// checkpoint 1 -> interval 0 path using a decodable PNG for the Go validator.
	capture := newMiSTerCaptureV2Fixture(t)
	local := t.TempDir()
	qualifiedMain := []byte("qualified recovery-capable Main executable")
	remote.before.MainSHA256 = digestBytes(qualifiedMain)
	remote.probe.MainSHA256 = remote.before.MainSHA256
	remote.files[remote.before.MainExePath] = append([]byte(nil), qualifiedMain...)
	remote.files[remote.before.ArgvMRA] = []byte("original menu MRA asset")
	remote.files[remote.before.ArgvRBF] = []byte("original menu RBF asset")
	remote.files["/media/fat/MiSTer.ini"] = []byte("[MiSTer]\nMAIN=OriginalMain\n")
	remote.restoreWatchedPaths = append(remote.restoreWatchedPaths, "/media/fat/MiSTer.ini")
	remote.files["/media/fat/OriginalMain"] = append([]byte(nil), qualifiedMain...)
	remote.restoreMainPath = "/media/fat/OriginalMain"
	remote.restoreMainHash = digestBytes(remote.files[remote.restoreMainPath])
	prepared := capture.expected.Prepared
	prepared.Core = "circus"
	prepared.Profile.Video, prepared.Profile.Startup = 4, 0
	inputs := MiSTerSessionInputs{FixturePaths: make(map[FixtureRole]string), PackedCABPath: filepath.Join(local, "reg.cab"),
		NativeStatusPath: "/media/fat/config/circusc.CFG", RBFStem: "jt224-circus-r1", ExpectedCoreName: "circusc", ExpectedRBFName: "JTCIRCUS"}
	writeFixture := func(name string, data []byte) string {
		t.Helper()
		path := filepath.Join(local, name)
		if err := os.WriteFile(path, data, 0600); err != nil {
			t.Fatal(err)
		}
		return path
	}
	originalMRA := []byte(`<mister><rbf>circus</rbf><rom zip="circus.zip"><part name="game.bin"/></rom><nvram index="2" size="4"/></mister>`)
	launchMRA := []byte(`<mister><rbf>jt224-circus-r1</rbf><rom zip="circus.zip"><part name="game.bin"/></rom><nvram index="2" size="4"/></mister>`)
	rbf := []byte("deterministic fake rbf")
	rom := []byte("deterministic fake zip")
	defaultNVRAM := []byte{0x12, 0x34, 0x56, 0x78}
	packed := capture.expected.PackedCAB
	inputs.FixturePaths[FixtureOriginalMRA] = writeFixture("original.mra", originalMRA)
	inputs.FixturePaths[FixtureLaunchMRA] = writeFixture("launch 'quoted'.mra", launchMRA)
	inputs.FixturePaths[FixtureRBF] = writeFixture("circus.rbf", rbf)
	romPath := writeFixture("circus.zip", rom)
	defaultNVRAMPath := writeFixture("circus-default.nvm", defaultNVRAM)
	inputs.FixtureFiles = []MiSTerFixtureFile{
		{Role: FixtureROMArchive, SHA256: digestBytes(rom), Path: romPath},
		{Role: FixtureDefaultRAM, SHA256: digestBytes(defaultNVRAM), Path: defaultNVRAMPath},
	}
	if err := os.WriteFile(inputs.PackedCABPath, packed, 0600); err != nil {
		t.Fatal(err)
	}
	prepared.OriginalMRA.SHA256 = digestBytes(originalMRA)
	prepared.LaunchMRA.SHA256 = digestBytes(launchMRA)
	prepared.RBF.SHA256 = digestBytes(rbf)
	prepared.Fixtures[0].SHA256 = digestBytes(rom)
	prepared.Fixtures = append(prepared.Fixtures, FixtureDigest{Role: FixtureDefaultRAM, SHA256: digestBytes(defaultNVRAM)})
	prepared.CAB = capture.expected.Prepared.CAB
	prepared.CAB.PackedSHA256 = digestBytes(packed)
	prepared.CAB.TotalFrames = 4
	inputs.FixturePaths[FixtureOriginalMRA] = filepath.Clean(inputs.FixturePaths[FixtureOriginalMRA])
	prepared.Paths.OriginalMRA = inputs.FixturePaths[FixtureOriginalMRA]
	prepared.Paths.LaunchMRA = inputs.FixturePaths[FixtureLaunchMRA]
	key := capture.expected.Attempt
	key.Board = "mister-home"
	fixture := capture
	fixture.expected.Prepared = prepared
	fixture.expected.Attempt = key
	plan, err := EncodeCapturePlan(packed, capturePlanForPrepared(prepared, 1000))
	if err != nil {
		t.Fatal(err)
	}
	planCRC := uint32(plan[len(plan)-4]) | uint32(plan[len(plan)-3])<<8 | uint32(plan[len(plan)-2])<<16 | uint32(plan[len(plan)-1])<<24
	fixture.expected.PlanCRC32 = planCRC
	planCRCText := fmt.Sprintf("%08x", planCRC)
	status, err := decodeMiSTerCaptureStatusV2(fixture.status)
	if err != nil {
		t.Fatal(err)
	}
	status.ScheduleCRC32 = planCRCText
	fixture.status, err = json.Marshal(status)
	if err != nil {
		t.Fatal(err)
	}
	manifestV2, err := decodeMiSTerCaptureManifestV2(fixture.manifest)
	if err != nil {
		t.Fatal(err)
	}
	manifestV2.PlanCRC32 = planCRCText
	for index, ref := range manifestV2.Images {
		manifestV2.Images[index].PlanCRC32 = planCRCText
		receipt, decodeErr := decodeMiSTerCaptureImageReceiptV2(fixture.files.ReceiptJSON[ref.ReceiptPath])
		if decodeErr != nil {
			t.Fatal(decodeErr)
		}
		receipt.PlanCRC32 = planCRCText
		fixture.files.ReceiptJSON[ref.ReceiptPath], err = json.Marshal(receipt)
		if err != nil {
			t.Fatal(err)
		}
		if err = os.WriteFile(fixture.files.ReceiptLocal[ref.ReceiptPath], fixture.files.ReceiptJSON[ref.ReceiptPath], 0600); err != nil {
			t.Fatal(err)
		}
	}
	fixture.manifest, err = json.Marshal(manifestV2)
	if err != nil {
		t.Fatal(err)
	}
	manifest, err := decodeMiSTerCaptureManifestV2(fixture.manifest)
	if err != nil {
		t.Fatal(err)
	}
	cabStatus, err := json.Marshal(miSTerCABProgressV2{Protocol: "jtframe-cab-host-v2", Session: key.SessionID,
		State: "done", Reason: "complete", Frame: manifest.CABTerminal.Frames, FramesTotal: manifest.CABTerminal.FramesTotal,
		EventsAccepted: manifest.CABTerminal.EventsAccepted, EventsApplied: manifest.CABTerminal.EventsApplied,
		EventsTotal: manifest.CABTerminal.EventsTotal, CleanupConfirmed: true})
	remote.startFiles = map[string][]byte{
		"/tmp/jtframe-capture-" + key.SessionID + ".json":          fixture.status,
		"/tmp/jtframe-capture-" + key.SessionID + ".manifest.json": fixture.manifest,
		"/tmp/jtframe-cab-" + key.SessionID + ".json":              cabStatus,
	}
	for receiptPath, data := range fixture.files.ReceiptJSON {
		remote.startFiles[receiptPath] = data
	}
	for pngPath, localPNG := range fixture.files.PNGLocal {
		data, readErr := os.ReadFile(localPNG)
		if readErr != nil {
			t.Fatal(readErr)
		}
		remote.startFiles[pngPath] = data
	}
	remote.loadMRA = attemptLaunchMRAPath(key)
	remote.loadRBF = "/media/fat/_Arcade/cores/jt224-circus-r1.rbf"
	remote.loadStem = inputs.RBFStem
	remote.nvramPath = "/media/fat/config/nvram/jtcap-" + key.SessionID + "-" + key.Nonce + ".nvm"
	remote.files[remote.nvramPath] = []byte{0xa1, 0xb2, 0xc3, 0xd4}
	restoreSettings := map[string][]byte{
		"/media/fat/config/arcade.ini": []byte("original arcade settings\n"),
		"/media/fat/config/arcade.dip": []byte{0x05, 0x06, 0x07},
	}
	for path, data := range restoreSettings {
		remote.files[path] = append([]byte(nil), data...)
		remote.restoreWatchedPaths = append(remote.restoreWatchedPaths, path)
	}
	remote.loaded = MiSTerBoardSnapshot{MainPID: 101, HostName: remote.before.HostName, MainExePath: "/media/fat/Main", MainSHA256: remote.before.MainSHA256,
		CoreName: "circusc", RBFName: inputs.ExpectedRBFName, ArgvRBF: remote.loadRBF, ArgvMRA: remote.loadMRA,
		FPGAState: "operating", BridgeStates: map[string]string{"/sys/class/fpga_bridge/br0/state": "enabled"}}
	originalCFG := []byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}
	driver := &MiSTerSessionDriver{Remote: remote, Config: MiSTerDriverConfig{BoardKey: key.Board, MainSHA256: remote.before.MainSHA256,
		LocalStateDir: filepath.Join(local, "state"), WorkspaceDir: filepath.Join(local, "work"),
		RestoreMRAPath: remote.before.ArgvMRA, RestoreRBFPath: remote.before.ArgvRBF,
		MainINIPath:    "/media/fat/MiSTer.ini",
		RestoreFiles:   []string{"/media/fat/config/arcade.ini", "/media/fat/config/arcade.dip"},
		CommandTimeout: time.Second, LoadTimeout: 2 * time.Second, CaptureTimeout: time.Second,
		CleanupTimeout: time.Second, PollInterval: time.Millisecond, MaxHoldMS: 1000, ExpectedBridgeCount: 1},
		Now: func() time.Time { return time.Now() }, Sleep: func(context.Context, time.Duration) error { return nil }}
	remote.ledgerPath = driver.ledgerName()
	return driver, prepared, inputs, key, originalCFG
}

func assertNativeMainMockDescriptor(t *testing.T) {
	t.Helper()
	status, err := decodeMiSTerCaptureStatusV2([]byte(mainMockCaptureStatusV2JSON))
	if err != nil || status.Protocol != "jtframe-capture-session-v2" || status.CaptureProtocol != miSTerCaptureProtocolV2 {
		t.Fatalf("native Main mock status schema was rejected: %v", err)
	}
	var cabStatus miSTerCABProgressV2
	if err = strictJSONDecode([]byte(mainMockCABStatusV2JSON), 64<<10, cabProgressV2Keys, &cabStatus); err != nil ||
		cabStatus.Protocol != "jtframe-cab-host-v2" || cabStatus.State != "done" || cabStatus.Frame != 4 ||
		cabStatus.EventsAccepted != 2 || cabStatus.EventsApplied != 2 || cabStatus.EventsTotal != 2 || !cabStatus.CleanupConfirmed {
		t.Fatalf("native Main mock CAB status schema was rejected: %v", err)
	}
	descriptor, err := hex.DecodeString(mainMockCheckpoint100DescriptorHex)
	if err != nil || len(descriptor) != 64 || string(descriptor[:4]) != "JTC2" || string(descriptor[60:64]) != "RDY2" ||
		binary.LittleEndian.Uint16(descriptor[8:10]) != 100 || binary.LittleEndian.Uint16(descriptor[10:12]) != 99 ||
		crc32.ChecksumIEEE(descriptor[:56]) != binary.LittleEndian.Uint32(descriptor[56:60]) {
		t.Fatalf("native Main mock descriptor does not retain the v2 JTC2/RDY2 checkpoint-100 -> interval-99 contract: %v", err)
	}
	header := make([]byte, 256)
	copy(header[:16], []byte{1, 1, 1, 0, 0, 16, 0, 87, 0, 9, 2, 0, 0, 87, 0, 9})
	copy(header[192:], descriptor)
	if crc32.ChecksumIEEE(header) != 0x9a8e79da {
		t.Fatalf("native Main mock header did not preserve the checked JTC2 bytes, CRC=%08x", crc32.ChecksumIEEE(header))
	}
}
