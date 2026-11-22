/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"archive/zip"
	"context"
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

type ManualArchive struct {
	Commit      string
	Path        string
	SHA256      string
	ReleaseRoot string
	Cores       []string
	Games       []InventoryTuple
}

type archiveMRAEntry struct {
	file  *zip.File
	path  string
	tuple InventoryTuple
}

// PrepareManualArchive prepares each selected archive game through the same
// conversion path as --jtbin while keeping its MRA and RBF pinned to the ZIP.
func PrepareManualArchive(ctx context.Context, cfg Config, dataRoot, workspace string, archive ManualArchive, cores, sets []string) (Manifest, error) {
	selected, err := ExtractManualArchive(ctx, archive, workspace, cores, sets)
	if err != nil {
		return Manifest{}, err
	}
	cfg.NoPublish = true
	currentExclusions, err := sourceExclusions(cfg.Source, selected.Games)
	if err != nil {
		return Manifest{}, err
	}
	profileExclusions, err := profileSkipExclusions(cfg.Source, selected.Games)
	if err != nil {
		return Manifest{}, err
	}
	eligible := selected.Games[:0]
	requestedSets := map[string]bool{}
	for _, set := range sets {
		requestedSets[set] = true
	}
	matchedSets := map[string]bool{}
	matchedCores := map[string]bool{}
	for _, tuple := range selected.Games {
		reason := currentExclusions[tupleKey(tuple)]
		if reason == "" {
			reason = profileExclusions[tupleKey(tuple)]
		}
		if debugMRADirectory(filepath.Join(selected.ReleaseRoot, "mra"), filepath.Join(selected.ReleaseRoot, "mra", tuple.Setname+".mra")) {
			reason = "MRA is in a debug directory"
		}
		if reason != "" {
			if len(sets) > 0 {
				return Manifest{}, fmt.Errorf("%s/%s is not regression eligible: %s", tuple.Core, tuple.Setname, reason)
			}
			continue
		}
		eligible = append(eligible, tuple)
		matchedSets[tuple.Setname] = true
		matchedCores[tuple.Core] = true
	}
	if err := requireManualCoreCoverage(cores, matchedCores, "archive"); err != nil {
		return Manifest{}, err
	}
	for set := range requestedSets {
		if !matchedSets[set] {
			return Manifest{}, fmt.Errorf("no eligible archive MRA matched requested setname %s", set)
		}
	}
	selected.Games = eligible
	if len(selected.Games) == 0 {
		return Manifest{}, fmt.Errorf("no archive games are regression eligible")
	}
	merged := Manifest{Source: cfg.Source}
	coreIndex := map[string]int{}
	gameTuples := append([]InventoryTuple(nil), selected.Games...)
	for _, tuple := range gameTuples {
		part, prepErr := PrepareManual(ctx, cfg, dataRoot, tuple.Core, tuple.Setname, true, selected.ReleaseRoot)
		if prepErr != nil {
			return Manifest{}, prepErr
		}
		if merged.RunID == "" {
			merged.RunID = part.RunID
			merged.ProjectSHA = part.ProjectSHA
		}
		if merged.ProjectSHA != part.ProjectSHA {
			return Manifest{}, fmt.Errorf("working project changed during archive preparation")
		}
		if len(part.Cores) != 1 || len(part.Cores[0].Games) != 1 {
			return Manifest{}, fmt.Errorf("archive preparation selected unexpected game inventory")
		}
		game := part.Cores[0].Games[0]
		// PrepareManual writes to the shared project rom/ directory. Copy its
		// outputs now so another core with the same setname cannot replace them.
		fixtureDir := filepath.Join(workspace, "manual-fixtures", tuple.Core, tuple.Setname)
		if err = os.MkdirAll(fixtureDir, 0750); err != nil {
			return Manifest{}, err
		}
		mapping := map[string]string{}
		for _, p := range append(append([]string(nil), game.ROMs...), game.ARC) {
			dst := filepath.Join(fixtureDir, filepath.Base(p))
			if err = copyFile(p, dst); err != nil {
				return Manifest{}, err
			}
			mapping[p] = dst
		}
		for i, p := range game.ROMs {
			if dst := mapping[p]; dst != "" {
				game.ROMs[i] = dst
			}
		}
		game.ARC = mapping[game.ARC]
		updatedHashes := map[string]string{}
		for old, digest := range game.PreparedHashes {
			if dst := mapping[old]; dst != "" {
				updatedHashes[dst] = digest
			} else {
				updatedHashes[old] = digest
			}
		}
		game.PreparedHashes = updatedHashes
		idx, ok := coreIndex[tuple.Core]
		if !ok {
			idx = len(merged.Cores)
			coreIndex[tuple.Core] = idx
			merged.Cores = append(merged.Cores, CoreManifest{Core: tuple.Core})
		}
		merged.Cores[idx].Games = append(merged.Cores[idx].Games, game)
	}
	merged.Build = BuildIdentity{Repository: "jotego/jtcores", Workflow: "manual", RunID: merged.RunID, Attempt: "1", SHA: selected.Commit, Event: "manual-archive", Ref: selected.Path, Artifact: selected.Path, ArtifactSHA: selected.SHA256, Conclusion: "manual"}
	return merged, nil
}

