/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

var manualCommand = func(ctx context.Context, source string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	cmd.Dir = source
	return cmd.CombinedOutput()
}

// PrepareManual selects only the requested core/set before generating ROMs.
// It never discovers Actions builds. RBF bytes and MRA bytes, rather than an
// inferred compile_all run, establish the identity of a manual session.
func PrepareManual(ctx context.Context, cfg Config, dataRoot, core, setname string, useJTBin bool) (Manifest, error) {
	if !manualComponent(core) || setname != "" && !manualComponent(setname) {
		return Manifest{}, fmt.Errorf("manual core and setname must be simple names")
	}
	if cfg.Source == "" || dataRoot == "" {
		return Manifest{}, fmt.Errorf("working project and regression root are required")
	}
	if ctx == nil {
		ctx = context.Background()
	}
	timeout := cfg.TimeoutSeconds
	if timeout <= 0 {
		timeout = 900
	}
	ctx, cancel := context.WithTimeout(ctx, time.Duration(timeout)*time.Second)
	defer cancel()
	source, err := filepath.Abs(cfg.Source)
	if err != nil {
		return Manifest{}, err
	}
	release := filepath.Join(source, "release")
	mode := "local"
	if useJTBin {
		release = os.Getenv("JTBIN")
		if release == "" {
			return Manifest{}, fmt.Errorf("--jtbin requires JTBIN")
		}
		release, err = filepath.Abs(release)
		if err != nil {
			return Manifest{}, err
		}
		mode = "jtbin"
	} else if !regularNonempty(filepath.Join(source, "cores", core, "cfg", "mame2mra.toml")) {
		return Manifest{}, fmt.Errorf("unknown project core %s", core)
	}
	if setname != "" {
		requested := InventoryTuple{Core: core, Setname: setname, RBF: "jt" + core}
		exclusions, classifyErr := sourceExclusions(source, []InventoryTuple{requested})
		if classifyErr != nil {
			return Manifest{}, classifyErr
		}
		if reason := exclusions[tupleKey(requested)]; reason != "" {
			return Manifest{}, fmt.Errorf("%s/%s is not regression eligible: %s", core, setname, reason)
		}
	}
	// Reject unavailable binaries before spending time on MRA or ROM preparation.
	rbf := filepath.Join(release, "sidi128", "jt"+core+".rbf")
	if !regularNonempty(rbf) {
		return Manifest{}, fmt.Errorf("manual SiDi128 RBF is missing or empty: %s", rbf)
	}
	var nonce [6]byte
	if _, err = rand.Read(nonce[:]); err != nil {
		return Manifest{}, err
	}
	runID := "manual-" + mode + "-" + core + "-" + time.Now().UTC().Format("20060102T150405") + "-" + hex.EncodeToString(nonce[:])
	cache := filepath.Join(source, ".cache", "jtutil-regression", "manual", runID)
	if err = os.MkdirAll(cache, 0750); err != nil {
		return Manifest{}, err
	}
	inputRBF := rbf
	rbf = filepath.Join(cache, "rbf", filepath.Base(inputRBF))
	if err = os.MkdirAll(filepath.Dir(rbf), 0750); err != nil {
		return Manifest{}, err
	}
	if err = copyFile(inputRBF, rbf); err != nil {
		return Manifest{}, err
	}
	mraRoot := filepath.Join(release, "mra")
	if !useJTBin {
		outputRoot := filepath.Join(cache, "source-release")
		if err = os.MkdirAll(outputRoot, 0750); err != nil {
			return Manifest{}, err
		}
		// --git directs the normal generator to an isolated project-cache release;
		// only the requested core is parsed, and an explicit set may be a clone.
		script := `core_arg=$1; set_arg=$2; out_arg=$3; set --; source ./setprj.sh >/dev/null && export JTBIN="$out_arg" && if [ -n "$set_arg" ]; then jtframe mra --nodbg --git --skipROM --skipPocket --setname "$set_arg" "$core_arg"; else jtframe mra --nodbg --git --mainonly --skipROM --skipPocket "$core_arg"; fi`
		output, commandErr := manualCommand(ctx, source, "bash", "-c", script, "_", core, setname, outputRoot)
		if err = os.WriteFile(filepath.Join(cache, "mra-generation.log"), output, 0640); err != nil {
			return Manifest{}, err
		}
		if commandErr != nil {
			diagnostic := fmt.Sprintf("%v: %s", commandErr, strings.TrimSpace(string(output)))
			if _, ok := reviewedMRAExit(core, diagnostic); !ok {
				return Manifest{}, fmt.Errorf("manual MRA generation: %s", diagnostic)
			}
		}
		mraRoot = filepath.Join(outputRoot, "mra")
	}
	selected, err := manualMRAs(mraRoot, core, setname)
	if err != nil {
		return Manifest{}, err
	}
	manualTuples := make([]InventoryTuple, 0, len(selected))
	for _, path := range selected {
		if tuple, ok := readTuple(path); ok {
			manualTuples = append(manualTuples, tuple)
		}
	}
	exclusions, err := sourceExclusions(source, manualTuples)
	if err != nil {
		return Manifest{}, err
	}
	eligible := selected[:0]
	for _, path := range selected {
		tuple, _ := readTuple(path)
		reason := exclusions[tupleKey(tuple)]
		if debugMRADirectory(mraRoot, path) {
			reason = "MRA is in a debug directory"
		}
		if reason != "" {
			if setname != "" {
				return Manifest{}, fmt.Errorf("%s/%s is not regression eligible: %s", core, setname, reason)
			}
			continue
		}
		eligible = append(eligible, path)
	}
	selected = eligible
	if len(selected) == 0 {
		return Manifest{}, fmt.Errorf("no MRA for manual selection core=%s setname=%s in %s", core, setname, mraRoot)
	}
	if cfg.GlobalProfile == "" {
		cfg.GlobalProfile = filepath.Join(source, "modules", "jtframe", "bin", "reg.yaml")
	}
	romSource := cfg.ROMSource
	if romSource == "" {
		romSource = filepath.Join(os.Getenv("HOME"), ".mame", "roms")
	}
	converter := cfg.MRAConverter
	if converter == "" {
		converter = "mra"
	}
	projectSHA, _ := gitHead(ctx, source)
	releaseSHA, _ := gitHead(ctx, release)
	identities := map[string]string{"rbf/" + filepath.Base(rbf): rbf}
	cm := CoreManifest{Core: core}
	records := []map[string]any{}
	for _, path := range selected {
		raw, readErr := os.ReadFile(path)
		if readErr != nil {
			return Manifest{}, readErr
		}
		var m mraInventory
		if err = xml.Unmarshal(raw, &m); err != nil {
			return Manifest{}, err
		}
		set := strings.TrimSpace(m.Setname)
		folder := filepath.Join(cache, "fixtures", set)
		if err = os.MkdirAll(folder, 0750); err != nil {
			return Manifest{}, err
		}
		fixtureMRA := filepath.Join(folder, filepath.Base(path))
		if err = os.WriteFile(fixtureMRA, raw, 0640); err != nil {
			return Manifest{}, err
		}
		identities["mra/"+set] = fixtureMRA
		profile, profileErr := ResolveProfile(cfg.GlobalProfile, source, core, set)
		if profileErr != nil {
			return Manifest{}, profileErr
		}
		game := GameSpec{Setname: set, RBF: rbf, Profile: profile}
		// Convert exactly the selected MRA, including when it came from JTBIN.
		// Mra2rom writes the normal project rom/ outputs, including RAM defaults.
		for _, outputPath := range []string{filepath.Join(source, "rom", set+".rom"), filepath.Join(source, "rom", strings.ToUpper(set)+".RAM")} {
			if err = os.Remove(outputPath); err != nil && !os.IsNotExist(err) {
				return Manifest{}, err
			}
		}
		output, commandErr := manualCommand(ctx, source, "bash", "-c", `mra_arg=$1; rom_arg=$2; set --; source ./setprj.sh >/dev/null && jtframe mra2rom --path "$rom_arg" "$mra_arg"`, "_", fixtureMRA, romSource)
		if err = os.WriteFile(filepath.Join(folder, "rom-generation.log"), output, 0640); err != nil {
			return Manifest{}, err
		}
		if commandErr != nil {
			return Manifest{}, fmt.Errorf("manual ROM generation for %s: %w: %s", set, commandErr, strings.TrimSpace(string(output)))
		}
		for _, romSpec := range m.ROM {
			if romSpec.Index != "0" {
				continue
			}
			from := filepath.Join(source, "rom", set+".rom")
			if !regularNonempty(from) {
				return Manifest{}, fmt.Errorf("manual generation did not produce %s", from)
			}
			dest := filepath.Join(source, "rom", ".regression", runID, core, set+".rom")
			if err = os.MkdirAll(filepath.Dir(dest), 0750); err != nil {
				return Manifest{}, err
			}
			if err = copyFile(from, dest); err != nil {
				return Manifest{}, err
			}
			game.ROMs = append(game.ROMs, dest)
			break
		}
		ram, ramErr := generatedNVRAM(source, fixtureMRA, set)
		if ramErr != nil {
			return Manifest{}, ramErr
		}
		if ram != "" {
			dest := filepath.Join(source, "rom", ".regression", runID, core, filepath.Base(ram))
			if err = os.MkdirAll(filepath.Dir(dest), 0750); err != nil {
				return Manifest{}, err
			}
			if err = copyFile(ram, dest); err != nil {
				return Manifest{}, err
			}
			game.ROMs = append(game.ROMs, dest)
		}
		game.ARC = filepath.Join(folder, set+".arc")
		output, commandErr = manualCommand(ctx, source, converter, "-s", "-A", "-a", game.ARC, fixtureMRA)
		if commandErr != nil {
			return Manifest{}, fmt.Errorf("manual ARC conversion for %s: %w: %s", set, commandErr, strings.TrimSpace(string(output)))
		}
		if !regularNonempty(game.ARC) {
			return Manifest{}, fmt.Errorf("manual ARC converter did not produce %s", game.ARC)
		}
		if profile.Inputs != "" {
			game.CAB = filepath.Join(source, "cores", core, "ver", set, profile.Inputs)
			if !regularNonempty(game.CAB) {
				return Manifest{}, fmt.Errorf("configured CAB unavailable: %s", game.CAB)
			}
		}
		fixtures := map[string]string{"mra": fixtureMRA, "arc": game.ARC, "rbf": rbf}
		for _, p := range game.ROMs {
			fixtures[filepath.Base(p)] = p
		}
		hashes := map[string]string{}
		for name, p := range fixtures {
			h, e := FileSHA256(p)
			if e != nil {
				return Manifest{}, e
			}
			hashes[name] = h
		}
		records = append(records, map[string]any{"setname": set, "selected_mra": path, "snapshot_mra": fixtureMRA, "fixture_sha256": hashes})
		cm.Games = append(cm.Games, game)
	}
	identityHash, err := HashFiles(identities)
	if err != nil {
		return Manifest{}, err
	}
	build := BuildIdentity{Repository: cfg.Repository, Workflow: "manual", RunID: runID, Attempt: "1", SHA: "", Ref: release, Event: "manual-" + mode, Artifact: release, ArtifactSHA: identityHash, Conclusion: "manual"}
	manifest := Manifest{RunID: runID, Build: build, Source: source, ProjectSHA: projectSHA, Cores: []CoreManifest{cm}}
	evidence := map[string]any{"schema": 1, "mode": mode, "run_id": runID, "project_sha": projectSHA, "release_checkout_sha": releaseSHA, "selected_rbf": inputRBF, "snapshot_rbf": rbf, "binary_source_commit": "not inferred; RBF content hash is authoritative", "games": records}
	data, _ := json.MarshalIndent(evidence, "", "  ")
	if err = os.WriteFile(filepath.Join(cache, "manual-preparation.json"), append(data, '\n'), 0640); err != nil {
		return Manifest{}, err
	}
	return manifest, nil
}

