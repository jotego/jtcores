/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"archive/zip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"hash/crc32"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

var validSHA = regexp.MustCompile(`^[0-9a-fA-F]{40}$`)
var verifiedROMParts sync.Map // map[archive SHA + entry CRC + size]bool

var jtframeMRACommand = func(ctx context.Context, source, core, roms string, haveROMSource bool) ([]byte, error) {
	// Inventory selection must not depend on which local ZIPs happen to be
	// installed. ROM generation is a separate targeted operation below.
	command := `core_arg=$1; set --; export JTROOT="$PWD" JTFRAME="$PWD/modules/jtframe" JTBIN="$PWD/release" GOCACHE="$PWD/.cache/go-build" GOMODCACHE="$PWD/.cache/go-mod"; mkdir -p "$JTBIN" "$GOCACHE" "$GOMODCACHE"; source ./setprj.sh >/dev/null && jtframe mra --mainonly --skipROM --skipPocket "$core_arg"`
	cmd := exec.CommandContext(ctx, "bash", "-c", command, "_", core)
	cmd.Dir = source
	return cmd.CombinedOutput()
}

type mraInventory struct {
	Name    string   `xml:"name"`
	Setname string   `xml:"setname"`
	RBF     string   `xml:"rbf"`
	ROM     []mraROM `xml:"rom"`
}
type mraPart struct {
	Name       string     `xml:"name,attr"`
	CRC        string     `xml:"crc,attr"`
	Map        string     `xml:"map,attr"`
	Offset     string     `xml:"offset,attr"`
	Length     string     `xml:"length,attr"`
	Text       string     `xml:",chardata"`
	OtherAttrs []xml.Attr `xml:",any,attr"`
}
type mraInterleave struct {
	Output     string          `xml:"output,attr"`
	Parts      []mraPart       `xml:"part"`
	Interleave []mraInterleave `xml:"interleave"`
	OtherAttrs []xml.Attr      `xml:",any,attr"`
	Comments   []byte          `xml:",comment"`
}
type mraROM struct {
	Index      string          `xml:"index,attr"`
	Zip        string          `xml:"zip,attr"`
	ASMMD5     string          `xml:"asm_md5,attr"`
	Parts      []mraPart       `xml:"part"`
	Interleave []mraInterleave `xml:"interleave"`
	OtherAttrs []xml.Attr      `xml:",any,attr"`
	Comments   []byte          `xml:",comment"`
}

func (r mraROM) AllParts() []mraPart {
	parts := append([]mraPart(nil), r.Parts...)
	var visit func([]mraInterleave)
	visit = func(groups []mraInterleave) {
		for _, group := range groups {
			parts = append(parts, group.Parts...)
			visit(group.Interleave)
		}
	}
	visit(r.Interleave)
	return parts
}

type InventoryTuple struct {
	Core    string `json:"core"`
	Setname string `json:"setname"`
	RBF     string `json:"rbf"`
}

type InventoryReconciliation struct {
	Schema                      int               `json:"schema"`
	RunID                       string            `json:"run_id"`
	Attempt                     string            `json:"attempt"`
	SourceSHA                   string            `json:"source_sha"`
	ArtifactSHA256              string            `json:"artifact_sha256"`
	ArtifactTuples              []InventoryTuple  `json:"artifact_main_mras"`
	SourceTuples                []InventoryTuple  `json:"exact_source_mainonly_mras"`
	SourceOnly                  []InventoryTuple  `json:"source_only_tuples"`
	ArtifactOnly                []InventoryTuple  `json:"artifact_only_tuples"`
	ArtifactFallbacks           []InventoryTuple  `json:"artifact_metadata_fallbacks"`
	SourceOnlyJustifications    map[string]string `json:"source_only_justifications"`
	ArtifactOnlyJustifications  map[string]string `json:"artifact_only_justifications"`
	SourceUniqueSetnames        int               `json:"source_unique_setnames"`
	ArtifactUniqueSetnames      int               `json:"artifact_unique_setnames"`
	ExactTupleOverlap           int               `json:"exact_tuple_overlap"`
	SourceOnlySetnames          []string          `json:"source_only_setnames"`
	SourceOnlyAlternateMappings []InventoryTuple  `json:"source_only_alternate_mappings"`
}

// Prepare discovers or selects a successful complete compile_all build,
// downloads its artifact, checks out its exact source SHA, and prepares the
// main-game ROM/ARC inventory. runID pins one Actions run (for example 40655576158).
func Prepare(ctx context.Context, cfg Config, dataRoot, runID string) (Manifest, error) {
	if ctx == nil {
		ctx = context.Background()
	}
	if cfg.Repository == "" {
		cfg.Repository = "jotego/jtcores"
	}
	identity, err := discoverBuildIn(ctx, cfg.Repository, runID, dataRoot)
	if err != nil {
		return Manifest{}, err
	}
	if cfg.Source == "" {
		return Manifest{}, fmt.Errorf("regression config source is required to check out build %s", identity.SHA)
	}
	if dataRoot == "" {
		return Manifest{}, fmt.Errorf("regression data root is required")
	}
	if cfg.TimeoutSeconds <= 0 {
		cfg.TimeoutSeconds = 900
	}
	stageCtx, cancel := context.WithTimeout(ctx, time.Duration(cfg.TimeoutSeconds)*time.Second)
	defer cancel()
	buildKey := identity.RunID + "-attempt-" + identity.Attempt
	buildDir := filepath.Join(dataRoot, "builds", buildKey)
	if err = os.MkdirAll(buildDir, 0750); err != nil {
		return Manifest{}, err
	}
	if cfg.GlobalProfile == "" {
		cfg.GlobalProfile = filepath.Join(dataRoot, "reg.yaml")
		if _, statErr := os.Stat(cfg.GlobalProfile); os.IsNotExist(statErr) {
			if err = os.WriteFile(cfg.GlobalProfile, []byte("video: 4000\nstart-up: 500\n"), 0640); err != nil {
				return Manifest{}, err
			}
		}
	}
	artifactPath, rbfRoot, err := prepareArtifact(stageCtx, cfg, buildDir, identity)
	if err != nil {
		return Manifest{}, err
	}
	identity.ArtifactSHA, err = fileSHA256(artifactPath)
	if err != nil {
		return Manifest{}, err
	}
	source, err := exactSource(stageCtx, cfg.Source, filepath.Join(dataRoot, "source"), identity.SHA)
	if err != nil {
		return Manifest{}, err
	}
	cores, rec, err := mainGameInventory(stageCtx, source, rbfRoot, filepath.Join(buildDir, "fixtures"), artifactPath, identity, cfg)
	if err != nil {
		return Manifest{}, err
	}
	recBytes, _ := json.MarshalIndent(rec, "", "  ")
	if err = os.WriteFile(filepath.Join(buildDir, "inventory-reconciliation.json"), append(recBytes, '\n'), 0640); err != nil {
		return Manifest{}, err
	}
	if len(cores) == 0 {
		return Manifest{}, fmt.Errorf("build %s produced no main-game inventory", identity.RunID)
	}
	return Manifest{RunID: identity.RunID + "-attempt-" + identity.Attempt, Build: identity, Source: source, Cores: cores}, nil
}

func extractArtifactPayload(wrapper, artifactName, destination string) error {
	z, err := zip.OpenReader(wrapper)
	if err != nil {
		return fmt.Errorf("open GitHub artifact archive: %w", err)
	}
	defer z.Close()
	var matches []*zip.File
	for _, f := range z.File {
		name := filepath.ToSlash(f.Name)
		if strings.Contains(name, "..") {
			return fmt.Errorf("unsafe artifact-container path %q", name)
		}
		if f.FileInfo().IsDir() {
			continue
		}
		if filepath.Base(name) == filepath.Base(artifactName) {
			matches = append(matches, f)
		}
	}
	if len(matches) != 1 {
		return fmt.Errorf("artifact container must contain exactly one %q payload; found %d", artifactName, len(matches))
	}
	f := matches[0]
	if f.UncompressedSize64 == 0 || f.UncompressedSize64 > 5*1024*1024*1024 {
		return fmt.Errorf("artifact payload size %d is invalid", f.UncompressedSize64)
	}
	in, err := f.Open()
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(filepath.Join(destination, filepath.Base(artifactName)), os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0640)
	if err != nil {
		return err
	}
	n, copyErr := io.Copy(out, io.LimitReader(in, int64(f.UncompressedSize64)+1))
	closeErr := out.Close()
	if copyErr != nil {
		return copyErr
	}
	if closeErr != nil {
		return closeErr
	}
	if uint64(n) != f.UncompressedSize64 {
		return fmt.Errorf("artifact payload length mismatch: expected %d, got %d", f.UncompressedSize64, n)
	}
	return nil
}

