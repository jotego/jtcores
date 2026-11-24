/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"context"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"image/png"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

type MameFrameResult struct {
	Core, Setname, Verdict, Detail string
}

type MameFrameOptions struct {
	Target          string
	LegacySiDi128   bool
	Generation      string
	QualificationID string
}

type mame_candidate struct {
	core, set, dir, digest string
	target                 string
	legacy_sidi128         bool
	generation             string
	qualification_id       string
	mister_provenance      *MiSTerReferenceProvenance
	profile                Profile
	cab_source             string
	cab_digest             string
	progress_path          string
	preflight_error        string
	promotion_error        string
	frames                 CaptureSet
}

type mame_frame_outcome struct {
	index  int
	result MameFrameResult
}

// RunMameFrames checks finalized new captures independently while hardware
// regression may continue to process other games.
func RunMameFrames(ctx context.Context, root, source, setname string, dryrun bool, jobs int, global_profile string, options MameFrameOptions) ([]MameFrameResult, error) {
	if jobs < 1 {
		return nil, fmt.Errorf("jobs must be positive")
	}
	if options.Target == "" {
		options.Target = "sidi128"
	}
	if options.Target != "sidi128" && options.Target != "mister" {
		return nil, fmt.Errorf("mame-frames target must be sidi128 or mister")
	}
	if options.Target == "mister" && options.LegacySiDi128 {
		return nil, fmt.Errorf("--legacy-sidi128 cannot be combined with target=mister")
	}
	if options.Target == "mister" && (options.Generation == "" || options.QualificationID == "") {
		return nil, fmt.Errorf("MiSTer MAME validation requires capture generation and qualification ID")
	}
	selected, err := parse_mame_setnames(setname)
	if err != nil {
		return nil, err
	}
	if !dryrun {
		if options.Target == "sidi128" && !options.LegacySiDi128 {
			return nil, fmt.Errorf("writing legacy SiDi128 MAME results requires --legacy-sidi128")
		}
		if err := guardMameArchiveForWrite(root, options.Target); err != nil {
			return nil, err
		}
	} else if target, present, err := ReadCaptureTarget(root); err != nil {
		return nil, err
	} else if present && target != options.Target {
		return nil, fmt.Errorf("regression archive belongs to target=%s, requested target=%s", target, options.Target)
	}
	candidates, err := discover_mame_candidates(root, source, selected)
	if err != nil {
		return nil, err
	}
	for requested := range selected {
		count := 0
		for _, candidate := range candidates {
			if candidate.set == requested {
				count++
			}
		}
		if count > 1 {
			return nil, fmt.Errorf("setname %s is ambiguous across %d core folders", requested, count)
		}
		if count == 0 && len(selected) > 1 {
			return nil, fmt.Errorf("setname %s was not found", requested)
		}
	}
	if len(candidates) == 0 {
		return nil, nil
	}
	if global_profile == "" {
		global_profile = filepath.Join(source, "modules", "jtframe", "bin", "reg.yaml")
	}
	needs_cab_exporter := false
	for i := range candidates {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		candidate := &candidates[i]
		candidate.target = options.Target
		candidate.legacy_sidi128 = options.LegacySiDi128
		candidate.generation = options.Generation
		candidate.qualification_id = options.QualificationID
		if options.Target == "mister" {
			is_mister, provenance, progress_path, provenance_err := findMiSTerMameProvenance(root, candidate.core, candidate.set, candidate.dir, candidate.frames, options.Generation, options.QualificationID)
			if provenance_err != nil {
				candidate.promotion_error = provenance_err.Error()
			} else if !is_mister {
				candidate.promotion_error = "no completed MiSTer capture provenance matches this candidate"
			} else {
				candidate.promotion_error = ""
				candidate.mister_provenance = provenance
				candidate.progress_path = progress_path
			}
		} else if is_mister, provenance_err := journaledMiSTerNewCapture(root, candidate.core, candidate.set, candidate.dir, candidate.frames); provenance_err != nil {
			candidate.promotion_error = appendMamePromotionError(candidate.promotion_error, provenance_err.Error())
		} else if is_mister {
			candidate.promotion_error = appendMamePromotionError(candidate.promotion_error, "MiSTer result cannot be written through the legacy SiDi128 path")
		} else if candidate.promotion_error == "" {
			candidate.progress_path, err = matching_mame_progress(root, candidate.core, candidate.set, candidate.digest)
			if err != nil {
				candidate.promotion_error = err.Error()
			}
		}
		if candidate.preflight_error != "" {
			continue
		}
		if profileErr := resolve_mame_candidate_profile(source, global_profile, candidate); profileErr != nil {
			candidate.preflight_error = fmt.Sprintf("regression profile: %v", profileErr)
			continue
		}
		_, has_dipsw := candidate.profile.Options["dipsw"]
		needs_cab_exporter = needs_cab_exporter || candidate.cab_source != "" || has_dipsw
	}
	cab_packer := ""
	if needs_cab_exporter {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		cab_packer, err = build_mame_cab_packer(ctx, source)
		if err != nil {
			return nil, err
		}
	}
	mame, mame_err := exec.LookPath("mame")
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	rompath := filepath.Join(home, ".mame", "roms")
	precisions := make([]int, len(candidates))
	precision_errors := make([]error, len(candidates))
	commit_views := map[string]*SourceCommitView{}
	defer func() {
		for _, view := range commit_views {
			_ = view.Close()
		}
	}()
	for i, candidate := range candidates {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		if candidate.preflight_error == "" && mame_err == nil {
			if options.Target == "mister" && candidate.mister_provenance != nil {
				commit := candidate.mister_provenance.SourceCommit
				view := commit_views[commit]
				if view == nil {
					var viewErr error
					view, viewErr = OpenSourceCommitView(ctx, source, commit)
					if viewErr == nil {
						commit_views[commit] = view
					}
					if viewErr != nil {
						precision_errors[i] = viewErr
						continue
					}
				}
				precisions[i], precision_errors[i] = mame_capture_precision(view.Root, candidate.core, options.Target)
				continue
			}
			if options.Target == "mister" && candidate.mister_provenance == nil {
				precision_errors[i] = fmt.Errorf("MiSTer capture candidate has no workflow source commit")
				continue
			}
			if options.Target != "mister" {
				precisions[i], precision_errors[i] = mame_capture_precision(source, candidate.core, options.Target)
			}
		}
	}
	if jobs > len(candidates) {
		jobs = len(candidates)
	}
	if jobs == 0 {
		return nil, nil
	}
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	completed := start_mame_candidate_workers(ctx, jobs, candidates, func(ctx context.Context, index int, candidate mame_candidate) MameFrameResult {
		result := MameFrameResult{Core: candidate.core, Setname: candidate.set, Verdict: "FAIL"}
		detail := ""
		var checkErr error
		if candidate.preflight_error != "" {
			checkErr = fmt.Errorf("%s", candidate.preflight_error)
		} else if mame_err != nil {
			checkErr = fmt.Errorf("MAME executable not found in PATH: %w", mame_err)
		} else if precision_errors[index] != nil {
			checkErr = precision_errors[index]
		} else {
			detail, checkErr = validate_mame_candidate(ctx, candidate, root, source, mame, rompath, cab_packer, true, precisions[index])
		}
		if checkErr != nil {
			result.Detail = compact_mame_error(checkErr.Error())
		} else {
			result.Verdict, result.Detail = "PASS", detail
		}
		return result
	})
	committed := make([]MameFrameResult, len(candidates))
	var runErr error
	done := ctx.Done()
	for completed != nil {
		select {
		case <-done:
			if runErr == nil {
				runErr = ctx.Err()
			}
			done = nil
		case item, ok := <-completed:
			if !ok {
				completed = nil
				continue
			}
			if runErr != nil || ctx.Err() != nil {
				if runErr == nil {
					runErr = ctx.Err()
				}
				continue
			}
			result := item.result
			candidate := candidates[item.index]
			if result.Verdict == "PASS" && !dryrun {
				if candidate.promotion_error != "" {
					result.Detail += "; ref not promoted: " + compact_mame_error(candidate.promotion_error)
				} else if err := promote_mame_candidate(root, candidate); err != nil {
					result.Detail += "; ref not promoted: " + compact_mame_error(err.Error())
				}
			}
			if !dryrun {
				if err := append_mame_frames_log(root, options.Target, result); err != nil {
					runErr = err
					cancel()
					done = nil
					break
				}
			}
			committed[item.index] = result
		}
	}
	if runErr == nil && ctx.Err() != nil {
		runErr = ctx.Err()
	}
	results := make([]MameFrameResult, 0, len(candidates))
	for _, result := range committed {
		if result.Setname != "" {
			results = append(results, result)
		}
	}
	if runErr != nil {
		return results, runErr
	}
	return results, nil
}

