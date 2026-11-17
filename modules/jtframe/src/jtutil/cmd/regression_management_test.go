/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package cmd

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func reset_curation_flags() {
	regressionBusy, regressionAccept, regressionReject, regressionReason, regressionStatus = false, "", "", "", false
	regressionLegacySiDi128 = false
	regressionAdoptLegacySiDi128, regressionConfirmLegacySiDi128 = false, ""
	regressionImport, regressionMigrate, regressionPoll, regressionJTBin = "", "", false, false
	regressionManifest, regressionRunID, regressionRetryErrors = "", "", false
	regressionCore, regressionCores, regressionSetname = "", "", ""
	regressionCommit, regressionMisterRunScope = "", ""
	regressionNoPublish, regressionPublishTo = false, "github"
	regressionConfig = filepath.Join(project_root(), ".jtutil-regression.yaml")
	regressionCmd.SilenceErrors, regressionCmd.SilenceUsage = false, false
	for _, name := range []string{"busy", "accept", "reject", "reason", "status", "legacy-sidi128", "adopt-legacy-sidi128", "confirm-legacy-sidi128", "config", "core", "cores", "setname", "manifest", "run-id", "poll", "jtbin", "retry-errors", "migrate-logs", "import-progress", "commit", "mister-run-scope", "publish-to", "no-publish"} {
		regressionCmd.Flags().Lookup(name).Changed = false
	}
}

func TestLegacyArchiveAdoptionUsesExistingRegressionCommandAndRejectsMiSTerTarget(t *testing.T) {
	reset_curation_flags()
	root := t.TempDir()
	t.Setenv("JOTEGO", root)
	config := filepath.Join(root, "sidi.yaml")
	if err := os.WriteFile(config, []byte("target: sidi128\n"), 0600); err != nil {
		t.Fatal(err)
	}
	archive := filepath.Join(root, "regression")
	game := filepath.Join(archive, "contra", "contra", "ref")
	if err := os.MkdirAll(game, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(game, "old.png"), []byte("legacy"), 0600); err != nil {
		t.Fatal(err)
	}
	regressionConfig = config
	regressionLegacySiDi128 = true
	regressionAdoptLegacySiDi128 = true
	regressionConfirmLegacySiDi128 = "sidi128"
	regressionCmd.Flags().Lookup("legacy-sidi128").Changed = true
	regressionCmd.Flags().Lookup("adopt-legacy-sidi128").Changed = true
	regressionCmd.Flags().Lookup("confirm-legacy-sidi128").Changed = true
	if err := run_regression_cmd(regressionCmd, nil); err != nil {
		t.Fatalf("existing regression entrypoint did not adopt archive: %v", err)
	}
	marker, err := os.ReadFile(filepath.Join(archive, ".capture-target.json"))
	if err != nil || string(marker) != "{\"target\":\"sidi128\"}\n" {
		t.Fatalf("adoption marker=%q err=%v", marker, err)
	}
	reset_curation_flags()
	root = t.TempDir()
	t.Setenv("JOTEGO", root)
	config = filepath.Join(root, "mister.yaml")
	if err = os.WriteFile(config, []byte("target: mister\n"), 0600); err != nil {
		t.Fatal(err)
	}
	regressionConfig = config
	regressionLegacySiDi128 = true
	regressionAdoptLegacySiDi128 = true
	regressionConfirmLegacySiDi128 = "sidi128"
	regressionCmd.Flags().Lookup("legacy-sidi128").Changed = true
	regressionCmd.Flags().Lookup("adopt-legacy-sidi128").Changed = true
	regressionCmd.Flags().Lookup("confirm-legacy-sidi128").Changed = true
	if err = run_regression_cmd(regressionCmd, nil); err == nil || !strings.Contains(err.Error(), "cannot target a MiSTer") {
		t.Fatalf("MiSTer target adoption result = %v", err)
	}
	if _, err = os.Stat(filepath.Join(root, "regression")); !os.IsNotExist(err) {
		t.Fatalf("rejected MiSTer adoption created an archive: %v", err)
	}
	reset_curation_flags()
}

func enableSidiCommandCuration(t *testing.T, root string) {
	t.Helper()
	archive := filepath.Join(root, "regression")
	if err := os.MkdirAll(archive, 0750); err != nil { t.Fatal(err) }
	if err := os.WriteFile(filepath.Join(archive, ".capture-target.json"), []byte("{\"target\":\"sidi128\"}\n"), 0640); err != nil { t.Fatal(err) }
	config := filepath.Join(t.TempDir(), "regression.yaml")
	if err := os.WriteFile(config, []byte("{}\n"), 0600); err != nil { t.Fatal(err) }
	regressionConfig = config
	regressionLegacySiDi128 = true
	regressionCmd.Flags().Lookup("legacy-sidi128").Changed = true
}

func TestRegressionBusyIdleOutputAndExit(t *testing.T) {
	reset_curation_flags()
	t.Setenv("JOTEGO", t.TempDir())
	var output bytes.Buffer
	regressionCmd.SetOut(&output)
	defer regressionCmd.SetOut(nil)
	regressionBusy = true
	regressionCmd.Flags().Lookup("busy").Changed = true
	err := run_regression_cmd(regressionCmd, nil)
	var coded interface{ ExitCode() int }
	if !errors.As(err, &coded) || coded.ExitCode() != 1 {
		t.Fatalf("idle --busy did not return exit 1: %v", err)
	}
	if output.String() != "no regression in progress\n" {
		t.Fatalf("unexpected --busy output %q", output.String())
	}
	if !regressionCmd.SilenceErrors || !regressionCmd.SilenceUsage {
		t.Fatal("idle --busy did not silence Cobra error and usage output")
	}
	reset_curation_flags()
}

