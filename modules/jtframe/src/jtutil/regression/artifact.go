/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"archive/zip"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"strings"
)

const default_builds_dir = "/gdrive/jotego/core-builds"

type archive_record struct {
	RunID           string            `json:"run_id"`
	Attempt         string            `json:"attempt"`
	SHA             string            `json:"source_sha"`
	ArtifactID      int64             `json:"artifact_id"`
	Artifact        string            `json:"artifact"`
	ArtifactSHA     string            `json:"artifact_sha256"`
	ArtifactAPIHash string            `json:"artifact_api_sha256"`
	Acquisition     string            `json:"acquisition"`
	ArchivePath     string            `json:"archive_path"`
	Target          string            `json:"target_directory"`
	RBF             map[string]string `json:"rbf_sha256"`
}

// ZIPs live only in the shared archive store. The local release tree is the
// extracted build; the run log records its identity without retaining binaries.
func prepareArtifact(ctx context.Context, cfg Config, log_dir string, id BuildIdentity) (string, string, error) {
	if cfg.Source == "" {
		return "", "", fmt.Errorf("working project is required for artifact extraction")
	}
	name := id.Artifact
	if name != filepath.Base(name) || strings.ContainsAny(name, "\\/") || !strings.HasSuffix(name, ".zip") {
		return "", "", fmt.Errorf("unsafe build archive name %q", name)
	}
	short_sha := strings.TrimSuffix(name, ".zip")
    if id.Workflow==compileSidi128Workflow {
        if !strings.HasSuffix(short_sha,"-sidi128") { return "","",fmt.Errorf("SiDi128-only build requires a -sidi128.zip archive") }
        short_sha=strings.TrimSuffix(short_sha,"-sidi128")
    }
	if len(short_sha) < 7 || !strings.HasPrefix(id.SHA, short_sha) {
		return "", "", fmt.Errorf("archive %s does not match build commit %s", name, id.SHA)
	}
	store := cfg.BuildsDir
	if store == "" {
		store = default_builds_dir
	}
	if err := os.MkdirAll(store, 0750); err != nil {
		return "", "", err
	}
	archive := filepath.Join(store, name)
	payload := archive
	acquisition := "local-store"
	info, err := os.Lstat(archive)
	if os.IsNotExist(err) {
		temporary, e := os.MkdirTemp("/tmp", "jtutil-regression-download-")
		if e != nil {
			return "", "", e
		}
		defer os.RemoveAll(temporary)
		wrapper := filepath.Join(temporary, "service.zip")
		if e = ghArtifactDownload(ctx, id.Repository, id.ArtifactID, wrapper); e != nil {
			return "", "", fmt.Errorf("download artifact %d: %w", id.ArtifactID, e)
		}
		if id.ArtifactAPIHash != "" {
			digest, e := fileSHA256(wrapper)
			if e != nil {
				return "", "", e
			}
			if !strings.EqualFold(digest, id.ArtifactAPIHash) {
				return "", "", fmt.Errorf("artifact service archive digest mismatch for artifact %d", id.ArtifactID)
			}
		}
		if e = extractArtifactPayload(wrapper, name, temporary); e != nil {
			return "", "", e
		}
		payload = filepath.Join(temporary, name)
		acquisition = "github-download"
	} else if err != nil {
		return "", "", err
	} else if !info.Mode().IsRegular() || info.Size() == 0 {
		return "", "", fmt.Errorf("build archive is not a nonempty regular file: %s", archive)
	}
	digest, err := fileSHA256(payload)
	if err != nil {
		return "", "", err
	}
	if id.ArtifactSHA != "" && !strings.EqualFold(digest, id.ArtifactSHA) {
		return "", "", fmt.Errorf("build archive checksum mismatch: %s", archive)
	}
	manifest_path := filepath.Join(log_dir, "build-manifest.json")
	var previous archive_record
	if raw, e := os.ReadFile(manifest_path); e == nil {
		if e = json.Unmarshal(raw, &previous); e != nil {
			return "", "", fmt.Errorf("read previous archive identity: %w", e)
		}
		if previous.RunID != id.RunID || previous.Attempt != id.Attempt || previous.SHA != id.SHA || previous.ArtifactID != id.ArtifactID || previous.Artifact != name || !strings.EqualFold(previous.ArtifactSHA, digest) {
			return "", "", fmt.Errorf("archive differs from recorded build identity for run %s attempt %s", id.RunID, id.Attempt)
		}
	} else if !os.IsNotExist(e) {
		return "", "", e
	}
	rbfs, err := extract_build_archive(payload, cfg.Source)
	if err != nil {
		return "", "", err
	}
	if payload != archive {
		if err = publish_build_archive(payload, archive, digest); err != nil {
			return "", "", err
		}
	}
	record := archive_record{RunID: id.RunID, Attempt: id.Attempt, SHA: id.SHA, ArtifactID: id.ArtifactID, Artifact: name, ArtifactSHA: digest, ArtifactAPIHash: id.ArtifactAPIHash, Acquisition: acquisition, ArchivePath: archive, Target: "release/sidi128", RBF: rbfs}
	// A local ZIP's payload hash is not the GitHub service-wrapper hash. Keep
	// its acquisition explicit instead of claiming the latter was verified.
	raw, err := json.MarshalIndent(record, "", "  ")
	if err != nil {
		return "", "", err
	}
	if err = os.MkdirAll(log_dir, 0750); err != nil {
		return "", "", err
	}
	if err = os.WriteFile(manifest_path, append(raw, '\n'), 0640); err != nil {
		return "", "", err
	}
	return archive, filepath.Join(cfg.Source, "release", "sidi128"), nil
}