func prepareArtifact(ctx context.Context, cfg Config, buildDir string, id BuildIdentity) (string, string, error) {
	// Retained artifacts and caches stay under the configured regression root.
	cache := buildDir
	if err := os.MkdirAll(cache, 0750); err != nil {
		return "", "", err
	}
	artifact := filepath.Join(cache, filepath.Base(id.Artifact))
	manifestPath := filepath.Join(cache, "build-manifest.json")
	if !regularNonempty(artifact) && id.RunNumber > 0 {
		legacy := filepath.Join(filepath.Dir(cache), strconv.FormatInt(id.RunNumber, 10), filepath.Base(id.Artifact))
		if regularNonempty(legacy) {
			if err := copyFile(legacy, artifact); err != nil {
				return "", "", err
			}
			oldManifest := filepath.Join(filepath.Dir(cache), strconv.FormatInt(id.RunNumber, 10), "build-manifest.json")
			if regularNonempty(oldManifest) {
				if err := copyFile(oldManifest, filepath.Join(cache, "build-manifest.json")); err != nil {
					return "", "", err
				}
			}
		}
	}
	var cached struct {
		RunID           string            `json:"run_id"`
		Attempt         string            `json:"attempt"`
		SHA             string            `json:"source_sha"`
		ArtifactID      int64             `json:"artifact_id"`
		Artifact        string            `json:"artifact"`
		ArtifactSHA     string            `json:"artifact_sha256"`
		ArtifactAPIHash string            `json:"artifact_api_sha256"`
		Target          string            `json:"target_directory"`
		RBF             map[string]string `json:"rbf_sha256"`
	}
	// The initial hardware-prepared #676 cache predates this command and uses
	// its richer build-manifest schema. Accept it only after every identity and
	// downloaded bundle digest agrees with the selected run/attempt/artifact.
	var pilot struct {
		RunID           int64  `json:"run_id"`
		Attempt         int    `json:"attempt"`
		SHA             string `json:"source_sha"`
		TargetDirectory string `json:"target_directory"`
		Artifact        struct {
			ID          int64  `json:"id"`
			Name        string `json:"name"`
			APIHash     string `json:"api_digest"`
			DownloadSHA string `json:"download_sha256"`
		} `json:"artifact"`
		RBF map[string]string `json:"rbf_sha256"`
	}
	if raw, e := os.ReadFile(manifestPath); e == nil && json.Unmarshal(raw, &pilot) == nil && pilot.RunID != 0 {
		if strconv.FormatInt(pilot.RunID, 10) != id.RunID || strconv.Itoa(pilot.Attempt) != id.Attempt || !strings.EqualFold(pilot.SHA, id.SHA) || pilot.Artifact.Name != id.Artifact || pilot.Artifact.ID != id.ArtifactID {
			return "", "", fmt.Errorf("cached build manifest provenance does not match run %s attempt %s", id.RunID, id.Attempt)
		}
		pilotAPIHash := strings.TrimPrefix(pilot.Artifact.APIHash, "sha256:")
		if id.ArtifactAPIHash != "" && pilotAPIHash != "" && !strings.EqualFold(id.ArtifactAPIHash, pilotAPIHash) {
			return "", "", fmt.Errorf("cached artifact service digest differs for run %s", id.RunID)
		}
		if pilot.Artifact.DownloadSHA != "" && regularNonempty(artifact) {
			digest, e := fileSHA256(artifact)
			if e != nil {
				return "", "", e
			}
			if !strings.EqualFold(digest, pilot.Artifact.DownloadSHA) {
				return "", "", fmt.Errorf("cached artifact checksum mismatch for run %s", id.RunID)
			}
		}
		cached.RunID = id.RunID
		cached.Attempt = id.Attempt
		cached.SHA = id.SHA
		cached.ArtifactID = id.ArtifactID
		cached.Artifact = id.Artifact
		cached.ArtifactSHA = pilot.Artifact.DownloadSHA
		cached.ArtifactAPIHash = strings.TrimPrefix(pilot.Artifact.APIHash, "sha256:")
		cached.Target = pilot.TargetDirectory
		cached.RBF = pilot.RBF
		b, _ := json.MarshalIndent(cached, "", "  ")
		if e := os.WriteFile(manifestPath, append(b, '\n'), 0640); e != nil {
			return "", "", e
		}
	}
	cachedOK := false
	if raw, e := os.ReadFile(manifestPath); e == nil && json.Unmarshal(raw, &cached) == nil && cached.RunID == id.RunID && cached.Attempt == id.Attempt && strings.EqualFold(cached.SHA, id.SHA) && cached.ArtifactID == id.ArtifactID && cached.Artifact == id.Artifact && cached.ArtifactSHA != "" && regularNonempty(artifact) {
		digest, e := fileSHA256(artifact)
		cachedOK = e == nil && strings.EqualFold(digest, cached.ArtifactSHA)
		if cached.ArtifactAPIHash != "" && id.ArtifactAPIHash != "" && cached.ArtifactAPIHash != id.ArtifactAPIHash {
			cachedOK = false
		}
	}
	if !cachedOK {
		tmp, err := os.MkdirTemp(cache, ".artifact-")
		if err != nil {
			return "", "", err
		}
		defer os.RemoveAll(tmp)
		wrapper := filepath.Join(tmp, "service.zip")
		if err = ghArtifactDownload(ctx, id.Repository, id.ArtifactID, wrapper); err != nil {
			return "", "", fmt.Errorf("download exact artifact %d from run %s attempt %s: %w", id.ArtifactID, id.RunID, id.Attempt, err)
		}
		if !regularNonempty(wrapper) {
			return "", "", fmt.Errorf("artifact service returned an empty archive for %d", id.ArtifactID)
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
		if err = extractArtifactPayload(wrapper, id.Artifact, tmp); err != nil {
			return "", "", err
		}
		if err = copyFile(filepath.Join(tmp, filepath.Base(id.Artifact)), artifact); err != nil {
			return "", "", err
		}
		cached.ArtifactSHA, err = fileSHA256(artifact)
		if err != nil {
			return "", "", err
		}
		cached.RunID = id.RunID
		cached.Attempt = id.Attempt
		cached.SHA = id.SHA
		cached.ArtifactID = id.ArtifactID
		cached.Artifact = id.Artifact
		cached.ArtifactAPIHash = id.ArtifactAPIHash
		cached.Target = "release/sidi128"
		manifestBytes, _ := json.MarshalIndent(cached, "", "  ")
		if err = os.WriteFile(manifestPath, append(manifestBytes, '\n'), 0640); err != nil {
			return "", "", err
		}
	}
	if _, err := zip.OpenReader(artifact); err != nil {
		return "", "", fmt.Errorf("artifact %s is not a valid ZIP: %w", artifact, err)
	}
	id.ArtifactSHA = cached.ArtifactSHA
	id.ArtifactAPIHash = cached.ArtifactAPIHash
	rbfRoot, err := extractRBFTree(artifact, cache, id, cached.Target, cached.RBF)
	if err != nil {
		return "", "", err
	}
	return artifact, rbfRoot, nil
}

func extractRBFTree(artifact, cache string, id BuildIdentity, target string, expected map[string]string) (string, error) {
	if target != "" && target != "release/sidi128" {
		return "", fmt.Errorf("artifact manifest selects %q; regression requires release/sidi128", target)
	}
	root := filepath.Join(cache, "release", "sidi128")
	z, err := zip.OpenReader(artifact)
	if err != nil {
		return "", err
	}
	defer z.Close()
	count := 0
	seen := map[string]bool{}
	for _, f := range z.File {
		name := filepath.ToSlash(f.Name)
		if strings.Contains(name, "..") {
			return "", fmt.Errorf("unsafe artifact path %q", name)
		}
		if f.FileInfo().IsDir() || !strings.HasSuffix(strings.ToLower(name), ".rbf") {
			continue
		}
		parts := strings.Split(name, "/")
		if len(parts) != 3 || parts[0] != "release" || parts[1] != "sidi128" || !strings.HasPrefix(parts[2], "jt") {
			continue
		}
		if filepath.Base(parts[2]) != parts[2] {
			return "", fmt.Errorf("unsafe RBF name %q", parts[2])
		}
		if seen[parts[2]] {
			return "", fmt.Errorf("artifact contains duplicate RBF %s", parts[2])
		}
		seen[parts[2]] = true
		targetDir := filepath.Join(cache, "release", "sidi128")
		// Keep a single canonical target directory even for historical artifacts
		// that named this target release/sidi.
		target := filepath.Join(targetDir, parts[2])
		if err = os.MkdirAll(targetDir, 0750); err != nil {
			return "", err
		}
		rc, e := f.Open()
		if e != nil {
			return "", e
		}
		dst, e := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0640)
		if e == nil {
			_, e = io.Copy(dst, rc)
			ce := dst.Close()
			if e == nil {
				e = ce
			}
		}
		_ = rc.Close()
		if e != nil {
			return "", e
		}
		if expected[parts[2]] != "" {
			digest, e := fileSHA256(target)
			if e != nil {
				return "", e
			}
			if !strings.EqualFold(digest, expected[parts[2]]) {
				return "", fmt.Errorf("RBF %s checksum mismatch in artifact", parts[2])
			}
		}
		count++
	}
	if count == 0 {
		return "", fmt.Errorf("artifact %s has no release/sidi128 SiDi RBFs", id.Artifact)
	}
	old, _ := filepath.Glob(filepath.Join(root, "jt*.rbf"))
	for _, p := range old {
		if !seen[filepath.Base(p)] {
			if e := os.Remove(p); e != nil && !os.IsNotExist(e) {
				return "", e
			}
		}
	}
	return root, nil
}

