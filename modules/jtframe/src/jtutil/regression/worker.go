/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// execute runs one worker per board over the shared queue. Each board starts
// as soon as its own copy of the release folder is done
func (r *runner) execute() error {
	sockets, e := os.MkdirTemp("/tmp", "jtreg-ssh-"); if e != nil { return e }
	defer os.RemoveAll(sockets)
	r.cond, r.alive = sync.NewCond(&r.mu), len(r.Boards)
	r.busy += len(r.Boards) // a board holds the queue open while it deploys
	var wg sync.WaitGroup
	for _, host := range r.Boards {
		b := r.new_board(host, sockets)
		wg.Add(1)
		go func() {
			defer wg.Done()
			defer b.Close()
			r.worker(b)
			r.mu.Lock()
			r.alive--
			r.cond.Broadcast()
			r.mu.Unlock()
		}()
	}
	wg.Wait()
	r.mu.Lock()
	defer r.mu.Unlock()
	r.progress.Status = "complete"
	for _, g := range r.progress.Games {
		if g.Result == Pending {
			r.progress.Status = "incomplete"
		}
	}
	e = r.save_locked(); if e != nil { return e }
	if r.ctx.Err() != nil {
		return r.ctx.Err()
	}
	if r.progress.Status != "complete" {
		return fmt.Errorf("%d games were not run: no board left", len(r.queue))
	}
	fmt.Fprintf(r.Out, "Regression of %s complete. Progress in %s\n", r.key, r.progress_path(r.key))
	return nil
}

func (r *runner) worker(b Board) {
	folder := "_" + r.key
	if e := b.Deploy(r.ctx, r.release, folder); e != nil {
		r.printf("%s: deploy failed, board left out: %v", b.Name(), e)
		r.done(nil)
		return
	}
	r.printf("%s: deployed to /media/fat/%s", b.Name(), folder)
	r.done(nil)
	for {
		j := r.next(b.Name())
		if j == nil {
			return
		}
		start := time.Now()
		dir, e := os.MkdirTemp("", "jtreg-png-")
		if e == nil {
			e = r.attempt(b, j, folder, dir)
		}
		seconds := time.Since(start).Seconds()
		if r.ctx.Err() != nil {
			os.RemoveAll(dir)
			r.done(nil)
			return
		}
		if e == nil {
			j.logs["MiSTer.log"], _ = b.Log(r.ctx) // kept if the frames differ
			if e := b.Clean(r.ctx, j.set); e != nil {
				r.printf("%s: cannot remove /tmp/jtcap/%s: %v", b.Name(), j.set, e)
			}
			outcome, msg, e := r.finalize(j, dir)
			if e != nil {
				outcome, msg = Error, e.Error()
			}
			os.RemoveAll(dir)
			r.record(j, b.Name(), seconds, outcome, msg)
			r.done(nil)
			continue
		}
		os.RemoveAll(dir)
		j.tries, j.failed_on = j.tries+1, b.Name()
		log, _ := b.Log(r.ctx) // before any reboot
		b.Clean(r.ctx, j.set)
		j.logs[fmt.Sprintf("MiSTer-%d-%s.log", j.tries, b.Name())] = log
		if j.tries < 2 {
			r.printf("%s: %s/%s attempt failed, retrying: %v", b.Name(), j.core, j.set, e)
			r.done(j)
		} else {
			r.publish_error(j)
			r.record(j, b.Name(), seconds, Error, e.Error())
			r.done(nil)
		}
		if e = b.Reboot(r.ctx); e != nil {
			r.printf("%s: recovery failed, board retired: %v", b.Name(), e)
			return
		}
	}
}