func guardMameArchiveForWrite(root, target string) error {
	lock, err := AcquireLock(root)
	if err != nil {
		return fmt.Errorf("cannot acquire regression lock for MAME archive guard: %w", err)
	}
	defer ReleaseLock(lock)
	return GuardCaptureTarget(root, target)
}

func resolve_mame_candidate_profile(source, global_profile string, candidate *mame_candidate) error {
	profile, err := ResolveProfile(global_profile, source, candidate.core, candidate.set)
	if err != nil {
		return err
	}
	candidate.profile = profile
	if profile.Inputs == "" {
		return nil
	}
	candidate.cab_source = filepath.Clean(filepath.Join(source, "cores", candidate.core, "ver", candidate.set, profile.Inputs))
	if !regularNonempty(candidate.cab_source) {
		return fmt.Errorf("configured CAB input %q is unavailable", profile.Inputs)
	}
	candidate.cab_digest, err = file_sha256(candidate.cab_source)
	if err != nil {
		return fmt.Errorf("hash configured CAB input: %w", err)
	}
	return nil
}

func start_mame_candidate_workers(ctx context.Context, jobs int, candidates []mame_candidate, validate func(context.Context, int, mame_candidate) MameFrameResult) <-chan mame_frame_outcome {
	type task struct {
		index     int
		candidate mame_candidate
	}
	queue := make(chan task, jobs)
	completed := make(chan mame_frame_outcome, jobs)
	var workers sync.WaitGroup
	for i := 0; i < jobs; i++ {
		workers.Add(1)
		go func() {
			defer workers.Done()
			for work := range queue {
				if ctx.Err() != nil {
					continue
				}
				completed <- mame_frame_outcome{index: work.index, result: validate(ctx, work.index, work.candidate)}
			}
		}()
	}
	go func() {
		defer close(queue)
		for i, candidate := range candidates {
			select {
			case <-ctx.Done():
				return
			case queue <- task{index: i, candidate: candidate}:
			}
		}
	}()
	go func() { workers.Wait(); close(completed) }()
	return completed
}

func parse_mame_setnames(value string) (map[string]bool, error) {
	selected := make(map[string]bool)
	if value == "" {
		return selected, nil
	}
	for _, set := range strings.Split(value, ",") {
		set = strings.TrimSpace(set)
		if !safeComponent(set) {
			return nil, fmt.Errorf("unsafe or empty setname %q", set)
		}
		if selected[set] {
			return nil, fmt.Errorf("duplicate setname %s", set)
		}
		selected[set] = true
	}
	return selected, nil
}

func discover_mame_candidates(root, source string, selected map[string]bool) ([]mame_candidate, error) {
	_ = source
	cores, err := os.ReadDir(root)
	if err != nil {
		return nil, err
	}
	var candidates []mame_candidate
	for _, core_entry := range cores {
		core := core_entry.Name()
		if !core_entry.IsDir() || !safeComponent(core) || core == "log" {
			continue
		}
		games, err := os.ReadDir(filepath.Join(root, core))
		if err != nil {
			return nil, err
		}
		for _, game_entry := range games {
			set := game_entry.Name()
			if !game_entry.IsDir() || !safeComponent(set) || len(selected) > 0 && !selected[set] {
				continue
			}
			game_root := filepath.Join(root, core, set)
			new_dir, ref_dir := filepath.Join(game_root, "new"), filepath.Join(game_root, "ref")
			if _, err = os.Lstat(new_dir); os.IsNotExist(err) {
				continue
			} else if err != nil {
				return nil, err
			}
			candidate := mame_candidate{core: core, set: set, dir: new_dir}
			if info, statErr := os.Lstat(new_dir); statErr != nil || !info.IsDir() {
				candidate.preflight_error = "new capture path is not a regular directory"
				candidates = append(candidates, candidate)
				continue
			}
			if _, err = os.Lstat(ref_dir); err == nil {
				candidate.preflight_error = "ref already exists; leaving new untouched"
			} else if !os.IsNotExist(err) {
				candidate.preflight_error = fmt.Sprintf("cannot inspect ref: %v", err)
			}
			frames, err := read_published_mame_frames(new_dir)
			if err != nil {
				candidate.preflight_error = fmt.Sprintf("invalid published capture set: %v", err)
				candidates = append(candidates, candidate)
				continue
			}
			candidate.frames = frames
			digest, err := result_slot_digest(new_dir)
			if err != nil {
				candidate.preflight_error = fmt.Sprintf("cannot hash candidate capture: %v", err)
				candidates = append(candidates, candidate)
				continue
			}
			candidate.digest = digest
			progress_path, progress_err := matching_mame_progress(root, core, set, digest)
			if progress_err != nil {
				candidate.promotion_error = progress_err.Error()
			} else {
				candidate.progress_path = progress_path
			}
			candidates = append(candidates, candidate)
		}
	}
	sort.Slice(candidates, func(i, j int) bool {
		if candidates[i].core == candidates[j].core {
			return candidates[i].set < candidates[j].set
		}
		return candidates[i].core < candidates[j].core
	})
	return candidates, nil
}