func exactSource(ctx context.Context, source, root, sha string) (string, error) {
	if !validSHA.MatchString(sha) {
		return "", fmt.Errorf("invalid source SHA %q", sha)
	}
	dest := filepath.Join(root, strings.ToLower(sha))
	if head, e := gitHead(ctx, dest); e == nil && strings.EqualFold(head, sha) {
		return dest, nil
	}
	if e := os.MkdirAll(root, 0750); e != nil {
		return "", e
	}
	if _, e := os.Stat(filepath.Join(dest, ".git")); e == nil {
		return "", fmt.Errorf("source cache %s exists at a different revision", dest)
	}
	if _, e := os.Stat(dest); e == nil {
		return "", fmt.Errorf("source cache path %s exists but is not the requested checkout", dest)
	}
	if _, e := exec.LookPath("git"); e != nil {
		return "", fmt.Errorf("git is required for exact source checkout: %w", e)
	}
	cmd := exec.CommandContext(ctx, "git", "clone", "--no-hardlinks", "--no-checkout", source, dest)
	if out, e := cmd.CombinedOutput(); e != nil {
		return "", fmt.Errorf("clone exact source repository: %w: %s", e, strings.TrimSpace(string(out)))
	}
	cmd = exec.CommandContext(ctx, "git", "-C", dest, "checkout", "--detach", sha)
	if out, e := cmd.CombinedOutput(); e != nil {
		return "", fmt.Errorf("checkout source SHA %s: %w: %s", sha, e, strings.TrimSpace(string(out)))
	}
	head, e := gitHead(ctx, dest)
	if e != nil {
		return "", e
	}
	if !strings.EqualFold(head, sha) {
		return "", fmt.Errorf("source checkout is %s, expected %s", head, sha)
	}
	return dest, nil
}

func gitHead(ctx context.Context, path string) (string, error) {
	cmd := exec.CommandContext(ctx, "git", "-C", path, "rev-parse", "HEAD")
	out, e := cmd.Output()
	if e != nil {
		return "", e
	}
	return strings.TrimSpace(string(out)), nil
}

