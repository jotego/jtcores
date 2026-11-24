/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"fmt"
	"hash/crc32"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Accept makes the pending new/ or fail/ frames of each named game the new ref/
// and adds an ACCEPT line with the CRC of ref/ to the game's log.
// A name is a setname or a core; a core accepts all of its pending games
func Accept(root string, names []string, out io.Writer) error {
	return each_game(root, names, out, "accepted", "no new or fail frames to accept", accept_game)
}

// Unaccept turns the ref/ of each named game back into new/, so it awaits review
// again, and adds an UNACCEPT line to the game's log. A game with new/ or fail/
// frames is left as it is
func Unaccept(root string, names []string, out io.Writer) error {
	return each_game(root, names, out, "back to new", "no ref frames to take back", unaccept_game)
}

// Reject moves the pending new/ or fail/ frames of each named game to rejected/,
// replacing an older rejected/, and adds a REJECT line to the game's log
func Reject(root string, names []string, out io.Writer) error {
	return each_game(root, names, out, "rejected", "no new or fail frames to reject", reject_game)
}

func each_game(root string, names []string, out io.Writer, done, none string, action func(string) (bool, error)) error {
	lock, e := lock_regression(root); if e != nil { return e }
	defer lock.Close()
	for _, name := range names {
		if name == "" || strings.ContainsAny(name, "/.") {
			return fmt.Errorf("takes setnames or cores, not %q", name)
		}
		games, _ := filepath.Glob(filepath.Join(root, "*", name))
		if len(games) == 0 {
			games, _ = filepath.Glob(filepath.Join(root, name, "*"))
		}
		count := 0
		for _, game := range games {
			ok, e := action(game); if e != nil { return e }
			if ok {
				count++
				fmt.Fprintf(out, "%s: %s\n", strings.TrimPrefix(game, root+"/"), done)
			}
		}
		if count == 0 {
			return fmt.Errorf("%s has %s", name, none)
		}
	}
	return nil
}

func accept_game(game string) (bool, error) {
	return promote_game(game, "manual")
}

// promote_game makes the new/ or fail/ frames the ref/ and logs an ACCEPT line by who
func promote_game(game, who string) (bool, error) {
	if pending_slot(game) == "" {
		return false, nil
	}
	pending := filepath.Join(game, pending_slot(game))
	logs, _ := filepath.Glob(filepath.Join(pending, "MiSTer*.log")) // fail/ keeps Main's log
	for _, log := range logs {
		if e := os.Remove(log); e != nil { return false, e }
	}
	ref, old := filepath.Join(game, "ref"), filepath.Join(game, "ref.old")
	if e := os.RemoveAll(old); e != nil { return false, e }
	if e := os.Rename(ref, old); e != nil && !os.IsNotExist(e) { return false, e }
	if e := os.Rename(pending, ref); e != nil { return false, e }
	for _, slot := range []string{"new", "fail"} { // a game has at most one, but leave no stale frames
		if e := os.RemoveAll(filepath.Join(game, slot)); e != nil { return false, e }
	}
	if e := os.RemoveAll(old); e != nil { return false, e }
	crc, e := reference_crc(ref); if e != nil { return false, e }
	return true, game_log(game, who, "ACCEPT", crc)
}

func reject_game(game string) (bool, error) {
	pending := pending_slot(game)
	if pending == "" {
		return false, nil
	}
	rejected := filepath.Join(game, "rejected")
	if e := os.RemoveAll(rejected); e != nil { return false, e }
	if e := os.Rename(filepath.Join(game, pending), rejected); e != nil { return false, e }
	for _, slot := range []string{"new", "fail"} {
		if e := os.RemoveAll(filepath.Join(game, slot)); e != nil { return false, e }
	}
	crc, e := reference_crc(filepath.Join(game, "ref")); if e != nil { return false, e }
	return true, game_log(game, "manual", "REJECT", crc)
}

// pending_slot is the result folder awaiting review, new or fail, or "" for none
func pending_slot(game string) string {
	for _, slot := range []string{"new", "fail"} {
		if info, e := os.Stat(filepath.Join(game, slot)); e == nil && info.IsDir() {
			return slot
		}
	}
	return ""
}

func unaccept_game(game string) (bool, error) {
	ref := filepath.Join(game, "ref")
	if _, e := os.Stat(ref); e != nil {
		return false, nil
	}
	for _, slot := range []string{"new", "fail"} {
		if _, e := os.Stat(filepath.Join(game, slot)); e == nil {
			return false, fmt.Errorf("%s has %s frames: accept or remove them first", game, slot)
		}
	}
	if e := os.Rename(ref, filepath.Join(game, "new")); e != nil { return false, e }
	return true, game_log(game, "manual", "UNACCEPT", "--------") // no reference left
}

// game_log appends a history row to <game>/log: time, who (a commit or manual), verdict and ref/ CRC
func game_log(game, who, verdict, crc string) error {
	log, e := os.OpenFile(filepath.Join(game, "log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0640); if e != nil { return e }
	_, e = fmt.Fprintf(log, "%s %-13s %-11s %s\n", LogTime(time.Now()), who, verdict, crc)
	if close_error := log.Close(); e == nil { e = close_error }
	return e
}

// LogTime formats log timestamps in the local time zone
func LogTime(value time.Time) string {
	return value.Local().Format("2006-01-02 15:04:05")
}

// reference_crc is the CRC32 of the sorted relative names, sizes and bytes of
// the files in dir, or -------- when dir does not exist
func reference_crc(dir string) (string, error) {
	info, e := os.Lstat(dir)
	if os.IsNotExist(e) { return "--------", nil }
	if e != nil { return "", e }
	if !info.IsDir() { return "", fmt.Errorf("%s is not a directory", dir) }
	digest := crc32.NewIEEE()
	e = filepath.WalkDir(dir, func(path string, entry fs.DirEntry, walk_error error) error {
		if walk_error != nil { return walk_error }
		if path == dir { return nil }
		relative, e := filepath.Rel(dir, path); if e != nil { return e }
		relative = filepath.ToSlash(relative)
		if entry.IsDir() {
			fmt.Fprintf(digest, "d%s\x00", relative)
			return nil
		}
		info, e := entry.Info(); if e != nil { return e }
		if !info.Mode().IsRegular() { return fmt.Errorf("%s is not a regular file", path) }
		fmt.Fprintf(digest, "f%s\x00%d\x00", relative, info.Size())
		file, e := os.Open(path); if e != nil { return e }
		size, e := io.Copy(digest, file)
		if close_error := file.Close(); e == nil { e = close_error }
		if e == nil && size != info.Size() { e = fmt.Errorf("%s changed while hashing", path) }
		return e
	})
	if e != nil { return "", e }
	return fmt.Sprintf("%08x", digest.Sum32()), nil
}
