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
	"sort"
	"strings"
	"time"
)

type MameFrameResult struct {
	Core, Setname, Verdict, Detail string
}

type mame_candidate struct {
	core, set, dir, digest string
	progress_path          string
	preflight_error        string
	promotion_error        string
	frames                 CaptureSet
}

// RunMameFrames checks finalized new captures independently while hardware
// regression may continue to process other games.
func RunMameFrames(ctx context.Context, root, source, setname string, dryrun bool) ([]MameFrameResult, error) {
	if setname != "" && !safeComponent(setname) {
		return nil, fmt.Errorf("unsafe setname %q", setname)
	}
	candidates, err := discover_mame_candidates(root, source, setname)
	if err != nil {
		return nil, err
	}
	if setname != "" && len(candidates) > 1 {
		return nil, fmt.Errorf("setname %s is ambiguous across %d core folders", setname, len(candidates))
	}
	if len(candidates) == 0 {
		return nil, nil
	}
	mame, mame_err := exec.LookPath("mame")
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	rompath := filepath.Join(home, ".mame", "roms")
	results := make([]MameFrameResult, 0, len(candidates))
	for _, candidate := range candidates {
		if err := ctx.Err(); err != nil {
			return results, err
		}
		result := MameFrameResult{Core: candidate.core, Setname: candidate.set, Verdict: "FAIL"}
		detail := ""
		var checkErr error
		if candidate.preflight_error != "" {
			checkErr = fmt.Errorf("%s", candidate.preflight_error)
		} else if mame_err != nil {
			checkErr = fmt.Errorf("MAME executable not found in PATH: %w", mame_err)
		} else {
			detail, checkErr = validate_mame_candidate(ctx, candidate, root, source, mame, rompath, dryrun)
		}
		if err := ctx.Err(); err != nil {
			return results, err
		}
		if checkErr != nil {
			result.Detail = compact_mame_error(checkErr.Error())
		} else {
			result.Verdict, result.Detail = "PASS", detail
		}
		if !dryrun {
			if err = append_mame_frames_log(root, result); err != nil {
				return results, err
			}
		}
		results = append(results, result)
	}
	return results, nil
}

func discover_mame_candidates(root, source, only_set string) ([]mame_candidate, error) {
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
			if !game_entry.IsDir() || !safeComponent(set) || only_set != "" && set != only_set {
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
		if requested <= 0 || requested%100 != 0 {
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

func validate_mame_candidate(ctx context.Context, candidate mame_candidate, root, source, mame, rompath string, dryrun bool) (string, error) {
	if err := check_mame_progress(root, candidate); err != nil {
		return "", err
	}
	work, err := os.MkdirTemp("/tmp", "jtutil-mame-frames-")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(work)
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
	frame_limit := max_frame + 500
	timeout := MameFrameTimeout(frame_limit, refresh)
	if timeout <= 0 {
		return "", fmt.Errorf("invalid MAME timeout for %.6g Hz", refresh)
	}
	if err = prepare_mame_nvram(ctx, mame, candidate.set, rompath, work, source, candidate.core); err != nil {
		return "", err
	}
	if err = capture_mame_frames(ctx, mame, candidate.set, rompath, work, frame_limit, timeout); err != nil {
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
	matched, err := match_mame_pngs_context(ctx, candidate.frames, fpga_dir, mame_paths)
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
	return fmt.Sprintf("%d frames matched at %g Hz; MAME frames %d..%d", len(matched), refresh, matched[0], matched[len(matched)-1]), nil
}

func promote_mame_candidate(root string, candidate mame_candidate) error {
	if candidate.promotion_error != "" {
		return fmt.Errorf("matches are read-only because promotion cannot be proven safe: %s", candidate.promotion_error)
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
	if err := os.Rename(candidate.dir, ref); err != nil {
		return fmt.Errorf("cannot promote exact match to ref: %w", err)
	}
	return nil
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
	return time.Duration(seconds) * time.Second
}

func capture_mame_frames(parent context.Context, mame, set, rompath, work string, frame_limit int, timeout time.Duration) error {
	if timeout <= 0 {
		return fmt.Errorf("invalid MAME frame timeout")
	}
	script := filepath.Join(work, "capture.lua")
	complete := filepath.Join(work, "complete")
	lua := fmt.Sprintf(`local machine = manager.machine
local screen
for _, candidate in pairs(machine.screens) do screen = candidate; break end
if not screen then
  local f = io.open(%q, "w"); if f then f:write("no screen"); f:close() end
  machine:exit(); return
end
local frames = 0
emu.register_frame_done(function()
  frames = frames + 1
  screen:snapshot(string.format("mame_%%08d.png", frames))
  if frames >= %d then
    local f = io.open(%q, "w"); if f then f:write(tostring(frames)); f:close() end
    manager.machine:exit()
  end
end, "frame")
`, complete, frame_limit, complete)
	if err := os.WriteFile(script, []byte(lua), 0600); err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(parent, timeout)
	defer cancel()
	command := exec.CommandContext(ctx, mame, set, "-noreadconfig", "-skip_gameinfo", "-sound", "none", "-nothrottle", "-video", "none", "-snapview", "native", "-autoboot_delay", "0",
		"-rompath", rompath, "-inipath", filepath.Join(work, "ini"), "-cfg_directory", filepath.Join(work, "cfg"), "-nvram_directory", filepath.Join(work, "nvram"), "-snapshot_directory", filepath.Join(work, "snapshots"), "-input_directory", filepath.Join(work, "input"), "-state_directory", filepath.Join(work, "state"), "-diff_directory", filepath.Join(work, "diff"), "-autoboot_script", script, "-norotate")
	command.Dir = work
	command.Env = isolated_mame_env(work)
	output, err := command.CombinedOutput()
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

func match_mame_pngs(reference CaptureSet, fpga_dir string, mame_paths []string) ([]int, error) {
	return match_mame_pngs_context(context.Background(), reference, fpga_dir, mame_paths)
}

func match_mame_pngs_context(ctx context.Context, reference CaptureSet, fpga_dir string, mame_paths []string) ([]int, error) {
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
		signature, err := SignatureImage(capture.Requested, img)
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
		signature, err := SignatureImage(i+1, img)
		if err != nil {
			return nil, err
		}
		candidate_signatures = append(candidate_signatures, signature)
	}
	matched, err := MatchFramesOrdered(reference_signatures, candidate_signatures)
	if err != nil {
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
		if !ImagesEqualRGB(fpga_img, mame_img) {
			return nil, fmt.Errorf("MAME frame %d hash candidate failed full RGB comparison", frame)
		}
	}
	return matched, nil
}

func append_mame_frames_log(root string, result MameFrameResult) error {
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
