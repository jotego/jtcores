/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"encoding/json"
	"fmt"
	"image"
	"image/png"
	"io"
	"os"
	"path/filepath"
	"sort"
	"time"
)

// progress is log/<key>.json, one file per commit. The field names follow the
// older progress files, which mame-frames still reads
type progress struct {
	Commit         string                    `json:"commit"`
	Dirty          bool                      `json:"dirty,omitempty"`
	Main           string                    `json:"main,omitempty"`
	Status         string                    `json:"status"`
	Started        time.Time                 `json:"started"`
	Updated        time.Time                 `json:"updated"`
	ReportURL      string                    `json:"report_url,omitempty"`
	GiteaReportURL string                    `json:"gitea_report_url,omitempty"`
	Games          map[string]*progress_game `json:"games"`
}

type progress_game struct {
	Result  Outcome `json:"result"`
	Board   string  `json:"board,omitempty"`
	Seconds float64 `json:"seconds,omitempty"`
	Message string  `json:"message,omitempty"`
}

func (r *runner) progress_path(key string) string {
	return filepath.Join(r.Root, "log", key+".json")
}

func read_progress(path string) (*progress, error) {
	data, e := os.ReadFile(path); if e != nil { return nil, e }
	var p progress
	if e = json.Unmarshal(data, &p); e == nil && p.Games == nil {
		e = fmt.Errorf("no games")
	}
	if e != nil {
		return nil, fmt.Errorf("%s: %w", path, e)
	}
	return &p, nil
}

func (r *runner) save() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.save_locked()
}

// save_locked writes the progress through a temporary file and a rename
func (r *runner) save_locked() error {
	r.progress.Updated = time.Now()
	data, e := json.MarshalIndent(r.progress, "", "  "); if e != nil { return e }
	path := r.progress_path(r.key)
	e = os.WriteFile(path+".tmp", append(data, '\n'), 0640); if e != nil { return e }
	return os.Rename(path+".tmp", path)
}

// finalize compares the PNGs in dir with ref and publishes the result folder.
// The progress file is updated after it, so a crash in between reruns the game
func (r *runner) finalize(j *job, dir string) (Outcome, string, error) {
	game := filepath.Join(r.Root, j.core, j.set)
	pngs, e := filepath.Glob(filepath.Join(dir, "*.png")); if e != nil { return "", "", e }
	refs, e := filepath.Glob(filepath.Join(game, "ref", "*.png")); if e != nil { return "", "", e }
	if len(refs) == 0 {
		return New, fmt.Sprintf("%d frames", len(pngs)), r.publish_slot(game, "new", dir)
	}
	differ := 0
	for _, got := range pngs {
		same, e := same_png(filepath.Join(game, "ref", filepath.Base(got)), got)
		if e != nil && !os.IsNotExist(e) {
			return "", "", e
		}
		if !same {
			differ++
		}
	}
	if differ == 0 && len(refs) == len(pngs) {
		return Pass, "", r.publish_slot(game, "", "")
	}
	msg := fmt.Sprintf("%d/%d frames differ", differ, len(pngs))
	if len(refs) != len(pngs) {
		msg += fmt.Sprintf(", ref has %d frames", len(refs))
	}
	for name, log := range j.logs {
		e = os.WriteFile(filepath.Join(dir, name), log, 0640); if e != nil { return "", "", e }
	}
	return Fail, msg, r.publish_slot(game, "fail", dir)
}

func same_png(a, b string) (bool, error) {
	ia, e := decode_png(a); if e != nil { return false, e }
	ib, e := decode_png(b); if e != nil { return false, e }
	if ia.Bounds() != ib.Bounds() {
		return false, nil
	}
	r := ia.Bounds()
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			r0, g0, b0, _ := ia.At(x, y).RGBA()
			r1, g1, b1, _ := ib.At(x, y).RGBA()
			if r0 != r1 || g0 != g1 || b0 != b1 {
				return false, nil
			}
		}
	}
	return true, nil
}

func decode_png(path string) (image.Image, error) {
	f, e := os.Open(path); if e != nil { return nil, e }
	defer f.Close()
	return png.Decode(f)
}

// publish_error keeps the Main logs of the failed attempts in the error folder
func (r *runner) publish_error(j *job) {
	dir, e := os.MkdirTemp("", "jtreg-err-")
	if e == nil {
		for name, log := range j.logs {
			os.WriteFile(filepath.Join(dir, name), log, 0640)
		}
		e = r.publish_slot(filepath.Join(r.Root, j.core, j.set), "error", dir)
		os.RemoveAll(dir)
	}
	if e != nil {
		r.printf("%s/%s: cannot keep the Main logs: %v", j.core, j.set, e)
	}
}

// publish_slot replaces the slot folder with a copy of src, through a
// temporary folder and a rename, and removes the other result folders.
// ref is never touched
func (r *runner) publish_slot(game, slot, src string) error {
	e := os.MkdirAll(game, 0750); if e != nil { return e }
	for _, name := range []string{"new", "fail", "error"} {
		dst := filepath.Join(game, name)
		if name != slot {
			if e = os.RemoveAll(dst); e != nil {
				return e
			}
			continue
		}
		tmp, e := os.MkdirTemp(game, "."+name+"-"); if e != nil { return e }
		files, e := os.ReadDir(src); if e != nil { return e }
		for _, f := range files {
			if e = copy_file(filepath.Join(src, f.Name()), filepath.Join(tmp, f.Name())); e != nil {
				os.RemoveAll(tmp)
				return e
			}
		}
		os.Chmod(tmp, 0750)
		os.RemoveAll(dst + ".old")
		if e = os.Rename(dst, dst+".old"); e != nil && !os.IsNotExist(e) {
			return e
		}
		if e = os.Rename(tmp, dst); e != nil {
			return e
		}
		os.RemoveAll(dst + ".old")
	}
	return nil
}

func copy_file(src, dst string) error {
	in, e := os.Open(src); if e != nil { return e }
	defer in.Close()
	out, e := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0640); if e != nil { return e }
	_, e = io.Copy(out, in)
	if e2 := out.Close(); e == nil {
		e = e2
	}
	return e
}

func sorted_keys[T any](m map[string]T) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
