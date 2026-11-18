/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package cmd

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/spf13/cobra"
	"jtutil/regression"
)

func TestMiSTerMissingPinnedMacrosReleasesLockAndWorkspace(t *testing.T) {
	root := t.TempDir()
	source, tempRoot, archiveRoot := filepath.Join(root, "source"), filepath.Join(root, "temp"), filepath.Join(root, "archives")
	for _, dir := range []string{filepath.Join(source, "cores", "fixture", "cfg"), filepath.Join(source, "modules", "jtframe", "target"), tempRoot, archiveRoot} {
		if err := os.MkdirAll(dir, 0700); err != nil { t.Fatal(err) }
	}
	if err := os.WriteFile(filepath.Join(source, "cores", "fixture", "cfg", "mame2mra.toml"), []byte("# fixture\n"), 0600); err != nil { t.Fatal(err) }
	if err := os.WriteFile(filepath.Join(source, "modules", "jtframe", "target", "fixture"), []byte("tracked"), 0600); err != nil { t.Fatal(err) }
	gitTestCommand(t, source, "init", "-q")
	gitTestCommand(t, source, "add", ".")
	gitTestCommand(t, source, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "missing pinned macros")
	commit := strings.TrimSpace(gitTestCommand(t, source, "rev-parse", "HEAD"))
	if err := os.WriteFile(filepath.Join(source, "cores", "fixture", "cfg", "macros.def"), []byte("JTFRAME_RATE=60\n"), 0600); err != nil { t.Fatal(err) }
	archive, err := os.Create(filepath.Join(archiveRoot, commit+".zip")); if err != nil { t.Fatal(err) }
	zw := zip.NewWriter(archive)
	for name, contents := range map[string]string{"release/mra/game.mra": `<mame><name>fixture</name><setname>game</setname><rbf>jtfixture</rbf></mame>`, "release/mister/jtfixture.rbf": "rbf"} {
		w, err := zw.Create(name); if err != nil { t.Fatal(err) }; if _, err = w.Write([]byte(contents)); err != nil { t.Fatal(err) }
	}
	if err = zw.Close(); err != nil { t.Fatal(err) }; if err = archive.Close(); err != nil { t.Fatal(err) }
	mainSHA := strings.Repeat("c", 64)
	qualification := filepath.Join(root, "qualification.json")
	qualificationData := fmt.Sprintf(`{"schema":1,"target":"mister","generation":"gen-cli","convention":"native-non-rotated-rgb888-v1","qualification_id":"qual-cli","main_sha256":"%s","qualified":true}`, mainSHA)
	if err = os.WriteFile(qualification, []byte(qualificationData), 0600); err != nil { t.Fatal(err) }
	dataRoot := filepath.Join(root, "results")
	cfg := regression.Config{Target: "mister", Root: dataRoot, BuildsDir: archiveRoot, Boards: []regression.MiSTerBoardConfig{{ID: "board-a", Host: "192.0.2.1", User: "jt", SSHConfig: "/nonexistent/offline", RemoteStagingRoot: "/media/fat/_Arcade"}}, CaptureContract: &regression.MiSTerCaptureContract{Generation: "gen-cli", Convention: regression.CaptureNativeNonRotatedRGB888, QualificationID: "qual-cli", QualificationEvidence: qualification, MainSHA256: mainSHA, CommandTimeoutSeconds: 1, LoadTimeoutSeconds: 1, CaptureTimeoutSeconds: 1, CleanupTimeoutSeconds: 1, MaxHoldMS: 1000, ExpectedBridgeCount: 1}}
	t.Setenv("JTROOT", source); t.Setenv("TMPDIR", tempRoot)
	oldGlobals := saveMiSTerCommandGlobals(); t.Cleanup(oldGlobals.restore)
	regressionCommit, regressionPublishTo = commit, "github"
	regressionManifest, regressionRunID, regressionMisterRunScope, regressionImport, regressionMigrate = "", "", "", "", ""
	regressionRetryErrors, regressionPoll, regressionJTBin = false, false, false
	command := newMiSTerCommandForTest(t)
	err = runMiSTerRegression(context.Background(), command, cfg, dataRoot, nil, nil, true, true)
	if err == nil || !strings.Contains(err.Error(), "macros.def") { t.Fatalf("missing pinned macros did not return an error: %v", err) }
	lock, err := regression.AcquireLock(dataRoot); if err != nil { t.Fatalf("regression lock not released: %v", err) }; _ = regression.ReleaseLock(lock)
	entries, err := os.ReadDir(tempRoot); if err != nil { t.Fatal(err) }
	for _, entry := range entries { if strings.HasPrefix(entry.Name(), "jtutil-mister-run-") || strings.HasPrefix(entry.Name(), "jtutil-source-commit-") { t.Fatalf("temporary workspace retained: %s", entry.Name()) } }
}

