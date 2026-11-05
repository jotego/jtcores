/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package cmd

import (
	"os"
	"path/filepath"
	"testing"
)

func TestMameGlobalProfileConfigSelection(t *testing.T) {
	source := t.TempDir()
	missing := filepath.Join(t.TempDir(), "missing.yaml")
	want_default := filepath.Join(source, "modules", "jtframe", "bin", "reg.yaml")
	got, err := mame_global_profile(source, missing, false)
	if err != nil || got != want_default {
		t.Fatalf("default missing config: got %q, %v", got, err)
	}
	if _, err = mame_global_profile(source, missing, true); err == nil {
		t.Fatal("explicit missing config silently used default profile")
	}
	custom := filepath.Join(t.TempDir(), "regression.yaml")
	if err = os.WriteFile(custom, []byte("global-profile: /tmp/custom-reg.yaml\n"), 0600); err != nil {
		t.Fatal(err)
	}
	got, err = mame_global_profile(source, custom, true)
	if err != nil || got != "/tmp/custom-reg.yaml" {
		t.Fatalf("custom profile: got %q, %v", got, err)
	}
}