func mainGameInventory(ctx context.Context, source, rbfRoot, fixtureRoot, artifactPath string, identity BuildIdentity, cfg Config) ([]CoreManifest, InventoryReconciliation, error) {
	coreRoot := filepath.Join(source, "cores")
	entries, err := os.ReadDir(coreRoot)
	if err != nil {
		return nil, InventoryReconciliation{}, err
	}
	cores := make([]string, 0)
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if regularNonempty(filepath.Join(coreRoot, e.Name(), "cfg", "mame2mra.toml")) && regularNonempty(filepath.Join(coreRoot, e.Name(), "cfg", "macros.def")) {
			cores = append(cores, e.Name())
		}
	}
	sort.Strings(cores)
	if len(cores) == 0 {
		return nil, InventoryReconciliation{}, fmt.Errorf("no cores with mame2mra configurations in exact source checkout")
	}
	roms := cfg.ROMSource
	if roms == "" {
		roms = filepath.Join(os.Getenv("HOME"), ".mame", "roms")
	}
	// Generate MRA source from this exact commit. Existing output is retained on
	// resume; the command is deterministic and safely refreshes the same files.
	// jtframe writes a flat release/mra directory. Snapshot each core's output
	// before the next core can overwrite an identically named MRA.
	mraRoot := filepath.Join(fixtureRoot, "mainonly-mra")
	if err := os.MkdirAll(mraRoot, 0750); err != nil {
		return nil, InventoryReconciliation{}, err
	}
	roms, haveROMSource, err := stageROMSource(roms, cfg.ROMSourceExtra, filepath.Join(fixtureRoot, "rom-source"))
	if err != nil {
		return nil, InventoryReconciliation{}, err
	}
	mraErrors := map[string]string{}
	for _, core := range cores {
		// Use argv through a tiny shell wrapper only for setprj.sh environment;
		// core names are repository path components and were read from DirEntry.
		// Clear only the generated MRA output directories owned by this exact
		// source cache. This prevents a previous core or interrupted pass from
		// contributing stale files to this core's snapshot.
		coreMRA := filepath.Join(mraRoot, core)
		if err := os.RemoveAll(coreMRA); err != nil {
			return nil, InventoryReconciliation{}, err
		}
		if err := os.RemoveAll(filepath.Join(source, "release", "mra")); err != nil {
			return nil, InventoryReconciliation{}, err
		}
		if err := os.MkdirAll(filepath.Join(source, "release", "mra"), 0750); err != nil {
			return nil, InventoryReconciliation{}, err
		}
		if out, e := jtframeMRACommand(ctx, source, core, roms, haveROMSource); e != nil {
			mraErrors[core] = fmt.Sprintf("exact-source jtframe mra inventory command failed: %v: %s", e, strings.TrimSpace(string(out)))
		}
		if err := os.MkdirAll(coreMRA, 0750); err != nil {
			return nil, InventoryReconciliation{}, err
		}
		generated, err := filepath.Glob(filepath.Join(source, "release", "mra", "*.mra"))
		if err != nil {
			return nil, InventoryReconciliation{}, err
		}
		for _, path := range generated {
			data, err := os.ReadFile(path)
			if err != nil {
				return nil, InventoryReconciliation{}, err
			}
			var m mraInventory
			if err = xml.Unmarshal(data, &m); err != nil {
				continue
			}
			if m.RBF != "jt"+core || strings.TrimSpace(m.Setname) == "" {
				continue
			}
			if err = copyFile(path, filepath.Join(coreMRA, filepath.Base(path))); err != nil {
				return nil, InventoryReconciliation{}, err
			}
		}
	}
	var files []string
	for _, core := range cores {
		generated, e := filepath.Glob(filepath.Join(mraRoot, core, "*.mra"))
		if e != nil {
			return nil, InventoryReconciliation{}, e
		}
		for _, path := range generated {
			if tuple, ok := readTuple(path); ok && tuple.Core == core {
				files = append(files, path)
			}
		}
	}
	artifactMRAs, artifactTuples, err := readArtifactMainMRAs(artifactPath, filepath.Join(fixtureRoot, "artifact-main-mra"))
	if err != nil {
		return nil, InventoryReconciliation{}, err
	}
	artifactMRAByTuple := make(map[string]string, len(artifactMRAs))
	for _, artifactMRA := range artifactMRAs {
		if tuple, ok := readTuple(artifactMRA); ok {
			artifactMRAByTuple[tupleKey(tuple)] = artifactMRA
		}
	}
	sourceTupleSet := map[string]bool{}
	for _, path := range files {
		if t, ok := readTuple(path); ok {
			sourceTupleSet[tupleKey(t)] = true
		}
	}
	artifactTupleSet := map[string]bool{}
	for _, t := range artifactTuples {
		artifactTupleSet[tupleKey(t)] = true
	}
	rec := InventoryReconciliation{Schema: 1, RunID: identity.RunID, Attempt: identity.Attempt, SourceSHA: identity.SHA, ArtifactSHA256: identity.ArtifactSHA, ArtifactTuples: artifactTuples}
	for _, path := range files {
		if t, ok := readTuple(path); ok {
			rec.SourceTuples = append(rec.SourceTuples, t)
		}
	}
	missingSource := map[string]bool{}
	for _, t := range artifactTuples {
		if !sourceTupleSet[tupleKey(t)] {
			rec.ArtifactOnly = append(rec.ArtifactOnly, t)
			rec.ArtifactFallbacks = append(rec.ArtifactFallbacks, t)
			missingSource[tupleKey(t)] = true
		}
	}
	for _, t := range rec.SourceTuples {
		if !artifactTupleSet[tupleKey(t)] {
			rec.SourceOnly = append(rec.SourceOnly, t)
		}
	}
	rec.SourceOnlyJustifications = justifySourceOnly(rec.SourceOnly, rec.ArtifactTuples)
	rec.ArtifactOnlyJustifications = make(map[string]string, len(rec.ArtifactOnly))
	rec.SourceUniqueSetnames = uniqueSetnameCount(rec.SourceTuples)
	rec.ArtifactUniqueSetnames = uniqueSetnameCount(rec.ArtifactTuples)
	rec.ExactTupleOverlap = len(rec.SourceTuples) - len(rec.SourceOnly)
	rec.SourceOnlySetnames, rec.SourceOnlyAlternateMappings = classifySourceOnly(rec.SourceOnly, rec.ArtifactTuples)
	for _, t := range rec.ArtifactOnly {
		rec.ArtifactOnlyJustifications[tupleKey(t)] = "The selected successful build contains this main MRA tuple but exact-SHA jtframe --mainonly did not emit it; artifact MRA is retained only as an explicit per-title preparation-error fallback."
	}
	var fallbackMRAs []string
	for _, path := range artifactMRAs {
		if t, ok := readTuple(path); ok && missingSource[tupleKey(t)] {
			fallbackMRAs = append(fallbackMRAs, path)
		}
	}
	// Artifact metadata may keep a title visible when an exact-source core
	// command failed before writing that MRA. Include it with an explicit error
	// so it cannot silently masquerade as exact-source metadata.
	sortTuples(rec.ArtifactTuples)
	sortTuples(rec.SourceTuples)
	sortTuples(rec.SourceOnly)
	sortTuples(rec.ArtifactOnly)
	sortTuples(rec.ArtifactFallbacks)
	sourceFiles := append([]string(nil), files...)
	generatedCore := map[string]int{}
	for _, path := range sourceFiles {
		data, e := os.ReadFile(path)
		if e != nil {
			return nil, InventoryReconciliation{}, e
		}
		var m mraInventory
		if xml.Unmarshal(data, &m) == nil && strings.HasPrefix(m.RBF, "jt") {
			generatedCore[strings.TrimPrefix(m.RBF, "jt")]++
		}
	}
	fallbackCore := map[string]bool{}
	for _, t := range rec.ArtifactFallbacks {
		fallbackCore[t.Core] = true
	}
	missingCore := make([]string, 0)
	rbfPaths, globErr := filepath.Glob(filepath.Join(rbfRoot, "jt*.rbf"))
	if globErr != nil {
		return nil, InventoryReconciliation{}, globErr
	}
	for _, rbf := range rbfPaths {
		core := strings.TrimSuffix(strings.TrimPrefix(filepath.Base(rbf), "jt"), ".rbf")
		if generatedCore[core] == 0 && !fallbackCore[core] && regularNonempty(filepath.Join(coreRoot, core, "cfg", "mame2mra.toml")) {
			missingCore = append(missingCore, core)
		}
	}
	if len(missingCore) > 0 {
		sort.Strings(missingCore)
		return nil, InventoryReconciliation{}, fmt.Errorf("incomplete mainonly inventory: no exact-source MRA titles were generated for supported RBF cores %s", strings.Join(missingCore, ", "))
	}
	files = append(files, fallbackMRAs...)
	if len(files) == 0 {
		return nil, InventoryReconciliation{}, fmt.Errorf("jtframe mra --mainonly generated no MRA files for any core")
	}
	if err = os.MkdirAll(fixtureRoot, 0750); err != nil {
		return nil, InventoryReconciliation{}, err
	}
	rbfFiles, err := filepath.Glob(filepath.Join(rbfRoot, "jt*.rbf"))
	if err != nil {
		return nil, InventoryReconciliation{}, err
	}
	rbfByName := make(map[string]string)
	for _, p := range rbfFiles {
		rbfByName[filepath.Base(p)] = p
	}
	type item struct {
		core string
		game GameSpec
	}
	byCore := map[string][]item{}
	for _, path := range files {
		data, e := os.ReadFile(path)
		if e != nil {
			return nil, InventoryReconciliation{}, e
		}
		var m mraInventory
		if e = xml.Unmarshal(data, &m); e != nil {
			return nil, InventoryReconciliation{}, fmt.Errorf("decode generated MRA %s: %w", path, e)
		}
		set := strings.TrimSpace(m.Setname)
		rbf := strings.TrimSpace(m.RBF)
		if set == "" || rbf == "" {
			continue
		}
		core := strings.TrimPrefix(rbf, "jt")
		if core == rbf {
			continue
		}
		// Verify the source metadata's target identity and artifact contents.
		spec := GameSpec{Setname: set, RBF: rbfByName[rbf+".rbf"]}
		tuple := InventoryTuple{Core: core, Setname: set, RBF: rbf}
		if missingSource[tupleKey(tuple)] {
			spec.PreparationError = "exact-source mainonly inventory omitted this artifact main MRA tuple; artifact metadata is retained only as an explicit fallback"
		}
		var lintCandidates []PreparationWarning
		profile, e := ResolveProfile(cfg.GlobalProfile, source, core, set)
		if e != nil {
			spec.PreparationError = e.Error()
		} else {
			spec.Profile = profile
		}
		if spec.RBF == "" {
			if coreSkipped(ctx, source, core) {
				spec.Unsupported = true
				spec.UnsupportedReason = "source marks this core skipped for the SiDi128 target"
			} else {
				spec.PreparationError = fmt.Sprintf("expected SiDi128 RBF %s is missing from successful build %s", rbf+".rbf", filepath.Base(rbfRoot))
			}
		} else if !spec.Unsupported {
			if mraErrors[core] != "" {
				if code, ok := reviewedMRAExit(core, mraErrors[core]); ok {
					lintCandidates = append(lintCandidates, PreparationWarning{Code: code, Message: "exact-source mainonly inventory completed with reviewed post-emission region/order lint", Command: "jtframe mra --mainonly --skipROM --skipPocket " + core, ExitStatus: commandExitStatus(mraErrors[core]), Diagnostic: mraErrors[core]})
				} else {
					spec.PreparationError = appendPrepError(spec.PreparationError, mraErrors[core])
				}
			}
			folder := filepath.Join(fixtureRoot, core, set)
			if e = os.MkdirAll(folder, 0750); e != nil {
				return nil, InventoryReconciliation{}, e
			}
			arc := filepath.Join(folder, set+".arc")
			rom := filepath.Join(folder, set+".rom")
			mraTool := path
			var targetMRA string
			var archiveSources []string
			var mainROM *mraROM
			romSourceUsed := roms
			romExpected := false
			for i := range m.ROM {
				if m.ROM[i].Index == "0" {
					romExpected = true
					mainROM = &m.ROM[i]
					break
				}
			}
			if romExpected {
				generatedROM := filepath.Join(source, "rom", set+".rom")
				// jtframe's ROM output cache is flat by setname. Rebuild each core
				// tuple from scratch so equal setnames owned by different cores can
				// never inherit each other's bytes.
				_ = os.Remove(generatedROM)
				if haveROMSource {
					if mainROM != nil {
						parts := mainROM.AllParts()
						zipNames, archiveErr := mraZipNames(mainROM.Zip)
						romSource := roms
						if archiveErr == nil && len(zipNames) == 1 {
							_ = ensureExactArchiveAlias(zipNames[0], parts, roms, filepath.Join(fixtureRoot, "rom-source-aliases.json"))
						}
						if archiveErr == nil {
							archiveSources, archiveErr = verifyMRAArchiveParts(mainROM.Zip, parts, roms)
						}
						if archiveErr != nil && len(zipNames) > 0 {
							overlayDir := filepath.Join(fixtureRoot, "rom-overlays", core, set)
							if _, overlayErr := buildROMOverlay(zipNames[0], parts, roms, overlayDir); overlayErr == nil {
								if sources, verifyErr := verifyMRAArchiveParts(zipNames[0], parts, overlayDir); verifyErr == nil {
									romSource = overlayDir
									archiveSources = sources
									archiveErr = nil
								}
							}
						}
						if archiveErr != nil {
							spec.PreparationError = appendPrepError(spec.PreparationError, "exact ROM CRC preflight failed: "+archiveErr.Error())
						} else if generatedROMPath, generatedMRAPth, targetWarning, targetErr := generateExactROM(ctx, source, core, set, rbf, romSource, path); targetErr != nil {
							spec.PreparationError = appendPrepError(spec.PreparationError, "targeted exact-source ROM generation failed: "+targetErr.Error())
						} else {
							generatedROM = generatedROMPath
							targetMRA = generatedMRAPth
							romSourceUsed = romSource
							if targetWarning != nil {
								lintCandidates = append(lintCandidates, *targetWarning)
							}
						}
					}
				}
				if regularNonempty(generatedROM) {
					if e = copyFile(generatedROM, rom); e != nil {
						spec.PreparationError = appendPrepError(spec.PreparationError, e.Error())
					}
				} else {
					reason := fmt.Sprintf("exact-source jtframe mra did not create %s.rom from ROM source %s", set, roms)
					if !haveROMSource {
						reason = fmt.Sprintf("MAME ROM source directory is unavailable (%s); %s.rom was not generated", roms, set)
					}
					spec.PreparationError = appendPrepError(spec.PreparationError, reason)
				}
			}
			if len(lintCandidates) > 0 && targetMRA != "" {
				persistedTargetMRA := filepath.Join(folder, set+".target.mra")
				if e = copyFile(targetMRA, persistedTargetMRA); e != nil {
					spec.PreparationError = appendPrepError(spec.PreparationError, "could not persist targeted MRA used to verify reviewed warning: "+e.Error())
				} else {
					targetMRA = persistedTargetMRA
				}
			}
			converter := cfg.MRAConverter
			if converter == "" {
				converter = "mra"
			}
			if err = os.Remove(arc); err != nil && !os.IsNotExist(err) {
				return nil, InventoryReconciliation{}, err
			}
			cmd := exec.CommandContext(ctx, converter, "-s", "-A", "-a", arc, mraTool)
			if out, e := cmd.CombinedOutput(); e != nil {
				spec.PreparationError = appendPrepError(spec.PreparationError, fmt.Sprintf("MRA ARC conversion failed: %v: %s", e, strings.TrimSpace(string(out))))
			}
			if !regularNonempty(arc) {
				spec.PreparationError = appendPrepError(spec.PreparationError, "MRA converter did not create an ARC file")
			}
			if spec.PreparationError == "" {
				if romExpected {
					spec.ROMs = []string{rom}
				}
				spec.ARC = arc
			}
			if spec.Profile.Inputs != "" {
				cab := filepath.Clean(filepath.Join(source, "cores", core, "ver", set, spec.Profile.Inputs))
				if regularNonempty(cab) {
					spec.CAB = cab
				} else {
					spec.PreparationError = appendPrepError(spec.PreparationError, fmt.Sprintf("configured CAB input %q was not found relative to cores/%s/ver/%s", spec.Profile.Inputs, core, set))
				}
			}
			if len(lintCandidates) > 0 {
				proof, proofErr := prepareWarningProof(identity, tuple, path, targetMRA, artifactMRAByTuple[tupleKey(tuple)], spec.RBF, rom, arc, mainROM, romSourceUsed, archiveSources)
				if proofErr != nil {
					for _, candidate := range lintCandidates {
						spec.PreparationError = appendPrepError(spec.PreparationError, candidate.Diagnostic)
					}
					spec.PreparationError = appendPrepError(spec.PreparationError, "reviewed MRA lint could not be downgraded because fixture proof failed: "+proofErr.Error())
					spec.ARC = ""
					spec.ROMs = nil
				} else {
					for i := range lintCandidates {
						lintCandidates[i].Proof = proof
						spec.PreparationWarnings = append(spec.PreparationWarnings, lintCandidates[i])
					}
				}
			}
			prep := map[string]any{"schema": 1, "source_sha": identity.SHA, "run_id": identity.RunID, "attempt": identity.Attempt, "core": core, "setname": set, "rbf": rbf, "mra_path": path, "preparation_error": spec.PreparationError}
			if len(spec.PreparationWarnings) > 0 {
				prep["preparation_warnings"] = spec.PreparationWarnings
			}
			if len(archiveSources) > 0 {
				archiveHashes := map[string]string{}
				for _, archivePath := range archiveSources {
					if hash, e := fileSHA256(archivePath); e == nil {
						archiveHashes[archivePath] = hash
					}
				}
				prep["rom_source_archives"] = archiveHashes
			}
			if v, e := fileSHA256(path); e == nil {
				prep["mra_sha256"] = v
			}
			if spec.RBF != "" {
				if v, e := fileSHA256(spec.RBF); e == nil {
					prep["rbf_sha256"] = v
				}
			}
			if regularNonempty(arc) {
				if v, e := fileSHA256(arc); e == nil {
					prep["arc"] = arc
					prep["arc_sha256"] = v
				}
			}
			if regularNonempty(rom) {
				if v, e := fileSHA256(rom); e == nil {
					prep["rom"] = rom
					prep["rom_sha256"] = v
				}
			}
			if spec.CAB != "" {
				if v, e := fileSHA256(spec.CAB); e == nil {
					prep["cab"] = spec.CAB
					prep["cab_sha256"] = v
				}
			}
			prepBytes, _ := json.MarshalIndent(prep, "", "  ")
			if e := os.WriteFile(filepath.Join(folder, "fixture-preparation.json"), append(prepBytes, '\n'), 0640); e != nil {
				return nil, InventoryReconciliation{}, e
			}
		}
		byCore[core] = append(byCore[core], item{core: core, game: spec})
	}
	// Explicit expected-but-unsupported cores can have no MRA titles because
	// their target macros prevent SiDi compilation. If main-only MRAs exist,
	// those individual titles are already represented above.
	result := make([]CoreManifest, 0, len(byCore))
	for core, games := range byCore {
		sort.Slice(games, func(i, j int) bool { return games[i].game.Setname < games[j].game.Setname })
		cm := CoreManifest{Core: core}
		for _, g := range games {
			cm.Games = append(cm.Games, g.game)
		}
		result = append(result, cm)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Core < result[j].Core })
	return result, rec, nil
}