func read_published_mame_frames(dir string) (CaptureSet, error) {
	set := CaptureSet{Dir: dir, Format: "png"}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return set, err
	}
	for _, entry := range entries {
		if !strings.EqualFold(filepath.Ext(entry.Name()), ".png") {
			return set, fmt.Errorf("unexpected entry %s", entry.Name())
		}
		info, statErr := os.Lstat(filepath.Join(dir, entry.Name()))
		if statErr != nil || !info.Mode().IsRegular() {
			return set, fmt.Errorf("capture %s is not a regular file", entry.Name())
		}
		requested, actual, parseErr := parse_png_capture_name(entry.Name())
		if parseErr != nil {
			return set, fmt.Errorf("unexpected PNG %s", entry.Name())
		}
		if requested <= 0 || actual < 1 || requested%100 != 0 {
			return set, fmt.Errorf("invalid regression checkpoint %s", entry.Name())
		}
		set.Captures = append(set.Captures, CaptureRecord{Type: "capture", Requested: requested, Actual: actual, Image: entry.Name()})
	}
	if len(set.Captures) == 0 {
		return set, fmt.Errorf("no published PNG frames")
	}
	sort.Slice(set.Captures, func(i, j int) bool { return set.Captures[i].Requested < set.Captures[j].Requested })
	cadence := 0
	for i, capture := range set.Captures {
		if i > 0 {
			delta := capture.Requested - set.Captures[i-1].Requested
			if delta != 100 || cadence != 0 && delta != cadence {
				return set, fmt.Errorf("published frame schedule is duplicate or irregular")
			}
			cadence = delta
		}
		decoded, decodeErr := decode_capture_image(filepath.Join(dir, capture.Image))
		if decodeErr != nil {
			return set, decodeErr
		}
		if set.Width == 0 {
			set.Width, set.Height = decoded.width, decoded.height
		} else if decoded.width != set.Width || decoded.height != set.Height {
			return set, fmt.Errorf("published frame geometry changed")
		}
	}
	return set, nil
}

func result_slot_digest(dir string) (string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return "", err
	}
	files := make(map[string]string)
	for _, entry := range entries {
		if entry.IsDir() || strings.EqualFold(filepath.Ext(entry.Name()), ".png") == false {
			continue
		}
		files[entry.Name()] = filepath.Join(dir, entry.Name())
	}
	if len(files) == 0 {
		return "", fmt.Errorf("no PNGs in %s", dir)
	}
	return HashFiles(files)
}

func matching_mame_progress(root, core, set, digest string) (string, error) {
	entries, err := os.ReadDir(filepath.Join(root, "log"))
	if err != nil {
		return "", fmt.Errorf("cannot read regression progress: %w", err)
	}
	game_key := core + "/" + set
	active := false
	type progress_match struct {
		path    string
		updated time.Time
	}
	var matches []progress_match
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" || !mame_progress_filename(entry.Name()) {
			continue
		}
		path := filepath.Join(root, "log", entry.Name())
		progress, err := read_mame_progress(root, path)
		if err != nil {
			return "", fmt.Errorf("cannot verify regression progress %s: %w", entry.Name(), err)
		}
		if progress.Current == game_key {
			active = true
		}
		game, ok := progress.Games[game_key]
		if ok && game.Result == New && game.Output == digest {
			matches = append(matches, progress_match{path, progress.Updated})
		}
	}
	if active {
		return "", fmt.Errorf("game is active in a regression run; deferred")
	}
	if len(matches) == 0 {
		return "", fmt.Errorf("no finalized progress entry matches this new capture digest")
	}
	sort.Slice(matches, func(i, j int) bool { return matches[i].updated.After(matches[j].updated) })
	return matches[0].path, nil
}

func mame_progress_filename(name string) bool {
	if filepath.Ext(name) != ".json" {
		return false
	}
	key := strings.TrimSuffix(name, ".json")
	key = strings.TrimSuffix(key, "-dirty")
	if len(key) != 7 && len(key) != 40 {
		return false
	}
	for _, r := range key {
		if !(r >= '0' && r <= '9' || r >= 'a' && r <= 'f') {
			return false
		}
	}
	return true
}

func read_mame_progress(root, path string) (*Progress, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var identity Progress
	if err = json.Unmarshal(data, &identity); err != nil {
		return nil, err
	}
	if len(identity.Commit) != 40 {
		return nil, fmt.Errorf("progress commit identity is invalid")
	}
	key := identity.Commit
	if identity.Dirty {
		key += "-dirty"
	}
	short_name := LogKey(identity.Commit, identity.Dirty) + ".json"
	full_name := key + ".json"
	if filepath.Base(path) != short_name && filepath.Base(path) != full_name {
		return nil, fmt.Errorf("progress filename does not match its commit identity")
	}
	return ReadProgress(root, key)
}

