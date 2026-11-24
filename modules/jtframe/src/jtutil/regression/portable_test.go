/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestResumeAcrossTemporaryCheckouts(t *testing.T) {
	record, manifest, cfg, hardware := compact_fixture(t)
	if err := RunCommit(context.Background(), record, manifest, cfg, hardware, false, false); err != nil {
		t.Fatal(err)
	}
	game := manifest.Cores[0].Games[0]
	relocate := func(path string) string {
		if path == "" {
			return ""
		}
		data, err := os.ReadFile(path)
		if os.IsNotExist(err) {
			return path
		}
		if err != nil {
			t.Fatal(err)
		}
		next := filepath.Join(t.TempDir(), filepath.Base(path))
		manualWrite(t, next, data)
		return next
	}
	game.ARC = relocate(game.ARC)
	game.RBF = relocate(game.RBF)
	game.CAB = relocate(game.CAB)
	game.SourceCAB = relocate(game.SourceCAB)
	game.ROMs = append([]string(nil), game.ROMs...)
	for i, path := range game.ROMs {
		game.ROMs[i] = relocate(path)
	}
	next := t.TempDir()
	profile := filepath.Join(cfg.Source, "cores", "fake", "cfg", "reg.yaml")
	if data, err := os.ReadFile(profile); err == nil {
		manualWrite(t, filepath.Join(next, "cores", "fake", "cfg", "reg.yaml"), data)
	}
	cfg.Source = next
	cfg.GlobalProfile = relocate(cfg.GlobalProfile)
	manifest.Cores[0].Games[0] = game
	if err := RunCommit(context.Background(), record, manifest, cfg, hardware, false, false); err != nil {
		t.Fatal(err)
	}
	if hardware.loads != 1 {
		t.Fatal("temporary checkout paths caused recapture")
	}
	manualWrite(t, game.ARC, []byte("changed board input"))
	if err := RunCommit(context.Background(), record, manifest, cfg, hardware, false, false); err != nil {
		t.Fatal(err)
	}
	if hardware.loads != 2 {
		t.Fatal("changed board input was skipped")
	}
}

func TestCancellationReleasesSharedLock(t *testing.T) {
	root := t.TempDir()
	lock, err := AcquireLock(root)
	if err != nil {
		t.Fatal(err)
	}
	record, manifest, cfg, hardware := compact_fixture(t)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	func() {
		defer ReleaseLock(lock)
		if err = RunCommit(ctx, record, manifest, cfg, hardware, false, false); err == nil {
			t.Fatal("cancellation ignored")
		}
	}()
	next, err := AcquireLock(root)
	if err != nil {
		t.Fatal(err)
	}
	ReleaseLock(next)
	if record.Progress.Status != "interrupted" {
		t.Fatal("progress cannot resume")
	}
	if !strings.Contains(record.Progress.Error, "canceled") {
		t.Fatal(record.Progress.Error)
	}
}