func tupleKey(t InventoryTuple) string { return t.Core + "\x00" + t.Setname + "\x00" + t.RBF }
func sortTuples(t []InventoryTuple) {
	sort.Slice(t, func(i, j int) bool {
		if t[i].Core != t[j].Core {
			return t[i].Core < t[j].Core
		}
		if t[i].Setname != t[j].Setname {
			return t[i].Setname < t[j].Setname
		}
		return t[i].RBF < t[j].RBF
	})
}
func justifySourceOnly(source, artifact []InventoryTuple) map[string]string {
	bySet := map[string][]InventoryTuple{}
	for _, t := range artifact {
		bySet[t.Setname] = append(bySet[t.Setname], t)
	}
	out := map[string]string{}
	for _, t := range source {
		key := tupleKey(t)
		if other := bySet[t.Setname]; len(other) > 0 {
			var mappings []string
			for _, x := range other {
				mappings = append(mappings, fmt.Sprintf("%s/%s", x.Core, x.RBF))
			}
			sort.Strings(mappings)
			out[key] = fmt.Sprintf("Exact-SHA source --mainonly emits %s/%s; selected artifact MRA maps the same setname to %s. Both core ownership rows are retained because they are distinct source and artifact tuples.", t.Core, t.Setname, strings.Join(mappings, ", "))
		} else {
			out[key] = fmt.Sprintf("Exact-SHA jtframe --mainonly emits source-only setname %s under core %s; the successful build archive has no main MRA for this title. Retained because source mainonly inventory is authoritative.", t.Setname, t.Core)
		}
	}
	return out
}

func uniqueSetnameCount(tuples []InventoryTuple) int {
	names := map[string]bool{}
	for _, t := range tuples {
		names[t.Setname] = true
	}
	return len(names)
}

func classifySourceOnly(source, artifact []InventoryTuple) ([]string, []InventoryTuple) {
	artifactNames := map[string]bool{}
	for _, t := range artifact {
		artifactNames[t.Setname] = true
	}
	newNames := map[string]bool{}
	var alternate []InventoryTuple
	for _, t := range source {
		if artifactNames[t.Setname] {
			alternate = append(alternate, t)
		} else {
			newNames[t.Setname] = true
		}
	}
	names := make([]string, 0, len(newNames))
	for name := range newNames {
		names = append(names, name)
	}
	sort.Strings(names)
	sortTuples(alternate)
	return names, alternate
}
func readTuple(path string) (InventoryTuple, bool) {
	b, e := os.ReadFile(path)
	if e != nil {
		return InventoryTuple{}, false
	}
	var m mraInventory
	if xml.Unmarshal(b, &m) != nil || strings.TrimSpace(m.Setname) == "" || strings.TrimSpace(m.RBF) == "" || !strings.HasPrefix(m.RBF, "jt") {
		return InventoryTuple{}, false
	}
	return InventoryTuple{Core: strings.TrimPrefix(m.RBF, "jt"), Setname: strings.TrimSpace(m.Setname), RBF: strings.TrimSpace(m.RBF)}, true
}
func generatedMRATuple(root, core, set, rbf string) error {
	_, err := findGeneratedMRATuple(root, core, set, rbf)
	return err
}
func findGeneratedMRATuple(root, core, set, rbf string) (string, error) {
	files, err := filepath.Glob(filepath.Join(root, "*.mra"))
	if err != nil {
		return "", err
	}
	for _, path := range files {
		t, ok := readTuple(path)
		if ok && t.Core == core && t.Setname == set && t.RBF == rbf {
			return path, nil
		}
	}
	return "", fmt.Errorf("jtframe did not emit expected MRA tuple (%s,%s,%s)", core, set, rbf)
}
func generatedROMForTuple(source, core, set, rbf string) (string, error) {
	if err := generatedMRATuple(filepath.Join(source, "release", "mra"), core, set, rbf); err != nil {
		return "", err
	}
	rom := filepath.Join(source, "rom", set+".rom")
	if !regularNonempty(rom) {
		return "", fmt.Errorf("jtframe emitted %s/%s but no ROM bytes at %s", core, set, rom)
	}
	return rom, nil
}
func generateExactROM(ctx context.Context, source, core, set, rbf, roms, expectedMRA string) (string, string, *PreparationWarning, error) {
	rom := filepath.Join(source, "rom", set+".rom")
	if err := os.Remove(rom); err != nil && !os.IsNotExist(err) {
		return "", "", nil, err
	}
	if err := os.RemoveAll(filepath.Join(source, "release", "mra")); err != nil {
		return "", "", nil, err
	}
	cmd := exec.CommandContext(ctx, "bash", "-c", `core_arg=$1; set_arg=$2; rom_path=$3; set --; export JTROOT="$PWD" JTFRAME="$PWD/modules/jtframe" JTBIN="$PWD/release" GOCACHE="$PWD/.cache/go-build" GOMODCACHE="$PWD/.cache/go-mod"; mkdir -p "$JTBIN" "$GOCACHE" "$GOMODCACHE"; source ./setprj.sh >/dev/null && jtframe mra --mainonly --skipPocket --setname "$set_arg" --path "$rom_path" "$core_arg"`, "_", core, set, roms)
	cmd.Dir = source
	output, runErr := cmd.CombinedOutput()
	var warning *PreparationWarning
	if runErr != nil {
		diagnostic := strings.TrimSpace(string(output))
		fullDiagnostic := fmt.Sprintf("%v: %s", runErr, diagnostic)
		code, reviewed := reviewedMRAExit(core, fullDiagnostic)
		if !reviewed {
			return "", "", nil, fmt.Errorf("jtframe mra failed: %s", fullDiagnostic)
		}
		warning = &PreparationWarning{Code: code, Message: "targeted exact-source ROM generation completed with reviewed post-emission region/order lint", Command: "jtframe mra --mainonly --skipPocket --setname " + set + " --path " + roms + " " + core, ExitStatus: commandErrorStatus(runErr), Diagnostic: fullDiagnostic}
	}
	generatedMRA, err := findGeneratedMRATuple(filepath.Join(source, "release", "mra"), core, set, rbf)
	if err != nil {
		return "", "", nil, err
	}
	if err = sameMainMRAIdentity(expectedMRA, generatedMRA); err != nil {
		return "", "", nil, err
	}
	rom, err = generatedROMForTuple(source, core, set, rbf)
	if err != nil {
		return "", "", nil, err
	}
	return rom, generatedMRA, warning, nil
}

