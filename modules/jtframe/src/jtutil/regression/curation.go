/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"time"
)

// CurationError distinguishes expected acceptance validation failures for CLI exit codes.
type CurationError struct {
	Code int
	Err  error
}

func (e *CurationError) Error() string { return e.Err.Error() }
func (e *CurationError) Unwrap() error { return e.Err }
func (e *CurationError) ExitCode() int { return e.Code }

// RegressionBusy checks the flock state of the shared lock without creating it.
func RegressionBusy(root string) (bool, error) {
	lock, err := os.OpenFile(filepath.Join(root, "log", "lock"), os.O_RDWR, 0)
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	defer lock.Close()
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		if err == ErrBoardBusy {
			return true, nil
		}
		if err == syscall.EWOULDBLOCK {
			return true, nil
		}
		return false, err
	}
	_ = syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	return false, lock.Close()
}

// AcceptResult promotes exactly one reviewed capture slot to ref after quality checks.
func AcceptResult(root, setname string) error {
	if !safeComponent(setname) {
		return &CurationError{7, fmt.Errorf("unsafe setname %q", setname)}
	}
	gameRoot, err := find_curation_game(root, setname)
	if err != nil {
		return err
	}
	return accept_curation_game(gameRoot)
}

// AcceptCoreResults promotes every pending game in each selected core.
func AcceptCoreResults(root string, selectedCores []string) error {
	if len(selectedCores) == 0 {
		return fmt.Errorf("at least one core is required")
	}
	seen := map[string]bool{}
	for _, core := range selectedCores {
		if !safeComponent(core) || core == "log" {
			return &CurationError{7, fmt.Errorf("unsafe core %q", core)}
		}
		if seen[core] { return fmt.Errorf("core %q was selected more than once", core) }
		seen[core] = true
	}
	games := []string{}
	for _, core := range selectedCores {
		coreRoot := filepath.Join(root, core)
		info, err := os.Lstat(coreRoot)
		if os.IsNotExist(err) {
			return fmt.Errorf("core folder does not exist: %s", coreRoot)
		}
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 || !info.IsDir() {
			return fmt.Errorf("core path is not a real directory: %s", coreRoot)
		}
		entries, err := os.ReadDir(coreRoot)
		if err != nil {
			return err
		}
		for _, entry := range entries {
			if !entry.IsDir() || entry.Type()&os.ModeSymlink != 0 || !safeComponent(entry.Name()) {
				continue
			}
			gameRoot := filepath.Join(coreRoot, entry.Name())
			newExists, err := is_real_directory(filepath.Join(gameRoot, "new"))
			if err != nil {
				return err
			}
			failExists, err := is_real_directory(filepath.Join(gameRoot, "fail"))
			if err != nil {
				return err
			}
			if newExists || failExists {
				games = append(games, gameRoot)
			}
		}
	}
	if len(games) == 0 {
		return fmt.Errorf("selected cores have no pending new/ or fail/ captures")
	}
	sort.Strings(games)
	for _, gameRoot := range games {
		if err := accept_curation_game(gameRoot); err != nil {
			return err
		}
	}
	return nil
}

