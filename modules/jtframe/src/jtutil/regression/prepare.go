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
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"time"
)


var jtframeMRACommand = func(ctx context.Context, source, core, roms string, haveROMSource bool) ([]byte, error) {
	// Inventory selection must not depend on which local ZIPs happen to be
	// installed. ROM generation is a separate targeted operation below.
	command := `core_arg=$1; set --; export JTROOT="$PWD" JTFRAME="$PWD/modules/jtframe" JTBIN="$PWD/release"; mkdir -p "$JTBIN"; source ./setprj.sh >/dev/null && jtframe mra --nodbg --mainonly --skipROM --skipPocket "$core_arg"`
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
	SourceTuples                []InventoryTuple  `json:"project_mainonly_mras"`
	SourceOnly                  []InventoryTuple  `json:"source_only_tuples"`
	ArtifactOnly                []InventoryTuple  `json:"artifact_only_tuples"`
	ArtifactFallbacks           []InventoryTuple  `json:"artifact_metadata_fallbacks"`
	SourceExcluded              []InventoryTuple  `json:"source_excluded_tuples,omitempty"`
	SourceExclusionReasons      map[string]string `json:"source_exclusion_reasons,omitempty"`
	SourceOnlyJustifications    map[string]string `json:"source_only_justifications"`
	ArtifactOnlyJustifications  map[string]string `json:"artifact_only_justifications"`
	SourceUniqueSetnames        int               `json:"source_unique_setnames"`
	ArtifactUniqueSetnames      int               `json:"artifact_unique_setnames"`
	ExactTupleOverlap           int               `json:"exact_tuple_overlap"`
	SourceOnlySetnames          []string          `json:"source_only_setnames"`
	SourceOnlyAlternateMappings []InventoryTuple  `json:"source_only_alternate_mappings"`
}

// Prepare discovers or selects a successful complete compile_all build,
// downloads its RBF artifact and uses the working project to prepare the
// main-game ROM/ARC inventory. runID pins one Actions run (for example 40655576158).
func Prepare(ctx context.Context, cfg Config, dataRoot, runID string) (Manifest, error) {
	if ctx == nil {
		ctx = context.Background()
	}
	if cfg.Repository == "" {
		cfg.Repository = "jotego/jtcores"
	}
	identity, err := discover_build(ctx, cfg.Repository, runID, dataRoot, cfg)
	if err != nil {
		return Manifest{}, err
	}
	return PrepareBuild(ctx, cfg, dataRoot, identity)
}