func TestParseRegressionCoreNames(t *testing.T) {
	cores, err := parse_regression_core_names(" core2,core1,core2 ")
	if err != nil || strings.Join(cores, ",") != "core1,core2" {
		t.Fatalf("comma separated cores parsed incorrectly: %v %v", cores, err)
	}
	for _, value := range []string{"", "core1,", "core1,../other"} {
		if _, err := parse_regression_core_names(value); err == nil {
			t.Fatalf("unsafe core selection %q accepted", value)
		}
	}
}

func TestRegressionAcceptCommaSeparatedCores(t *testing.T) {
	reset_curation_flags()
	root := t.TempDir()
	t.Setenv("JOTEGO", root)
	enableSidiCommandCuration(t, root)
	for i, core := range []string{"core1", "core2"} {
		slot := filepath.Join(root, "regression", core, "same", "new")
		if err := os.MkdirAll(slot, 0750); err != nil { t.Fatal(err) }
		for frame, pixel := range []color.RGBA{{R: 1, A: 255}, {G: 1, A: 255}} {
			img := image.NewRGBA(image.Rect(0, 0, 2, 2))
			for y := 0; y < 2; y++ { for x := 0; x < 2; x++ { img.SetRGBA(x, y, pixel) } }
			file, err := os.Create(filepath.Join(slot, fmt.Sprintf("frame_%08d.png", frame+1+i*2)))
			if err != nil { t.Fatal(err) }
			if err = png.Encode(file, img); err != nil { t.Fatal(err) }
			if err = file.Close(); err != nil { t.Fatal(err) }
		}
	}
	var output bytes.Buffer
	regressionCmd.SetOut(&output)
	defer regressionCmd.SetOut(nil)
	regressionAccept = "core2,core1"
	regressionCmd.Flags().Lookup("accept").Changed = true
	if err := run_regression_cmd(regressionCmd, nil); err != nil { t.Fatal(err) }
	if !strings.Contains(output.String(), "Accepted pending captures for cores core1, core2 as ref") { t.Fatalf("unexpected accept output %q", output.String()) }
	for _, core := range []string{"core1", "core2"} {
		game := filepath.Join(root, "regression", core, "same")
		if _, err := os.Stat(filepath.Join(game, "new")); !os.IsNotExist(err) { t.Fatalf("%s new slot remains: %v", core, err) }
		if _, err := os.Stat(filepath.Join(game, "ref")); err != nil { t.Fatalf("%s ref missing: %v", core, err) }
	}
	reset_curation_flags()
}

func TestRegressionManagementRejectsExplicitEmptySelectors(t *testing.T) {
	reset_curation_flags()
	t.Setenv("JOTEGO", t.TempDir())
	regressionAccept = ""
	regressionCmd.Flags().Lookup("accept").Changed = true
	err := run_regression_cmd(regressionCmd, nil)
	var coded interface{ ExitCode() int }
	if !errors.As(err, &coded) || coded.ExitCode() != 6 {
		t.Fatalf("empty --accept did not return its validation code: %v", err)
	}

	reset_curation_flags()
	regressionReject = ""
	regressionCmd.Flags().Lookup("reject").Changed = true
	err = run_regression_cmd(regressionCmd, nil)
	if err == nil || !strings.Contains(err.Error(), "nonempty setname") {
		t.Fatalf("empty --reject was not rejected: %v", err)
	}
}

func TestRegressionManagementReasonRequiresRejectEvenWhenEmpty(t *testing.T) {
	reset_curation_flags()
	t.Setenv("JOTEGO", t.TempDir())
	regressionStatus = true
	regressionReason = ""
	regressionCmd.Flags().Lookup("reason").Changed = true
	err := run_regression_cmd(regressionCmd, nil)
	if err == nil || !strings.Contains(err.Error(), "--reason requires --reject") {
		t.Fatalf("empty --reason escaped validation: %v", err)
	}
}

func TestRegressionManagementRejectAndStatus(t *testing.T) {
	reset_curation_flags()
	root := t.TempDir()
	t.Setenv("JOTEGO", root)
	enableSidiCommandCuration(t, root)
	game := filepath.Join(root, "regression", "core", "game")
	if err := os.MkdirAll(filepath.Join(game, "new"), 0750); err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	regressionCmd.SetOut(&output)
	defer regressionCmd.SetOut(nil)
	regressionReject, regressionReason = "game", "reviewed"
	regressionCmd.Flags().Lookup("reject").Changed = true
	regressionCmd.Flags().Lookup("reason").Changed = true
	if err := run_regression_cmd(regressionCmd, nil); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(game, "new")); !os.IsNotExist(err) {
		t.Fatalf("reject left new slot: %v", err)
	}
	data, err := os.ReadFile(filepath.Join(game, "log"))
	if err != nil || !strings.Contains(string(data), "REJECT") || !strings.Contains(string(data), "reviewed") {
		t.Fatalf("rejection event missing: %s %v", data, err)
	}

	reset_curation_flags()
	regressionStatus = true
	if err := run_regression_cmd(regressionCmd, nil); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output.String(), "REJECTED: 1") || strings.Contains(output.String(), "FAIL: 1") {
		t.Fatalf("status did not reflect latest review: %s", output.String())
	}
	reset_curation_flags()
	regressionCmd.SetOut(os.Stdout)
}