// PrepareManualSelection runs the existing local/JTBIN preparation once per
// core, then pins each game's generated files in a core-specific workspace.
func PrepareManualSelection(ctx context.Context, cfg Config, dataRoot, workspace string, cores, sets []string, useJTBin bool) (Manifest, error) {
	if err := preflightManualSelection(ctx, cfg, cores, sets, useJTBin); err != nil {
		return Manifest{}, err
	}
	merged := Manifest{Source: cfg.Source}
	coreIndex := map[string]int{}
	matched := map[string]bool{}
	matchedCores := map[string]bool{}
	artifactIdentities := map[string]string{}
	for _, core := range cores {
		requests := []string{""}
		if len(sets) > 0 {
			requests = sets
		}
		for _, requestedSet := range requests {
			part, err := PrepareManual(ctx, cfg, dataRoot, core, requestedSet, useJTBin)
			if err != nil {
				if requestedSet != "" && strings.Contains(err.Error(), "no MRA for manual selection") {
					continue
				}
				return Manifest{}, err
			}
			if merged.RunID == "" {
				merged.RunID = part.RunID
				merged.ProjectSHA = part.ProjectSHA
				merged.Build = part.Build
			}
			if merged.ProjectSHA != part.ProjectSHA {
				return Manifest{}, fmt.Errorf("working project changed during manual preparation")
			}
			games := part.Cores[0].Games
			idx, ok := coreIndex[core]
			if !ok {
				idx = len(merged.Cores)
				coreIndex[core] = idx
				merged.Cores = append(merged.Cores, CoreManifest{Core: core})
			}
			for _, game := range games {
				if len(sets) > 0 {
					found := false
					for _, set := range sets {
						if game.Setname == set {
							found = true
							matched[set] = true
							break
						}
					}
					if !found {
						continue
					}
				}
				fixtureDir := filepath.Join(workspace, "manual-fixtures", core, game.Setname)
				if err := os.MkdirAll(fixtureDir, 0750); err != nil {
					return Manifest{}, err
				}
				mapping := map[string]string{}
				for _, p := range append(append([]string(nil), game.ROMs...), game.ARC) {
					dst := filepath.Join(fixtureDir, filepath.Base(p))
					if err := copyFile(p, dst); err != nil {
						return Manifest{}, err
					}
					mapping[p] = dst
				}
				for i, p := range game.ROMs {
					if dst := mapping[p]; dst != "" {
						game.ROMs[i] = dst
					}
				}
				game.ARC = mapping[game.ARC]
				hashes := map[string]string{}
				for p, digest := range game.PreparedHashes {
					if dst := mapping[p]; dst != "" {
						hashes[dst] = digest
					} else {
						hashes[p] = digest
					}
				}
				game.PreparedHashes = hashes
				for p := range hashes {
					artifactIdentities[core+"/"+game.Setname+"/"+filepath.Base(p)] = p
				}
				merged.Cores[idx].Games = append(merged.Cores[idx].Games, game)
				matchedCores[core] = true
			}
		}
	}
	if err := requireManualCoreCoverage(cores, matchedCores, "manual"); err != nil {
		return Manifest{}, err
	}
	for _, set := range sets {
		if !matched[set] {
			return Manifest{}, fmt.Errorf("no eligible manual MRA matched requested setname %s", set)
		}
	}
	if len(merged.Cores) == 0 {
		return Manifest{}, fmt.Errorf("manual selection contains no games")
	}
	kept := merged.Cores[:0]
	for _, core := range merged.Cores {
		if len(core.Games) > 0 {
			kept = append(kept, core)
		}
	}
	merged.Cores = kept
	digest, hashErr := HashFiles(artifactIdentities)
	if hashErr != nil {
		return Manifest{}, hashErr
	}
	merged.Build.ArtifactSHA = digest
	merged.Build.SHA = ""
	return merged, nil
}

