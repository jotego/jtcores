/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// rebootFakeRemote models a board that comes back with a new Main PID after
// each reboot. healthyAfterReboot controls whether that Main is qualified.
type rebootFakeRemote struct {
	MiSTerRemote
	files              map[string][]byte
	snapshot           MiSTerBoardSnapshot
	mainSHA            string
	healthyAfterReboot bool
	reboots            int
	removed            []string
	fifo               []string
}

func (r *rebootFakeRemote) Probe(context.Context) (MiSTerBoardSnapshot, error) {
	return cloneMiSTerBoardSnapshot(r.snapshot), nil
}

func (r *rebootFakeRemote) Reboot(context.Context) error {
	r.reboots++
	r.snapshot.MainPID += 100
	// The boot scripts start Main without an RBF argument.
	r.snapshot.ArgvRBF, r.snapshot.ArgvMRA = "", ""
	if r.healthyAfterReboot {
		r.snapshot.MainSHA256 = r.mainSHA
	}
	return nil
}

func (r *rebootFakeRemote) File(_ context.Context, name string, _ int64) ([]byte, bool, error) {
	data, ok := r.files[name]
	return append([]byte(nil), data...), ok, nil
}

func (r *rebootFakeRemote) WriteFile(_ context.Context, name string, data []byte) error {
	r.files[name] = append([]byte(nil), data...)
	return nil
}

func (r *rebootFakeRemote) RemoveOwned(_ context.Context, name, sha string) error {
	data, ok := r.files[name]
	if !ok {
		return nil
	}
	if digestBytes(data) != sha {
		return errors.New("owned file changed")
	}
	delete(r.files, name)
	r.removed = append(r.removed, name)
	return nil
}

func (r *rebootFakeRemote) RemoveEmptyDir(context.Context, string) error { return nil }

func (r *rebootFakeRemote) WriteFIFO(_ context.Context, record []byte, _ time.Duration) error {
	r.fifo = append(r.fifo, string(record))
	if string(record) == "load_core menu.rbf\n" {
		r.snapshot.MainPID++
		r.snapshot.ArgvRBF, r.snapshot.ArgvMRA = "menu.rbf", ""
	}
	return nil
}

func newRebootTestDriver(t *testing.T, remote *rebootFakeRemote) *MiSTerSessionDriver {
	t.Helper()
	remote.mainSHA = strings.Repeat("c", 64)
	if remote.snapshot.MainSHA256 == "" {
		remote.snapshot.MainSHA256 = remote.mainSHA
	}
	remote.snapshot.MainPID = 10
	remote.snapshot.FPGAState = "operating"
	remote.snapshot.BridgeStates = map[string]string{"/sys/class/fpga_bridge/br0/state": "enabled"}
	if remote.files == nil {
		remote.files = map[string][]byte{}
	}
	base := t.TempDir()
	driver := &MiSTerSessionDriver{Config: MiSTerDriverConfig{BoardKey: "mister-home", MainSHA256: remote.mainSHA,
		MainINIPath: "/media/fat/MiSTer.ini", LocalStateDir: filepath.Join(base, "state"), WorkspaceDir: filepath.Join(base, "work"),
		CommandTimeout: time.Second, LoadTimeout: time.Second, CaptureTimeout: time.Second, CleanupTimeout: time.Second,
		PollInterval: time.Millisecond, MaxHoldMS: capturePlanMinHoldMS, ExpectedBridgeCount: 1},
		Remote: remote, Sleep: func(context.Context, time.Duration) error { return nil }}
	// Each clock read advances 30 s so a reboot that never finishes times out quickly.
	now := time.Unix(0, 0)
	driver.Now = func() time.Time { now = now.Add(30 * time.Second); return now }
	if err := driver.ValidateLocalConfig(); err != nil {
		t.Fatal(err)
	}
	return driver
}

// writeRebootTestLedger leaves the ledger of a failed attempt: MiSTer.ini was
// changed on the board and a staged RBF is still there.
func writeRebootTestLedger(t *testing.T, driver *MiSTerSessionDriver, remote *rebootFakeRemote) {
	t.Helper()
	original := []byte("[MiSTer]\nvideo_mode=8\n")
	backupDir := filepath.Join(driver.Config.WorkspaceDir, "session", "backup")
	if err := os.MkdirAll(backupDir, 0700); err != nil {
		t.Fatal(err)
	}
	local := filepath.Join(backupDir, "MiSTer.ini")
	if err := os.WriteFile(local, original, 0600); err != nil {
		t.Fatal(err)
	}
	staged := []byte("staged candidate rbf")
	remote.files["/media/fat/MiSTer.ini"] = []byte("[MiSTer]\nvideo_mode=0\n")
	remote.files["/media/fat/_Arcade/cores/jt224-x.rbf"] = staged
	ledger := miSTerBoardLedger{Version: 1, Board: driver.Config.BoardKey, SessionID: "s1", Nonce: "n1", BackupDir: backupDir,
		OriginalLoaderKind: "menu-rbf",
		Backups:            []miSTerFileBackup{{Path: "/media/fat/MiSTer.ini", Exists: true, SHA256: digestBytes(original), Local: local}},
		OwnedFiles:         []miSTerOwnedRemoteFile{{Path: "/media/fat/_Arcade/cores/jt224-x.rbf", SHA256: digestBytes(staged), Owned: true}}}
	if err := driver.writeLedger(ledger, "quarantined", "capture_target_late"); err != nil {
		t.Fatal(err)
	}
}

