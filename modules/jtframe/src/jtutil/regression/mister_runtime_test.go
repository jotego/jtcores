/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildMiSTerPoolBoardsPreflightsDriverBeforeCABStaging(t *testing.T) {
	for _, test := range []struct {
		name            string
		captureTimeout  int
		maxHoldMS       uint32
		wantErrContains string
	}{
		{name: "driver capture timeout", captureTimeout: 3600, maxHoldMS: 250, wantErrContains: "local MiSTer driver config"},
		{name: "unsupported hold", captureTimeout: 900, maxHoldMS: 2001, wantErrContains: "outside supported bounds"},
	} {
		t.Run(test.name, func(t *testing.T) {
			root := t.TempDir()
			sshConfig := filepath.Join(root, "ssh.conf")
			if err := os.WriteFile(sshConfig, []byte("Host board\n"), 0600); err != nil {
				t.Fatal(err)
			}
			remoteMarker := installMiSTerRemoteCallSentinel(t, root)
			cfg := runtimeBuilderTestConfig(root, sshConfig, test.captureTimeout, test.maxHoldMS)
			prepared := makeRuntimePoolPreparedGame(t, root, "fixture")
			_, err := BuildMiSTerPoolBoards(cfg, []MiSTerPreparedGame{prepared}, filepath.Join(root, "data"))
			if err == nil || !strings.Contains(err.Error(), test.wantErrContains) {
				t.Fatalf("BuildMiSTerPoolBoards error = %v, want text %q", err, test.wantErrContains)
			}
			if _, err = os.Lstat(filepath.Join(root, "data", "log", ".mister-inputs")); !os.IsNotExist(err) {
				t.Fatalf("invalid config staged CAB directory: stat error = %v", err)
			}
			for _, localRoot := range []string{".mister-state", ".mister-workspaces"} {
				if _, err = os.Lstat(filepath.Join(root, "data", "log", localRoot)); !os.IsNotExist(err) {
					t.Fatalf("invalid config staged local %s directory: stat error = %v", localRoot, err)
				}
			}
			if _, err = os.Lstat(remoteMarker); !os.IsNotExist(err) {
				t.Fatalf("invalid config made a remote call: marker stat error = %v", err)
			}
		})
	}
}

func TestBuildMiSTerPoolBoardsAcceptsDocumentedAndPilotTimeouts(t *testing.T) {
	for _, timeout := range []int{900, 180} {
		t.Run(fmt.Sprintf("timeout-%d", timeout), func(t *testing.T) {
			root := t.TempDir()
			sshConfig := filepath.Join(root, "ssh.conf")
			if err := os.WriteFile(sshConfig, []byte("Host board\n"), 0600); err != nil {
				t.Fatal(err)
			}
			remoteMarker := installMiSTerRemoteCallSentinel(t, root)
			cfg := runtimeBuilderTestConfig(root, sshConfig, timeout, 250)
			prepared := makeRuntimePoolPreparedGame(t, root, "fixture")
			boards, err := BuildMiSTerPoolBoards(cfg, []MiSTerPreparedGame{prepared}, filepath.Join(root, "data"))
			if err != nil {
				t.Fatalf("valid timeout %d rejected: %v", timeout, err)
			}
			if len(boards) != 1 {
				t.Fatalf("got %d boards, want one", len(boards))
			}
			identity, err := prepared.Job.Session.PortableIdentity()
			if err != nil {
				t.Fatal(err)
			}
			cabPath := filepath.Join(root, "data", "log", ".mister-inputs", identity+".jtcab")
			if info, statErr := os.Lstat(cabPath); statErr != nil || !info.Mode().IsRegular() {
				t.Fatalf("valid config did not stage CAB: info=%v err=%v", info, statErr)
			}
			if _, err = os.Lstat(remoteMarker); !os.IsNotExist(err) {
				t.Fatalf("local board construction made a remote call: marker stat error = %v", err)
			}
		})
	}
}