func reviewedMRAExit(core, diagnostic string) (string, bool) {
	if commandExitStatus(diagnostic) != "exit status 1" {
		return "", false
	}
	statusAt := strings.Index(diagnostic, "exit status 1:")
	if statusAt < 0 {
		return "", false
	}
	body := strings.TrimSpace(diagnostic[statusAt+len("exit status 1:"):])
	if body == "" {
		return "", false
	}
	allowedLines := map[string]int{}
	code := ""
	switch core {
	case "s16b":
		code = "post-emission-unused-region-soundcpu-key"
		allowedLines[`s16b: ROM region "soundcpu:key" does not match any MAME region in applicable sets: aliensyn, altbeast, aurail, bayroute, bullet, cotton, ddux, dunkshot, eswat, exctleag, fantzn2x, fpoint, goldnaxe, mvp, passsht, riotcity, ryukyu, sjryuko, sonicbom, suprleag, timescan, toryumon, tturfu, wb3, wrestwar`] = 1
	case "sf":
		code = "post-emission-unused-region-order-protcpu"
		allowedLines[`sf: ROM region "protcpu" does not match any MAME region in applicable sets: sf`] = 1
		allowedLines[`ROM.order region "protcpu" does not match any MAME region`] = 1
	case "shanon":
		code = "post-emission-unused-region-maincpu-key"
		allowedLines[`shanon: ROM region "maincpu:key" does not match any MAME region in applicable sets: shangon`] = 1
	case "tora":
		code = "post-emission-unused-region-order-sample"
		allowedLines[`tora: ROM.order region "sample" does not match any MAME region`] = 1
	default:
		return "", false
	}
	seen := map[string]int{}
	for _, line := range strings.Split(body, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if core == "s16b" && line == "Warning: Game sjryuko (in JTS16B) uses 23 buttons but JTFRAME_BUTTONS is set to 5" {
			seen[line]++
			continue
		}
		matched := false
		for expected := range allowedLines {
			if line == expected {
				matched = true
				seen[expected]++
				break
			}
		}
		if !matched {
			return "", false
		}
	}
	if seen["Warning: Game sjryuko (in JTS16B) uses 23 buttons but JTFRAME_BUTTONS is set to 5"] > 1 {
		return "", false
	}
	for expected, count := range allowedLines {
		if seen[expected] != count {
			return "", false
		}
	}
	return code, true
}

func commandExitStatus(message string) string {
	idx := strings.Index(message, "exit status ")
	if idx < 0 {
		return ""
	}
	status := message[idx:]
	if end := strings.Index(status, ":"); end >= 0 {
		status = status[:end]
	}
	return strings.TrimSpace(status)
}

func commandErrorStatus(err error) string {
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return "exit status " + strconv.Itoa(exitErr.ExitCode())
	}
	return err.Error()
}

func prepareWarningProof(identity BuildIdentity, tuple InventoryTuple, sourceMRA, targetMRA, artifactMRA, rbf, rom, arc string, mainROM *mraROM, romSource string, archiveSources []string) (PreparationWarningProof, error) {
	proof := PreparationWarningProof{RunID: identity.RunID, Attempt: identity.Attempt, SourceSHA: identity.SHA, ArtifactSHA256: identity.ArtifactSHA, Tuple: tuple}
	if tuple.Core == "" || tuple.Setname == "" || tuple.RBF != "jt"+tuple.Core || mainROM == nil {
		return proof, fmt.Errorf("missing exact main MRA tuple or index-0 ROM")
	}
	artifactTuple, ok := readTuple(artifactMRA)
	if !ok || artifactTuple != tuple {
		return proof, fmt.Errorf("selected artifact main MRA does not contain exact tuple %s/%s/%s", tuple.Core, tuple.Setname, tuple.RBF)
	}
	sourceTuple, ok := readTuple(sourceMRA)
	if !ok || sourceTuple != tuple {
		return proof, fmt.Errorf("exact-source mainonly MRA tuple does not match")
	}
	targetTuple, ok := readTuple(targetMRA)
	if !ok || targetTuple != tuple {
		return proof, fmt.Errorf("fresh targeted MRA tuple does not match")
	}
	if err := sameMainMRAIdentity(sourceMRA, targetMRA); err != nil {
		return proof, err
	}
	if err := sameMainMRAIdentity(sourceMRA, artifactMRA); err != nil {
		return proof, fmt.Errorf("selected artifact MRA identity differs: %w", err)
	}
	if !strings.Contains(filepath.ToSlash(rbf), "/release/sidi128/") || !regularNonempty(rbf) || !regularNonempty(rom) || !regularNonempty(arc) {
		return proof, fmt.Errorf("SiDi128 RBF, freshly generated ROM, or ARC output is missing")
	}
	archives, err := verifyMRAArchiveParts(mainROM.Zip, mainROM.AllParts(), romSource)
	if err != nil {
		return proof, fmt.Errorf("recursive ROM archive CRC verification failed: %w", err)
	}
	archiveSet := make(map[string]bool, len(archives))
	for _, path := range archives {
		archiveSet[filepath.Clean(path)] = true
	}
	archiveHashes := make(map[string]string, len(archiveSet))
	for _, path := range archiveSources {
		path = filepath.Clean(path)
		if !archiveSet[path] {
			continue
		}
		hash, hashErr := fileSHA256(path)
		if hashErr != nil {
			return proof, hashErr
		}
		archiveHashes[path] = hash
	}
	if len(archiveHashes) == 0 {
		return proof, fmt.Errorf("no CRC-verified ROM source archive hashes recorded")
	}
	var hashErr error
	if proof.SourceMRASHA256, hashErr = fileSHA256(sourceMRA); hashErr != nil {
		return proof, hashErr
	}
	if proof.TargetMRASHA256, hashErr = fileSHA256(targetMRA); hashErr != nil {
		return proof, hashErr
	}
	if proof.ArtifactMRASHA256, hashErr = fileSHA256(artifactMRA); hashErr != nil {
		return proof, hashErr
	}
	if proof.RBFSHA256, hashErr = fileSHA256(rbf); hashErr != nil {
		return proof, hashErr
	}
	if proof.ROMSHA256, hashErr = fileSHA256(rom); hashErr != nil {
		return proof, hashErr
	}
	if proof.ARCSHA256, hashErr = fileSHA256(arc); hashErr != nil {
		return proof, hashErr
	}
	proof.PartIdentitySHA256, err = mainROMIdentityDigest(sourceMRA)
	if err != nil {
		return proof, err
	}
	proof.RBFFile, proof.ROMFile, proof.ARCFile = rbf, rom, arc
	proof.TargetMRAFile = targetMRA
	proof.SourceMRAFile = sourceMRA
	proof.ArtifactMRAFile = artifactMRA
	proof.ROMPartCount = len(mainROM.AllParts())
	proof.ROMSourceArchiveSHA256 = archiveHashes
	return proof, nil
}
func sameMainMRAIdentity(expected, generated string) error {
	read := func(path string) (mraInventory, mraROM, error) {
		b, e := os.ReadFile(path)
		if e != nil {
			return mraInventory{}, mraROM{}, e
		}
		var m mraInventory
		if e = xml.Unmarshal(b, &m); e != nil {
			return mraInventory{}, mraROM{}, e
		}
		for _, r := range m.ROM {
			if r.Index == "0" {
				return m, r, nil
			}
		}
		return m, mraROM{}, fmt.Errorf("%s has no index-0 ROM", path)
	}
	a, ar, e := read(expected)
	if e != nil {
		return e
	}
	b, br, e := read(generated)
	if e != nil {
		return e
	}
	if a.Setname != b.Setname || a.RBF != b.RBF || ar.Zip != br.Zip {
		return fmt.Errorf("target MRA identity differs from exact mainonly MRA: %s/%s %s vs %s/%s %s", a.RBF, a.Setname, ar.Zip, b.RBF, b.Setname, br.Zip)
	}
	identityA, err := canonicalMainROMIdentity(expected)
	if err != nil {
		return err
	}
	identityB, err := canonicalMainROMIdentity(generated)
	if err != nil {
		return err
	}
	if !reflect.DeepEqual(identityA, identityB) {
		return fmt.Errorf("target MRA ordered ROM part identity differs from exact mainonly MRA (%s/%s)", a.RBF, a.Setname)
	}
	return nil
}

type canonicalXMLChild struct {
	Name       xml.Name            `json:"name,omitempty"`
	Attributes []canonicalXMLAttr  `json:"attributes,omitempty"`
	Text       string              `json:"text,omitempty"`
	Children   []canonicalXMLChild `json:"children,omitempty"`
}

type canonicalXMLAttr struct {
	Name  xml.Name `json:"name"`
	Value string   `json:"value"`
}

