/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"errors"
	"crypto/sha256"
	"encoding/hex"
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

type miSTerGamePreparationError struct { err error }
func (e miSTerGamePreparationError) Error() string { return e.err.Error() }
func (e miSTerGamePreparationError) Unwrap() error { return e.err }
func isMiSTerGamePreparationError(err error) bool { var target miSTerGamePreparationError; return errors.As(err, &target) }
// IsMiSTerGamePreparationError reports an expected failure limited to one game's inputs.
func IsMiSTerGamePreparationError(err error) bool { return isMiSTerGamePreparationError(err) }
func miSTerGameInputError(err error) error { return miSTerGamePreparationError{err: err} }

// PrepareMiSTerManualSelection inventories exact source MRAs and the matching
// release/mister build. It performs no hardware work and never assembles ARC
// or arcade ROM files; MiSTer loads the original MRA and its declared archives.
func PrepareMiSTerManualSelection(ctx context.Context, cfg Config, workspace string, cores, sets []string, useJTBin bool) (Manifest, error) {
	if ctx == nil {
		return Manifest{}, fmt.Errorf("MiSTer preparation requires a context")
	}
	if cfg.Target != "mister" || cfg.Source == "" || workspace == "" || len(cores) == 0 {
		return Manifest{}, fmt.Errorf("MiSTer preparation requires target=mister, source, workspace and selected cores")
	}
	if err := cfg.ValidateMiSTerRun(); err != nil {
		return Manifest{}, err
	}
	timeoutSeconds := cfg.TimeoutSeconds
	if timeoutSeconds <= 0 {
		timeoutSeconds = 900
	}
	ctx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSeconds)*time.Second)
	defer cancel()
	source, err := filepath.Abs(cfg.Source)
	if err != nil {
		return Manifest{}, err
	}
	workspace, err = filepath.Abs(workspace)
	if err != nil {
		return Manifest{}, err
	}
	if err = os.MkdirAll(workspace, 0700); err != nil {
		return Manifest{}, err
	}
	release := filepath.Join(source, "release")
	if useJTBin {
		release = os.Getenv("JTBIN")
		if release == "" {
			return Manifest{}, fmt.Errorf("--jtbin requires JTBIN")
		}
		release, err = filepath.Abs(release)
		if err != nil {
			return Manifest{}, err
		}
	}
	if !useJTBin {
		// Generate the selected source MRA inventory once per core. Existing
		// release output is managed by jtframe and the command's private logs.
		for _, core := range cores {
			if !manualComponent(core) || !regularNonempty(filepath.Join(source, "cores", core, "cfg", "mame2mra.toml")) {
				return Manifest{}, fmt.Errorf("unknown or unsafe project core %q", core)
			}
			requests := []string{""}
			if len(sets) > 0 {
				requests = sets
			}
			for _, setArg := range requests {
				script := `core_arg=$1; set_arg=$2; out_arg=$3; set --; source ./setprj.sh >/dev/null && export JTBIN="$out_arg" && if [ -n "$set_arg" ]; then jtframe mra --nodbg --git --skipROM --skipPocket --setname "$set_arg" "$core_arg"; else jtframe mra --nodbg --git --mainonly --skipROM --skipPocket "$core_arg"; fi`
				output, commandErr := manualCommand(ctx, source, "bash", "-c", script, "_", core, setArg, release)
				if commandErr != nil {
					return Manifest{}, fmt.Errorf("MiSTer source MRA generation for %s/%s: %w: %s", core, setArg, commandErr, strings.TrimSpace(string(output)))
				}
			}
		}
	}
	return prepareMiSTerReleaseSelection(ctx, cfg, source, release, workspace, cores, sets)
}

