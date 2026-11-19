package cmd

import (
	"bytes"
	"context"
	"jtutil/regression"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/spf13/cobra"
)

func TestMiSTerArchivePreparationFailuresRemainExplicit(t *testing.T) {
	manifest := regression.Manifest{Cores: []regression.CoreManifest{{Core: "missing", Games: []regression.GameSpec{{Setname: "game", PreparationError: "missing RBF"}}}}}
	prepared, failures, err := prepareMiSTerJobs(context.Background(), regression.Config{}, manifest, t.TempDir(), regression.CaptureQualification{}, true)
	if err != nil || len(prepared) != 0 || len(failures) != 1 || failures[0].game != "missing/game" || failures[0].message != "missing RBF" {
		t.Fatalf("got prepared=%v failures=%v err=%v", prepared, failures, err)
	}
	_, _, err = prepareMiSTerJobs(context.Background(), regression.Config{}, manifest, t.TempDir(), regression.CaptureQualification{}, false)
	if err == nil || !strings.Contains(err.Error(), "missing RBF") {
		t.Fatalf("strict selection did not fail: %v", err)
	}
}

func TestMiSTerPreparationSkipsAreLoggedOnceAcrossResume(t *testing.T) {
	root := t.TempDir()
	if err := regression.InitializeLog(root); err != nil { t.Fatal(err) }
	commit := strings.Repeat("a", 40)
	manifest := regression.Manifest{SkippedTargets: []string{"ngp"}, SkippedBuilds: []string{"dd2", "dd2"}, SkippedGames: []string{"s18/aquario: skip"}}
	for i := 0; i < 2; i++ {
		log, err := regression.OpenCommitLog(root, commit); if err != nil { t.Fatal(err) }
		if err = recordMiSTerPreparationSkips(log, manifest); err != nil { t.Fatal(err) }
		if err = log.Close(); err != nil { t.Fatal(err) }
	}
	raw, err := os.ReadFile(filepath.Join(root, "log", "aaaaaaa.log")); if err != nil { t.Fatal(err) }
	for _, text := range []string{"MiSTer target explicitly skipped", "MiSTer bitstream omitted", "MiSTer source exclusion s18/aquario"} {
		if count := strings.Count(string(raw), text); count != 1 { t.Fatalf("%q appears %d times in %s", text, count, raw) }
	}
	if _, err = os.Stat(filepath.Join(root, "log", "aaaaaaa.json")); !os.IsNotExist(err) { t.Fatalf("skip logging changed lane progress: %v", err) }
}

func TestMiSTerLaneSummaryPrintedBeforePreparationError(t *testing.T) {
	var out bytes.Buffer
	command := &cobra.Command{}; command.SetOut(&out)
	lane := regression.MiSTerLaneStatus{Key: "test-lane", Lane: regression.CaptureRunProgress{Status: "complete", Selected: map[string]string{"fake/game": "identity"}}}
	err := printMiSTerLaneResult(command, lane, 2)
	if err == nil || !strings.Contains(err.Error(), "2 preparation errors") || !strings.Contains(out.String(), "MiSTer lane test-lane: complete (1 selected games)") { t.Fatalf("lane summary=%q err=%v", out.String(), err) }
}

func TestMiSTerLaneReportingPreservesPreparationAndStatusErrors(t *testing.T) {
	for _, tc := range []struct { name string; qualification regression.CaptureQualification; want string; unreadable bool }{
		{"status read", regression.CaptureQualification{Generation: "gen-r1", QualificationID: "qual-r1"}, "not a directory", true},
		{"missing lane", regression.CaptureQualification{Generation: "gen-r1", QualificationID: "qual-r1"}, "without a persisted selected lane", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var out bytes.Buffer
			command := &cobra.Command{}; command.SetOut(&out)
			root := t.TempDir()
			if tc.unreadable { if err := os.WriteFile(filepath.Join(root, "log"), []byte("not a directory"), 0600); err != nil { t.Fatal(err) } }
			err := reportMiSTerLane(command, root, tc.qualification, strings.Repeat("a", 40), "scope", 2)
			if err == nil || !strings.Contains(err.Error(), "2 preparation errors") || !strings.Contains(err.Error(), tc.want) || out.Len() != 0 { t.Fatalf("summary=%q error=%v", out.String(), err) }
		})
	}
}

func TestMiSTerEmptyInventoryStillValidatesDispatch(t *testing.T) {
	root := t.TempDir()
	sshConfig := filepath.Join(root, "ssh.conf")
	if err := os.WriteFile(sshConfig, []byte("Host board\n"), 0600); err != nil { t.Fatal(err) }
	cfg := regression.Config{Target: "mister", Root: filepath.Join(root, "results"), Boards: []regression.MiSTerBoardConfig{{ID: "board-a", Host: "192.0.2.1", User: "jt", SSHConfig: sshConfig, RemoteStagingRoot: "/media/fat/_Arcade"}}, CaptureContract: &regression.MiSTerCaptureContract{Generation: "gen-r1", Convention: regression.CaptureNativeNonRotatedRGB888, QualificationID: "qual-r1", QualificationEvidence: filepath.Join(root, "qual.json"), MainSHA256: strings.Repeat("c", 64), CommandTimeoutSeconds: 5, LoadTimeoutSeconds: 5, CaptureTimeoutSeconds: 180, CleanupTimeoutSeconds: 5, MaxHoldMS: 250, ExpectedBridgeCount: 2}}
	boards, _, _, err := miSTerDispatchInputs(cfg, nil, root, true, "")
	if err != nil || len(boards) != 1 { t.Fatalf("valid empty inventory: boards=%d err=%v", len(boards), err) }
	if _, _, _, err = miSTerDispatchInputs(cfg, nil, root, true, regression.MiSTerAutomaticRunScopeID); err == nil { t.Fatal("reserved scope accepted") }
	cfg.CaptureContract.CaptureTimeoutSeconds = 3600
	if _, _, _, err = miSTerDispatchInputs(cfg, nil, root, true, ""); err == nil { t.Fatal("invalid driver accepted") }
}

func TestMiSTerManualScopeCannotUseAutomaticScope(t *testing.T) {
	if _, _, err := miSTerScopeID(regression.MiSTerAutomaticRunScopeID); err == nil {
		t.Fatal("manual scope accepted reserved automatic scope")
	}
}