func validate_mame_candidate(ctx context.Context, candidate mame_candidate, root, source, mame, rompath, cab_packer string, dryrun bool, capture_bits int) (string, error) {
	if err := validate_published_capture_precision(candidate.frames, capture_bits); err != nil {
		return "", err
	}
	if err := check_mame_progress(root, candidate); err != nil {
		return "", err
	}
	work, err := os.MkdirTemp("/tmp", "jtutil-mame-frames-")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(work)
	cab_script, err := prepare_mame_cab(ctx, candidate, cab_packer, work)
	if err != nil {
		return "", err
	}
	fpga_dir := filepath.Join(work, "fpga")
	if err = copy_mame_frames(candidate, fpga_dir); err != nil {
		return "", err
	}
	if digest, e := result_slot_digest(candidate.dir); e != nil || digest != candidate.digest {
		return "", fmt.Errorf("new capture changed while being snapshotted")
	}
	quality, ocr_failure, _, err := captureQualityContext(ctx, candidate.frames, 0)
	if err != nil {
		return "", err
	}
	if quality != "" {
		return "", fmt.Errorf("capture quality check: %s", quality)
	}
	if ocr_failure != "" {
		return "", fmt.Errorf("capture quality check: %s", ocr_failure)
	}
	max_frame := 0
	for _, capture := range candidate.frames.Captures {
		if capture.Requested > max_frame {
			max_frame = capture.Requested
		}
		if capture.Actual > max_frame {
			max_frame = capture.Actual
		}
	}
	for _, dir := range []string{"cfg", "snapshots", "input", "state", "diff", "ini"} {
		if err = os.MkdirAll(filepath.Join(work, dir), 0700); err != nil {
			return "", err
		}
	}
	refresh, err := mame_refresh(ctx, mame, candidate.set, filepath.Join(work, "cfg"))
	if err != nil {
		return "", err
	}
	frame_limit, startup_secs, err := mame_comparison_frame_limit(max_frame, refresh)
	if err != nil {
		return "", err
	}
	timeout := MameFrameTimeout(frame_limit, refresh)
	if timeout <= 0 {
		return "", fmt.Errorf("invalid MAME timeout for %.6g Hz", refresh)
	}
	if err = prepare_mame_nvram(ctx, mame, candidate.set, rompath, work, source, candidate.core); err != nil {
		return "", err
	}
	if err = capture_mame_frames(ctx, mame, candidate.set, rompath, work, frame_limit, startup_secs, timeout, cab_script); err != nil {
		return "", err
	}
	mame_dir := filepath.Join(work, "snapshots")
	mame_paths, err := filepath.Glob(filepath.Join(mame_dir, "mame_*.png"))
	if err != nil {
		return "", err
	}
	if len(mame_paths) != frame_limit {
		return "", fmt.Errorf("MAME saved %d frames; expected %d", len(mame_paths), frame_limit)
	}
	for i, path := range mame_paths {
		if filepath.Base(path) != fmt.Sprintf("mame_%08d.png", i+1) {
			return "", fmt.Errorf("MAME frame sequence is missing or duplicated at frame %d", i+1)
		}
	}
	matched, err := match_mame_pngs_context(ctx, candidate.frames, fpga_dir, mame_paths, capture_bits)
	if err != nil {
		return "", err
	}
	if err = ctx.Err(); err != nil {
		return "", err
	}
	if !dryrun {
		if err = ctx.Err(); err != nil {
			return "", err
		}
		if err = promote_mame_candidate(root, candidate); err != nil {
			return "", err
		}
	}
	return fmt.Sprintf("%d frames matched at %s capture precision and %g Hz; MAME frames %d..%d", len(matched), capture_precision_name(capture_bits), refresh, matched[0], matched[len(matched)-1]), nil
}

const mameStartupScreenBypassMaxSeconds = 299

func mame_comparison_frame_limit(maxCheckpoint int, refresh float64) (int, int, error) {
	if maxCheckpoint < 1 || math.IsNaN(refresh) || math.IsInf(refresh, 0) || refresh <= 0 {
		return 0, 0, fmt.Errorf("invalid MAME frame budget inputs: checkpoint=%d refresh=%g", maxCheckpoint, refresh)
	}
	frameLimit := maxCheckpoint + 500
	startupSeconds := int(math.Ceil(float64(frameLimit) / refresh))
	if startupSeconds < 1 || startupSeconds > mameStartupScreenBypassMaxSeconds {
		return 0, 0, fmt.Errorf("checkpoint %d plus the 500-frame MAME search grace requires %d emulated seconds; visible unattended startup is supported only through %d seconds", maxCheckpoint, startupSeconds, mameStartupScreenBypassMaxSeconds)
	}
	return frameLimit, startupSeconds, nil
}

func capture_precision_name(bits int) string {
	if bits == 4 {
		return "RGB444"
	}
	if bits == 5 {
		return "RGB555"
	}
	return fmt.Sprintf("RGB%d%d%d", bits, bits, bits)
}

func mame_capture_precision(source, core, target string) (int, error) {
	if target != "sidi128" && target != "mister" {
		return 0, fmt.Errorf("unsupported MAME capture target %q", target)
	}
	value, err := resolveJTFRAMEValue(source, core, target, "JTFRAME_COLORW")
	if err != nil {
		return 0, err
	}
	color_width, err := strconv.Atoi(value)
	if err != nil {
		return 0, fmt.Errorf("parse %s JTFRAME_COLORW: %w", core, err)
	}
	return mame_target_capture_precision(color_width, target)
}

func mame_target_capture_precision(color_width int, target string) (int, error) {
	if target != "sidi128" && target != "mister" {
		return 0, fmt.Errorf("unsupported MAME capture target %q", target)
	}
	if color_width < 1 || color_width > 8 {
		return 0, fmt.Errorf("JTFRAME_COLORW %d is outside the supported range 1..8", color_width)
	}
	if target == "mister" {
		return color_width, nil
	}
	if color_width < 5 {
		return 4, nil
	}
	return 5, nil
}

func same_mame_source_path(left, right string) bool {
	left_abs, err := filepath.Abs(left)
	if err != nil {
		return false
	}
	right_abs, err := filepath.Abs(right)
	if err != nil {
		return false
	}
	if path, e := filepath.EvalSymlinks(left_abs); e == nil {
		left_abs = path
	}
	if path, e := filepath.EvalSymlinks(right_abs); e == nil {
		right_abs = path
	}
	return left_abs == right_abs
}

func validate_published_capture_precision(reference CaptureSet, capture_bits int) error {
	if capture_bits < 1 || capture_bits > 8 {
		return fmt.Errorf("invalid FPGA capture precision %d bits per channel", capture_bits)
	}
	for _, capture := range reference.Captures {
		path := filepath.Join(reference.Dir, capture.Image)
		file, err := os.Open(path)
		if err != nil {
			return err
		}
		img, err := png.Decode(file)
		_ = file.Close()
		if err != nil {
			return fmt.Errorf("decode FPGA capture %s: %w", capture.Image, err)
		}
		if _, err = SignatureImageAtCapturePrecision(capture.Requested, img, capture_bits); err != nil {
			return fmt.Errorf("FPGA capture %s does not match source-inferred %s capture precision: %w", capture.Image, capture_precision_name(capture_bits), err)
		}
	}
	return nil
}

