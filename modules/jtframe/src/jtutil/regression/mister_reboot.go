/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"strings"
	"time"
)

// miSTerRebootTimeout bounds the wait for Linux and Main to come back.
const miSTerRebootTimeout = 4 * time.Minute

// miSTerRebooter is the optional remote operation used to recover a board
// whose attempt could not be cleaned up exactly.
type miSTerRebooter interface {
	Reboot(context.Context) error
}

// Reboot runs the reboot in its own session so closing SSH cannot kill it.
func (r MiSTerSSHRemote) Reboot(ctx context.Context) error {
	_, err := r.runSSH(ctx, "sync; setsid nohup sh -c 'sleep 1; reboot' </dev/null >/dev/null 2>&1 &", nil, 1024)
	return err
}

// recoverByReboot brings a board back to a usable state after any failed
// attempt instead of quarantining it. It restores the backed-up files, reboots
// so no core or capture session survives, waits for the qualified Main on its
// original loader and removes the files the attempt owned. Files that changed
// or are missing are reported but do not block recovery. The ledger is gone
// once this returns nil, so the board can take the next game.
func (d *MiSTerSessionDriver) recoverByReboot(ctx context.Context, cause error) (SessionCleanup, error) {
	rebooter, ok := d.Remote.(miSTerRebooter)
	if !ok {
		return SessionCleanup{}, fmt.Errorf("board cannot be rebooted for recovery: %w", cause)
	}
	d.mu.Lock()
	lock := d.lockFile
	d.mu.Unlock()
	if lock == nil {
		file, lockPath, ledgerPath, err := d.acquireLock()
		if err != nil {
			return SessionCleanup{}, err
		}
		d.mu.Lock()
		d.lockFile, d.lockPath, d.ledgerPath = file, lockPath, ledgerPath
		d.mu.Unlock()
	}
	ledgerPath := d.ledgerName()
	var ledger miSTerBoardLedger
	hasLedger := false
	if data, err := os.ReadFile(ledgerPath); err == nil {
		if json.Unmarshal(data, &ledger) == nil && ledger.Board == d.Config.BoardKey {
			hasLedger = true
		}
	} else if !os.IsNotExist(err) {
		return SessionCleanup{}, err
	}
	var warnings []string
	if hasLedger {
		_ = d.writeLedger(ledger, "reboot_recovery", "recovering by reboot")
		if err := d.restoreRecoveryBackups(ctx, ledger.Backups); err != nil {
			warnings = append(warnings, "restore before reboot: "+err.Error())
		}
	}
	before, _ := d.Remote.Probe(ctx)
	if err := rebooter.Reboot(ctx); err != nil {
		return SessionCleanup{}, fmt.Errorf("reboot board: %w", err)
	}
	snapshot, err := d.waitForReboot(ctx, before)
	if err != nil {
		return SessionCleanup{}, err
	}
	if snapshot, err = d.loadMenuAfterBoot(ctx, snapshot); err != nil {
		return SessionCleanup{}, err
	}
	if hasLedger {
		// Main may write NVRAM or CFG while it shuts down; restore again.
		if err = d.restoreRecoveryBackups(ctx, ledger.Backups); err != nil {
			return SessionCleanup{}, fmt.Errorf("restore pre-attempt files after reboot: %w", err)
		}
		if ledger.OriginalLoaderKind != "" && ledger.OriginalLoaderKind != "menu-rbf" {
			restoreArg, argErr := originalLoaderCommand(ledger)
			if argErr != nil {
				return SessionCleanup{}, fmt.Errorf("original loader is unknown after reboot: %w", argErr)
			}
			if err = d.Remote.WriteFIFO(ctx, []byte("load_core "+restoreArg+"\n"), d.Config.CommandTimeout); err != nil {
				return SessionCleanup{}, fmt.Errorf("load original core after reboot: %w", err)
			}
			if snapshot, err = d.waitForOriginalSnapshot(ctx, ledger); err != nil {
				return SessionCleanup{}, err
			}
		}
		for _, owned := range ledger.OwnedFiles {
			if !owned.Owned || owned.SHA256 == "" || validMiSTerRemotePath(owned.Path) != nil {
				continue
			}
			if err = d.Remote.RemoveOwned(ctx, owned.Path, owned.SHA256); err != nil {
				warnings = append(warnings, "remove "+path.Base(owned.Path)+": "+err.Error())
			}
		}
		if validateMiSTerOwnedDirs(ledger) == nil {
			for _, directory := range ledger.OwnedDirs {
				if err = d.Remote.RemoveEmptyDir(ctx, directory); err != nil {
					warnings = append(warnings, "remove directory "+path.Base(directory)+": "+err.Error())
				}
			}
		}
		if ledger.BackupDir != "" && strings.HasPrefix(filepath.Clean(ledger.BackupDir), filepath.Clean(d.Config.WorkspaceDir)+string(filepath.Separator)) {
			_ = removeSessionWorkspace(d.Config.WorkspaceDir, filepath.Dir(ledger.BackupDir))
		}
	}
	if err = d.validateSnapshot(snapshot); err != nil {
		return SessionCleanup{}, fmt.Errorf("board after reboot: %w", err)
	}
	if err = os.Remove(ledgerPath); err != nil && !os.IsNotExist(err) {
		return SessionCleanup{}, err
	}
	_ = syncDirectory(d.Config.LocalStateDir)
	d.releaseLock()
	message := "recovered by reboot"
	if cause != nil {
		message += " after: " + cause.Error()
	}
	if len(warnings) != 0 {
		message += "; " + strings.Join(warnings, "; ")
	}
	return SessionCleanup{Confirmed: true, Message: message}, nil
}

