/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestRunCommitMiSTerPinsArchiveIdentityInSelectedLane(t *testing.T) {
	root := t.TempDir()
	progressRoot := filepath.Join(root, "progress")
	if err := os.Mkdir(progressRoot, 0750); err != nil { t.Fatal(err) }
	if err := GuardCaptureTarget(progressRoot, "mister"); err != nil { t.Fatal(err) }
	if err := os.MkdirAll(filepath.Join(progressRoot, "log"), 0750); err != nil {
		t.Fatal(err)
	}
	log, err := OpenCommitLog(progressRoot, strings.Repeat("a", 40))
	if err != nil {
		t.Fatal(err)
	}
	defer log.Close()
	legacyArchive := strings.Repeat("b", 64)
	log.Progress.ArchiveSHA = legacyArchive
	prepared := makeRunCommitPreparedGame(t, root, "alpha")
	prepared.Job.SessionID, prepared.Job.Nonce = "archive-session", "archive-nonce"
	qualification := CaptureQualification{Target: "mister", Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", Qualified: true}
	driver, standby := &runCommitTestDriver{root: root}, &runCommitTestDriver{root: root}
	boards := []PoolBoard{{Key: "board-a", Host: "192.0.2.1", Driver: driver}, {Key: "board-b", Host: "192.0.2.2", Driver: standby}}
	cfg := runCommitTestConfig(progressRoot)
	deps := MiSTerCommitDeps{Qualification: qualification, Boards: boards,
		CoordinatorOptions: CaptureCoordinatorOptions{CaptureTimeout: 5 * time.Second, CleanupTimeout: 5 * time.Second}, PrivateWorkRoot: filepath.Join(root, "private")}
	archiveSHA := strings.Repeat("c", 64)
	policy := MiSTerRunPolicy{Manual: true, RunScopeID: "archive-scope", ArchiveSHA256: archiveSHA}
	if _, err = RunCommitMiSTer(context.Background(), log, []MiSTerPreparedGame{prepared}, cfg, deps, policy); err != nil {
		t.Fatalf("run MiSTer capture with a lane-specific archive identity: %v", err)
	}
	if log.Progress.ArchiveSHA != legacyArchive {
		t.Fatalf("legacy archive field changed: %q", log.Progress.ArchiveSHA)
	}
	lane := log.Progress.CaptureRuns[captureRunLaneForTest(log.Progress, policy.RunScopeID)]
	if lane.SelectedArchiveSHA256 != archiveSHA || !lane.Complete {
		t.Fatalf("selected archive identity was not persisted in completed lane: %+v", lane)
	}
	changed := policy
	changed.Retry = true
	changed.ArchiveSHA256 = strings.Repeat("d", 64)
	secondDriver, secondStandby := &runCommitTestDriver{root: root}, &runCommitTestDriver{root: root}
	changedDeps := deps
	changedDeps.Boards = []PoolBoard{{Key: "board-a", Host: "192.0.2.1", Driver: secondDriver}, {Key: "board-b", Host: "192.0.2.2", Driver: secondStandby}}
	if _, err = RunCommitMiSTer(context.Background(), log, []MiSTerPreparedGame{prepared}, cfg, changedDeps, changed); err == nil || !strings.Contains(err.Error(), "does not match run scope") {
		t.Fatalf("changed archive identity resumed the old lane: %v", err)
	}
	secondDriver.mu.Lock()
	calls := secondDriver.calls
	secondDriver.mu.Unlock()
	if calls != 0 {
		t.Fatalf("changed archive identity dispatched %d board calls before rejection", calls)
	}
}