func promote_mame_candidate(root string, candidate mame_candidate) error {
	if candidate.target != "sidi128" && candidate.target != "mister" {
		return fmt.Errorf("MAME promotion requires an explicit capture target")
	}
	if candidate.target == "sidi128" && !candidate.legacy_sidi128 {
		return fmt.Errorf("legacy SiDi128 MAME promotion requires --legacy-sidi128")
	}
	if candidate.target == "sidi128" {
		is_mister, err := journaledMiSTerNewCapture(root, candidate.core, candidate.set, candidate.dir, candidate.frames)
		if err != nil {
			return fmt.Errorf("cannot verify MAME target provenance before promotion: %w", err)
		}
		if is_mister {
			return fmt.Errorf("MiSTer result cannot be promoted through the legacy SiDi128 path")
		}
	}
	if candidate.promotion_error != "" {
		return fmt.Errorf("matches are read-only because promotion cannot be proven safe: %s", candidate.promotion_error)
	}
	lock, err := AcquireLock(root)
	if err != nil {
		return fmt.Errorf("cannot acquire regression lock for MAME promotion: %w", err)
	}
	defer ReleaseLock(lock)
	if err := RequireCaptureTarget(root, candidate.target); err != nil {
		return err
	}
	if err := recheck_mame_candidate(root, candidate); err != nil {
		return err
	}
	ref := filepath.Join(filepath.Dir(candidate.dir), "ref")
	if _, err := os.Lstat(ref); err == nil {
		return fmt.Errorf("ref appeared during validation; leaving new unapproved")
	} else if !os.IsNotExist(err) {
		return err
	}
	if candidate.target == "mister" {
		isMiSTer, provenance, _, err := findMiSTerMameProvenance(root, candidate.core, candidate.set, candidate.dir, candidate.frames, candidate.generation, candidate.qualification_id)
		if err != nil || !isMiSTer || provenance == nil || candidate.mister_provenance == nil || !reflect.DeepEqual(*provenance, *candidate.mister_provenance) {
			return fmt.Errorf("MiSTer candidate generation or qualification changed during MAME validation")
		}
		if err = validateMiSTerPriorReferenceForAcceptance(root, filepath.Dir(candidate.dir), *provenance); err != nil {
			return err
		}
		provenanceBytes, encodeErr := encodeMiSTerReferenceProvenance(*provenance)
		if encodeErr != nil {
			return encodeErr
		}
		if err = accept_curation_game_with_metadata(filepath.Dir(candidate.dir), provenanceBytes, nil); err != nil {
			return fmt.Errorf("cannot promote exact MiSTer match: %w", err)
		}
		return nil
	}
	if err := os.Rename(candidate.dir, ref); err != nil {
		return fmt.Errorf("cannot promote exact match to ref: %w", err)
	}
	return nil
}

func journaledMiSTerNewCapture(root, core, set, newDir string, frames CaptureSet) (bool, error) {
	entries, err := os.ReadDir(filepath.Join(root, "log"))
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	job := PoolJobKey{Core: core, Setname: set}
	for _, entry := range entries {
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 || filepath.Ext(entry.Name()) != ".json" || !mame_progress_filename(entry.Name()) {
			continue
		}
		progressPath := filepath.Join(root, "log", entry.Name())
		progress, err := read_mame_progress(root, progressPath)
		if err != nil {
			return false, fmt.Errorf("read candidate target provenance %s: %w", entry.Name(), err)
		}
		for key, lane := range progress.CaptureRuns {
			if lane.Target != "mister" || lane.FinalizationKind != miSTerSerialResultsKind {
				continue
			}
			if err := validateCaptureRunLane(key, lane); err != nil {
				return false, fmt.Errorf("validate MiSTer capture lane %s: %w", key, err)
			}
			for _, finalization := range lane.Finalizations {
				plan := finalization.Plan
				if plan == nil || finalization.JobKey != job || plan.Effect != MiSTerEffectNew || plan.Candidate.Target != "mister" || plan.Candidate.Core != core || plan.Candidate.Setname != set {
					continue
				}
				digest, err := digestOwnedTree(newDir)
				if err != nil {
					return false, err
				}
				if digest != plan.AfterSlotDigests["new"] {
					continue
				}
				published, err := readMiSTerPublishedCandidate(newDir, plan.Candidate)
				if err != nil || !sameMameCaptureSequence(published, frames) {
					continue
				}
				return true, nil
			}
		}
	}
	return false, nil
}

func findMiSTerMameProvenance(root, core, set, newDir string, frames CaptureSet, generation, qualificationID string) (bool, *MiSTerReferenceProvenance, string, error) {
	entries, err := os.ReadDir(filepath.Join(root, "log"))
	if os.IsNotExist(err) {
		return false, nil, "", nil
	}
	if err != nil {
		return false, nil, "", err
	}
	job := PoolJobKey{Core: core, Setname: set}
	var candidates []MiSTerReferenceProvenance
	var candidate_paths []string
	active := false
	for _, entry := range entries {
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 || filepath.Ext(entry.Name()) != ".json" || !mame_progress_filename(entry.Name()) {
			continue
		}
		progress, readErr := read_mame_progress(root, filepath.Join(root, "log", entry.Name()))
		if readErr != nil {
			return false, nil, "", fmt.Errorf("read MiSTer candidate provenance %s: %w", entry.Name(), readErr)
		}
		active = active || progress.Current == core+"/"+set
		for key, lane := range progress.CaptureRuns {
			if lane.Target != "mister" || lane.FinalizationKind != miSTerSerialResultsKind || lane.CaptureGeneration != generation || lane.QualificationID != qualificationID {
				continue
			}
			if err = validateCaptureRunLane(key, lane); err != nil {
				return false, nil, "", fmt.Errorf("validate MiSTer candidate lane %s: %w", key, err)
			}
			jobKey := poolJobMapKey(job)
			for _, finalization := range lane.Finalizations {
				plan := finalization.Plan
				if finalization.State != CaptureFinalizationComplete || finalization.JobKey != job || plan == nil || plan.Effect != MiSTerEffectNew || plan.Summary.Result != New ||
					!miSTerCurrentCaptureProtocol(plan.Candidate.CaptureProtocol) || plan.Candidate.Target != "mister" || plan.Candidate.Core != core || plan.Candidate.Setname != set || plan.Candidate.Generation != generation || plan.Candidate.QualificationID != qualificationID {
					continue
				}
				if lane.Selected[jobKey] != plan.Summary.PortableID || lane.Games[jobKey].OperationKey != plan.Summary.OperationKey || lane.Games[jobKey].OutputDigest != plan.CandidateDigest {
					continue
				}
				if err = plan.Validate(); err != nil {
					return false, nil, "", fmt.Errorf("validate finalized MiSTer candidate plan: %w", err)
				}
				currentDigest, digestErr := digestOwnedTree(newDir)
				if digestErr != nil || currentDigest != plan.AfterSlotDigests["new"] {
					continue
				}
				published, publishedErr := readMiSTerPublishedCandidate(newDir, plan.Candidate)
				if publishedErr != nil || !sameMameCaptureSequence(published, frames) {
					continue
				}
				staged, _, stagedErr := readStagedCandidate(plan.CandidateLocator, plan.Candidate)
				if stagedErr != nil || !sameMameCaptureSequence(staged, frames) {
					return false, nil, "", fmt.Errorf("private MiSTer candidate no longer matches published frame sequence")
				}
				candidates = append(candidates, plan.Candidate)
				candidate_paths = append(candidate_paths, filepath.Join(root, "log", entry.Name()))
			}
		}
	}
	if len(candidates) > 1 {
		return false, nil, "", fmt.Errorf("multiple completed MiSTer generations match %s/%s", core, set)
	}
	if active {
		return false, nil, "", fmt.Errorf("game is active in a regression run; deferred")
	}
	if len(candidates) == 0 {
		return false, nil, "", nil
	}
	return true, &candidates[0], candidate_paths[0], nil
}

