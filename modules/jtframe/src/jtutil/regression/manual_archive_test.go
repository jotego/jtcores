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

func TestResolveManualArchiveFullSHAUsesSevenCharacterZIP(t *testing.T) {
	root := t.TempDir()
	const sha = "0123456789abcdef0123456789abcdef01234567"
	archivePath := filepath.Join(root, sha[:7]+".zip")
	if err := os.WriteFile(archivePath, []byte("zip fixture"), 0600); err != nil {
		t.Fatal(err)
	}
	oldResolver := resolveManualGitCommit
	resolveManualGitCommit = func(context.Context, string, string) (string, error) { return "", os.ErrNotExist }
	t.Cleanup(func() { resolveManualGitCommit = oldResolver })
	archive, err := ResolveManualArchive(context.Background(), t.TempDir(), root, sha)
	if err != nil || archive.Commit != sha || archive.Path != archivePath || archive.SHA256 == "" {
		t.Fatalf("archive=%+v err=%v", archive, err)
	}
}

func TestResolveManualArchiveRequiresResolvableShortSHA(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "0123456.zip"), []byte("archive"), 0600); err != nil {
		t.Fatal(err)
	}
	oldResolver := resolveManualGitCommit
	resolveManualGitCommit = func(context.Context, string, string) (string, error) { return "", os.ErrNotExist }
	t.Cleanup(func() { resolveManualGitCommit = oldResolver })
	_, err := ResolveManualArchive(context.Background(), t.TempDir(), root, "0123456")
	if err == nil || !strings.Contains(err.Error(), "full 40-character SHA") {
		t.Fatalf("expected actionable full-SHA error, got %v", err)
	}
}

func TestResolveManualArchiveRejectsAmbiguousFullArchiveBasenames(t *testing.T) {
	root := t.TempDir()
	for _, name := range []string{"abcdef0" + "1111111111111111111111111111111" + ".zip", "abcdef0" + "2222222222222222222222222222222" + "-sidi128.zip"} {
		if err := os.WriteFile(filepath.Join(root, name), []byte("archive"), 0600); err != nil {
			t.Fatal(err)
		}
	}
	_, err := full_archive_commit(root, "abcdef0")
	if err == nil {
		t.Fatal("ambiguous archive commit prefix accepted")
	}
}

func TestManualCoreCoverageChecksEveryRequestedCore(t *testing.T) {
	if err := requireManualCoreCoverage([]string{"alpha", "beta"}, map[string]bool{"alpha": true, "beta": true}, "archive"); err != nil {
		t.Fatal(err)
	}
	for _, matched := range []map[string]bool{{"alpha": true}, {}} {
		if err := requireManualCoreCoverage([]string{"alpha", "beta"}, matched, "manual"); err == nil {
			t.Fatalf("accepted incomplete core coverage: %v", matched)
		}
	}
}
