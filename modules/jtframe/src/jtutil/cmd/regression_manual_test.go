/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package cmd

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestManualRegressionSelection(t *testing.T) {
	for _, tc := range []struct {
		core, set, manifest, run    string
		retry, valid, manual, jtbin bool
	}{
		{valid: true},
		{jtbin: true},
		{core: "shouse", set: "splatter", jtbin: true, valid: true, manual: true}, {core: "shouse", valid: true, manual: true}, {core: "shouse", set: "splatter", valid: true, manual: true},
		{core: "1942", set: "1942a", valid: true, manual: true}, {set: "splatter"}, {core: "../shouse"}, {core: "shouse", set: "x\nSITE LOAD bad"},
		{core: "shouse", manifest: "manifest.json"}, {core: "shouse", run: "676"}, {core: "shouse", retry: true},
		{manifest: "manifest.json", run: "676", retry: true, valid: true},
	} {
		manual, err := validate_regression_selection(tc.core, tc.set, tc.manifest, tc.run, tc.retry, tc.jtbin)
		if (err == nil) != tc.valid || err == nil && manual != tc.manual {
			t.Fatalf("selection %+v =>manual%v err%v", tc, manual, err)
		}
	}
}

func TestExplicitDebugManifestRejectedBeforeAnyCampaignWrite(t *testing.T) {
	for _, existing := range []bool{false, true} {
		t.Run(map[bool]string{false: "fresh", true: "resume"}[existing], func(t *testing.T) {
			root := t.TempDir()
			source := filepath.Join(root, "project")
			data := filepath.Join(root, "data")
			t.Setenv("JTROOT", source)
			t.Setenv("JOTEGO", data)
			if err := os.MkdirAll(filepath.Join(source, "cores", "fake", "cfg"), 0750); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(source, "cores", "fake", "cfg", "mame2mra.toml"), []byte("[parse]\ndebug.Setnames=[\"broken\"]\n"), 0600); err != nil {
				t.Fatal(err)
			}
			config := filepath.Join(root, "config.yaml")
			if err := os.WriteFile(config, []byte("{}\n"), 0600); err != nil {
				t.Fatal(err)
			}
			manifest := filepath.Join(root, "manifest.json")
			original := []byte(`{"run_id":"old-run","cores":[{"core":"fake","games":[{"setname":"broken"}]}]}`)
			if err := os.WriteFile(manifest, original, 0600); err != nil {
				t.Fatal(err)
			}
			logRoot := filepath.Join(data, "regression", "log")
			sentinel := filepath.Join(logRoot, "old-run", "state.json")
			if existing {
				os.MkdirAll(filepath.Dir(sentinel), 0750)
				os.WriteFile(sentinel, []byte("preserve existing resume state"), 0600)
			}
			oldConfig, oldManifest, oldRun, oldCore, oldSet := regressionConfig, regressionManifest, regressionRunID, regressionCore, regressionSetname
			oldRetry, oldNoPublish, oldJTBin := regressionRetryErrors, regressionNoPublish, regressionJTBin
			t.Cleanup(func() {
				regressionConfig, regressionManifest, regressionRunID, regressionCore, regressionSetname = oldConfig, oldManifest, oldRun, oldCore, oldSet
				regressionRetryErrors, regressionNoPublish, regressionJTBin = oldRetry, oldNoPublish, oldJTBin
			})
			regressionConfig, regressionManifest, regressionRunID, regressionCore, regressionSetname = config, manifest, "", "", ""
			regressionRetryErrors, regressionNoPublish, regressionJTBin = existing, true, false
			err := run_regression_cmd(regressionCmd, nil)
			if err == nil || !strings.Contains(err.Error(), "debug") {
				t.Fatalf("expected debug exclusion before any other preflight: %v", err)
			}
			if bytes, readErr := os.ReadFile(manifest); readErr != nil || string(bytes) != string(original) {
				t.Fatal("manifest modified")
			}
			if existing {
				bytes, readErr := os.ReadFile(sentinel)
				if readErr != nil || string(bytes) != "preserve existing resume state" {
					t.Fatal("resume state modified")
				}
				entries, _ := os.ReadDir(logRoot)
				if len(entries) != 1 || entries[0].Name() != "old-run" {
					t.Fatal("log or lock created during rejected selection")
				}
			} else if _, statErr := os.Stat(filepath.Join(data, "regression")); !os.IsNotExist(statErr) {
				t.Fatal("rejected manifest created result/log directories")
			}
		})
	}
}