func prepareMiSTerReleaseSelection(ctx context.Context, cfg Config, source, release, workspace string, cores, sets []string, tolerateGameErrors ...bool) (Manifest, error) {
	profilePath := cfg.GlobalProfile
	if profilePath == "" {
		profilePath = filepath.Join(source, "modules", "jtframe", "bin", "reg.yaml")
	}
	configSource := cfg.SourceConfigRoot
	if configSource == "" { configSource = source }
	romRoot := cfg.ROMSource
	if romRoot == "" {
		romRoot = filepath.Join(os.Getenv("HOME"), ".mame", "roms")
	}
	romSourceChecked := false
	if len(tolerateGameErrors)>0 && tolerateGameErrors[0] {
		rbfDir := filepath.Join(release, "mister")
		info, err := os.Stat(rbfDir)
		if err != nil { return Manifest{}, fmt.Errorf("inspect MiSTer bitstream directory: %w", err) }
		if !info.IsDir() { return Manifest{}, fmt.Errorf("MiSTer bitstream path is not a directory: %s", rbfDir) }
	}
	selectedSets := map[string]bool{}
	for _, set := range sets {
		if !manualComponent(set) || selectedSets[set] {
			return Manifest{}, fmt.Errorf("unsafe or duplicate MiSTer setname %q", set)
		}
		selectedSets[set] = true
	}
	manifest := Manifest{Source: source}
	projectSHA, _ := gitHead(ctx, source)
	manifest.ProjectSHA = projectSHA
	usedTuples := map[string]bool{}
	for _, core := range cores {
		if !manualComponent(core) {
			return Manifest{}, fmt.Errorf("unsafe MiSTer core %q", core)
		}
		if len(tolerateGameErrors)>0 && tolerateGameErrors[0] {
			skipped, err := miSTerTargetSkipped(configSource, core)
			if err != nil { return Manifest{}, err }
			if skipped { manifest.SkippedTargets = append(manifest.SkippedTargets, core); continue }
		}
		mraPaths, err := manualMRAs(filepath.Join(release, "mra"), core, "")
		if err != nil {
			return Manifest{}, err
		}
		requested := make(map[string]bool, len(sets))
		for _, set := range sets {
			requested[set] = true
		}
		var tuples []InventoryTuple
		for _, mraPath := range mraPaths {
			if tuple, ok := readTuple(mraPath); ok {
				tuples = append(tuples, tuple)
			}
		}
		exclusions, err := sourceExclusions(configSource, tuples)
		if err != nil {
			return Manifest{}, err
		}
		profileExclusions, err := profileSkipExclusions(configSource, tuples)
		if err != nil {
			return Manifest{}, err
		}
		if configSource != source {
			currentExclusions, err := profileSkipExclusions(source, tuples)
			if err != nil { return Manifest{}, err }
			for key, reason := range currentExclusions { profileExclusions[key] = reason }
		}
		coreManifest := CoreManifest{Core: core}
		for _, mraPath := range mraPaths {
			tuple, ok := readTuple(mraPath)
			if !ok {
				continue
			}
			if len(sets) > 0 && !requested[tuple.Setname] {
				continue
			}
			reason := exclusions[tupleKey(tuple)]
			if reason == "" {
				reason = profileExclusions[tupleKey(tuple)]
			}
			if reason != "" || debugMRADirectory(filepath.Join(release, "mra"), mraPath) {
				if len(sets) != 0 {
					return Manifest{}, fmt.Errorf("%s/%s is not regression eligible: %s", core, tuple.Setname, reason)
				}
				if reason == "" { reason = "debug MRA directory" }
				manifest.SkippedGames = append(manifest.SkippedGames, core+"/"+tuple.Setname+": "+reason)
				continue
			}
			if len(tolerateGameErrors)>0 && tolerateGameErrors[0] {
				_, err := os.Lstat(filepath.Join(release, "mister", "jt"+core+".rbf"))
				if os.IsNotExist(err) { manifest.SkippedBuilds = append(manifest.SkippedBuilds, core); break }
				if err != nil { return Manifest{}, err }
			}
			if usedTuples[tupleKey(tuple)] {
				return Manifest{}, fmt.Errorf("duplicate selected MRA tuple %s/%s/%s", tuple.Core, tuple.Setname, tuple.RBF)
			}
			usedTuples[tupleKey(tuple)] = true
			if len(tolerateGameErrors)>0 && tolerateGameErrors[0] && !romSourceChecked {
				raw, err := os.ReadFile(mraPath); if err != nil { return Manifest{}, err }
				var inventory mraInventory
				if err = xml.Unmarshal(raw,&inventory); err != nil { return Manifest{}, err }
				reads, err := effectiveMRAArchiveReads(inventory); if err != nil { return Manifest{}, err }
				if len(reads)>0 {
					info, err := os.Stat(romRoot); if err != nil { return Manifest{}, fmt.Errorf("inspect MiSTer ROM source: %w", err) }
					if !info.IsDir() { return Manifest{}, fmt.Errorf("MiSTer ROM source is not a directory: %s",romRoot) }
					dir, err := os.Open(romRoot); if err != nil { return Manifest{}, fmt.Errorf("open MiSTer ROM source: %w",err) }
					if err = dir.Close(); err != nil { return Manifest{}, err }; romSourceChecked = true
				}
			}
			spec, err := prepareMiSTerGameAssets(ctx, cfg, source, release, romRoot, workspace, core, tuple.Setname, mraPath, profilePath)
			if err != nil {
				if len(tolerateGameErrors) == 0 || !tolerateGameErrors[0] || !isMiSTerGamePreparationError(err) { return Manifest{}, err }
				spec = GameSpec{Setname: tuple.Setname, PreparationError: err.Error()}
			}
			coreManifest.Games = append(coreManifest.Games, spec)
		}
		if len(coreManifest.Games) == 0 {
			if len(tolerateGameErrors)>0 && tolerateGameErrors[0] { continue }
			return Manifest{}, fmt.Errorf("no eligible MiSTer MRAs selected for core %s", core)
		}
		manifest.Cores = append(manifest.Cores, coreManifest)
	}
	for _, set := range sets {
		found := false
		for key := range usedTuples {
			if strings.Split(key, "\x00")[1] == set {
				found = true
				break
			}
		}
		if !found {
			return Manifest{}, fmt.Errorf("no eligible MiSTer MRA matched requested setname %s", set)
		}
	}
	if len(manifest.Cores) == 0 && (len(tolerateGameErrors)==0 || !tolerateGameErrors[0]) {
		return Manifest{}, fmt.Errorf("MiSTer selection is empty")
	}
	manifest.RunID = "mister-manual"
	manifest.Build = BuildIdentity{Repository: "jotego/jtcores", Workflow: "manual", RunID: manifest.RunID, Attempt: "1", SHA: projectSHA, Ref: release, Event: "manual-mister", Artifact: release, Conclusion: "manual"}
	return manifest, nil
}