func canonicalMainROMIdentity(path string) (canonicalXMLChild, error) {
	f, err := os.Open(path)
	if err != nil {
		return canonicalXMLChild{}, err
	}
	defer f.Close()
	decoder := xml.NewDecoder(f)
	for {
		token, err := decoder.Token()
		if err != nil {
			if err == io.EOF {
				return canonicalXMLChild{}, fmt.Errorf("%s has no index-0 ROM", path)
			}
			return canonicalXMLChild{}, err
		}
		start, ok := token.(xml.StartElement)
		if !ok || start.Name.Local != "rom" || attrValue(start.Attr, "index") != "0" {
			continue
		}
		return canonicalXMLNode(decoder, start, true)
	}
}

func canonicalXMLNode(decoder *xml.Decoder, start xml.StartElement, mainROM bool) (canonicalXMLChild, error) {
	node := canonicalXMLChild{Name: start.Name}
	for _, attr := range start.Attr {
		if mainROM && attr.Name.Local == "asm_md5" {
			continue
		}
		node.Attributes = append(node.Attributes, canonicalXMLAttr{Name: attr.Name, Value: attr.Value})
	}
	sort.Slice(node.Attributes, func(i, j int) bool {
		a, b := node.Attributes[i], node.Attributes[j]
		if a.Name.Space != b.Name.Space {
			return a.Name.Space < b.Name.Space
		}
		if a.Name.Local != b.Name.Local {
			return a.Name.Local < b.Name.Local
		}
		return a.Value < b.Value
	})
	for {
		token, err := decoder.Token()
		if err != nil {
			return canonicalXMLChild{}, err
		}
		switch value := token.(type) {
		case xml.StartElement:
			child, err := canonicalXMLNode(decoder, value, false)
			if err != nil {
				return canonicalXMLChild{}, err
			}
			node.Children = append(node.Children, child)
		case xml.EndElement:
			if value.Name == start.Name {
				return node, nil
			}
		case xml.CharData:
			text := strings.TrimSpace(string(value))
			if text != "" {
				node.Children = append(node.Children, canonicalXMLChild{Text: text})
			}
		}
	}
}

func attrValue(attrs []xml.Attr, name string) string {
	for _, attr := range attrs {
		if attr.Name.Local == name {
			return attr.Value
		}
	}
	return ""
}

func mainROMIdentityDigest(path string) (string, error) {
	identity, err := canonicalMainROMIdentity(path)
	if err != nil {
		return "", err
	}
	data, err := json.Marshal(identity)
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:]), nil
}
func readArtifactMainMRAs(artifact, dst string) ([]string, []InventoryTuple, error) {
	z, e := zip.OpenReader(artifact)
	if e != nil {
		return nil, nil, e
	}
	defer z.Close()
	if e = os.MkdirAll(dst, 0750); e != nil {
		return nil, nil, e
	}
	var paths []string
	var tuples []InventoryTuple
	seen := map[string]bool{}
	for _, f := range z.File {
		name := filepath.ToSlash(f.Name)
		if strings.Contains(name, "..") {
			return nil, nil, fmt.Errorf("unsafe artifact MRA path %q", name)
		}
		if f.FileInfo().IsDir() || !strings.HasPrefix(name, "release/mra/") || !strings.HasSuffix(strings.ToLower(name), ".mra") || strings.Count(name, "/") != 2 {
			continue
		}
		b, e := readZipEntry(f)
		if e != nil {
			return nil, nil, e
		}
		var m mraInventory
		if xml.Unmarshal(b, &m) != nil || strings.TrimSpace(m.Setname) == "" || !strings.HasPrefix(strings.TrimSpace(m.RBF), "jt") {
			continue
		}
		t := InventoryTuple{Core: strings.TrimPrefix(strings.TrimSpace(m.RBF), "jt"), Setname: strings.TrimSpace(m.Setname), RBF: strings.TrimSpace(m.RBF)}
		if seen[tupleKey(t)] {
			return nil, nil, fmt.Errorf("duplicate artifact main MRA tuple %s/%s/%s", t.Core, t.Setname, t.RBF)
		}
		seen[tupleKey(t)] = true
		out := filepath.Join(dst, fmt.Sprintf("%s-%s.mra", t.Core, filepath.Base(name)))
		if e = os.WriteFile(out, b, 0640); e != nil {
			return nil, nil, e
		}
		paths = append(paths, out)
		tuples = append(tuples, t)
	}
	sort.Strings(paths)
	sortTuples(tuples)
	return paths, tuples, nil
}

func coreSkipped(ctx context.Context, source, core string) bool {
	cmd := exec.CommandContext(ctx, "bash", "-c", `core_arg=$1; set --; export JTROOT="$PWD" JTFRAME="$PWD/modules/jtframe" JTBIN="$PWD/release" GOCACHE="$PWD/.cache/go-build" GOMODCACHE="$PWD/.cache/go-mod"; mkdir -p "$JTBIN" "$GOCACHE" "$GOMODCACHE"; source ./setprj.sh >/dev/null && jtframe cfgstr "$core_arg" --target=sidi128 --output bash`, "_", core)
	cmd.Dir = source
	out, e := cmd.Output()
	if e != nil {
		return false
	}
	for _, line := range strings.Split(string(out), "\n") {
		s := strings.TrimSpace(line)
		if strings.HasPrefix(s, "export JTFRAME_SKIP=") && !strings.HasSuffix(s, "=\"\"") && !strings.HasSuffix(s, "=''") && !strings.HasSuffix(s, "=") {
			return true
		}
	}
	return false
}

func dirHasRBF(path string) bool {
	f, e := filepath.Glob(filepath.Join(path, "jt*.rbf"))
	return e == nil && len(f) > 0
}

// stageROMSource builds a cache-local view over configured, user-owned ROM
// archives. The archives themselves are not copied or modified.
func stageROMSource(configured string, extra []string, destination string) (string, bool, error) {
	var dirs []string
	configuredDirs := append(filepath.SplitList(configured), extra...)
	for _, part := range configuredDirs {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		abs, err := filepath.Abs(part)
		if err != nil {
			return "", false, err
		}
		if isDir(abs) {
			dirs = append(dirs, abs)
		}
	}
	if len(dirs) == 0 {
		return configured, false, nil
	}
	if err := os.MkdirAll(destination, 0750); err != nil {
		return "", false, err
	}
	for dirIndex, dir := range dirs {
		files, err := filepath.Glob(filepath.Join(dir, "*.zip"))
		if err != nil {
			return "", false, err
		}
		for _, src := range files {
			if filepath.Base(src) == ".zip" {
				continue
			}
			dst := filepath.Join(destination, filepath.Base(src))
			if _, err := os.Lstat(dst); err == nil {
				// Preserve duplicate basenames under source-qualified names so an
				// exact-CRC overlay can inspect every configured archive.
				dst = filepath.Join(destination, fmt.Sprintf("source%d-%s", dirIndex, filepath.Base(src)))
				if _, err := os.Lstat(dst); err == nil {
					resolved, evalErr := filepath.EvalSymlinks(dst)
					want, wantErr := filepath.EvalSymlinks(src)
					if evalErr != nil || wantErr != nil || resolved != want {
						return "", false, fmt.Errorf("ROM pool collision at %s (existing source %s, configured source %s)", dst, resolved, src)
					}
					continue
				}
			}
			if err := os.Symlink(src, dst); err != nil {
				return "", false, err
			}
		}
	}
	return destination, true, nil
}

func mraZipNames(value string) ([]string, error) {
	seen := map[string]bool{}
	var names []string
	for _, raw := range strings.Split(value, "|") {
		name := strings.TrimSpace(raw)
		if name == "" {
			continue
		}
		if filepath.Base(name) != name || !strings.HasSuffix(strings.ToLower(name), ".zip") {
			return nil, fmt.Errorf("invalid MRA ZIP identity %q", name)
		}
		if !seen[name] {
			seen[name] = true
			names = append(names, name)
		}
	}
	if len(names) == 0 {
		return nil, fmt.Errorf("MRA has no ZIP archive identity")
	}
	return names, nil
}