// The validated payload comes from /tmp, which may be another filesystem.
// Never replace a ZIP already published by another downloader.
func publish_build_archive(payload, archive, digest string) (result_error error) {
	out, e := os.OpenFile(archive, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0640)
	if os.IsExist(e) {
		current, hash_error := fileSHA256(archive)
		if hash_error != nil || current != digest {
			return fmt.Errorf("concurrent archive download differs: %s", archive)
		}
		return nil
	}
	if e != nil {
		return e
	}
	defer func() {
		if result_error != nil {
			os.Remove(archive)
		}
	}()
	in, e := os.Open(payload)
	if e != nil {
		out.Close()
		return e
	}
	defer in.Close()
	_, e = io.Copy(out, in)
	close_error := out.Close()
	if e != nil {
		return e
	}
	return close_error
}

// Validate and unpack every release file before touching the working release.
// Staging is temporary and removed on success or failure, never a build cache.
func extract_build_archive(archive, source string) (map[string]string, error) {
	source, err := filepath.Abs(source)
	if err != nil {
		return nil, err
	}
	z, err := zip.OpenReader(archive)
	if err != nil {
		return nil, err
	}
	defer z.Close()
	if err = os.MkdirAll(source, 0750); err != nil {
		return nil, err
	}
	stage, err := os.MkdirTemp("/tmp", "jtutil-regression-extract-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(stage)
	seen := make(map[string]bool)
	rbfs := make(map[string]string)
	var total uint64
	for _, entry := range z.File {
		name := strings.TrimSuffix(entry.Name, "/")
		if strings.ContainsAny(name, "\\\x00") || path.Clean(name) != name || name != "release" && !strings.HasPrefix(name, "release/") || seen[name] {
			return nil, fmt.Errorf("unsafe or duplicate build archive path %q", entry.Name)
		}
		seen[name] = true
		if !entry.Mode().IsRegular() && !entry.FileInfo().IsDir() {
			return nil, fmt.Errorf("unsupported build archive entry %q", entry.Name)
		}
		destination := filepath.Join(stage, filepath.FromSlash(name))
		if entry.FileInfo().IsDir() {
			if err = os.MkdirAll(destination, 0750); err != nil {
				return nil, err
			}
			continue
		}
		if entry.UncompressedSize64 > 5<<30 || total > 5<<30-entry.UncompressedSize64 {
			return nil, fmt.Errorf("build archive exceeds 5 GiB unpacked limit")
		}
		total += entry.UncompressedSize64
		if err = os.MkdirAll(filepath.Dir(destination), 0750); err != nil {
			return nil, err
		}
		if err = extract_build_file(entry, destination); err != nil {
			return nil, err
		}
		parts := strings.Split(name, "/")
		if len(parts) == 3 && parts[1] == "sidi128" && strings.HasPrefix(parts[2], "jt") && strings.HasSuffix(parts[2], ".rbf") {
			if entry.UncompressedSize64 == 0 {
				return nil, fmt.Errorf("empty SiDi128 RBF: %s", name)
			}
			rbfs[parts[2]], err = fileSHA256(destination)
			if err != nil {
				return nil, err
			}
		}
	}
	if len(rbfs) == 0 {
		return nil, fmt.Errorf("artifact has no release/sidi128 SiDi RBFs")
	}
	// Preflight all destinations before replacing anything. Existing symlinks
	// must not redirect extraction outside the selected checkout.
	for name := range seen {
		destination := filepath.Join(source, filepath.FromSlash(name))
		staged, e := os.Stat(filepath.Join(stage, filepath.FromSlash(name)))
		if e != nil {
			return nil, e
		}
		for p := destination; p != source; p = filepath.Dir(p) {
			info, e := os.Lstat(p)
			if os.IsNotExist(e) {
				continue
			}
			if e != nil {
				return nil, e
			}
			if info.Mode()&os.ModeSymlink != 0 {
				return nil, fmt.Errorf("archive destination is a symlink: %s", p)
			}
			want_dir := p != destination || staged.IsDir()
			if info.IsDir() != want_dir || !info.IsDir() && !info.Mode().IsRegular() {
				return nil, fmt.Errorf("archive destination has incompatible type: %s", p)
			}
		}
	}
	err = filepath.WalkDir(filepath.Join(stage, "release"), func(p string, entry os.DirEntry, e error) error {
		if e != nil {
			return e
		}
		relative, e := filepath.Rel(stage, p)
		if e != nil {
			return e
		}
		destination := filepath.Join(source, relative)
		if entry.IsDir() {
			return os.MkdirAll(destination, 0750)
		}
		return copyFile(p, destination)
	})
	if err != nil {
		return nil, err
	}
	// The regression inventory scans this directory; stale RBFs from another
	// build must not become candidates for the selected build.
	old, err := filepath.Glob(filepath.Join(source, "release", "sidi128", "jt*.rbf"))
	if err != nil {
		return nil, err
	}
	for _, p := range old {
		if _, ok := rbfs[filepath.Base(p)]; !ok {
			if err = os.Remove(p); err != nil {
				return nil, err
			}
		}
	}
	return rbfs, nil
}

func extract_build_file(entry *zip.File, destination string) error {
	in, err := entry.Open()
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(destination, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0640)
	if err != nil {
		return err
	}
	n, err := io.Copy(out, io.LimitReader(in, int64(entry.UncompressedSize64)+1))
	close_error := out.Close()
	if err != nil {
		return fmt.Errorf("extract %s: %w", entry.Name, err)
	}
	if close_error != nil {
		return close_error
	}
	if uint64(n) != entry.UncompressedSize64 {
		return fmt.Errorf("incorrect length for %s", entry.Name)
	}
	return nil
}