// PrepareMiSTerBuild consumes a selected local or downloaded Compile all ZIP,
// extracts its exact MiSTer RBF and MRA pair into the project release
// tree using the existing archive transaction, then builds detached sessions.
// SiDi-only ZIPs are deliberately ineligible for this target.
func PrepareMiSTerBuild(ctx context.Context, cfg Config, dataRoot, workspace string, identity BuildIdentity, tolerateGameErrors ...bool) (Manifest, error) {
	if identity.Workflow != compileAllWorkflow {
		return Manifest{}, fmt.Errorf("MiSTer preparation requires a complete Compile all artifact")
	}
	if cfg.Target != "mister" || cfg.Source == "" || dataRoot == "" || workspace == "" {
		return Manifest{}, fmt.Errorf("MiSTer build preparation requires explicit target, source and staging paths")
	}
	// Keep target-specific build manifests beside the existing flat run logs
	// without colliding with a historical SiDi extraction of the same attempt.
	buildDir := filepath.Join(dataRoot, "log", identity.RunID+"-attempt-"+identity.Attempt, "preparation", "mister")
	buildSource := filepath.Join(workspace, "build-project")
	buildCfg := cfg
	buildCfg.Source = buildSource
	archive, _, err := prepareArtifact(ctx, buildCfg, buildDir, identity)
	if err != nil {
		return Manifest{}, err
	}
	identity.ArtifactSHA, err = file_sha256(archive)
	if err != nil {
		return Manifest{}, err
	}
	release, err := filepath.Abs(filepath.Join(buildSource, "release"))
	if err != nil {
		return Manifest{}, err
	}
	files, err := filepath.Glob(filepath.Join(release, "mra", "*.mra"))
	if err != nil {
		return Manifest{}, err
	}
	coreSet := map[string]bool{}
	for _, filename := range files {
		if tuple, ok := readTuple(filename); ok && manualComponent(tuple.Core) && regularNonempty(filepath.Join(cfg.Source, "cores", tuple.Core, "cfg", "mame2mra.toml")) {
			coreSet[tuple.Core] = true
		}
	}
	cores := make([]string, 0, len(coreSet))
	for core := range coreSet {
		cores = append(cores, core)
	}
	sort.Strings(cores)
	if len(cores) == 0 {
		return Manifest{}, fmt.Errorf("selected Compile all artifact has no MiSTer main-game MRA inventory")
	}
	manifest, err := prepareMiSTerReleaseSelection(ctx, cfg, cfg.Source, release, workspace, cores, nil, tolerateGameErrors...)
	if err != nil {
		return Manifest{}, err
	}
	manifest.Build = identity
	manifest.RunID = identity.RunID + "-attempt-" + identity.Attempt
	return manifest, nil
}