func verifyMRAArchiveParts(zipValue string, parts []mraPart, sourceDir string) ([]string, error) {
	names, err := mraZipNames(zipValue)
	if err != nil {
		return nil, err
	}
	need := map[uint32]bool{}
	for _, p := range parts {
		if p.Name == "" {
			continue
		}
		if p.CRC == "" {
			return nil, fmt.Errorf("MRA ROM part %s has no CRC", p.Name)
		}
		n, e := strconv.ParseUint(strings.TrimPrefix(strings.ToLower(p.CRC), "0x"), 16, 32)
		if e != nil {
			return nil, fmt.Errorf("invalid CRC %q for MRA part %s", p.CRC, p.Name)
		}
		need[uint32(n)] = true
	}
	if len(need) == 0 {
		return nil, fmt.Errorf("MRA %s has no named CRC parts to validate", zipValue)
	}
	found := map[uint32]string{}
	used := map[string]bool{}
	for _, name := range names {
		path := filepath.Join(sourceDir, name)
		z, e := zip.OpenReader(path)
		if e != nil {
			continue
		}
		archiveSHA, _ := fileSHA256(path)
		for _, f := range z.File {
			if !need[f.CRC32] || f.FileInfo().IsDir() {
				continue
			}
			key := fmt.Sprintf("%s:%08x:%d", archiveSHA, f.CRC32, f.UncompressedSize64)
			if _, ok := verifiedROMParts.Load(key); !ok {
				data, e := readZipEntry(f)
				if e != nil || crc32.ChecksumIEEE(data) != f.CRC32 {
					continue
				}
				verifiedROMParts.Store(key, true)
			}
			found[f.CRC32] = path
			used[path] = true
		}
		_ = z.Close()
	}
	missing := make([]string, 0)
	for crc := range need {
		if found[crc] == "" {
			missing = append(missing, fmt.Sprintf("%08x", crc))
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return nil, fmt.Errorf("MRA ROM part CRCs absent from named local archives %s: %s", strings.Join(names, "|"), strings.Join(missing, ", "))
	}
	archives := make([]string, 0, len(used))
	for path := range used {
		archives = append(archives, path)
	}
	sort.Strings(archives)
	return archives, nil
}

func ensureExactArchiveAlias(zipName string, parts []mraPart, sourceDir, manifestPath string) error {
	if zipName == "" || filepath.Base(zipName) != zipName || !strings.HasSuffix(strings.ToLower(zipName), ".zip") {
		return fmt.Errorf("invalid MRA archive identity %q", zipName)
	}
	target := filepath.Join(sourceDir, zipName)
	if regularNonempty(target) {
		_, err := verifyMRAArchiveParts(zipName, parts, sourceDir)
		return err
	}
	archives, err := filepath.Glob(filepath.Join(sourceDir, "*.zip"))
	if err != nil {
		return err
	}
	need := map[uint32]bool{}
	for _, p := range parts {
		if p.Name == "" {
			continue
		}
		if p.CRC == "" {
			return fmt.Errorf("MRA ROM part %s has no CRC", p.Name)
		}
		n, e := strconv.ParseUint(strings.TrimPrefix(strings.ToLower(p.CRC), "0x"), 16, 32)
		if e != nil {
			return fmt.Errorf("MRA %s has invalid CRC %q", zipName, p.CRC)
		}
		need[uint32(n)] = true
	}
	if len(need) == 0 {
		return fmt.Errorf("MRA %s has no checksummed ROM parts", zipName)
	}
	for _, candidate := range archives {
		if filepath.Base(candidate) == zipName {
			continue
		}
		z, e := zip.OpenReader(candidate)
		if e != nil {
			continue
		}
		found := map[uint32]bool{}
		for _, f := range z.File {
			if f.FileInfo().IsDir() {
				continue
			}
			crc, ok := need[f.CRC32]
			if ok && crc {
				data, readErr := readZipEntry(f)
				if readErr == nil && crc32.ChecksumIEEE(data) == f.CRC32 {
					found[f.CRC32] = true
				}
			}
		}
		_ = z.Close()
		if len(found) != len(need) {
			continue
		}
		if err = os.Symlink(candidate, target); err != nil {
			return err
		}
		digest, e := fileSHA256(candidate)
		if e != nil {
			_ = os.Remove(target)
			return e
		}
		entry := map[string]any{"archive": zipName, "symlink_target": candidate, "source_archive_sha256": digest, "required_crc32": need, "all_parts_match": true}
		var doc map[string]any
		if raw, readErr := os.ReadFile(manifestPath); readErr == nil {
			_ = json.Unmarshal(raw, &doc)
		}
		if doc == nil {
			doc = map[string]any{"schema": 1, "aliases": []any{}}
		}
		aliases, _ := doc["aliases"].([]any)
		aliases = append(aliases, entry)
		doc["aliases"] = aliases
		b, _ := json.MarshalIndent(doc, "", "  ")
		if err = os.WriteFile(manifestPath, append(b, '\n'), 0640); err != nil {
			return err
		}
		return nil
	}
	return fmt.Errorf("no owned local archive provides every exact CRC required by %s", zipName)
}
func regularNonempty(path string) bool {
	fi, e := os.Stat(path)
	return e == nil && fi.Mode().IsRegular() && fi.Size() > 0
}
func appendPrepError(existing, next string) string {
	if next == "" {
		return existing
	}
	if existing == "" {
		return next
	}
	return existing + "; " + next
}
func isDir(path string) bool { fi, e := os.Stat(path); return e == nil && fi.IsDir() }
func fileSHA256(path string) (string, error) {
	f, e := os.Open(path)
	if e != nil {
		return "", e
	}
	defer f.Close()
	h := sha256.New()
	if _, e = io.Copy(h, f); e != nil {
		return "", e
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
func copyFile(src, dst string) error {
	in, e := os.Open(src)
	if e != nil {
		return e
	}
	defer in.Close()
	out, e := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0640)
	if e != nil {
		return e
	}
	_, e = io.Copy(out, in)
	ce := out.Close()
	if e != nil {
		return e
	}
	return ce
}

// buildROMOverlay creates a local alias ZIP only when the MAME set's own ZIP is
// absent. Every needed entry must be present in an already-owned archive with
// the exact CRC declared by this build's generated MRA. This safely covers
// sets such as kchampvs whose complete ROM data is identical to local kchamp.zip.
func buildROMOverlay(zipName string, parts []mraPart, sourceDir, destination string) (string, error) {
	if zipName == "" || filepath.Base(zipName) != zipName || !strings.HasSuffix(strings.ToLower(zipName), ".zip") {
		return "", fmt.Errorf("invalid MRA ZIP identity %q", zipName)
	}
	need := map[uint32][]string{}
	for _, p := range parts {
		if p.Name == "" {
			continue
		}
		if filepath.Base(p.Name) != p.Name || p.Name == "." || p.Name == ".." {
			return "", fmt.Errorf("invalid ROM part name %q", p.Name)
		}
		if p.CRC == "" {
			return "", fmt.Errorf("MRA ROM part %s has no CRC; exact ROM provenance cannot be verified", p.Name)
		}
		crc, parseErr := strconv.ParseUint(strings.TrimPrefix(strings.ToLower(p.CRC), "0x"), 16, 32)
		if parseErr != nil {
			return "", fmt.Errorf("invalid MRA CRC %q for %s", p.CRC, p.Name)
		}
		need[uint32(crc)] = append(need[uint32(crc)], p.Name)
	}
	if len(need) == 0 {
		return "", fmt.Errorf("MRA has no named ROM parts")
	}
	paths, err := filepath.Glob(filepath.Join(sourceDir, "*.zip"))
	if err != nil {
		return "", err
	}
	sort.Strings(paths)
	found := map[string][]byte{}
	sources := map[string]string{}
	for _, path := range paths {
		z, e := zip.OpenReader(path)
		if e != nil {
			continue
		}
		used := false
		for _, f := range z.File {
			names := need[f.CRC32]
			if len(names) == 0 || f.FileInfo().IsDir() {
				continue
			}
			data, readErr := readZipEntry(f)
			if readErr != nil || crc32.ChecksumIEEE(data) != f.CRC32 {
				continue
			}
			for _, name := range names {
				if _, ok := found[name]; !ok {
					found[name] = data
					used = true
				}
			}
		}
		_ = z.Close()
		if used {
			digest, e := fileSHA256(path)
			if e == nil {
				sources[filepath.Base(path)] = digest
			}
		}
		complete := true
		for _, names := range need {
			for _, name := range names {
				if _, ok := found[name]; !ok {
					complete = false
					break
				}
			}
			if !complete {
				break
			}
		}
		if complete {
			break
		}
	}
	missing := make([]string, 0)
	for _, names := range need {
		for _, name := range names {
			if _, ok := found[name]; !ok {
				missing = append(missing, name)
			}
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return "", fmt.Errorf("local ROM archives do not contain required MAME ROMs: %s", strings.Join(missing, ", "))
	}
	if err = os.MkdirAll(destination, 0750); err != nil {
		return "", err
	}
	archivePath := filepath.Join(destination, zipName)
	file, err := os.Create(archivePath)
	if err != nil {
		return "", err
	}
	w := zip.NewWriter(file)
	names := make([]string, 0, len(found))
	for name := range found {
		names = append(names, name)
	}
	sort.Strings(names)
	for _, name := range names {
		entry, e := w.Create(name)
		if e != nil {
			_ = w.Close()
			_ = file.Close()
			return "", e
		}
		if _, e = entry.Write(found[name]); e != nil {
			_ = w.Close()
			_ = file.Close()
			return "", e
		}
	}
	if err = w.Close(); err != nil {
		_ = file.Close()
		return "", err
	}
	if err = file.Close(); err != nil {
		return "", err
	}
	archiveSHA, err := fileSHA256(archivePath)
	if err != nil {
		return "", err
	}
	manifest, _ := json.MarshalIndent(map[string]any{"zip": zipName, "sha256": archiveSHA, "source_archives": sources, "rom_parts": names}, "", "  ")
	if err = os.WriteFile(filepath.Join(destination, "overlay-manifest.json"), append(manifest, '\n'), 0640); err != nil {
		return "", err
	}
	return destination, nil
}

func readZipEntry(f *zip.File) ([]byte, error) {
	r, e := f.Open()
	if e != nil {
		return nil, e
	}
	defer r.Close()
	limit := int64(f.UncompressedSize64) + 1
	b, e := io.ReadAll(io.LimitReader(r, limit))
	if e != nil {
		return nil, e
	}
	if uint64(len(b)) != f.UncompressedSize64 {
		return nil, fmt.Errorf("short ROM archive entry")
	}
	return b, nil
}
