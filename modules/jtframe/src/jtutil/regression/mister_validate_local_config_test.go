/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type forbiddenLocalConfigRemote struct{ MiSTerRemote }

func TestMiSTerValidateLocalConfigUsesRuntimeBoundsWithoutRemoteCalls(t *testing.T) {
	tests := []struct {
		name        string
		command     time.Duration
		load        time.Duration
		capture     time.Duration
		cleanup     time.Duration
		holdMS      uint32
		mainINIPath string
		wantErr     bool
	}{
		{name: "accepted 180 second capture", command: 30 * time.Second, load: 5 * time.Minute, capture: 180 * time.Second, cleanup: 120 * time.Second, holdMS: 1000, mainINIPath: "/media/fat/MiSTer.ini"},
		{name: "runtime-rejected 3600 second capture", command: 30 * time.Second, load: 5 * time.Minute, capture: 3600 * time.Second, cleanup: 120 * time.Second, holdMS: 1000, mainINIPath: "/media/fat/MiSTer.ini", wantErr: true},
		{name: "command timeout above runtime bound", command: 121 * time.Second, load: 5 * time.Minute, capture: 180 * time.Second, cleanup: 120 * time.Second, holdMS: 1000, mainINIPath: "/media/fat/MiSTer.ini", wantErr: true},
		{name: "load timeout above runtime bound", command: 30 * time.Second, load: 301 * time.Second, capture: 180 * time.Second, cleanup: 120 * time.Second, holdMS: 1000, mainINIPath: "/media/fat/MiSTer.ini", wantErr: true},
		{name: "cleanup timeout above runtime bound", command: 30 * time.Second, load: 5 * time.Minute, capture: 180 * time.Second, cleanup: 301 * time.Second, holdMS: 1000, mainINIPath: "/media/fat/MiSTer.ini", wantErr: true},
		{name: "capture hold above runtime bound", command: 30 * time.Second, load: 5 * time.Minute, capture: 180 * time.Second, cleanup: 120 * time.Second, holdMS: 2001, mainINIPath: "/media/fat/MiSTer.ini", wantErr: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			root := t.TempDir()
			stateDir, workspaceDir := filepath.Join(root, "state"), filepath.Join(root, "workspace")
			driver := &MiSTerSessionDriver{Remote: forbiddenLocalConfigRemote{}, Config: MiSTerDriverConfig{
				BoardKey: "mister-home", MainSHA256: strings.Repeat("a", 64), MainINIPath: test.mainINIPath,
				LocalStateDir: stateDir, WorkspaceDir: workspaceDir, CommandTimeout: test.command,
				LoadTimeout: test.load, CaptureTimeout: test.capture, CleanupTimeout: test.cleanup,
				MaxHoldMS: test.holdMS, ExpectedBridgeCount: 3,
			}}
			err := driver.ValidateLocalConfig()
			if (err != nil) != test.wantErr {
				t.Fatalf("ValidateLocalConfig() error = %v, wantErr %v", err, test.wantErr)
			}
			if err == nil {
				for _, dir := range []string{stateDir, workspaceDir} {
					info, statErr := os.Lstat(dir)
					if statErr != nil || !info.IsDir() || info.Mode().Perm()&0077 != 0 {
						t.Fatalf("local validation did not create a private directory %q: %v", dir, statErr)
					}
				}
				if driver.Now == nil || driver.Sleep == nil {
					t.Fatal("local validation did not initialize the runtime clock defaults")
				}
			}
		})
	}
}
