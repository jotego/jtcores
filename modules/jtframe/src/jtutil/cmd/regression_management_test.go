/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package cmd

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func reset_curation_flags() {
	regressionBusy, regressionAccept, regressionReject, regressionReason, regressionStatus = false, "", "", "", false
	for _, name := range []string{"busy", "accept", "reject", "reason", "status", "core", "setname", "manifest", "run-id", "poll", "jtbin", "retry-errors", "migrate-logs", "import-progress"} {
		regressionCmd.Flags().Lookup(name).Changed = false
	}
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