// PrepareMiSTerManualArchive materializes a pinned local Compile all archive.
// It refuses the target-specific SiDi ZIP even when that is the only archive
// available for the requested commit.
func PrepareMiSTerManualArchive(ctx context.Context, cfg Config, dataRoot, workspace string, archive ManualArchive, cores, sets []string) (Manifest, error) {
	if archive.Path == "" || archive.Commit == "" || !isCommitSHA(archive.Commit) || !isSHA256Hex(archive.SHA256) {
		return Manifest{}, fmt.Errorf("manual MiSTer archive lacks an exact commit and digest")
	}
	name := filepath.Base(archive.Path)
	if strings.HasSuffix(name, "-sidi128.zip") || !strings.HasSuffix(name, ".zip") {
		return Manifest{}, fmt.Errorf("MiSTer manual runs require the full Compile all ZIP, not a SiDi128-only archive")
	}
	actual, err := FileSHA256(archive.Path)
	if err != nil {
		return Manifest{}, err
	}
	if !strings.EqualFold(actual, archive.SHA256) {
		return Manifest{}, fmt.Errorf("manual MiSTer archive changed after selection")
	}
	cfg.BuildsDir = filepath.Dir(archive.Path)
	identity := BuildIdentity{Repository: "jotego/jtcores", Workflow: compileAllWorkflow,
		RunID: "manual-" + archive.Commit[:12], Attempt: "1", SHA: archive.Commit,
		Artifact: name, ArtifactSHA: archive.SHA256, Conclusion: "manual", Event: "manual-mister"}
	manifest, err := PrepareMiSTerBuild(ctx, cfg, dataRoot, workspace, identity, len(cores)==0 && len(sets)==0)
	if err != nil {
		return Manifest{}, err
	}
	if len(cores) != 0 || len(sets) != 0 {
		return filterMiSTerManifest(manifest, cores, sets)
	}
	return manifest, nil
}

// MiSTerReleaseBuildCommit reads the source commit recorded in JTBIN's Git
// history for each selected RBF. The workflow commit is the build identity;
// no per-RBF proof sidecars are required.
func MiSTerReleaseBuildCommit(ctx context.Context, release string, cores []string) (string, error) {
	if release == "" || len(cores) == 0 {
		return "", fmt.Errorf("JTBIN release and selected cores are required")
	}
	var selected string
	seen := map[string]bool{}
	for _, core := range cores {
		if !manualComponent(core) || seen[core] {
			return "", fmt.Errorf("unsafe or duplicate JTBIN core %q", core)
		}
		seen[core] = true
		filename := "mister/jt" + core + ".rbf"
		output, err := exec.CommandContext(ctx, "git", "-C", release, "log", "-1", "--format=%B", "--", filename).Output()
		if err != nil {
			return "", fmt.Errorf("read JTBIN history for %s: %w", core, err)
		}
		match := regexp.MustCompile(`jtcores/commit/([0-9a-f]{40})(?:\s|$)`).FindSubmatch(output)
		if len(match) != 2 {
			return "", fmt.Errorf("JTBIN history for %s does not identify a jtcores source commit", core)
		}
		commit := string(match[1])
		if selected != "" && selected != commit {
			return "", fmt.Errorf("selected JTBIN cores were built from different source commits")
		}
		selected = commit
	}
	return selected, nil
}

