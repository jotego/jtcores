/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"archive/zip"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSharedBuildArchiveReuseAndRestore(t *testing.T) {
	check_preparation_cleanup(t)
	root := t.TempDir()
	cfg := Config{Source: filepath.Join(root, "project"), BuildsDir: filepath.Join(root, "store")}
	id := BuildIdentity{Repository: "jotego/jtcores", RunID: "456", Attempt: "2", SHA: strings.Repeat("a", 40), Artifact: "aaaaaaa.zip", ArtifactID: 765}
	if err := os.MkdirAll(cfg.BuildsDir, 0750); err != nil {
		t.Fatal(err)
	}
	archive := filepath.Join(cfg.BuildsDir, id.Artifact)
	files := map[string]string{"release/sidi128/jtfoo.rbf": "sidi128", "release/mister/jtfoo.rbf": "mister", "release/mra/Foo.mra": "mra", "release/pocket/raw/Cores/jotego.foo/core.json": "pocket"}
	writeZip(t, archive, files)
	original := readString(t, archive)
	manualWrite(t, filepath.Join(cfg.Source, "release", "sidi128", "jtold.rbf"), []byte("old build"))
	manualWrite(t, filepath.Join(cfg.Source, "release", "notes.txt"), []byte("keep"))
	previous := ghArtifactDownload
	t.Cleanup(func() { ghArtifactDownload = previous })
	ghArtifactDownload = func(context.Context, string, int64, string) error {
		t.Fatal("existing ZIP triggered a download")
		return nil
	}
	log_dir := filepath.Join(root, "log", "preparation")
	for attempt := 0; attempt < 2; attempt++ {
		got, rbfs, err := prepareArtifact(context.Background(), cfg, log_dir, id)
		if err != nil {
			t.Fatal(err)
		}
		if got != archive || rbfs != filepath.Join(cfg.Source, "release", "sidi128") {
			t.Fatalf("wrong locations: %s %s", got, rbfs)
		}
		for name, body := range files {
			if got := readString(t, filepath.Join(cfg.Source, name)); got != body {
				t.Fatalf("%s: %q", name, got)
			}
		}
		if _, err = os.Stat(filepath.Join(rbfs, "jtold.rbf")); !os.IsNotExist(err) {
			t.Fatal("stale RBF survived")
		}
		if readString(t, filepath.Join(cfg.Source, "release", "notes.txt")) != "keep" {
			t.Fatal("unrelated local file changed")
		}
		// A modified extraction is restored from the shared ZIP on the next run.
		manualWrite(t, filepath.Join(rbfs, "jtfoo.rbf"), []byte("modified"))
	}
	if readString(t, archive) != original {
		t.Fatal("shared archive modified")
	}
	var record archive_record
	if err := json.Unmarshal([]byte(readString(t, filepath.Join(log_dir, "build-manifest.json"))), &record); err != nil {
		t.Fatal(err)
	}
	if record.Acquisition != "local-store" || record.ArchivePath != archive || record.RBF["jtfoo.rbf"] == "" {
		t.Fatalf("missing provenance: %+v", record)
	}
	writeZip(t, archive, map[string]string{"release/sidi128/jtfoo.rbf": "different"})
	if _, _, err := prepareArtifact(context.Background(), cfg, log_dir, id); err == nil || !strings.Contains(err.Error(), "recorded build identity") {
		t.Fatalf("accepted changed archive on resume: %v", err)
	}
}

func TestSharedBuildDownloadFailuresLeaveNoArchiveOrRelease(t *testing.T) {
	check_preparation_cleanup(t)
	for _, failure := range []string{"download", "checksum", "payload", "layout"} {
		t.Run(failure, func(t *testing.T) {
			root := t.TempDir()
			cfg := Config{Source: filepath.Join(root, "project"), BuildsDir: filepath.Join(root, "store")}
			id := BuildIdentity{Repository: "jotego/jtcores", RunID: "456", Attempt: "2", SHA: strings.Repeat("a", 40), Artifact: "aaaaaaa.zip", ArtifactID: 765}
			payload := filepath.Join(root, "payload.zip")
			writeZip(t, payload, map[string]string{"release/sidi128/jtfoo.rbf": "rbf"})
			if failure == "layout" {
				writeZip(t, payload, map[string]string{"../outside": "bad"})
			}
			wrapper := filepath.Join(root, "wrapper.zip")
			name := id.Artifact
			if failure == "payload" {
				name = "wrong.zip"
			}
			writeZip(t, wrapper, map[string]string{name: readString(t, payload)})
			if failure == "checksum" {
				id.ArtifactAPIHash = strings.Repeat("0", 64)
			}
			previous := ghArtifactDownload
			t.Cleanup(func() { ghArtifactDownload = previous })
			ghArtifactDownload = func(_ context.Context, _ string, _ int64, destination string) error {
				if failure == "download" {
					return fmt.Errorf("interrupted download")
				}
				return copyFile(wrapper, destination)
			}
			if _, _, err := prepareArtifact(context.Background(), cfg, filepath.Join(root, "log"), id); err == nil {
				t.Fatal("expected failure")
			}
			entries, err := os.ReadDir(cfg.BuildsDir)
			if err != nil || len(entries) != 0 {
				t.Fatalf("download left files: %v %v", entries, err)
			}
			if _, err = os.Stat(filepath.Join(cfg.Source, "release")); !os.IsNotExist(err) {
				t.Fatal("failed archive modified release")
			}
		})
	}
}

