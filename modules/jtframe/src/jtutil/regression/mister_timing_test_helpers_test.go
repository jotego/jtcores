/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func pinJTFRAMEForSourceTest(t *testing.T, source, core, macrosDef string) {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("locate jtframe test source")
	}
	jtframe := filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
	gitDir, err := exec.Command("git", "-C", jtframe, "rev-parse", "--git-dir").Output()
	if err != nil {
		t.Fatalf("locate selected source git metadata: %v", err)
	}
	if err = os.WriteFile(filepath.Join(source, ".git"), []byte("gitdir: "+strings.TrimSpace(string(gitDir))+"\n"), 0600); err != nil {
		t.Fatal(err)
	}
	moduleLink := filepath.Join(source, "modules", "jtframe")
	if err := os.MkdirAll(filepath.Dir(moduleLink), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(jtframe, moduleLink); err != nil {
		t.Fatal(err)
	}
	cfg := filepath.Join(source, "cores", core, "cfg")
	if err := os.MkdirAll(cfg, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(cfg, "macros.def"), []byte(macrosDef), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("JTROOT", source)
	t.Setenv("JTFRAME", moduleLink)
}

func TestMiSTerConfigVersionMatchesMainLowercaseVRule(t *testing.T) {
	for _, test := range []struct {
		config string
		want   uint64
	}{
		{config: "JTCIRCUS;;V,vab123;", want: 0},
		{config: "JTCIRCUS;;V,v07abc;", want: 0},
		{config: "JTCIRCUS;;v,ab;", want: 0},
		{config: "JTCIRCUS;;v,c1;", want: 0},
		{config: "JTCIRCUS;;v,ff;", want: 0},
		{config: "JTCIRCUS;;v,00;", want: 0},
		{config: "JTCIRCUS;;v,07;", want: 7},
		{config: "JTCIRCUS;;v,1f;", want: 1},
		{config: "JTCIRCUS;;v,9a;", want: 9},
		{config: "JTCIRCUS;;v,68;", want: 68},
		{config: "JTCIRCUS;;v52;", want: 0},
		{config: "JTCIRCUS;; v,07;", want: 0},
		{config: "JTCIRCUS;;v,7;v,ab;", want: 7},
		{config: "JTCIRCUS;;v,7;v,00;", want: 7},
	} {
		got, err := miSTerConfigVersion(test.config)
		if err != nil || got != test.want {
			t.Errorf("miSTerConfigVersion(%q) = %d, %v; want %d", test.config, got, err, test.want)
		}
	}
	if got := miSTerNativeStatusPath("another-set", 52); got != "/media/fat/config/another-set_v52.CFG" {
		t.Fatalf("native config path = %q", got)
	}

	source := t.TempDir()
	_, file, _, _ := runtime.Caller(0)
	jtframe := filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
	gitDir, err := exec.Command("git", "-C", jtframe, "rev-parse", "--git-dir").Output()
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(source, ".git"), []byte("gitdir: "+strings.TrimSpace(string(gitDir))+"\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if err = os.MkdirAll(filepath.Join(source, "cores", "circus", "cfg"), 0700); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(source, "cores", "circus", "cfg", "macros.def"), []byte("JTFRAME_RATE=60.00\n"), 0600); err != nil {
		t.Fatal(err)
	}
	frameLink := filepath.Join(source, "modules", "jtframe")
	if err = os.MkdirAll(filepath.Dir(frameLink), 0700); err != nil {
		t.Fatal(err)
	}
	if err = os.Symlink(jtframe, frameLink); err != nil {
		t.Fatal(err)
	}
	t.Setenv("JTROOT", source)
	t.Setenv("JTFRAME", frameLink)
	if _, err = MiSTerConfigVersion(source, "circus"); err != nil {
		t.Fatalf("render native config through jtframe cfgstr provider: %v", err)
	}
}

func TestSourceCommitViewUsesSelectedCommitConfigWithNewerActiveCheckout(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	frame := filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
	root := t.TempDir()
	runGit := func(args ...string) string {
		t.Helper()
		cmd := exec.Command("git", append([]string{"-C", root}, args...)...)
		out, err := cmd.CombinedOutput()
		if err != nil {
			t.Fatalf("git %v: %v: %s", args, err, out)
		}
		return strings.TrimSpace(string(out))
	}
	runGit("init", "-q", "-b", "master")
	runGit("config", "user.name", "JTFRAME test")
	runGit("config", "user.email", "test@example.invalid")
	if err := os.MkdirAll(filepath.Join(root, "cores", "circus", "cfg"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(root, "modules"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(frame, filepath.Join(root, "modules", "jtframe")); err != nil {
		t.Fatal(err)
	}
	writeMacros := func(rate, color string) {
		t.Helper()
		body := fmt.Sprintf("CORENAME=JTCIRCUS\nJTFRAME_RATE=%s\nJTFRAME_COLORW=%s\n", rate, color)
		if err := os.WriteFile(filepath.Join(root, "cores", "circus", "cfg", "macros.def"), []byte(body), 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(root, "cores", "circus", "cfg", "mem.yaml"), []byte("\n"), 0600); err != nil {
			t.Fatal(err)
		}
	}
	writeMacros("60.00", "4")
	runGit("add", ".")
	runGit("commit", "-qm", "A initial")
	a := runGit("rev-parse", "HEAD")
	writeMacros("75.00", "8")
	runGit("add", ".")
	runGit("commit", "-qm", "C initial")
	c := runGit("rev-parse", "HEAD")
	if a == c || runGit("rev-parse", "HEAD") != c {
		t.Fatal("fixture did not advance from selected A to active C")
	}
	shallow := filepath.Join(t.TempDir(), "shallow")
	shallowURL := "file://" + filepath.ToSlash(root)
	if output, err := exec.Command("git", "clone", "--quiet", "--depth", "1", "--branch", "master", shallowURL, shallow).CombinedOutput(); err != nil {
		t.Fatalf("create shallow checkout fixture: %v: %s", err, output)
	}
	if err := RequireSourceCommit(context.Background(), shallow, a, "circus"); err == nil {
		t.Fatal("shallow scheduled checkout unexpectedly contains the older queued workflow commit")
	}
	view, err := OpenSourceCommitView(context.Background(), root, a)
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		if err := view.Close(); err != nil {
			t.Errorf("close source view: %v", err)
		}
	}()
	if version, err := MiSTerConfigVersion(view.Root, "circus"); err != nil || version != 0 {
		t.Fatalf("selected A native config version = %d, %v; want no suffix for V,v<commit>", version, err)
	}
	if rate, _, err := resolveMiSTerFrameRate(view.Root, "circus", "testset"); err != nil || rate != 60000 {
		t.Fatalf("selected A frame rate = %d mHz, %v; want 60000", rate, err)
	}
	if precision, err := mame_capture_precision(view.Root, "circus", "mister"); err != nil || precision != 4 {
		t.Fatalf("selected A COLORW precision = %d, %v; want 4", precision, err)
	}
	if version, err := MiSTerConfigVersion(root, "circus"); err != nil || version != 0 {
		t.Fatalf("active C native config version = %d, %v; want no suffix for V,v<commit>", version, err)
	}
	if rate, _, err := resolveMiSTerFrameRate(root, "circus", "testset"); err != nil || rate != 75000 {
		t.Fatalf("active C frame rate = %d mHz, %v; want 75000", rate, err)
	}
	if precision, err := mame_capture_precision(root, "circus", "mister"); err != nil || precision != 8 {
		t.Fatalf("active C COLORW precision = %d, %v; want 8", precision, err)
	}
}

func TestRequireSourceCommitChecksObjectAvailabilityOnly(t *testing.T) {
	root := os.Getenv("JTROOT")
	if root == "" {
		t.Skip("JTROOT is not configured")
	}
	commit, err := exec.Command("git", "-C", root, "rev-parse", "HEAD~1").Output()
	if err != nil {
		t.Fatal(err)
	}
	if err = RequireSourceCommit(context.Background(), root, strings.TrimSpace(string(commit)), "circus"); err != nil {
		t.Fatalf("available workflow commit rejected when checkout is newer: %v", err)
	}
	if err = RequireSourceCommit(context.Background(), root, strings.Repeat("a", 40), "circus"); err == nil {
		t.Fatal("unavailable workflow commit accepted")
	}
}

func TestResolveJTFRAMEValueMissingMacrosReturnsPerCoreError(t *testing.T) {
	source := t.TempDir()
	pinJTFRAMEForSourceTest(t, source, "valid", "JTFRAME_RATE=60.00\n")
	if err := os.MkdirAll(filepath.Join(source, "cores", "missing", "cfg"), 0700); err != nil {
		t.Fatal(err)
	}
	if _, err := resolveJTFRAMEValue(source, "missing", "mister", "JTFRAME_RATE"); err == nil || !strings.Contains(err.Error(), "macros.def") {
		t.Fatalf("missing core macros result = %v", err)
	}
	if got, err := resolveJTFRAMEValue(source, "valid", "mister", "JTFRAME_RATE"); err != nil || got != "60.00" {
		t.Fatalf("valid core after missing-core lookup = %q, %v", got, err)
	}
}