// preflightManualSelection discovers every requested core/set and applies
// current eligibility rules before any ROM conversion starts.
func preflightManualSelection(ctx context.Context, cfg Config, cores, sets []string, useJTBin bool) error {
	source, err := filepath.Abs(cfg.Source)
	if err != nil {
		return err
	}
	release := filepath.Join(source, "release")
	if useJTBin {
		release = os.Getenv("JTBIN")
		if release == "" {
			return fmt.Errorf("--jtbin requires JTBIN")
		}
	}
	var tuples []InventoryTuple
	for _, core := range cores {
		requests := []string{""}
		if len(sets) > 0 {
			requests = sets
		}
		for _, set := range requests {
			if !useJTBin {
				setArg := set
				script := `core_arg=$1; set_arg=$2; out_arg=$3; set --; source ./setprj.sh >/dev/null && export JTBIN="$out_arg" && if [ -n "$set_arg" ]; then jtframe mra --nodbg --git --skipROM --skipPocket --setname "$set_arg" "$core_arg"; else jtframe mra --nodbg --git --mainonly --skipROM --skipPocket "$core_arg"; fi`
				output, commandErr := manualCommand(ctx, source, "bash", "-c", script, "_", core, setArg, release)
				if commandErr != nil {
					return fmt.Errorf("manual MRA preflight for %s/%s: %w: %s", core, set, commandErr, strings.TrimSpace(string(output)))
				}
			}
			selected, selectErr := manualMRAs(filepath.Join(release, "mra"), core, set)
			if selectErr != nil {
				return selectErr
			}
			for _, path := range selected {
				if tuple, ok := readTuple(path); ok {
					tuples = append(tuples, tuple)
				}
			}
		}
	}
	if len(tuples) == 0 {
		return fmt.Errorf("manual selection contains no MRA games")
	}
	exclusions, err := sourceExclusions(source, tuples)
	if err != nil {
		return err
	}
	profileExclusions, err := profileSkipExclusions(source, tuples)
	if err != nil {
		return err
	}
	matchedCores, matchedSets := map[string]bool{}, map[string]bool{}
	for _, tuple := range tuples {
		reason := exclusions[tupleKey(tuple)]
		if reason == "" {
			reason = profileExclusions[tupleKey(tuple)]
		}
		if debugMRADirectory(filepath.Join(release, "mra"), filepath.Join(release, "mra", tuple.Setname+".mra")) {
			reason = "MRA is in a debug directory"
		}
		if reason == "" {
			matchedCores[tuple.Core] = true
			matchedSets[tuple.Setname] = true
		}
	}
	if err := requireManualCoreCoverage(cores, matchedCores, "manual"); err != nil {
		return err
	}
	for _, set := range sets {
		if !matchedSets[set] {
			return fmt.Errorf("no eligible manual MRA matched requested setname %s", set)
		}
	}
	return nil
}

func requireManualCoreCoverage(cores []string, matched map[string]bool, source string) error {
	for _, core := range cores {
		if !matched[core] {
			return fmt.Errorf("no eligible %s game matched requested core %s", source, core)
		}
	}
	return nil
}