func TestBuildExtractionRejectsUnsafeArchivesBeforeReplacingFiles(t *testing.T) {
	check_preparation_cleanup(t)
	for _, bad := range []string{"traversal", "absolute", "duplicate", "symlink", "destination-symlink", "destination-directory", "corrupt", "empty-rbf"} {
		t.Run(bad, func(t *testing.T) {
			root := t.TempDir()
			source := filepath.Join(root, "project")
			old := filepath.Join(source, "release", "sidi128", "jtfoo.rbf")
			manualWrite(t, old, []byte("old"))
			archive := filepath.Join(root, "archive.zip")
			file, err := os.Create(archive)
			if err != nil {
				t.Fatal(err)
			}
			writer := zip.NewWriter(file)
			entry, err := writer.CreateHeader(&zip.FileHeader{Name: "release/sidi128/jtfoo.rbf", Method: zip.Store})
			if err != nil {
				t.Fatal(err)
			}
			if bad != "empty-rbf" {
				entry.Write([]byte("UNIQUE_PAYLOAD"))
			}
			header := &zip.FileHeader{Name: "release/readme.txt"}
			switch bad {
			case "traversal":
				header.Name = "release/../../outside"
			case "absolute":
				header.Name = "/outside"
			case "duplicate":
				header.Name = "release/sidi128/jtfoo.rbf"
			case "symlink":
				header.SetMode(os.ModeSymlink | 0777)
			case "destination-symlink":
				outside := filepath.Join(root, "outside")
				manualWrite(t, outside, []byte("preserve"))
				if err = os.Symlink(outside, filepath.Join(source, "release", "readme.txt")); err != nil {
					t.Fatal(err)
				}
			case "destination-directory":
				if err = os.MkdirAll(filepath.Join(source, "release", "readme.txt"), 0750); err != nil {
					t.Fatal(err)
				}
			}
			entry, err = writer.CreateHeader(header)
			if err != nil {
				t.Fatal(err)
			}
			entry.Write([]byte("content"))
			if err = writer.Close(); err != nil {
				t.Fatal(err)
			}
			file.Close()
			if bad == "corrupt" {
				contents := readString(t, archive)
				if err = os.WriteFile(archive, []byte(strings.Replace(contents, "UNIQUE_PAYLOAD", "BROKEN_PAYLOAD", 1)), 0640); err != nil {
					t.Fatal(err)
				}
			}
			if _, err = extract_build_archive(archive, source); err == nil {
				t.Fatal("unsafe archive accepted")
			}
			if readString(t, old) != "old" {
				t.Fatal("old RBF replaced before validation")
			}

		})
	}
}

// Optional integration check against the shared store, without network access
// or changes to the user's release tree or archive.
func TestRealSharedBuildArchive(t *testing.T) {
	archive := os.Getenv("JTUTIL_TEST_BUILD_ZIP")
	if archive == "" {
		t.Skip("set JTUTIL_TEST_BUILD_ZIP for a real archive smoke test")
	}
	root := t.TempDir()
	id := BuildIdentity{RunID: "smoke", Attempt: "1", Artifact: filepath.Base(archive), SHA: strings.TrimSuffix(filepath.Base(archive), ".zip")}
	cfg := Config{Source: filepath.Join(root, "project"), BuildsDir: filepath.Dir(archive)}
	previous := ghArtifactDownload
	t.Cleanup(func() { ghArtifactDownload = previous })
	ghArtifactDownload = func(context.Context, string, int64, string) error {
		t.Fatal("local smoke attempted download")
		return nil
	}
	got, rbfs, err := prepareArtifact(context.Background(), cfg, filepath.Join(root, "log"), id)
	if err != nil {
		t.Fatal(err)
	}
	if got != archive {
		t.Fatalf("wrong archive: %s", got)
	}
	z, err := zip.OpenReader(archive)
	if err != nil {
		t.Fatal(err)
	}
	defer z.Close()
	for _, entry := range z.File {
		if entry.FileInfo().IsDir() {
			continue
		}
		info, err := os.Stat(filepath.Join(cfg.Source, entry.Name))
		if err != nil || uint64(info.Size()) != entry.UncompressedSize64 {
			t.Fatalf("entry not fully extracted: %s: %v", entry.Name, err)
		}
	}
	files, _ := filepath.Glob(filepath.Join(rbfs, "jt*.rbf"))
	t.Logf("Validated and extracted %d ZIP entries, %d SiDi128 RBFs", len(z.File), len(files))
}

func check_preparation_cleanup(t *testing.T) {
	t.Helper()
	before := map[string]bool{}
	for _, prefix := range []string{"extract", "download", "prepare"} {
		paths, _ := filepath.Glob("/tmp/jtutil-regression-" + prefix + "-*")
		for _, path := range paths {
			before[path] = true
		}
	}
	t.Cleanup(func() {
		for _, prefix := range []string{"extract", "download", "prepare"} {
			paths, _ := filepath.Glob("/tmp/jtutil-regression-" + prefix + "-*")
			for _, path := range paths {
				if !before[path] {
					t.Errorf("temporary preparation survived: %s", path)
				}
			}
		}
	})
}