func filterMiSTerManifest(manifest Manifest, cores, sets []string) (Manifest, error) {
	wantedCore, wantedSet := map[string]bool{}, map[string]bool{}
	for _, core := range cores {
		if !manualComponent(core) || wantedCore[core] {
			return Manifest{}, fmt.Errorf("unsafe or duplicate selected MiSTer core %q", core)
		}
		wantedCore[core] = true
	}
	for _, set := range sets {
		if !manualComponent(set) || wantedSet[set] {
			return Manifest{}, fmt.Errorf("unsafe or duplicate selected MiSTer set %q", set)
		}
		wantedSet[set] = true
	}
	filtered := Manifest{RunID: manifest.RunID, Build: manifest.Build, Source: manifest.Source, ProjectSHA: manifest.ProjectSHA}
	for _, core := range manifest.SkippedTargets { if len(wantedCore)==0 || wantedCore[core] { filtered.SkippedTargets=append(filtered.SkippedTargets,core) } }
	for _, core := range manifest.SkippedBuilds { if len(wantedCore)==0 || wantedCore[core] { filtered.SkippedBuilds=append(filtered.SkippedBuilds,core) } }
	for _, game := range manifest.SkippedGames {
		core, rest, _ := strings.Cut(game,"/"); set, _, _ := strings.Cut(rest,":")
		if (len(wantedCore)==0 || wantedCore[core]) && (len(wantedSet)==0 || wantedSet[set]) { filtered.SkippedGames=append(filtered.SkippedGames,game) }
	}
	seenCore, seenSet := map[string]bool{}, map[string]bool{}
	for _, core := range manifest.Cores {
		if len(wantedCore) != 0 && !wantedCore[core.Core] {
			continue
		}
		games := CoreManifest{Core: core.Core}
		for _, game := range core.Games {
			if len(wantedSet) != 0 && !wantedSet[game.Setname] {
				continue
			}
			games.Games = append(games.Games, game)
			seenSet[game.Setname] = true
		}
		if len(games.Games) != 0 {
			filtered.Cores = append(filtered.Cores, games)
			seenCore[core.Core] = true
		}
	}
	for _, core := range cores {
		if !seenCore[core] {
			return Manifest{}, fmt.Errorf("selected Compile all artifact has no eligible MiSTer games for core %s", core)
		}
	}
	for _, set := range sets {
		if !seenSet[set] {
			return Manifest{}, fmt.Errorf("selected Compile all artifact has no eligible MiSTer game %s", set)
		}
	}
	if len(filtered.Cores) == 0 {
		return Manifest{}, fmt.Errorf("manual MiSTer archive selection is empty")
	}
	return filtered, nil
}