var resolveManualGitCommit = func(ctx context.Context, source, prefix string) (string, error) {
	out, err := exec.CommandContext(ctx, "git", "-C", source, "rev-parse", "--verify", prefix+"^{commit}").Output()
	if err != nil {
		return "", err
	}
	commit := strings.TrimSpace(string(out))
	if len(commit) != 40 || !validHexCommit(commit) || !strings.HasPrefix(strings.ToLower(commit), strings.ToLower(prefix)) {
		return "", fmt.Errorf("git returned an invalid commit identity")
	}
	return strings.ToLower(commit), nil
}

// ResolveManualArchive resolves a user-supplied local commit and its build ZIP without network access.
func ResolveManualArchive(ctx context.Context, source, archiveRoot, requested string) (ManualArchive, error) {
	archive := ManualArchive{}
	if len(requested) < 7 || len(requested) > 40 || !validHexCommit(requested) {
		return archive, fmt.Errorf("--commit must be 7 to 40 hexadecimal characters")
	}
	requested = strings.ToLower(requested)
	commit := requested
	if len(requested) < 40 {
		resolved, resolveErr := resolveManualGitCommit(ctx, source, requested)
		if resolveErr == nil {
			commit = resolved
		} else {
			commit, resolveErr = full_archive_commit(archiveRoot, requested)
			if resolveErr != nil {
				return archive, fmt.Errorf("cannot resolve short commit %s locally; pass the full 40-character SHA: %w", requested, resolveErr)
			}
		}
	}
	filename, err := select_manual_archive(archiveRoot, commit)
	if err != nil {
		return archive, err
	}
	info, err := os.Lstat(filename)
	if err != nil {
		return archive, err
	}
	if info.Mode()&os.ModeSymlink != 0 || !info.Mode().IsRegular() || info.Size() == 0 {
		return archive, fmt.Errorf("manual build archive is not a nonempty regular file: %s", filename)
	}
	digest, err := fileSHA256(filename)
	if err != nil {
		return archive, err
	}
	return ManualArchive{Commit: commit, Path: filename, SHA256: digest}, nil
}

func validHexCommit(value string) bool {
	for _, c := range value {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f' || c >= 'A' && c <= 'F') {
			return false
		}
	}
	return value != ""
}

func full_archive_commit(root, prefix string) (string, error) {
	entries, err := os.ReadDir(root)
	if err != nil {
		return "", err
	}
	matches := map[string]bool{}
	for _, entry := range entries {
		stem := strings.TrimSuffix(entry.Name(), ".zip")
		if strings.HasSuffix(stem, "-sidi128") {
			stem = strings.TrimSuffix(stem, "-sidi128")
		}
		if len(stem) == 40 && validHexCommit(stem) && strings.HasPrefix(strings.ToLower(stem), prefix) {
			matches[strings.ToLower(stem)] = true
		}
	}
	if len(matches) != 1 {
		return "", fmt.Errorf("full-SHA archive basename matched %d commits", len(matches))
	}
	for commit := range matches {
		return commit, nil
	}
	return "", fmt.Errorf("no full-SHA archive basename matched")
}

func select_manual_archive(root, commit string) (string, error) {
	entries, err := os.ReadDir(root)
	if err != nil {
		return "", err
	}
	plain, sidi := []string{}, []string{}
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.HasSuffix(name, ".zip") {
			continue
		}
		stem := strings.TrimSuffix(name, ".zip")
		is_sidi := strings.HasSuffix(stem, "-sidi128")
		if is_sidi {
			stem = strings.TrimSuffix(stem, "-sidi128")
		}
		if len(stem) < 7 || len(stem) > 40 || !validHexCommit(stem) || !strings.HasPrefix(commit, strings.ToLower(stem)) {
			continue
		}
		if is_sidi {
			sidi = append(sidi, filepath.Join(root, name))
		} else {
			plain = append(plain, filepath.Join(root, name))
		}
	}
	candidates := plain
	if len(candidates) == 0 {
		candidates = sidi
	}
	if len(candidates) == 0 {
		return "", fmt.Errorf("no local build ZIP matches commit %s in %s", commit, root)
	}
	if len(candidates) != 1 {
		sort.Strings(candidates)
		return "", fmt.Errorf("ambiguous local build ZIPs for commit %s: %s", commit, strings.Join(candidates, ", "))
	}
	return candidates[0], nil
}