func TestMiSTerHealthyRecoversStaleLedgerByReboot(t *testing.T) {
	remote := &rebootFakeRemote{healthyAfterReboot: true}
	driver := newRebootTestDriver(t, remote)
	writeRebootTestLedger(t, driver, remote)
	if err := driver.Healthy(context.Background()); err != nil {
		t.Fatalf("stale ledger was not recovered: %v", err)
	}
	if remote.reboots != 1 {
		t.Fatalf("expected one reboot, got %d", remote.reboots)
	}
	if string(remote.files["/media/fat/MiSTer.ini"]) != "[MiSTer]\nvideo_mode=8\n" {
		t.Fatalf("MiSTer.ini was not restored: %q", remote.files["/media/fat/MiSTer.ini"])
	}
	if _, exists := remote.files["/media/fat/_Arcade/cores/jt224-x.rbf"]; exists {
		t.Fatal("staged candidate was left on the board")
	}
	if _, err := os.Lstat(driver.ledgerName()); !os.IsNotExist(err) {
		t.Fatalf("ledger survived recovery: %v", err)
	}
	if remote.snapshot.ArgvRBF != "menu.rbf" || len(remote.fifo) != 1 {
		t.Fatalf("MENU was not loaded through Main after boot: argv=%q fifo=%q", remote.snapshot.ArgvRBF, remote.fifo)
	}
	if err := driver.Healthy(context.Background()); err != nil || remote.reboots != 1 {
		t.Fatalf("healthy board was rebooted again: reboots=%d err=%v", remote.reboots, err)
	}
}

func TestMiSTerRecoveryAcceptsRestoredFileWithoutLocalBackup(t *testing.T) {
	remote := &rebootFakeRemote{healthyAfterReboot: true}
	driver := newRebootTestDriver(t, remote)
	writeRebootTestLedger(t, driver, remote)
	// The board already has the original MiSTer.ini, but the local copy is gone.
	remote.files["/media/fat/MiSTer.ini"] = []byte("[MiSTer]\nvideo_mode=8\n")
	if err := os.RemoveAll(filepath.Join(driver.Config.WorkspaceDir, "session")); err != nil {
		t.Fatal(err)
	}
	if err := driver.Healthy(context.Background()); err != nil {
		t.Fatalf("matching board file still needed the lost local backup: %v", err)
	}
	// A board file that differs cannot be restored without the backup.
	remote = &rebootFakeRemote{healthyAfterReboot: true}
	driver = newRebootTestDriver(t, remote)
	writeRebootTestLedger(t, driver, remote)
	if err := os.RemoveAll(filepath.Join(driver.Config.WorkspaceDir, "session")); err != nil {
		t.Fatal(err)
	}
	if err := driver.Healthy(context.Background()); err == nil || !strings.Contains(err.Error(), "MiSTer.ini") {
		t.Fatalf("changed MiSTer.ini without a backup was accepted: %v", err)
	}
}

func TestMiSTerHealthyLoadsMenuAfterFreshBoot(t *testing.T) {
	remote := &rebootFakeRemote{healthyAfterReboot: true}
	driver := newRebootTestDriver(t, remote)
	remote.snapshot.ArgvRBF = ""
	if err := driver.Healthy(context.Background()); err != nil || remote.reboots != 0 || remote.snapshot.ArgvRBF != "menu.rbf" {
		t.Fatalf("freshly booted board did not get MENU loaded: reboots=%d argv=%q err=%v", remote.reboots, remote.snapshot.ArgvRBF, err)
	}
}

func TestMiSTerRecoveryToleratesMissingStagedFiles(t *testing.T) {
	remote := &rebootFakeRemote{healthyAfterReboot: true}
	driver := newRebootTestDriver(t, remote)
	writeRebootTestLedger(t, driver, remote)
	// The case seen on hardware: the staged candidate was already removed.
	delete(remote.files, "/media/fat/_Arcade/cores/jt224-x.rbf")
	cleanup, err := driver.Reconcile(context.Background(), AttemptKey{Board: "mister-home", SessionID: "s1", Nonce: "n1"})
	if err != nil || !cleanup.Confirmed || cleanup.Required || !strings.Contains(cleanup.Message, "recovered by reboot") {
		t.Fatalf("missing staged files blocked recovery: cleanup=%+v err=%v", cleanup, err)
	}
	if remote.reboots != 1 {
		t.Fatalf("expected one reboot, got %d", remote.reboots)
	}
}

func TestMiSTerHealthyRebootsUnqualifiedBoard(t *testing.T) {
	remote := &rebootFakeRemote{healthyAfterReboot: true, snapshot: MiSTerBoardSnapshot{MainSHA256: strings.Repeat("d", 64)}}
	driver := newRebootTestDriver(t, remote)
	if err := driver.Healthy(context.Background()); err != nil || remote.reboots != 1 {
		t.Fatalf("unqualified board was not rebooted back to health: reboots=%d err=%v", remote.reboots, err)
	}
	broken := &rebootFakeRemote{snapshot: MiSTerBoardSnapshot{MainSHA256: strings.Repeat("d", 64)}}
	driver = newRebootTestDriver(t, broken)
	if err := driver.Healthy(context.Background()); err == nil || !strings.Contains(err.Error(), "after reboot") {
		t.Fatalf("board that stays unqualified after reboot was accepted: %v", err)
	}
}