// attempt runs one game on a board and leaves its PNGs in dir. Any error is operational
func (r *runner) attempt(b Board, j *job, folder, dir string) error {
	e := b.Health(r.ctx); if e != nil { return fmt.Errorf("health: %w", e) }
	e = b.Load(r.ctx, "/media/fat/"+folder+"/"+j.mra); if e != nil { return fmt.Errorf("load_core: %w", e) }
	st, e := r.wait(b, "load", r.LoadLimit, "loaded", "load_error"); if e != nil { return e }
	if st.State == "load_error" {
		return fmt.Errorf("load_error: %s", st.Error)
	}
	cab := "/media/fat/" + folder + "/cab/" + j.set + ".cab"
	e = b.Send(r.ctx, "cab_session_start "+j.set+" "+cab); if e != nil { return fmt.Errorf("cab_session_start: %w", e) }
	limit := time.Duration(capture_slack * float64(j.cab.LastFrame()+1) / min_refresh * float64(time.Second))
	st, e = r.wait(b, "capture", limit, "done", "error"); if e != nil { return e }
	if st.State == "error" {
		return fmt.Errorf("capture: %s", st.Error)
	}
	if st.Protocol != 3 || st.ID != j.set {
		return fmt.Errorf("status of %q has protocol %d, expected %s and 3", st.ID, st.Protocol, j.set)
	}
	e = b.Fetch(r.ctx, j.set, dir); if e != nil { return fmt.Errorf("fetch: %w", e) }
	got, e := filepath.Glob(filepath.Join(dir, "*.png")); if e != nil { return e }
	frames := j.cab.CaptureFrames()
	for _, frame := range frames {
		if _, e = os.Stat(filepath.Join(dir, fmt.Sprintf("frame_%08d.png", frame))); e != nil {
			return fmt.Errorf("missing frame %d", frame)
		}
	}
	if len(got) != len(frames) {
		return fmt.Errorf("%d PNGs, expected %d", len(got), len(frames))
	}
	return nil
}

// wait polls the status until it reaches one of the given states or the limit
func (r *runner) wait(b Board, stage string, limit time.Duration, states ...string) (BoardStatus, error) {
	deadline := time.Now().Add(limit)
	for {
		st, e := b.Status(r.ctx); if e != nil { return st, fmt.Errorf("%s status: %w", stage, e) }
		if st.Main != "" {
			r.mu.Lock()
			if r.progress.Main == "" {
				r.progress.Main = st.Main
			}
			r.mu.Unlock()
		}
		for _, state := range states {
			if st.State == state {
				return st, nil
			}
		}
		if time.Now().After(deadline) && st.State == "" {
			return st, fmt.Errorf("%s limit of %s exceeded: no status file", stage, limit.Round(time.Second))
		}
		if time.Now().After(deadline) {
			return st, fmt.Errorf("%s limit of %s exceeded: state %q, frame %d/%d, %d/%d PNGs", stage, limit.Round(time.Second),
				st.State, st.Frame, st.FramesTotal, st.Captured, st.CapturesTotal)
		}
		if e = sleep(r.ctx, r.poll); e != nil {
			return st, e
		}
	}
}

// next blocks while the queue is empty and another worker may still put back
// a retry. A retry goes to another board while there is one
func (r *runner) next(board string) *job {
	r.mu.Lock()
	defer r.mu.Unlock()
	for r.ctx.Err() == nil && (len(r.queue) > 0 || r.busy > 0) {
		for i, j := range r.queue {
			if j.failed_on != board || r.alive == 1 {
				r.queue = append(r.queue[:i], r.queue[i+1:]...)
				r.busy++
				return j
			}
		}
		r.cond.Wait()
	}
	return nil
}

// done ends the work taken with next, putting retry at the head of the queue
func (r *runner) done(retry *job) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if retry != nil {
		r.queue = append([]*job{retry}, r.queue...)
	}
	r.busy--
	r.cond.Broadcast()
}

// record saves a game result in the progress file and the text log
func (r *runner) record(j *job, board string, seconds float64, outcome Outcome, msg string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.progress.Games[j.core+"/"+j.set] = &progress_game{Result: outcome, Board: board, Seconds: seconds, Message: msg}
	line := fmt.Sprintf("%s %-12s %-20s %5.0fs %-5s %s", LogTime(time.Now()), board, j.core+"/"+j.set, seconds, strings.ToUpper(string(outcome)), msg)
	fmt.Fprintln(r.Out, line)
	if f, e := os.OpenFile(filepath.Join(r.Root, "log", r.key+".log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0640); e == nil {
		fmt.Fprintln(f, line)
		f.Close()
	}
	if e := r.save_locked(); e != nil {
		fmt.Fprintln(r.Out, "Cannot save the progress:", e)
	}
}

func (r *runner) printf(format string, args ...any) {
	r.mu.Lock()
	defer r.mu.Unlock()
	fmt.Fprintf(r.Out, format+"\n", args...)
}
