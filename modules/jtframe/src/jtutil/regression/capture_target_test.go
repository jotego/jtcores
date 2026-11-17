/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCaptureTargetClaimsOnlyEmptyArchiveAndRemainsImmutable(t *testing.T) {
	root := t.TempDir()
	if err := GuardCaptureTarget(root, "mister"); err != nil {
		t.Fatal(err)
	}
	if target, present, err := ReadCaptureTarget(root); err != nil || !present || target != "mister" {
		t.Fatalf("ReadCaptureTarget = %q, %v, %v", target, present, err)
	}
	if err := GuardCaptureTarget(root, "sidi128"); err == nil || !strings.Contains(err.Error(), "belongs to target=mister") {
		t.Fatalf("target marker changed owners: %v", err)
	}
	unmarked := t.TempDir()
	if err := os.Mkdir(filepath.Join(unmarked, "legacy"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := GuardCaptureTarget(unmarked, "sidi128"); err == nil || !strings.Contains(err.Error(), "unmarked regression archive contains prior data") {
		t.Fatalf("unmarked nonempty archive was claimed: %v", err)
	}
	if _, present, err := ReadCaptureTarget(unmarked); err != nil || present {
		t.Fatalf("failed claim wrote a marker: present=%v err=%v", present, err)
	}
}

func TestCaptureTargetAllowsOnlyStructuralLogEntriesBeforeFirstClaim(t *testing.T) {
	root := t.TempDir()
	log := filepath.Join(root, "log")
	if err := os.Mkdir(log, 0700); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"lock", "README.md"} {
		if err := os.WriteFile(filepath.Join(log, name), nil, 0600); err != nil {
			t.Fatal(err)
		}
	}
	if err := GuardCaptureTarget(root, "sidi128"); err != nil {
		t.Fatalf("empty archive structure should be claimable: %v", err)
	}
	if err := os.WriteFile(filepath.Join(log, "history.log"), []byte("old rows\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := GuardCaptureTarget(root, "mister"); err == nil {
		t.Fatal("existing marked archive accepted a different target")
	}
}

func TestAdoptLegacySiDi128RequiresConfirmationAndRejectsMiSTerProvenance(t *testing.T) {
	root := t.TempDir()
	legacyGame := filepath.Join(root, "contra", "contra", "ref")
	if err := os.MkdirAll(legacyGame, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(legacyGame, "frame_00000100.png"), []byte("legacy"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := AdoptLegacySiDi128(root, ""); err == nil {
		t.Fatal("adoption did not require explicit confirmation")
	}
	if err := AdoptLegacySiDi128(root, "mister"); err == nil {
		t.Fatal("adoption accepted confirmation for another target")
	}
	if err := os.MkdirAll(filepath.Join(root, "log"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "log", "mister.json"), []byte(`{"capture_runs":{"scope":{"target":"mister"}}}`), 0600); err != nil {
		t.Fatal(err)
	}
	if err := AdoptLegacySiDi128(root, "sidi128"); err == nil || !strings.Contains(err.Error(), "MiSTer") {
		t.Fatalf("MiSTer provenance adoption result = %v", err)
	}
	if _, present, err := ReadCaptureTarget(root); err != nil || present {
		t.Fatalf("rejected adoption left a marker: present=%v err=%v", present, err)
	}
	if err := os.Remove(filepath.Join(root, "log", "mister.json")); err != nil {
		t.Fatal(err)
	}
	if err := AdoptLegacySiDi128(root, "sidi128"); err != nil {
		t.Fatalf("explicit legacy adoption failed: %v", err)
	}
	if err := RequireCaptureTarget(root, "sidi128"); err != nil {
		t.Fatal(err)
	}
	if err := RequireCaptureTarget(root, "mister"); err == nil {
		t.Fatal("adopted SiDi128 archive was accepted as MiSTer")
	}
	if got, err := os.ReadFile(filepath.Join(legacyGame, "frame_00000100.png")); err != nil || string(got) != "legacy" {
		t.Fatalf("adoption modified existing archive data: %q %v", got, err)
	}
}
