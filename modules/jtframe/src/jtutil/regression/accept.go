/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Accept makes the pending new/ or fail/ frames of each named game the new ref/
// and adds an ACCEPT line with the CRC of ref/ to the game's log.
// A name is a setname or a core; a core accepts all of its pending games
func Accept(root string, names []string, out io.Writer) error {
	lock, e := lock_regression(root); if e != nil { return e }
	defer lock.Close()
	for _, name := range names {
		if name == "" || strings.ContainsAny(name, "/.") {
			return fmt.Errorf("--accept takes setnames or cores, not %q", name)
		}
		games, _ := filepath.Glob(filepath.Join(root, "*", name))
		if len(games) == 0 {
			games, _ = filepath.Glob(filepath.Join(root, name, "*"))
		}
		accepted := 0
		for _, game := range games {
			ok, e := accept_game(game); if e != nil { return e }
			if ok {
				accepted++
				fmt.Fprintf(out, "%s: accepted\n", strings.TrimPrefix(game, root+"/"))
			}
		}
		if accepted == 0 {
			return fmt.Errorf("%s has no new or fail frames to accept", name)
		}
	}
	return nil
}

func accept_game(game string) (bool, error) {
	pending := ""
	for _, slot := range []string{"new", "fail"} {
		if _, e := os.Stat(filepath.Join(game, slot)); e == nil {
			pending = filepath.Join(game, slot)
			break
		}
	}
	if pending == "" {
		return false, nil
	}
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
	log, e := os.OpenFile(filepath.Join(game, "log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0640); if e != nil { return false, e }
	_, e = fmt.Fprintf(log, "%s %-13s %-11s %s\n", LogTime(time.Now()), "manual", "ACCEPT", crc)
	if close_error := log.Close(); e == nil { e = close_error }
	return true, e
}