func prepareMiSTerGameAssets(ctx context.Context, cfg Config, source, release, romRoot, workspace, core, set, mraPath, profilePath string) (GameSpec, error) {
	var spec GameSpec
	spec.PreparedHashes = make(map[string]string)
	rbf := filepath.Join(release, "mister", "jt"+core+".rbf")
	info, err := os.Lstat(rbf)
	if os.IsNotExist(err) { return spec, miSTerGameInputError(fmt.Errorf("MiSTer RBF is missing for %s", core)) }
	if err != nil { return spec, err }
	if !info.Mode().IsRegular() || info.Size()==0 { return spec, fmt.Errorf("MiSTer RBF is not a nonempty regular file for %s", core) }
	profile, err := ResolveProfile(profilePath, source, core, set)
	if err != nil {
		return spec, err
	}
	originalBytes, err := os.ReadFile(mraPath)
	if err != nil {
		return spec, err
	}
	var inventory mraInventory
	if err = xml.Unmarshal(originalBytes, &inventory); err != nil || inventory.RBF != "jt"+core || inventory.Setname != set {
		return spec, fmt.Errorf("selected MRA identity does not match %s/%s", core, set)
	}
	assetDir := filepath.Join(workspace, "assets", core, set)
	if err = os.MkdirAll(assetDir, 0700); err != nil {
		return spec, err
	}
	originalPath := filepath.Join(assetDir, set+".mra")
	if err = os.WriteFile(originalPath, originalBytes, 0600); err != nil {
		return spec, err
	}
	rbfSHA, err := FileSHA256(rbf)
	if err != nil {
		return spec, err
	}
	launchStem := "jt224-" + rbfSHA[:24]
	launchBytes, err := pathOnlyLaunchMRA(originalBytes, launchStem)
	if err != nil {
		return spec, err
	}
	launchPath := filepath.Join(assetDir, launchStem+".mra")
	if err = os.WriteFile(launchPath, launchBytes, 0600); err != nil {
		return spec, err
	}
	archives, defaultRAM, err := resolveMiSTerROMFixtures(inventory, romRoot, assetDir, set)
	if err != nil {
		return spec, err
	}
	originalSHA, err := FileSHA256(originalPath)
	if err != nil {
		return spec, err
	}
	launchSHA, err := FileSHA256(launchPath)
	if err != nil {
		return spec, err
	}
	configSource := cfg.SourceConfigRoot
	if configSource == "" {
		configSource = source
	}
	configVersion, err := MiSTerConfigVersion(configSource, core)
	if err != nil {
		return spec, err
	}
	nativeStatusPath := miSTerNativeStatusPath(set, configVersion)
	proof := MiSTerNativeStatusProof{MainSHA256: cfg.CaptureContract.MainSHA256,
		ExpectedCoreName: set, ConfigVersion: configVersion, NativeStatusPath: nativeStatusPath}
	assets := &MiSTerGameAssets{OriginalMRA: MiSTerAssetFile{Role: FixtureOriginalMRA, Name: filepath.Base(originalPath), Path: originalPath, SHA256: originalSHA},
		LaunchMRA:   MiSTerAssetFile{Role: FixtureLaunchMRA, Name: filepath.Base(launchPath), Path: launchPath, SHA256: launchSHA},
		ROMArchives: archives, DefaultRAM: defaultRAM, NativeStatus: proof}
	for _, asset := range append(append([]MiSTerAssetFile(nil), archives...), defaultRAM...) {
		spec.PreparedHashes = ensureStringMap(spec.PreparedHashes)
		spec.PreparedHashes[asset.Path] = asset.SHA256
	}
	spec.Setname, spec.RBF, spec.Profile, spec.MisterAssets = set, rbf, profile, assets
	spec.CAB = ""
	if profile.Inputs != "" {
		spec.CAB = filepath.Clean(filepath.Join(source, "cores", core, "ver", set, profile.Inputs))
		info, err := os.Stat(spec.CAB)
		if os.IsNotExist(err) { return GameSpec{}, miSTerGameInputError(fmt.Errorf("configured CAB input %q is unavailable", spec.CAB)) }
		if err != nil { return GameSpec{}, err }
		if !info.Mode().IsRegular() || info.Size()==0 { return GameSpec{}, miSTerGameInputError(fmt.Errorf("configured CAB input %q is empty or not regular", spec.CAB)) }
	}
	spec.PreparedHashes[rbf] = rbfSHA
	spec.PreparedHashes[originalPath] = originalSHA
	spec.PreparedHashes[launchPath] = launchSHA
	return spec, nil
}