func TestRegressionHelpDocumentsMiSTerAndHistoricalBoundaries(t *testing.T) {
	for _, fragment := range []string{"qualification-gated MiSTer capture", "full-HDMI regression-capable RBFs", "board-free", "selected generation and qualification", "mame-frames"} {
		if !strings.Contains(regressionCmd.Long, fragment) {
			t.Errorf("regression help omits %q", fragment)
		}
	}
	if strings.Contains(regressionCmd.Long, "release/sidi128 RBF") {
		t.Fatal("stale SiDi-only setup help remains")
	}
}

func TestMiSTerManualArchiveKeepsLegacyProgressAndPinsLaneIdentity(t *testing.T) {
	root := t.TempDir()
	source := filepath.Join(root, "source")
	if err := os.MkdirAll(source, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(source, "README"), []byte("tracked source"), 0600); err != nil {
		t.Fatal(err)
	}
	gitTestCommand(t, source, "init", "-q")
	gitTestCommand(t, source, "add", "README")
	gitTestCommand(t, source, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "fixture")
	commit := strings.TrimSpace(gitTestCommand(t, source, "rev-parse", "HEAD"))
	t.Setenv("JTROOT", source)
	t.Setenv("JOTEGO", filepath.Join(root, "private"))
	dataRoot := filepath.Join(os.Getenv("JOTEGO"), "regression")
	archiveRoot := filepath.Join(root, "archives")
	if err := os.MkdirAll(archiveRoot, 0700); err != nil {
		t.Fatal(err)
	}
	selectedArchive := []byte("not a zip: fail during local MiSTer preparation")
	if err := os.WriteFile(filepath.Join(archiveRoot, commit+".zip"), selectedArchive, 0600); err != nil {
		t.Fatal(err)
	}
	mainSHA := strings.Repeat("c", 64)
	qualificationPath := filepath.Join(root, "qualification.json")
	qualification, err := json.Marshal(map[string]any{"schema": 1, "target": "mister", "generation": "gen-cli", "convention": regression.CaptureNativeNonRotatedRGB888,
		"qualification_id": "qual-cli", "main_sha256": mainSHA, "qualified": true})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(qualificationPath, qualification, 0600); err != nil {
		t.Fatal(err)
	}
	configPath := filepath.Join(root, "regression.yaml")
	config := fmt.Sprintf("target: mister\nbuilds-dir: %q\nboards:\n  - id: board-a\n    host: 192.0.2.1\n    user: jt\n    ssh-config: /nonexistent/offline-config\n    remote-staging-root: /media/fat/_Arcade\ncapture-contract:\n  generation: gen-cli\n  convention: native-non-rotated-rgb888-v1\n  qualification-id: qual-cli\n  qualification-evidence: %q\n  main-sha256: %s\n  command-timeout-seconds: 1\n  load-timeout-seconds: 1\n  capture-timeout-seconds: 1\n  cleanup-timeout-seconds: 1\n  max-hold-ms: 1000\n  expected-bridge-count: 1\n", archiveRoot, qualificationPath, mainSHA)
	if err = os.WriteFile(configPath, []byte(config), 0600); err != nil {
		t.Fatal(err)
	}
	sshMarker := filepath.Join(root, "unexpected-ssh")
	installCommandMarker(t, root, "ssh", sshMarker)
	installCommandMarker(t, root, "scp", sshMarker)
	oldPath := os.Getenv("PATH")
	t.Setenv("PATH", filepath.Join(root, "bin")+string(os.PathListSeparator)+oldPath)
	if err = regression.InitializeLog(dataRoot); err != nil {
		t.Fatal(err)
	}
	log, err := regression.OpenCommitLog(dataRoot, commit)
	if err != nil {
		t.Fatal(err)
	}
	reportPR := 37
	log.Progress.Status = "legacy-status"
	log.Progress.Error = "legacy-error"
	log.Progress.AutomaticComplete = true
	log.Progress.ProjectCommit = strings.Repeat("d", 40)
	log.Progress.Current = "legacy/set"
	log.Progress.ArchiveSHA = strings.Repeat("b", 64)
	log.Progress.RBFs = map[string]string{"legacy.rbf": strings.Repeat("e", 64)}
	log.Progress.Games = map[string]regression.ProgressGame{"legacy/set": {Result: regression.Pass, Input: "legacy-input", Output: "legacy-output", Seconds: 12.5, Stage: "legacy-stage", Message: "legacy-message"}}
	log.Progress.ReportURL = "https://legacy.invalid/report"
	log.Progress.GiteaReportURL = "http://legacy.invalid/issue/1"
	log.Progress.GiteaReportComplete = true
	log.Progress.ReportPR = &reportPR
	if err = log.Save(); err != nil {
		t.Fatal(err)
	}
	if err = log.Close(); err != nil {
		t.Fatal(err)
	}
	before, err := regression.OpenCommitLog(dataRoot, commit)
	if err != nil {
		t.Fatal(err)
	}
	expected := *before.Progress
	expected.Updated = time.Time{}
	if err = before.Close(); err != nil {
		t.Fatal(err)
	}
	oldGlobals := saveMiSTerCommandGlobals()
	t.Cleanup(oldGlobals.restore)
	regressionCommit, regressionConfig, regressionPublishTo = commit, configPath, "github"
	regressionCore, regressionCores, regressionSetname = "", "", ""
	regressionManifest, regressionRunID, regressionMisterRunScope = "", "", ""
	regressionImport, regressionMigrate = "", ""
	command := newMiSTerCommandForTest(t)
	if err = command.Flags().Set("commit", commit); err != nil {
		t.Fatal(err)
	}
	err = run_regression_cmd(command, nil)
	if err == nil || strings.Contains(err.Error(), "archive pinned in this log") {
		t.Fatalf("MiSTer archive selection was rejected by legacy ArchiveSHA or unexpectedly succeeded: %v", err)
	}
	after, openErr := regression.OpenCommitLog(dataRoot, commit)
	if openErr != nil {
		t.Fatal(openErr)
	}
	got := *after.Progress
	got.Updated = time.Time{}
	if !reflect.DeepEqual(got, expected) {
		t.Fatalf("MiSTer command changed legacy progress on setup/preparation failure\n got: %+v\nwant: %+v", got, expected)
	}
	if err = after.Close(); err != nil {
		t.Fatal(err)
	}
	if _, statErr := os.Stat(sshMarker); !os.IsNotExist(statErr) {
		t.Fatalf("invalid archive reached a board command (marker=%v)", statErr)
	}
}