func sameMameCaptureSequence(a, b CaptureSet) bool {
	// read_published_mame_frames has no descriptor from which to infer image
	// dimensions. The caller already matched the complete owned-tree digest;
	// compare the ordered filenames/checkpoints here.
	if len(a.Captures) != len(b.Captures) {
		return false
	}
	for index, left := range a.Captures {
		right := b.Captures[index]
		if left.Requested != right.Requested || left.Actual != right.Actual || left.Image != right.Image {
			return false
		}
	}
	return true
}

func appendMamePromotionError(current, next string) string {
	if current == "" {
		return next
	}
	return current + "; " + next
}

func copy_mame_frames(candidate mame_candidate, destination string) error {
	if err := os.MkdirAll(destination, 0700); err != nil {
		return err
	}
	for _, capture := range candidate.frames.Captures {
		data, err := os.ReadFile(filepath.Join(candidate.dir, capture.Image))
		if err != nil {
			return err
		}
		if err = os.WriteFile(filepath.Join(destination, capture.Image), data, 0600); err != nil {
			return err
		}
	}
	return nil
}

func check_mame_progress(root string, candidate mame_candidate) error {
	frames, err := read_published_mame_frames(candidate.dir)
	if err != nil || len(frames.Captures) != len(candidate.frames.Captures) {
		return fmt.Errorf("new capture contents changed before promotion")
	}
	for i, frame := range frames.Captures {
		original := candidate.frames.Captures[i]
		if frame.Requested != original.Requested || frame.Actual != original.Actual || frame.Image != original.Image {
			return fmt.Errorf("new capture schedule changed before promotion")
		}
	}
	digest, err := result_slot_digest(candidate.dir)
	if err != nil || digest != candidate.digest {
		return fmt.Errorf("new capture changed before validation")
	}
	if _, err = os.Lstat(filepath.Join(filepath.Dir(candidate.dir), "ref")); err == nil {
		return fmt.Errorf("ref already exists")
	} else if !os.IsNotExist(err) {
		return err
	}
	return nil
}

func recheck_mame_candidate(root string, candidate mame_candidate) error {
	if err := check_mame_progress(root, candidate); err != nil {
		return err
	}
	if candidate.target == "mister" {
		is_mister, provenance, path, err := findMiSTerMameProvenance(root, candidate.core, candidate.set, candidate.dir, candidate.frames, candidate.generation, candidate.qualification_id)
		if err != nil || !is_mister || provenance == nil || path != candidate.progress_path || candidate.mister_provenance == nil || !reflect.DeepEqual(*provenance, *candidate.mister_provenance) {
			return fmt.Errorf("MiSTer capture generation or qualification changed during validation")
		}
		return nil
	}
	progress, err := read_mame_progress(root, candidate.progress_path)
	if err != nil {
		return fmt.Errorf("cannot reread finalized progress: %w", err)
	}
	key := candidate.core + "/" + candidate.set
	game, ok := progress.Games[key]
	if !ok || game.Result != New || game.Output != candidate.digest || progress.Current == key {
		return fmt.Errorf("progress no longer marks this game as a completed new capture")
	}
	path, err := matching_mame_progress(root, candidate.core, candidate.set, candidate.digest)
	if err != nil || path != candidate.progress_path {
		return fmt.Errorf("progress identity changed during validation")
	}
	return nil
}

func mame_refresh(ctx context.Context, mame, set, cfg_dir string) (float64, error) {
	probe_ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	work := filepath.Dir(cfg_dir)
	command := exec.CommandContext(probe_ctx, mame, "-noreadconfig", "-listxml", set, "-inipath", filepath.Join(work, "ini"), "-cfg_directory", cfg_dir)
	command.Dir = work
	command.Env = isolated_mame_env(work)
	output, err := command.Output()
	if err != nil {
		if probe_ctx.Err() != nil {
			return 0, fmt.Errorf("MAME refresh probe timed out: %w", probe_ctx.Err())
		}
		return 0, fmt.Errorf("MAME refresh probe failed: %w", err)
	}
	var root struct {
		Machines []struct {
			Name     string `xml:"name,attr"`
			Displays []struct {
				Type    string  `xml:"type,attr"`
				Refresh float64 `xml:"refresh,attr"`
			} `xml:"display"`
		} `xml:"machine"`
	}
	if err = xml.Unmarshal(output, &root); err != nil {
		return 0, fmt.Errorf("parse MAME refresh metadata: %w", err)
	}
	for _, machine := range root.Machines {
		if machine.Name != set {
			continue
		}
		var refresh float64
		for _, display := range machine.Displays {
			if display.Type != "vector" {
				if refresh != 0 {
					return 0, fmt.Errorf("MAME reports multiple raster displays for %s", set)
				}
				refresh = display.Refresh
			}
		}
		if refresh > 0 && !math.IsInf(refresh, 0) && !math.IsNaN(refresh) {
			return refresh, nil
		}
	}
	return 0, fmt.Errorf("MAME did not report a raster refresh rate for %s", set)
}