// ExtractManualArchive selects and stages only requested RBF/MRA fixtures outside release/.
func ExtractManualArchive(ctx context.Context, archive ManualArchive, workspace string, requestedCores, requestedSets []string) (ManualArchive, error) {
	result := archive
	before, err := fileSHA256(archive.Path)
	if err != nil {
		return result, err
	}
	if before != archive.SHA256 {
		return result, fmt.Errorf("manual build archive changed after selection")
	}
	z, err := zip.OpenReader(archive.Path)
	if err != nil {
		return result, err
	}
	defer z.Close()
	entries := make(map[string]*zip.File, len(z.File))
	var total uint64
	for _, file := range z.File {
		name := strings.TrimSuffix(file.Name, "/")
		if name == "" || strings.ContainsAny(name, "\\\x00") || path.Clean(name) != name || name != "release" && !strings.HasPrefix(name, "release/") || entries[name] != nil {
			return result, fmt.Errorf("unsafe or duplicate build archive path %q", file.Name)
		}
		if !file.Mode().IsRegular() && !file.FileInfo().IsDir() {
			return result, fmt.Errorf("unsupported build archive entry %q", file.Name)
		}
		entries[name] = file
		if !file.FileInfo().IsDir() {
			if file.UncompressedSize64 > 5<<30 || total > 5<<30-file.UncompressedSize64 {
				return result, fmt.Errorf("build archive exceeds 5 GiB unpacked limit")
			}
			total += file.UncompressedSize64
		}
	}
	rbfEntries := map[string]*zip.File{}
	for name, file := range entries {
		if !strings.HasPrefix(name, "release/sidi128/") || strings.Count(strings.TrimPrefix(name, "release/sidi128/"), "/") != 0 || !strings.HasPrefix(filepath.Base(name), "jt") || !strings.HasSuffix(name, ".rbf") {
			continue
		}
		core := strings.TrimSuffix(strings.TrimPrefix(filepath.Base(name), "jt"), ".rbf")
		if !manualComponent(core) {
			return result, fmt.Errorf("unsafe core in archive RBF %s", name)
		}
		if rbfEntries[core] != nil {
			return result, fmt.Errorf("duplicate archive RBF for %s", core)
		}
		rbfEntries[core] = file
	}
	cores := append([]string(nil), requestedCores...)
	if len(cores) == 0 {
		for core := range rbfEntries {
			cores = append(cores, core)
		}
	}
	sort.Strings(cores)
	coreSet := map[string]bool{}
	for _, core := range cores {
		if !manualComponent(core) {
			return result, fmt.Errorf("unsafe core %q", core)
		}
		if rbfEntries[core] == nil {
			return result, fmt.Errorf("archive has no SiDi128 RBF for requested core %s", core)
		}
		coreSet[core] = true
	}
	setSet := map[string]bool{}
	for _, set := range requestedSets {
		if !manualComponent(set) {
			return result, fmt.Errorf("unsafe setname %q", set)
		}
		setSet[set] = true
	}
	mraEntries := []archiveMRAEntry{}
	for name, file := range entries {
		if !strings.HasPrefix(name, "release/mra/") || !strings.EqualFold(filepath.Ext(name), ".mra") {
			continue
		}
		if len(requestedSets) == 0 && path.Dir(name) != "release/mra" {
			continue
		}
		if file.UncompressedSize64 > 64<<20 {
			return result, fmt.Errorf("archive MRA is too large: %s", name)
		}
		reader, openErr := file.Open()
		if openErr != nil {
			return result, openErr
		}
		data, readErr := io.ReadAll(io.LimitReader(reader, 64<<20+1))
		closeErr := reader.Close()
		if readErr != nil {
			return result, readErr
		}
		if closeErr != nil {
			return result, closeErr
		}
		if len(data) > 64<<20 {
			return result, fmt.Errorf("archive MRA exceeds size limit: %s", name)
		}
		var m mraInventory
		if err = xml.Unmarshal(data, &m); err != nil {
			return result, fmt.Errorf("decode archive MRA %s: %w", name, err)
		}
		if m.interlaced_video() { continue }
		core := strings.TrimPrefix(strings.TrimSpace(m.RBF), "jt")
		set := strings.TrimSpace(m.Setname)
		if !strings.HasPrefix(strings.TrimSpace(m.RBF), "jt") || !manualComponent(core) || !manualComponent(set) {
			return result, fmt.Errorf("invalid core/setname in archive MRA %s", name)
		}
		if !coreSet[core] || len(requestedSets) > 0 && !setSet[set] {
			continue
		}
		mraEntries = append(mraEntries, archiveMRAEntry{file: file, path: name, tuple: InventoryTuple{Core: core, Setname: set, RBF: strings.TrimSpace(m.RBF)}})
	}
	sort.Slice(mraEntries, func(i, j int) bool {
		if mraEntries[i].tuple.Core != mraEntries[j].tuple.Core {
			return mraEntries[i].tuple.Core < mraEntries[j].tuple.Core
		}
		if mraEntries[i].tuple.Setname != mraEntries[j].tuple.Setname {
			return mraEntries[i].tuple.Setname < mraEntries[j].tuple.Setname
		}
		return mraEntries[i].path < mraEntries[j].path
	})
	seenPairs, matchedSets, matchedCores := map[string]bool{}, map[string]bool{}, map[string]bool{}
	for _, candidate := range mraEntries {
		key := tupleKey(candidate.tuple)
		if seenPairs[key] {
			return result, fmt.Errorf("duplicate selected archive MRA tuple %s/%s", candidate.tuple.Core, candidate.tuple.Setname)
		}
		seenPairs[key], matchedSets[candidate.tuple.Setname], matchedCores[candidate.tuple.Core] = true, true, true
	}
	if len(requestedCores) > 0 {
		for _, core := range cores {
			if !matchedCores[core] {
				return result, fmt.Errorf("no archive MRA matched requested core %s", core)
			}
		}
	}
	for _, set := range requestedSets {
		if !matchedSets[set] {
			return result, fmt.Errorf("no archive MRA matched requested setname %s", set)
		}
	}
	if len(mraEntries) == 0 {
		return result, fmt.Errorf("archive selection contains no main-game MRAs")
	}
	selectedCores := make([]string, 0, len(matchedCores))
	for core := range matchedCores {
		selectedCores = append(selectedCores, core)
	}
	sort.Strings(selectedCores)
	stageRoot := filepath.Join(workspace, "archive-release")
	selectedFiles := make([]*zip.File, 0, len(selectedCores)+len(mraEntries))
	for _, core := range selectedCores {
		file := rbfEntries[core]
		if file.UncompressedSize64 == 0 {
			return result, fmt.Errorf("empty archive SiDi128 RBF for %s", core)
		}
		selectedFiles = append(selectedFiles, file)
	}
	for _, item := range mraEntries {
		selectedFiles = append(selectedFiles, item.file)
	}
	for _, file := range selectedFiles {
		name := strings.TrimSuffix(file.Name, "/")
		relative := strings.TrimPrefix(name, "release/")
		destination := filepath.Join(stageRoot, filepath.FromSlash(relative))
		if err = os.MkdirAll(filepath.Dir(destination), 0750); err != nil {
			return result, err
		}
		if err = extract_build_file(file, destination); err != nil {
			return result, err
		}
	}
	after, err := fileSHA256(archive.Path)
	if err != nil {
		return result, err
	}
	if after != archive.SHA256 {
		return result, fmt.Errorf("manual build archive changed during extraction")
	}
	result.ReleaseRoot, result.Cores, result.Games = stageRoot, selectedCores, make([]InventoryTuple, 0, len(mraEntries))
	for _, item := range mraEntries {
		result.Games = append(result.Games, item.tuple)
	}
	return result, nil
}