func TestMiSTerMigrationFlagsRejectBeforeDiscovery(t *testing.T) {
	for _, mode := range []string{"migrate", "import"} {
		t.Run(mode, func(t *testing.T) {
			root := t.TempDir()
			t.Setenv("JTROOT", filepath.Join(root, "source"))
			if err := os.MkdirAll(os.Getenv("JTROOT"), 0700); err != nil {
				t.Fatal(err)
			}
			t.Setenv("JOTEGO", filepath.Join(root, "private"))
			bin := filepath.Join(root, "bin")
			if err := os.MkdirAll(bin, 0700); err != nil {
				t.Fatal(err)
			}
			marker := filepath.Join(root, "gh-invoked")
			t.Setenv("MISTER_TEST_GH_MARKER", marker)
			if err := os.WriteFile(filepath.Join(bin, "gh"), []byte("#!/bin/sh\nprintf invoked > \"$MISTER_TEST_GH_MARKER\"\nexit 77\n"), 0700); err != nil {
				t.Fatal(err)
			}
			boardMarker := filepath.Join(root, "board-command-invoked")
			installCommandMarker(t, root, "ssh", boardMarker)
			installCommandMarker(t, root, "scp", boardMarker)
			t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
			mainSHA := strings.Repeat("c", 64)
			qualificationPath := filepath.Join(root, "qualification.json")
			qualification, err := json.Marshal(map[string]any{"schema": 1, "target": "mister", "generation": "gen-cli", "convention": regression.CaptureNativeNonRotatedRGB888,
				"qualification_id": "qual-cli", "main_sha256": mainSHA, "qualified": true})
			if err != nil {
				t.Fatal(err)
			}
			if err = os.WriteFile(qualificationPath, qualification, 0600); err != nil {
				t.Fatal(err)
			}
			configPath := filepath.Join(root, "regression.yaml")
			config := fmt.Sprintf("target: mister\nboards:\n  - id: board-a\n    host: 192.0.2.1\n    user: jt\n    ssh-config: /nonexistent/offline-config\n    remote-staging-root: /media/fat/_Arcade\ncapture-contract:\n  generation: gen-cli\n  convention: native-non-rotated-rgb888-v1\n  qualification-id: qual-cli\n  qualification-evidence: %q\n  main-sha256: %s\n  command-timeout-seconds: 1\n  load-timeout-seconds: 1\n  capture-timeout-seconds: 1\n  cleanup-timeout-seconds: 1\n  max-hold-ms: 1000\n  expected-bridge-count: 1\n", qualificationPath, mainSHA)
			if err = os.WriteFile(configPath, []byte(config), 0600); err != nil {
				t.Fatal(err)
			}
			oldGlobals := saveMiSTerCommandGlobals()
			t.Cleanup(oldGlobals.restore)
			regressionConfig, regressionPublishTo, regressionImport, regressionMigrate = configPath, "github", "", ""
			if mode == "migrate" {
				regressionMigrate = "legacy.log"
			} else {
				regressionImport = "legacy.json"
			}
			command := newMiSTerCommandForTest(t)
			err = run_regression_cmd(command, nil)
			if err == nil || !strings.Contains(err.Error(), "not supported for target=mister") {
				t.Fatalf("%s flag did not fail closed for MiSTer: %v", mode, err)
			}
			if _, statErr := os.Stat(marker); !os.IsNotExist(statErr) {
				t.Fatalf("%s flag reached capture discovery (fake gh marker=%v)", mode, statErr)
			}
			if _, statErr := os.Stat(boardMarker); !os.IsNotExist(statErr) {
				t.Fatalf("%s flag reached a board command (marker=%v)", mode, statErr)
			}
		})
	}
}