// MameFrameTimeout applies the requested 10%% wall-clock margin to emulated time.
func MameFrameTimeout(frame_limit int, refresh float64) time.Duration {
	if frame_limit <= 0 || refresh <= 0 || math.IsNaN(refresh) || math.IsInf(refresh, 0) {
		return 0
	}
	seconds := math.Ceil(1.1 * float64(frame_limit) / refresh)
	if seconds <= 0 || math.IsInf(seconds, 0) || math.IsNaN(seconds) {
		return 0
	}
	if seconds > 300 {
		return 5 * time.Minute
	}
	return time.Duration(seconds) * time.Second
}

func capture_mame_frames(parent context.Context, mame, set, rompath, work string, frame_limit, startup_seconds int, timeout time.Duration, cab MameCabScript) error {
	if timeout <= 0 {
		return fmt.Errorf("invalid MAME frame timeout")
	}
	if startup_seconds < 1 || startup_seconds > mameStartupScreenBypassMaxSeconds {
		return fmt.Errorf("invalid MAME startup bypass duration %d seconds", startup_seconds)
	}
	script := filepath.Join(work, "capture.lua")
	complete := filepath.Join(work, "complete")
	failure := filepath.Join(work, "failure")
	lua, err := make_mame_capture_lua(cab, frame_limit, filepath.Join(work, "snapshots"), complete, failure)
	if err != nil {
		return err
	}
	if err := os.WriteFile(script, []byte(lua), 0600); err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(parent, timeout)
	defer cancel()
	command := exec.CommandContext(ctx, mame, set, "-noreadconfig", "-skip_gameinfo", "-seconds_to_run", fmt.Sprint(startup_seconds), "-sound", "none", "-nothrottle", "-window", "-snapview", "native", "-autoboot_delay", "0",
		"-rompath", rompath, "-inipath", filepath.Join(work, "ini"), "-cfg_directory", filepath.Join(work, "cfg"), "-nvram_directory", filepath.Join(work, "nvram"), "-snapshot_directory", filepath.Join(work, "snapshots"), "-input_directory", filepath.Join(work, "input"), "-state_directory", filepath.Join(work, "state"), "-diff_directory", filepath.Join(work, "diff"), "-autoboot_script", script, "-norotate")
	command.Dir = work
	command.Env = isolated_mame_env(work)
	output, err := command.CombinedOutput()
	if error_data, readErr := os.ReadFile(failure); readErr == nil {
		return fmt.Errorf("MAME CAB replay failed: %s", strings.TrimSpace(string(error_data)))
	}
	if err != nil {
		if ctx.Err() != nil {
			return fmt.Errorf("MAME frame capture timed out after %s", timeout)
		}
		return fmt.Errorf("MAME frame capture failed: %w: %s", err, compact_mame_error(string(output)))
	}
	if _, err = os.Stat(complete); err != nil {
		return fmt.Errorf("MAME frame capture did not write a completion marker")
	}
	count, err := os.ReadFile(complete)
	if err != nil || strings.TrimSpace(string(count)) != fmt.Sprint(frame_limit) {
		return fmt.Errorf("MAME frame capture completion count is invalid")
	}
	return nil
}

func make_mame_capture_lua(cab MameCabScript, frame_limit int, snapshot_dir, complete, failure string) (string, error) {
	input_tokens := map[uint]string{
		0: "COIN1", 1: "SERVICE1", 2: "START1", 3: "START2",
		4: "P1_JOYSTICK_RIGHT", 5: "P1_JOYSTICK_LEFT", 6: "P1_JOYSTICK_DOWN", 7: "P1_JOYSTICK_UP",
		8: "P1_BUTTON1", 9: "P1_BUTTON2", 10: "P1_BUTTON3",
		13: "COIN2", 14: "P2_JOYSTICK_RIGHT", 15: "P2_JOYSTICK_LEFT", 16: "P2_JOYSTICK_DOWN", 17: "P2_JOYSTICK_UP",
		18: "P2_BUTTON1", 19: "P2_BUTTON2", 20: "P2_BUTTON3",
	}
	used := make(map[uint]bool)
	for _, run := range cab.Runs {
		for bit := uint(0); bit < 21; bit++ {
			if run.Inputs&(1<<bit) == 0 {
				continue
			}
			if bit == 11 {
				return "", fmt.Errorf("CAB test actions are not mapped for MAME frame validation")
			}
			if bit == 12 {
				return "", fmt.Errorf("CAB reset actions are not mapped for MAME frame validation")
			}
			if _, ok := input_tokens[bit]; !ok {
				return "", fmt.Errorf("CAB action bit %d is not mapped for MAME frame validation", bit)
			}
			used[bit] = true
		}
		if run.HasDIPSW {
			return "", fmt.Errorf("CAB DIP switch actions are not mapped for MAME frame validation")
		}
		if run.Dump {
			return "", fmt.Errorf("CAB dump actions are unsupported by MAME frame validation")
		}
	}
	var controls strings.Builder
	for bit := uint(0); bit < 21; bit++ {
		if token, ok := input_tokens[bit]; ok && used[bit] {
			fmt.Fprintf(&controls, "  { bit = %d, token = %q },\n", bit, token)
		}
	}
	var runs strings.Builder
	for _, run := range cab.Runs {
		fmt.Fprintf(&runs, "  { %d, %d },\n", run.Frames, run.Inputs)
	}
	lua := fmt.Sprintf(`local machine = manager.machine
local ioports = machine.ioport
local controls = {
%s}
local runs = {
%s}
local frame_limit = %d
local profile_frames = %d
local snapshot_dir = %q
local complete_path = %q
local failure_path = %q
local function fail(message)
  local f = io.open(failure_path, "w"); if f then f:write(message); f:close() end
  machine:exit()
end
local wanted, fields = {}, {}
for _, control in ipairs(controls) do wanted[control.token] = true end
for _, port in pairs(ioports.ports) do
  for _, field in pairs(port.fields) do
    local ok, token = pcall(function() return ioports:input_type_to_token(field.type, field.player) end)
    if ok and token and wanted[token] and field.enabled then
      if fields[token] then fail("ambiguous MAME input token " .. token); return end
      fields[token] = field
    end
  end
end
for _, control in ipairs(controls) do
  if not fields[control.token] then fail("missing MAME input token " .. control.token); return end
end
local function enabled(mask, bit)
  return math.floor(mask / (2 ^ bit)) %% 2 == 1
end
local function mask_at(frame)
  if frame < 0 or frame >= profile_frames then return 0 end
  local position = 0
  for _, run in ipairs(runs) do
    if frame < position + run[1] then return run[2] end
    position = position + run[1]
  end
  return 0
end
local function apply(frame)
  local mask = mask_at(frame)
  for _, control in ipairs(controls) do
    fields[control.token]:set_value(enabled(mask, control.bit) and 1 or 0)
  end
end
local screen
for _, candidate in pairs(machine.screens) do screen = candidate; break end
if not screen then fail("MAME has no screen device"); return end
apply(0)
local completed = 0
emu.register_frame_done(function()
  completed = completed + 1
  screen:snapshot(string.format("%%s/mame_%%08d.png", snapshot_dir, completed))
  apply(completed)
  if completed >= frame_limit then
    local f = io.open(complete_path, "w"); if f then f:write(tostring(completed)); f:close() end
    machine:exit()
  end
end, "frame")
`, controls.String(), runs.String(), frame_limit, cab.Frames, snapshot_dir, complete, failure)
	return lua, nil
}

