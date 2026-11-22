/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestRunCommitMiSTerPreservesLegacyProgressFields(t *testing.T) {
	root := t.TempDir()
	if err := GuardCaptureTarget(root, "mister"); err != nil { t.Fatal(err) }
	if err := os.MkdirAll(filepath.Join(root, "log"), 0750); err != nil {
		t.Fatal(err)
	}
	log, err := OpenCommitLog(root, strings.Repeat("a", 40))
	if err != nil {
		t.Fatal(err)
	}
	defer log.Close()
	prepared := makeRunCommitPreparedGame(t, root, "legacy-isolation")
	log.Progress.Status = "legacy-status"
	log.Progress.Error = "legacy-error"
	log.Progress.AutomaticComplete = true
	log.Progress.ProjectCommit = "legacy-project"
	log.Progress.ReportURL = "https://example.invalid/legacy"
	log.Progress.GiteaReportURL = "https://example.invalid/gitea"
	log.Progress.GiteaReportComplete = true
	log.Progress.ReportPR = new(int)
	*log.Progress.ReportPR = 17
	log.Progress.ArchiveSHA = strings.Repeat("b", 64)
	log.Progress.RBFs["legacy-core"] = strings.Repeat("c", 64)
	log.Progress.Games["legacy-core/legacy-set"] = ProgressGame{Result: Pass, Input: "legacy-input", Output: "legacy-output", Message: "keep"}
	before := *log.Progress
	before.Games = make(map[string]ProgressGame, len(log.Progress.Games))
	for key, game := range log.Progress.Games {
		before.Games[key] = game
	}
	before.RBFs = cloneStringMap(log.Progress.RBFs)
	before.CaptureRuns = nil

	cfg := runCommitTestConfig(root)
	cfg.Boards = cfg.Boards[:1]
	board := &runCommitTestDriver{root: root}
	deps := MiSTerCommitDeps{Qualification: CaptureQualification{Target: "mister", Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", Qualified: true},
		Boards:             []PoolBoard{{Key: "board-a", Host: "192.0.2.1", Driver: board}},
		CoordinatorOptions: CaptureCoordinatorOptions{CaptureTimeout: 5 * time.Second, CleanupTimeout: 5 * time.Second}, PrivateWorkRoot: filepath.Join(root, "private")}
	if _, err = RunCommitMiSTer(context.Background(), log, []MiSTerPreparedGame{prepared}, cfg, deps, MiSTerRunPolicy{Manual: true, RunScopeID: "legacy-isolation"}); err != nil {
		t.Fatal(err)
	}
	after := *log.Progress
	after.CaptureRuns = nil
	after.Updated = before.Updated
	if !reflect.DeepEqual(before, after) {
		t.Fatalf("MiSTer lane changed legacy progress fields:\nbefore=%+v\nafter=%+v", before, after)
	}
	if board.calls != 1 {
		t.Fatalf("expected one fake capture call, got %d", board.calls)
	}
}