func TestBuildMiSTerPoolBoardsRejectsRawLaunchBeforeDispatch(t *testing.T) {
	root := t.TempDir()
	sshConfig := filepath.Join(root, "ssh.conf")
	if err := os.WriteFile(sshConfig, []byte("Host board\n"), 0600); err != nil {
		t.Fatal(err)
	}
	remoteMarker := installMiSTerRemoteCallSentinel(t, root)
	cfg := runtimeBuilderTestConfig(root, sshConfig, 180, 1000)
	prepared := makeRunCommitPreparedGame(t, root, "raw-launch")
	boards, err := BuildMiSTerPoolBoards(cfg, []MiSTerPreparedGame{prepared}, filepath.Join(root, "data"))
	if err == nil || !strings.Contains(err.Error(), "verified path-only RBF derivative") {
		t.Fatalf("raw launch mapping error=%v", err)
	}
	if boards != nil {
		t.Fatalf("invalid runtime input returned %d dispatchable boards", len(boards))
	}
	if _, err = os.Lstat(remoteMarker); !os.IsNotExist(err) {
		t.Fatalf("invalid runtime input caused a remote call: marker stat error = %v", err)
	}
}

func makeRuntimePoolPreparedGame(t *testing.T, root, setname string) MiSTerPreparedGame {
	t.Helper()
	prepared := makeRunCommitPreparedGame(t, root, setname)
	originalPath := prepared.Spec.MisterAssets.OriginalMRA.Path
	original, err := os.ReadFile(originalPath)
	if err != nil {
		t.Fatal(err)
	}
	stem := "jt224-" + prepared.Job.Session.RBF.SHA256[:24]
	launch, err := pathOnlyLaunchMRA(original, stem)
	if err != nil {
		t.Fatal(err)
	}
	launchPath := filepath.Join(filepath.Dir(originalPath), stem+".mra")
	if err = os.WriteFile(launchPath, launch, 0600); err != nil {
		t.Fatal(err)
	}
	launchSHA := digestBytes(launch)
	prepared.Job.Session.LaunchMRA.SHA256 = launchSHA
	prepared.Job.Session.Paths.LaunchMRA = launchPath
	prepared.Spec.MisterAssets.LaunchMRA = MiSTerAssetFile{Role: FixtureLaunchMRA, Name: filepath.Base(launchPath), Path: launchPath, SHA256: launchSHA}
	return prepared
}

func installMiSTerRemoteCallSentinel(t *testing.T, root string) string {
	t.Helper()
	binDir := filepath.Join(root, "fake-bin")
	if err := os.Mkdir(binDir, 0700); err != nil {
		t.Fatal(err)
	}
	marker := filepath.Join(root, "remote-called")
	script := []byte(fmt.Sprintf("#!/bin/sh\nprintf called > %q\n", marker))
	for _, tool := range []string{"ssh", "scp", "sshpass"} {
		if err := os.WriteFile(filepath.Join(binDir, tool), script, 0700); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", binDir+string(os.PathListSeparator)+os.Getenv("PATH"))
	return marker
}

func runtimeBuilderTestConfig(root, sshConfig string, captureTimeout int, maxHoldMS uint32) Config {
	return Config{Target: "mister", Root: filepath.Join(root, "results"), Boards: []MiSTerBoardConfig{{
		ID: "board-a", Host: "192.0.2.1", User: "jt", SSHConfig: sshConfig, RemoteStagingRoot: "/media/fat/_Arcade",
	}}, CaptureContract: &MiSTerCaptureContract{Generation: "gen-r1", Convention: CaptureNativeNonRotatedRGB888,
		QualificationID: "qual-r1", QualificationEvidence: filepath.Join(root, "qual.json"), MainSHA256: strings.Repeat("c", 64),
		CommandTimeoutSeconds: 5, LoadTimeoutSeconds: 5, CaptureTimeoutSeconds: captureTimeout, CleanupTimeoutSeconds: 5,
		MaxHoldMS: maxHoldMS, ExpectedBridgeCount: 2}}
}