func isolated_mame_env(work string) []string {
	env := make([]string, 0, len(os.Environ())+2)
	for _, value := range os.Environ() {
		if strings.HasPrefix(value, "XDG_CONFIG_HOME=") {
			continue
		}
		env = append(env, value)
	}
	return append(env, "XDG_CONFIG_HOME="+filepath.Join(work, "xdg"))
}

func match_mame_pngs(reference CaptureSet, fpga_dir string, mame_paths []string, capture_bits int) ([]int, error) {
	return match_mame_pngs_context(context.Background(), reference, fpga_dir, mame_paths, capture_bits)
}

func match_mame_pngs_context(ctx context.Context, reference CaptureSet, fpga_dir string, mame_paths []string, capture_bits int) ([]int, error) {
	reference_signatures := make([]FrameSignature, 0, len(reference.Captures))
	for _, capture := range reference.Captures {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		file, err := os.Open(filepath.Join(fpga_dir, capture.Image))
		if err != nil {
			return nil, err
		}
		img, err := png.Decode(file)
		_ = file.Close()
		if err != nil {
			return nil, err
		}
		signature, err := SignatureImageAtCapturePrecision(capture.Requested, img, capture_bits)
		if err != nil {
			return nil, err
		}
		reference_signatures = append(reference_signatures, signature)
	}
	candidate_signatures := make([]FrameSignature, 0, len(mame_paths))
	for i, path := range mame_paths {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		file, err := os.Open(path)
		if err != nil {
			return nil, err
		}
		img, err := png.Decode(file)
		_ = file.Close()
		if err != nil {
			return nil, fmt.Errorf("decode MAME frame %d: %w", i+1, err)
		}
		signature, err := SignatureImageAtCapturePrecision(i+1, img, capture_bits)
		if err != nil {
			return nil, err
		}
		candidate_signatures = append(candidate_signatures, signature)
	}
	matched, err := MatchFramesOrdered(reference_signatures, candidate_signatures)
	if err != nil {
		if matched != nil {
			last := -1
			if len(matched) > 0 {
				last = matched[len(matched)-1]
			}
			index := len(matched)
			boundary, check_err := mame_boundary_match(ctx, reference_signatures[index], candidate_signatures, last,
				filepath.Join(fpga_dir, reference.Captures[index].Image), mame_paths, capture_bits)
			if check_err != nil {
				return nil, check_err
			}
			if boundary {
				return nil, fmt.Errorf("boundary differences at frame %d", reference_signatures[index].Frame)
			}
		}
		return nil, err
	}
	for i, frame := range matched {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		mame_file, err := os.Open(mame_paths[frame-1])
		if err != nil {
			return nil, err
		}
		mame_img, err := png.Decode(mame_file)
		_ = mame_file.Close()
		if err != nil {
			return nil, err
		}
		fpga_file, err := os.Open(filepath.Join(fpga_dir, reference.Captures[i].Image))
		if err != nil {
			return nil, err
		}
		fpga_img, err := png.Decode(fpga_file)
		_ = fpga_file.Close()
		if err != nil {
			return nil, err
		}
		if !ImagesEqualAtCapturePrecision(fpga_img, mame_img, capture_bits) {
			return nil, fmt.Errorf("MAME frame %d hash candidate failed full %s capture-code comparison", frame, capture_precision_name(capture_bits))
		}
	}
	return matched, nil
}

// A boundary match diagnoses the first failed checkpoint; it never permits
// promotion. Candidates must still follow the last exact MAME match.
func mame_boundary_match(ctx context.Context, reference FrameSignature, candidates []FrameSignature, last int, fpga_path string, mame_paths []string, bits int) (bool, error) {
	if reference.Width <= 2 || reference.Height <= 2 {
		return false, nil
	}
	fpga_file, err := os.Open(fpga_path)
	if err != nil {
		return false, err
	}
	fpga_img, err := png.Decode(fpga_file)
	_ = fpga_file.Close()
	if err != nil {
		return false, err
	}
	for _, candidate := range candidates {
		if err := ctx.Err(); err != nil {
			return false, err
		}
		if candidate.Frame <= last || candidate.Width != reference.Width || candidate.Height != reference.Height || candidate.Interior != reference.Interior {
			continue
		}
		file, err := os.Open(mame_paths[candidate.Frame-1])
		if err != nil {
			return false, err
		}
		img, err := png.Decode(file)
		_ = file.Close()
		if err != nil {
			return false, err
		}
		if images_equal_capture_region(fpga_img, img, bits, 1) && !ImagesEqualAtCapturePrecision(fpga_img, img, bits) {
			return true, nil
		}
	}
	return false, nil
}

func append_mame_frames_log(root, target string, result MameFrameResult) error {
	lock, err := AcquireLock(root)
	if err != nil {
		return fmt.Errorf("cannot acquire regression lock for MAME log append: %w", err)
	}
	defer ReleaseLock(lock)
	if err = RequireCaptureTarget(root, target); err != nil {
		return err
	}
	log_dir := filepath.Join(root, "log")
	if err := os.MkdirAll(log_dir, 0750); err != nil {
		return err
	}
	file, err := os.OpenFile(filepath.Join(log_dir, "mame-frames.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0640)
	if err != nil {
		return err
	}
	defer file.Close()
	// MAME parent and clone shortnames are limited to 16 characters.
	_, err = fmt.Fprintf(file, "%-19s %-16.16s %-5s %s\n", time.Now().Format("2006-01-02 15:04:05"), result.Setname, result.Verdict, compact_mame_error(result.Detail))
	if err != nil {
		return err
	}
	return file.Sync()
}

func compact_mame_error(detail string) string {
	detail = strings.Join(strings.Fields(detail), " ")
	if len(detail) > 240 {
		return detail[:237] + "..."
	}
	return detail
}