type miSTerCommandGlobals struct {
	commit, config, publish, core, cores, setname, manifest, runID, scope string
	importValue, migrate                                                  string
	jtbin, retry, poll                                                    bool
}

func saveMiSTerCommandGlobals() miSTerCommandGlobals {
	return miSTerCommandGlobals{regressionCommit, regressionConfig, regressionPublishTo, regressionCore, regressionCores, regressionSetname,
		regressionManifest, regressionRunID, regressionMisterRunScope, regressionImport, regressionMigrate, regressionJTBin, regressionRetryErrors, regressionPoll}
}

func (g miSTerCommandGlobals) restore() {
	regressionCommit, regressionConfig, regressionPublishTo, regressionCore, regressionCores, regressionSetname = g.commit, g.config, g.publish, g.core, g.cores, g.setname
	regressionManifest, regressionRunID, regressionMisterRunScope, regressionImport, regressionMigrate = g.manifest, g.runID, g.scope, g.importValue, g.migrate
	regressionJTBin, regressionRetryErrors, regressionPoll = g.jtbin, g.retry, g.poll
}

func newMiSTerCommandForTest(t *testing.T) *cobra.Command {
	t.Helper()
	command := &cobra.Command{}
	command.Flags().StringVar(&regressionCommit, "commit", regressionCommit, "")
	command.Flags().StringVar(&regressionConfig, "config", regressionConfig, "")
	command.Flags().StringVar(&regressionPublishTo, "publish-to", regressionPublishTo, "")
	command.Flags().StringVar(&regressionCore, "core", regressionCore, "")
	command.Flags().StringVar(&regressionCores, "cores", regressionCores, "")
	command.Flags().StringVar(&regressionSetname, "setname", regressionSetname, "")
	command.Flags().StringVar(&regressionManifest, "manifest", regressionManifest, "")
	command.Flags().StringVar(&regressionRunID, "run-id", regressionRunID, "")
	command.Flags().BoolVar(&regressionJTBin, "jtbin", regressionJTBin, "")
	command.Flags().BoolVar(&regressionRetryErrors, "retry-errors", regressionRetryErrors, "")
	command.Flags().BoolVar(&regressionPoll, "poll", regressionPoll, "")
	return command
}