// PrepareBuild prepares an already selected build. dataRoot may be a temporary
// workspace; normal command execution keeps preparation diagnostics in /tmp.
func PrepareBuild(ctx context.Context, cfg Config, dataRoot string, identity BuildIdentity) (Manifest, error) {
	if cfg.Source == "" {
		return Manifest{}, fmt.Errorf("working project is required for build %s", identity.SHA)
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
	buildDir := filepath.Join(dataRoot, "log", buildKey, "preparation")
	if err := os.MkdirAll(buildDir, 0750); err != nil {
		return Manifest{}, err
	}
	if cfg.GlobalProfile == "" { cfg.GlobalProfile = filepath.Join(cfg.Source, "modules", "jtframe", "bin", "reg.yaml") }
	artifactPath, rbfRoot, err := prepareArtifact(stageCtx, cfg, buildDir, identity)
	if err != nil {
		return Manifest{}, err
	}
	identity.ArtifactSHA, err = fileSHA256(artifactPath)
	if err != nil {
		return Manifest{}, err
	}
	source := cfg.Source
	work, err := os.MkdirTemp("/tmp", "jtutil-regression-prepare-")
	if err != nil { return Manifest{}, err }
	defer os.RemoveAll(work)
	cores, rec, err := mainGameInventory(stageCtx, source, rbfRoot, work, artifactPath, identity, cfg)
	if log_error := persist_preparation_reports(work, buildDir); log_error != nil { return Manifest{}, errors.Join(err,log_error) }
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
	project_sha, _ := gitHead(ctx, source)
	return Manifest{RunID: identity.RunID + "-attempt-" + identity.Attempt, Build: identity, Source: source, ProjectSHA: project_sha, Cores: cores}, nil
}

// Preserve preparation diagnostics, not temporary source copies or binaries.
func persist_preparation_reports(work, destination string) error {
	return filepath.WalkDir(work, func(name string, entry fs.DirEntry, walk_error error) error {
		if walk_error != nil { return walk_error }
		if entry.IsDir() || filepath.Ext(name) != ".json" && filepath.Ext(name) != ".log" { return nil }
		relative, e := filepath.Rel(work, name)
		if e != nil { return e }
		output := filepath.Join(destination, relative)
		if e = os.MkdirAll(filepath.Dir(output), 0750); e != nil { return e }
		return copyFile(name, output)
	})
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
		return nil, InventoryReconciliation{}, fmt.Errorf("no cores with mame2mra configurations in working project")
	}
	roms := cfg.ROMSource
	if roms == "" {
		roms = filepath.Join(os.Getenv("HOME"), ".mame", "roms")
	}
	// Generate main-game MRAs from the working project. Existing output is
	// preserved while only this invocation's emissions enter its snapshot.
	// jtframe writes a flat release/mra directory. Snapshot each core's output
	// before the next core can overwrite an identically named MRA.
	mraRoot := filepath.Join(fixtureRoot, "mainonly-mra")
	if err := os.MkdirAll(mraRoot, 0750); err != nil {
		return nil, InventoryReconciliation{}, err
	}
	haveROMSource := isDir(roms)
	mraErrors := map[string]string{}
	for _, core := range cores {
		// Use argv through a tiny shell wrapper only for setprj.sh environment;
		// core names are repository path components and were read from DirEntry.
		// Refresh only the task-owned snapshot. The live release/mra folder
		// is preserved by refresh_core_mras, including on command failure.
		coreMRA := filepath.Join(mraRoot, core)
		if err := os.RemoveAll(coreMRA); err != nil {
			return nil, InventoryReconciliation{}, err
		}
		if err := os.MkdirAll(coreMRA, 0750); err != nil { return nil, InventoryReconciliation{}, err }
		if out, e := refresh_core_mras(ctx, source, core, roms, haveROMSource, coreMRA); e != nil {
			mraErrors[core] = fmt.Sprintf("project jtframe mra inventory command failed: %v: %s", e, strings.TrimSpace(string(out)))
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
	allTuples := append([]InventoryTuple(nil), artifactTuples...)
	error_only := map[string]bool{}
	for _, tuple := range artifactTuples { error_only[tupleKey(tuple)] = true }
	for _, path := range files { if tuple, ok := readTuple(path); ok { allTuples = append(allTuples, tuple); delete(error_only,tupleKey(tuple)) } }
	exclusions, err := sourceExclusions(source, allTuples, error_only)
	if err != nil { return nil, InventoryReconciliation{}, err }
	profileExclusions, err := profileSkipExclusions(source, allTuples)
	if err != nil { return nil, InventoryReconciliation{}, err }
	for key, reason := range profileExclusions {
		if exclusions[key] == "" { exclusions[key] = reason }
	}
	eligibleFiles := files[:0]
	for _, path := range files { if tuple, ok := readTuple(path); !ok || exclusions[tupleKey(tuple)] == "" { eligibleFiles = append(eligibleFiles, path) } }
	files = eligibleFiles
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
	project_sha, _ := gitHead(ctx, source)
	rec := InventoryReconciliation{Schema: 1, RunID: identity.RunID, Attempt: identity.Attempt, SourceSHA: project_sha, ArtifactSHA256: identity.ArtifactSHA, ArtifactTuples: artifactTuples}
	rec.SourceExclusionReasons = exclusions
	seenExclusions := map[string]bool{}
	for _, tuple := range allTuples { if exclusions[tupleKey(tuple)] != "" && !seenExclusions[tupleKey(tuple)] { rec.SourceExcluded = append(rec.SourceExcluded, tuple); seenExclusions[tupleKey(tuple)] = true } }
	sortTuples(rec.SourceExcluded)
	for _, path := range files {
		if t, ok := readTuple(path); ok {
			rec.SourceTuples = append(rec.SourceTuples, t)
		}
	}
	missingSource := map[string]bool{}
	for _, t := range artifactTuples {
		if !sourceTupleSet[tupleKey(t)] {
			rec.ArtifactOnly = append(rec.ArtifactOnly, t)
			if exclusions[tupleKey(t)] == "" {
				rec.ArtifactFallbacks = append(rec.ArtifactFallbacks, t)
				missingSource[tupleKey(t)] = true
			}
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
		if reason := exclusions[tupleKey(t)]; reason != "" { rec.ArtifactOnlyJustifications[tupleKey(t)] = "Excluded from regression: " + reason; continue }
		rec.ArtifactOnlyJustifications[tupleKey(t)] = "The selected successful build contains this main MRA tuple but working-project jtframe --mainonly did not emit it; artifact MRA is retained only as an explicit per-title preparation-error fallback."
	}
	var fallbackMRAs []string
	for _, path := range artifactMRAs {
		if t, ok := readTuple(path); ok && missingSource[tupleKey(t)] {
			fallbackMRAs = append(fallbackMRAs, path)
		}
	}
	// Artifact metadata may keep a title visible when an project core
	// command failed before writing that MRA. Include it with an explicit error
	// so it cannot silently masquerade as project metadata.
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
	artifactEligibleCore, artifactExcludedCore := map[string]int{}, map[string]int{}
	for _, tuple := range artifactTuples { if exclusions[tupleKey(tuple)] != "" { artifactExcludedCore[tuple.Core]++ } else { artifactEligibleCore[tuple.Core]++ } }
	missingCore := make([]string, 0)
	rbfPaths, globErr := filepath.Glob(filepath.Join(rbfRoot, "jt*.rbf"))
	if globErr != nil {
		return nil, InventoryReconciliation{}, globErr
	}
	for _, rbf := range rbfPaths {
		core := strings.TrimSuffix(strings.TrimPrefix(filepath.Base(rbf), "jt"), ".rbf")
		if generatedCore[core] == 0 && !fallbackCore[core] && !(artifactExcludedCore[core] > 0 && artifactEligibleCore[core] == 0) && regularNonempty(filepath.Join(coreRoot, core, "cfg", "mame2mra.toml")) {
			missingCore = append(missingCore, core)
		}
	}
	if len(missingCore) > 0 {
		sort.Strings(missingCore)
		return nil, InventoryReconciliation{}, fmt.Errorf("incomplete mainonly inventory: no project MRA titles were generated for supported RBF cores %s", strings.Join(missingCore, ", "))
	}
	files = append(files, fallbackMRAs...)
	if len(files) == 0 {
		return nil, InventoryReconciliation{}, fmt.Errorf("jtframe mra --nodbg --mainonly generated no MRA files for any core")
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
			spec.PreparationError = "project mainonly inventory omitted this artifact main MRA tuple; artifact metadata is retained only as an explicit fallback"
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
					lintCandidates = append(lintCandidates, PreparationWarning{Code: code, Message: "project mainonly inventory completed with reviewed post-emission region/order lint", Command: "jtframe mra --nodbg --mainonly --skipROM --skipPocket " + core, ExitStatus: commandExitStatus(mraErrors[core]), Diagnostic: mraErrors[core]})
				} else {
					spec.PreparationError = appendPrepError(spec.PreparationError, mraErrors[core])
				}
			}
			folder := filepath.Join(fixtureRoot, core, set)
			if e = os.MkdirAll(folder, 0750); e != nil {
				return nil, InventoryReconciliation{}, e
			}
			arc := filepath.Join(source, "rom", set+".arc")
			rom := filepath.Join(source, "rom", set+".rom")
			mraTool := filepath.Join(source, "release", "mra", filepath.Base(path))
			if err = os.MkdirAll(filepath.Dir(rom), 0750); err != nil { return nil, InventoryReconciliation{}, err }
			var targetMRA string
			romExpected := false
			for i := range m.ROM { if m.ROM[i].Index == "0" { romExpected = true; break } }
			if romExpected {
				generated_rom, generated_mra, warning, gen_err := generateExactROM(ctx, source, core, set, rbf, roms, path)
				if gen_err != nil {
					spec.PreparationError = appendPrepError(spec.PreparationError, gen_err.Error())
				} else {
					targetMRA, mraTool, rom = generated_mra, generated_mra, generated_rom
					if warning != nil { lintCandidates = append(lintCandidates, *warning) }
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
					ram, ramErr := generatedNVRAM(source, targetMRA, set)
					if ramErr != nil {
						spec.PreparationError = appendPrepError(spec.PreparationError, ramErr.Error())
					} else if ram != "" {
						spec.ROMs = append(spec.ROMs, ram)
					}
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
			if spec.PreparationError == "" {
				spec.PreparationWarnings = append(spec.PreparationWarnings, lintCandidates...)
				spec.PreparedHashes = make(map[string]string)
				inputs := append([]string{spec.RBF, spec.ARC, mraTool}, spec.ROMs...)
				for _, input := range inputs {
					digest, hash_error := fileSHA256(input)
					if hash_error != nil { spec.PreparationError = appendPrepError(spec.PreparationError, hash_error.Error()); break }
					spec.PreparedHashes[input] = digest
				}
			}
			prep := map[string]any{"schema": 1, "source_sha": project_sha, "rbf_source_sha": identity.SHA, "run_id": identity.RunID, "attempt": identity.Attempt, "core": core, "setname": set, "rbf": rbf, "mra_path": mraTool, "preparation_error": spec.PreparationError}
			if len(spec.PreparationWarnings) > 0 { prep["preparation_warnings"] = spec.PreparationWarnings }
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

// refresh_core_mras excludes stale current-core output without clearing the
// live release directory. Originals omitted by this invocation are restored.
func refresh_core_mras(ctx context.Context, source, core, roms string, have_roms bool, snapshot string) (output []byte, result_error error) {
	backup, err := os.MkdirTemp(filepath.Dir(snapshot), "mra-backup-")
	if err != nil { return nil, err }
	mra_dir := filepath.Join(source, "release", "mra")
	defer func() {
		entries, read_error := os.ReadDir(backup)
		if read_error != nil { result_error = errors.Join(result_error, read_error); return }
		for _, entry := range entries {
			target := filepath.Join(mra_dir, entry.Name())
			if _, stat_error := os.Lstat(target); os.IsNotExist(stat_error) {
				if restore_error := copyFile(filepath.Join(backup, entry.Name()), target); restore_error != nil {
					result_error = errors.Join(result_error, fmt.Errorf("restore generated MRA from %s: %w", backup, restore_error))
					return
				}
			} else if stat_error != nil { result_error = errors.Join(result_error, stat_error); return }
		}
		result_error = errors.Join(result_error, os.RemoveAll(backup))
	}()
	files, err := filepath.Glob(filepath.Join(mra_dir, "*.mra"))
	if err != nil { return nil, err }
	for _, path := range files {
		if tuple, ok := readTuple(path); ok && tuple.Core == core {
			info, stat_error := os.Lstat(path)
			if stat_error != nil { return nil, stat_error }
			if !info.Mode().IsRegular() { return nil, fmt.Errorf("generated MRA is not a regular file: %s", path) }
			if err = copyFile(path, filepath.Join(backup, filepath.Base(path))); err != nil { return nil, err }
			if err = os.Remove(path); err != nil { return nil, err }
		}
	}
	output, result_error = jtframeMRACommand(ctx, source, core, roms, have_roms)
	files, err = filepath.Glob(filepath.Join(mra_dir, "*.mra"))
	if err != nil { return output, errors.Join(result_error, err) }
	for _, path := range files {
		if tuple, ok := readTuple(path); ok && tuple.Core == core {
			if err = copyFile(path, filepath.Join(snapshot, filepath.Base(path))); err != nil { return output, errors.Join(result_error, err) }
		}
	}
	return output, result_error
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
			out[key] = fmt.Sprintf("Working project --mainonly emits %s/%s; selected artifact MRA maps the same setname to %s. Both core ownership rows are retained because they are distinct source and artifact tuples.", t.Core, t.Setname, strings.Join(mappings, ", "))
		} else {
			out[key] = fmt.Sprintf("Working-project jtframe --mainonly emits source-only setname %s under core %s; the successful build archive has no main MRA for this title. Retained because source mainonly inventory is authoritative.", t.Setname, t.Core)
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
	// Both files are generated outputs; remove them before invoking jtframe so
	// an old game's NVRAM can never masquerade as freshly generated defaults.
	for _, output := range []string{rom, filepath.Join(source, "rom", strings.ToUpper(set)+".RAM")} {
		if err := os.Remove(output); err != nil && !os.IsNotExist(err) {
			return "", "", nil, err
		}
	}
	cmd := exec.CommandContext(ctx, "bash", "-c", `core_arg=$1; set_arg=$2; rom_path=$3; set --; export JTROOT="$PWD" JTFRAME="$PWD/modules/jtframe" JTBIN="$PWD/release"; mkdir -p "$JTBIN"; source ./setprj.sh >/dev/null && jtframe mra --nodbg --mainonly --skipPocket --setname "$set_arg" --path "$rom_path" "$core_arg"`, "_", core, set, roms)
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
		warning = &PreparationWarning{Code: code, Message: "targeted project ROM generation completed with reviewed post-emission region/order lint", Command: "jtframe mra --nodbg --mainonly --skipPocket --setname " + set + " --path " + roms + " " + core, ExitStatus: commandErrorStatus(runErr), Diagnostic: fullDiagnostic}
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
	cmd := exec.CommandContext(ctx, "bash", "-c", `core_arg=$1; set --; export JTROOT="$PWD" JTFRAME="$PWD/modules/jtframe" JTBIN="$PWD/release"; mkdir -p "$JTBIN"; source ./setprj.sh >/dev/null && jtframe cfgstr "$core_arg" --target=sidi128 --output bash`, "_", core)
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

func readZipEntry(f *zip.File) ([]byte, error) {
	r, e := f.Open()
	if e != nil { return nil, e }
	defer r.Close()
	b, e := io.ReadAll(io.LimitReader(r, int64(f.UncompressedSize64)+1))
	if e != nil { return nil, e }
	if uint64(len(b)) != f.UncompressedSize64 { return nil, fmt.Errorf("short artifact archive entry") }
	return b, nil
}