// waitForReboot waits for a new Main process with the qualified identity.
// With no previous snapshot, any qualified Main on its loader is accepted.
func (d *MiSTerSessionDriver) waitForReboot(ctx context.Context, before MiSTerBoardSnapshot) (MiSTerBoardSnapshot, error) {
	deadline := d.Now().Add(miSTerRebootTimeout)
	for {
		if err := d.Sleep(ctx, d.rebootPollInterval()); err != nil {
			return MiSTerBoardSnapshot{}, err
		}
		snapshot, err := d.Remote.Probe(ctx)
		if err == nil && (before.MainPID == 0 || snapshot.MainPID != before.MainPID) && d.validateSnapshot(snapshot) == nil {
			return snapshot, nil
		}
		if d.Now().After(deadline) {
			if err == nil {
				err = fmt.Errorf("Main PID %d, rbf %q", snapshot.MainPID, snapshot.ArgvRBF)
			}
			return MiSTerBoardSnapshot{}, fmt.Errorf("board did not come back with the qualified Main after reboot: %w", err)
		}
	}
}

func (d *MiSTerSessionDriver) rebootPollInterval() time.Duration {
	if d.Config.PollInterval > 0 {
		return d.Config.PollInterval
	}
	return 5 * time.Second
}

// freshBootLoader reports Main started by the boot scripts, which run it with
// no RBF argument. The capture path pins the exact loader argv, so the menu
// must be loaded once through Main to get the "menu.rbf" argv.
func freshBootLoader(snapshot MiSTerBoardSnapshot) bool {
	return snapshot.ArgvRBF == "" && snapshot.ArgvMRA == ""
}

// loadMenuAfterBoot loads menu.rbf through Main after a fresh boot and waits
// for the new Main process with the qualified identity.
func (d *MiSTerSessionDriver) loadMenuAfterBoot(ctx context.Context, snapshot MiSTerBoardSnapshot) (MiSTerBoardSnapshot, error) {
	if !freshBootLoader(snapshot) {
		return snapshot, nil
	}
	if err := d.Remote.WriteFIFO(ctx, []byte("load_core menu.rbf\n"), d.Config.CommandTimeout); err != nil {
		return MiSTerBoardSnapshot{}, fmt.Errorf("load MENU after boot: %w", err)
	}
	deadline := d.Now().Add(d.Config.LoadTimeout)
	for {
		if err := d.Sleep(ctx, d.pollInterval()); err != nil {
			return MiSTerBoardSnapshot{}, err
		}
		loaded, err := d.Remote.Probe(ctx)
		if err == nil && loaded.MainPID != snapshot.MainPID && loaded.ArgvRBF == "menu.rbf" && loaded.ArgvMRA == "" && d.validateSnapshot(loaded) == nil {
			return loaded, nil
		}
		if d.Now().After(deadline) {
			return MiSTerBoardSnapshot{}, fmt.Errorf("MENU did not load after boot")
		}
	}
}

// restoreRecoveryBackups restores like restoreBackups but accepts a file that
// already has its backed-up content on the board, so a lost local copy only
// matters when the board file actually differs.
func (d *MiSTerSessionDriver) restoreRecoveryBackups(ctx context.Context, backups []miSTerFileBackup) error {
	pending := make([]miSTerFileBackup, 0, len(backups))
	for _, backup := range backups {
		if backup.Exists && isSHA256Hex(backup.SHA256) {
			if current, exists, err := d.Remote.File(ctx, backup.Path, miSTerRemoteOutputLimit); err == nil && exists && digestBytes(current) == backup.SHA256 {
				continue
			}
		}
		pending = append(pending, backup)
	}
	return d.restoreBackups(ctx, pending)
}