func accept_curation_game(gameRoot string) error {
	newDir, failDir := filepath.Join(gameRoot, "new"), filepath.Join(gameRoot, "fail")
	newExists, err := is_real_directory(newDir)
	if err != nil {
		return err
	}
	failExists, err := is_real_directory(failDir)
	if err != nil {
		return err
	}
	if newExists == failExists {
		return &CurationError{6, fmt.Errorf("expected exactly one of new/ or fail/ in %s", gameRoot)}
	}
	source := newDir
	if failExists {
		source = failDir
	}
	frames, err := acceptance_frames(source)
	if err != nil {
		return err
	}
	if len(frames) == 0 {
		return &CurationError{2, fmt.Errorf("%s contains no PNG frames", source)}
	}
	counts := make(map[string]int)
	allBlack := true
	for _, filename := range frames {
		img, decodeErr := decode_capture_image(filename)
		if decodeErr != nil {
			return &CurationError{3, fmt.Errorf("decode %s: %w", filepath.Base(filename), decodeErr)}
		}
		hash := sha256.New()
		fmt.Fprintf(hash, "%dx%d\x00", img.width, img.height)
		for _, pixel := range img.pixels {
			var rgb [3]byte
			rgb[0], rgb[1], rgb[2] = byte(pixel>>16), byte(pixel>>8), byte(pixel)
			_, _ = hash.Write(rgb[:])
			if pixel != 0 {
				allBlack = false
			}
		}
		counts[hex.EncodeToString(hash.Sum(nil))]++
	}
	if allBlack {
		return &CurationError{4, fmt.Errorf("all %d frames are black", len(frames))}
	}
	most := 0
	for _, count := range counts {
		if count > most {
			most = count
		}
	}
	if most*2 > len(frames) {
		return &CurationError{5, fmt.Errorf("%d of %d frames are identical (more than 50%%)", most, len(frames))}
	}
	refDir := filepath.Join(gameRoot, "ref")
	crc, err := reference_crc(source)
	if err != nil {
		return err
	}
	if err = preflight_curation_paths(gameRoot, source, refDir); err != nil {
		return err
	}
	if err = replace_curation_ref(source, refDir, gameRoot, crc); err != nil {
		return err
	}
	return os.RemoveAll(source)
}

// RejectResult removes pending captures and appends a rejection event if either slot exists.
func RejectResult(root, setname, reason string) error {
	if !safeComponent(setname) {
		return fmt.Errorf("unsafe setname %q", setname)
	}
	if strings.ContainsAny(reason, "\r\n") {
		return fmt.Errorf("reason must be a single line")
	}
	gameRoot, err := find_curation_game(root, setname)
	if err != nil {
		return err
	}
	newDir, failDir := filepath.Join(gameRoot, "new"), filepath.Join(gameRoot, "fail")
	newExists, err := is_real_directory(newDir)
	if err != nil {
		return err
	}
	failExists, err := is_real_directory(failDir)
	if err != nil {
		return err
	}
	if !newExists && !failExists {
		return fmt.Errorf("no new/ or fail/ folder exists in %s", gameRoot)
	}
	crc, err := reference_crc(filepath.Join(gameRoot, "ref"))
	if err != nil {
		return err
	}
	if err = preflight_curation_paths(gameRoot, "", filepath.Join(gameRoot, "ref")); err != nil {
		return err
	}
	return reject_pending_transaction(gameRoot, newDir, failDir, newExists, failExists, crc, reason, io.WriteString)
}