func gitTestCommand(t *testing.T, root string, args ...string) string {
	t.Helper()
	command := exec.Command("git", append([]string{"-C", root}, args...)...)
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v: %s", args, err, output)
	}
	return string(output)
}

func installCommandMarker(t *testing.T, root, name, marker string) {
	t.Helper()
	bin := filepath.Join(root, "bin")
	if err := os.MkdirAll(bin, 0700); err != nil {
		t.Fatal(err)
	}
	body := fmt.Sprintf("#!/bin/sh\nprintf invoked > %q\nexit 77\n", marker)
	if err := os.WriteFile(filepath.Join(bin, name), []byte(body), 0700); err != nil {
		t.Fatal(err)
	}
}

func TestParseMiSTerGameSelector(t *testing.T) {
	for _, value := range []string{"circus/circusc", "flstory/flstory"} {
		core, set, err := parseMiSTerGameSelector(value)
		if err != nil || core == "" || set == "" {
			t.Fatalf("parse %q: core=%q set=%q err=%v", value, core, set, err)
		}
	}
	for _, value := range []string{"", "circusc", "/circusc", "circus/", "circus/set/extra", "../circus/set"} {
		if _, _, err := parseMiSTerGameSelector(value); err == nil {
			t.Fatalf("accepted invalid selector %q", value)
		}
	}
}

func TestMiSTerStatusManagementDoesNotRequireBoardConfiguration(t *testing.T) {
	root := t.TempDir()
	evidencePath := filepath.Join(root, "qualification.json")
	const mainSHA = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
	evidence := struct {
		Schema          int                          `json:"schema"`
		Target          string                       `json:"target"`
		Generation      string                       `json:"generation"`
		Convention      regression.CaptureConvention `json:"convention"`
		QualificationID string                       `json:"qualification_id"`
		MainSHA256      string                       `json:"main_sha256"`
		Qualified       bool                         `json:"qualified"`
	}{1, "mister", "gen-test", regression.CaptureNativeNonRotatedRGB888, "qual-test", mainSHA, true}
	raw, err := json.Marshal(evidence)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(evidencePath, raw, 0600); err != nil {
		t.Fatal(err)
	}
	cfg := regression.Config{Target: "mister", Root: root, CaptureContract: &regression.MiSTerCaptureContract{
		Generation: "gen-test", Convention: regression.CaptureNativeNonRotatedRGB888, QualificationID: "qual-test",
		QualificationEvidence: evidencePath, MainSHA256: mainSHA, CommandTimeoutSeconds: 1, LoadTimeoutSeconds: 1,
		CaptureTimeoutSeconds: 1, CleanupTimeoutSeconds: 1, MaxHoldMS: 1000, ExpectedBridgeCount: 1,
	}}
	oldStatus, oldAccept, oldReject := regressionStatus, regressionAccept, regressionReject
	regressionStatus, regressionAccept, regressionReject = true, "", ""
	t.Cleanup(func() { regressionStatus, regressionAccept, regressionReject = oldStatus, oldAccept, oldReject })
	var output bytes.Buffer
	command := &cobra.Command{}
	command.SetOut(&output)
	if err = runMiSTerManagement(command, cfg, root); err != nil {
		t.Fatalf("board-free status failed without board config: %v", err)
	}
	if !strings.Contains(output.String(), "No qualified MiSTer capture lanes") {
		t.Fatalf("unexpected board-free status output: %q", output.String())
	}
}