func resolveMiSTerROMFixtures(inventory mraInventory, romRoot, assetDir, set string) ([]MiSTerAssetFile, []MiSTerAssetFile, error) {
	archiveNames := map[string]bool{}
	orderedArchiveNames := make([]string, 0)
	reads, err := effectiveMRAArchiveReads(inventory)
	if err != nil {
		return nil, nil, err
	}
	for _, read := range reads {
		for _, name := range read.candidates {
			if !archiveNames[name] {
				archiveNames[name] = true
				orderedArchiveNames = append(orderedArchiveNames, name)
			}
		}
	}
	archives := make([]MiSTerAssetFile, 0, len(orderedArchiveNames))
	for _, name := range orderedArchiveNames {
		filename := filepath.Join(romRoot, name)
		info, err := os.Lstat(filename)
		if os.IsNotExist(err) && name == "jtbeta.zip" && os.Getenv("JTUTIL") != "" {
			filename = filepath.Join(os.Getenv("JTUTIL"), name)
			info, err = os.Lstat(filename)
		}
		if os.IsNotExist(err) {
			// MRA zip fields are ordered candidates. Main continues to the next
			// candidate when this archive is absent, so don't manufacture or
			// require a missing child archive when another candidate covers it.
			continue
		}
		if err != nil {
			return nil, nil, fmt.Errorf("inspect MiSTer ROM archive candidate %s: %w", name, err)
		}
		if info.Mode()&os.ModeSymlink != 0 || !info.Mode().IsRegular() {
			return nil, nil, fmt.Errorf("MiSTer ROM archive candidate %s is not a regular file", name)
		}
		digest, err := FileSHA256(filename)
		if err != nil {
			return nil, nil, err
		}
		archives = append(archives, MiSTerAssetFile{Role: FixtureROMArchive, Name: name, Path: filename, SHA256: digest})
	}
	var ram []MiSTerAssetFile
	for _, rom := range inventory.ROM {
		if rom.Index != "2" || len(rom.AllParts()) == 0 {
			continue
		}
		if len(rom.AllParts()) != 1 {
			return nil, nil, fmt.Errorf("default RAM MRA entry for %s is ambiguous", set)
		}
		part := rom.AllParts()[0]
		var data []byte
		var err error
		if part.Name != "" {
			candidates, candidateErr := effectiveMRAArchiveCandidates(rom, part)
			if candidateErr != nil {
				return nil, nil, candidateErr
			}
			data, err = readMRAArchivePart(archives, strings.Join(candidates, "|"), part)
		} else {
			data, err = mame_nvram_hex(part.Text)
			if err == nil {
				data, err = mraPartWindow(data, part)
			}
		}
		if err != nil {
			return nil, nil, fmt.Errorf("resolve default MiSTer RAM for %s: %w", set, err)
		}
		if len(data) != 0 {
			filename := filepath.Join(assetDir, strings.ToUpper(set)+".RAM")
			if err = os.WriteFile(filename, data, 0600); err != nil {
				return nil, nil, err
			}
			digest := sha256.Sum256(data)
			ram = append(ram, MiSTerAssetFile{Role: FixtureDefaultRAM, Name: strings.ToUpper(set) + ".RAM", Path: filename, SHA256: hex.EncodeToString(digest[:])})
		}
		break
	}
	return archives, ram, nil
}

func pathOnlyLaunchMRA(original []byte, stem string) ([]byte, error) {
	if !safeMRAStem(stem) || !strings.HasPrefix(stem, "jt224-") {
		return nil, fmt.Errorf("launch MRA requires a content-addressed safe RBF stem")
	}
	decoder := xml.NewDecoder(strings.NewReader(string(original)))
	var output strings.Builder
	encoder := xml.NewEncoder(&output)
	depth, rbfDepth, count := 0, -1, 0
	for {
		token, err := decoder.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		switch item := token.(type) {
		case xml.StartElement:
			depth++
			if item.Name.Local == "rbf" {
				count++
				if count != 1 {
					return nil, fmt.Errorf("MRA has multiple RBF elements")
				}
				rbfDepth = depth
			}
		case xml.EndElement:
			if rbfDepth == depth {
				rbfDepth = -1
			}
			depth--
		case xml.CharData:
			if rbfDepth == depth && strings.TrimSpace(string(item)) != "" {
				token = xml.CharData(stem)
			}
		}
		if err = encoder.EncodeToken(token); err != nil {
			return nil, err
		}
	}
	if count != 1 {
		return nil, fmt.Errorf("MRA must contain exactly one RBF element")
	}
	if err := encoder.Flush(); err != nil {
		return nil, err
	}
	result := []byte(output.String())
	originalCanonical, _, err := canonicalMRA(original)
	if err != nil {
		return nil, err
	}
	launchCanonical, gotStem, err := canonicalMRA(result)
	if err != nil || gotStem != stem || string(originalCanonical) != string(launchCanonical) {
		return nil, fmt.Errorf("launch MRA is not a verified RBF-path-only derivative")
	}
	return result, nil
}

func ensureStringMap(values map[string]string) map[string]string {
	if values == nil {
		return map[string]string{}
	}
	return values
}