func manualComponent(name string) bool {
	if name == "" || name == "." || name == ".." {
		return false
	}
	for _, c := range name {
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') {
			return false
		}
	}
	return true
}

// Root MRAs represent main games. Alternatives are searched only for an
// explicitly selected set, preventing clone expansion in whole-core sessions.
func manualMRAs(root, core, set string) ([]string, error) {
	bySet := map[string]string{}
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if d.IsDir() {
			if path != root && set == "" {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.EqualFold(filepath.Ext(path), ".mra") {
			return nil
		}
		tuple, ok := readTuple(path)
		if !ok || tuple.Core != core || set != "" && tuple.Setname != set {
			return nil
		}
		if !manualComponent(tuple.Setname) {
			return fmt.Errorf("unsafe MRA setname %q", tuple.Setname)
		}
		if previous, exists := bySet[tuple.Setname]; exists {
			return fmt.Errorf("ambiguous MRA for %s: %s and %s", tuple.Setname, previous, path)
		}
		bySet[tuple.Setname] = path
		return nil
	})
	if err != nil {
		return nil, err
	}
	names := make([]string, 0, len(bySet))
	for s := range bySet {
		names = append(names, s)
	}
	sort.Strings(names)
	paths := make([]string, 0, len(names))
	for _, s := range names {
		paths = append(paths, bySet[s])
	}
	return paths, nil
}