func reject_pending_transaction(gameRoot, newDir, failDir string, newExists, failExists bool, crc, reason string, write_event func(io.Writer, string) (int, error)) error {
	log, err := os.OpenFile(filepath.Join(gameRoot, "log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0640)
	if err != nil {
		return err
	}
	defer log.Close()
	info, err := log.Stat()
	if err != nil {
		return err
	}
	originalSize := info.Size()
	stagedNew, stagedFail := newDir+".rejecting", failDir+".rejecting"
	for _, path := range []string{stagedNew, stagedFail} {
		if _, err = os.Lstat(path); err == nil {
			return fmt.Errorf("unfinished rejection staging exists: %s", path)
		} else if !os.IsNotExist(err) {
			return err
		}
	}
	if newExists {
		if err = os.Rename(newDir, stagedNew); err != nil {
			return err
		}
	}
	if failExists {
		if err = os.Rename(failDir, stagedFail); err != nil {
			if newExists {
				_ = os.Rename(stagedNew, newDir)
			}
			return err
		}
	}
	restore := func(cause error) error {
		truncateErr := log.Truncate(originalSize)
		_, seekErr := log.Seek(0, io.SeekEnd)
		syncErr := log.Sync()
		var restoreErr error
		if failExists {
			restoreErr = os.Rename(stagedFail, failDir)
		}
		if newExists {
			if e := os.Rename(stagedNew, newDir); restoreErr == nil {
				restoreErr = e
			}
		}
		if truncateErr != nil || seekErr != nil || syncErr != nil || restoreErr != nil {
			return fmt.Errorf("%v; rollback errors: truncate=%v seek=%v sync=%v restore=%v", cause, truncateErr, seekErr, syncErr, restoreErr)
		}
		return cause
	}
	line := curation_event_line("REJECT", crc, reason)
	if _, err = write_event(log, line); err != nil {
		return restore(err)
	}
	if err = log.Sync(); err != nil {
		return restore(err)
	}
	if newExists {
		if err = os.RemoveAll(stagedNew); err != nil {
			return err
		}
	}
	if failExists {
		if err = os.RemoveAll(stagedFail); err != nil {
			return err
		}
	}
	return nil
}

type CurationStatus struct {
	Totals   map[Outcome]int
	Failures map[string][]string
}

// ReadCurationStatus summarizes each game's most recent completed check row.
func ReadCurationStatus(root string) (CurationStatus, error) {
	status := CurationStatus{Totals: map[Outcome]int{}, Failures: map[string][]string{}}
	cores, err := os.ReadDir(root)
	if os.IsNotExist(err) {
		return status, nil
	}
	if err != nil {
		return status, err
	}
	for _, core := range cores {
		if !core.IsDir() || core.Type()&os.ModeSymlink != 0 || !safeComponent(core.Name()) || core.Name() == "log" {
			continue
		}
		games, readErr := os.ReadDir(filepath.Join(root, core.Name()))
		if readErr != nil {
			return status, readErr
		}
		for _, game := range games {
			if !game.IsDir() || game.Type()&os.ModeSymlink != 0 || !safeComponent(game.Name()) {
				continue
			}
			outcome, found, readErr := latest_game_outcome(filepath.Join(root, core.Name(), game.Name(), "log"))
			if readErr != nil {
				return status, fmt.Errorf("%s/%s: %w", core.Name(), game.Name(), readErr)
			}
			if !found {
				// Slots can be left by older runs without per-game check history.
				if exists, _ := is_real_directory(filepath.Join(root, core.Name(), game.Name(), "fail")); exists {
					outcome, found = Fail, true
				} else if exists, _ := is_real_directory(filepath.Join(root, core.Name(), game.Name(), "new")); exists {
					outcome, found = New, true
				}
			}
			if found {
				status.Totals[outcome]++
				if outcome == Fail || outcome == Error {
					status.Failures[core.Name()] = append(status.Failures[core.Name()], game.Name()+" ("+strings.ToUpper(string(outcome))+")")
				}
			}
		}
	}
	for core := range status.Failures {
		sort.Strings(status.Failures[core])
	}
	return status, nil
}

func latest_game_outcome(filename string) (Outcome, bool, error) {
	data, err := os.ReadFile(filename)
	if os.IsNotExist(err) {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		fields := strings.Fields(lines[i])
		if len(fields) < 4 {
			continue
		}
		candidate := Outcome(strings.ToLower(fields[3]))
		switch candidate {
		case Pass, New, Fail, Error, Unsupported, Outcome("accept"), Outcome("reject"):
			return candidate, true, nil
		}
	}
	return "", false, nil
}

func is_real_directory(path string) (bool, error) {
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if info.Mode()&os.ModeSymlink != 0 || !info.IsDir() {
		return false, fmt.Errorf("%s is not a real directory", path)
	}
	return true, nil
}

func find_curation_game(root, setname string) (string, error) {
	cores, err := os.ReadDir(root)
	if err != nil {
		return "", err
	}
	matches := []string{}
	for _, core := range cores {
		if !core.IsDir() || core.Type()&os.ModeSymlink != 0 || !safeComponent(core.Name()) || core.Name() == "log" {
			continue
		}
		candidate := filepath.Join(root, core.Name(), setname)
		if info, statErr := os.Lstat(candidate); statErr == nil {
			if info.Mode()&os.ModeSymlink != 0 || !info.IsDir() {
				return "", &CurationError{6, fmt.Errorf("setname path is not a real directory: %s", candidate)}
			}
			matches = append(matches, candidate)
		} else if !os.IsNotExist(statErr) {
			return "", statErr
		}
	}
	if len(matches) != 1 {
		return "", &CurationError{6, fmt.Errorf("setname %s matched %d core folders; expected exactly one", setname, len(matches))}
	}
	return matches[0], nil
}

func acceptance_frames(dir string) ([]string, error) {
	frames := []string{}
	err := filepath.WalkDir(dir, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == dir {
			return nil
		}
		if entry.Type()&os.ModeSymlink != 0 {
			return fmt.Errorf("pending slot contains symlink: %s", path)
		}
		if entry.IsDir() {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() || !strings.EqualFold(filepath.Ext(entry.Name()), ".png") {
			return fmt.Errorf("pending slot contains non-PNG or non-regular entry: %s", path)
		}
		if _, err = decode_capture_image(path); err != nil {
			return &CurationError{3, fmt.Errorf("invalid PNG %s: %w", path, err)}
		}
		frames = append(frames, path)
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Strings(frames)
	return frames, nil
}

func preflight_curation_paths(gameRoot, source, ref string) error {
	for _, path := range []string{gameRoot, filepath.Join(gameRoot, "log")} {
		info, err := os.Lstat(path)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("refusing symlink path %s", path)
		}
		if path == gameRoot && !info.IsDir() {
			return fmt.Errorf("game path is not a directory")
		}
		if path != gameRoot && !info.Mode().IsRegular() {
			return fmt.Errorf("game log is not a regular file")
		}
	}
	for _, path := range []string{ref, ref + ".old", ref + ".staging"} {
		info, err := os.Lstat(path)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("refusing symlink path %s", path)
		}
		if !info.IsDir() {
			return fmt.Errorf("reference path is not a directory: %s", path)
		}
	}
	if source != "" {
		if _, err := is_real_directory(source); err != nil {
			return err
		}
	}
	return nil
}

func replace_curation_ref(source, destination, gameRoot, crc string) error {
	if err := recover_dir(destination); err != nil {
		return err
	}
	staging, old := destination+".staging", destination+".old"
	if err := os.RemoveAll(staging); err != nil {
		return err
	}
	if err := copy_tree(source, staging); err != nil {
		_ = os.RemoveAll(staging)
		return err
	}
	log, err := os.OpenFile(filepath.Join(gameRoot, "log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0640)
	if err != nil {
		_ = os.RemoveAll(staging)
		return err
	}
	defer log.Close()
	info, err := log.Stat()
	if err != nil {
		_ = os.RemoveAll(staging)
		return err
	}
	originalSize := info.Size()
	_ = os.RemoveAll(old)
	if _, err = os.Lstat(destination); err == nil {
		if err = os.Rename(destination, old); err != nil {
			_ = os.RemoveAll(staging)
			return err
		}
	} else if !os.IsNotExist(err) {
		_ = os.RemoveAll(staging)
		return err
	}
	rollback := func(cause error) error {
		_ = os.RemoveAll(destination)
		if _, statErr := os.Lstat(old); statErr == nil {
			if restoreErr := os.Rename(old, destination); restoreErr != nil {
				return fmt.Errorf("%v; restore prior reference: %w", cause, restoreErr)
			}
		}
		_ = os.RemoveAll(staging)
		_ = log.Truncate(originalSize)
		_, _ = log.Seek(0, io.SeekEnd)
		_ = log.Sync()
		return cause
	}
	if err = os.Rename(staging, destination); err != nil {
		return rollback(err)
	}
	line := fmt.Sprintf("%s %-13s %-11s %s\n", LogTime(time.Now()), "manual", "ACCEPT", crc)
	if _, err = io.WriteString(log, line); err != nil {
		return rollback(err)
	}
	if err = log.Sync(); err != nil {
		return rollback(err)
	}
	if err = os.RemoveAll(old); err != nil {
		return fmt.Errorf("accepted reference but could not remove prior reference: %w", err)
	}
	return nil
}

func append_curation_event(gameRoot, event, crc, reason string) error {
	if err := os.MkdirAll(gameRoot, 0750); err != nil {
		return err
	}
	file, err := os.OpenFile(filepath.Join(gameRoot, "log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0640)
	if err != nil {
		return err
	}
	line := curation_event_line(event, crc, reason)
	_, writeErr := io.WriteString(file, line+"\n")
	if writeErr == nil {
		writeErr = file.Sync()
	}
	closeErr := file.Close()
	if writeErr != nil {
		return writeErr
	}
	return closeErr
}

func curation_event_line(event, crc, reason string) string {
	line := fmt.Sprintf("%s %-13s %-11s %s", LogTime(time.Now()), "manual", event, crc)
	if reason != "" {
		line += " " + strings.TrimSpace(reason)
	}
	return line + "\n"
}
