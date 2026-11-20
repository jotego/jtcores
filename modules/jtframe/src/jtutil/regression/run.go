/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"syscall"
	"time"
)

// Options of a MiSTer regression run. Exactly one of Commit, Poll and Core is set
type Options struct {
	Commit    string // full run from <Builds>/<commit>.zip
	Poll      bool   // full run of the newest successful compile-all build
	Core      string // manual run of one core from the working tree
	Boards    []string
	LoadLimit time.Duration
	PublishTo string // github, gitea or none
	Root      string // $JOTEGO/regression
	Builds    string // $JOTEGO/core-builds
	Source    string // JTROOT
	Out       io.Writer
	new_board    func(host, socket_dir string) Board
	deploy_limit time.Duration
}

// The capture limit assumes the lowest refresh rate of the cores, so that
// no game is cut short: 1.2*(M+1)/50 seconds for a CAB whose last line is M
const (
	min_refresh  = 50.0
	capture_slack = 1.2
)

type runner struct {
	Options
	commit, key   string // full SHA; short SHA plus -dirty for dirty manual runs
	work, release string
	ctx           context.Context
	poll          time.Duration
	mu            sync.Mutex
	cond          *sync.Cond
	queue         []*job
	busy, alive   int
	progress      *progress
}

type job struct {
	core, set, mra string
	cab            CabScript
	tries          int
	failed_on      string
	logs           map[string][]byte
}

var errBusy = errors.New("another regression holds the lock")

func Run(ctx context.Context, opts Options) (e error) {
	sources := 0
	for _, set := range []bool{opts.Commit != "", opts.Poll, opts.Core != ""} {
		if set {
			sources++
		}
	}
	if sources != 1 {
		return fmt.Errorf("use one of --commit, --poll and --core")
	}
	if opts.PublishTo != "github" && opts.PublishTo != "gitea" && opts.PublishTo != "none" {
		return fmt.Errorf("--publish-to must be github, gitea or none")
	}
	if opts.new_board == nil {
		opts.new_board = new_ssh_board
	}
	if opts.deploy_limit == 0 {
		opts.deploy_limit = 10 * time.Minute
	}
	lock, e := lock_regression(opts.Root)
	if opts.Poll && e == errBusy {
		fmt.Fprintln(opts.Out, e)
		return nil
	}
	if e != nil {
		return e
	}
	defer lock.Close()
	r := &runner{Options: opts, ctx: ctx, poll: time.Second}
	r.work, e = os.MkdirTemp("", "jtutil-regression-"); if e != nil { return e }
	defer os.RemoveAll(r.work)
	r.release = filepath.Join(r.work, "release")
	switch {
	case opts.Core != "":
		e = r.manual_source()
	case opts.Poll:
		e = r.poll_source()
		if e == nil && r.commit == "" {
			return nil
		}
	default:
		e = r.zip_source(opts.Commit, "")
	}
	if e != nil {
		return e
	}
	e = r.load_jobs(); if e != nil { return e }
	e = r.execute(); if e != nil { return e }
	return r.publish()
}

func lock_regression(root string) (*os.File, error) {
	e := os.MkdirAll(filepath.Join(root, "log"), 0750); if e != nil { return nil, e }
	f, e := os.OpenFile(filepath.Join(root, "log", "lock"), os.O_CREATE|os.O_RDWR, 0640); if e != nil { return nil, e }
	if e = syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); e != nil {
		f.Close()
		if e == syscall.EWOULDBLOCK {
			return nil, errBusy
		}
		return nil, e
	}
	return f, nil
}

// manual_source builds a fresh release folder for one core from the working tree
func (r *runner) manual_source() error {
	head, e := r.git("rev-parse", "HEAD"); if e != nil { return e }
	status, e := r.git("status", "--porcelain"); if e != nil { return e }
	r.commit, r.key = head, head[:7]
	if status != "" {
		r.key += "-dirty"
		fmt.Fprintln(r.Out, "Warning: the working tree is dirty")
	}
	rbf := filepath.Join(r.Source, "release", "mister", "jt"+r.Core+".rbf")
	e = os.MkdirAll(filepath.Join(r.release, "mister"), 0750); if e != nil { return e }
	e = copy_file(rbf, filepath.Join(r.release, "mister", filepath.Base(rbf)))
	if e != nil {
		return fmt.Errorf("%w (build it with jtcore %s -mr)", e, r.Core)
	}
	e = r.tool("jtframe", "mra", r.Core, "--git", "--skipROM", "--skipPocket"); if e != nil { return e }
	return r.tool(filepath.Join(r.Source, "modules", "jtframe", "devops", "reg-cabs.sh"), "-o", filepath.Join(r.release, "cab"), r.Core)
}

func (r *runner) git(args ...string) (string, error) {
	out, e := exec.Command("git", append([]string{"-C", r.Source}, args...)...).Output()
	if e != nil {
		return "", fmt.Errorf("git %s: %w", strings.Join(args, " "), e)
	}
	return strings.TrimSpace(string(out)), nil
}

func (r *runner) tool(name string, args ...string) error {
	cmd := exec.CommandContext(r.ctx, name, args...)
	cmd.Dir, cmd.Env = r.Source, append(os.Environ(), "JTBIN="+r.release)
	out, e := cmd.CombinedOutput()
	if e != nil {
		return fmt.Errorf("%s: %w\n%s", filepath.Base(name), e, out)
	}
	return nil
}

// poll_source selects the newest successful compile-all build that has a zip.
// r.commit stays empty when that build was already tested
func (r *runner) poll_source() error {
	out, e := exec.CommandContext(r.ctx, "gh", "run", "list", "-R", "jotego/jtcores", "--workflow", "compile-all.yaml",
		"--status", "success", "--limit", "20", "--json", "databaseId,headSha").Output()
	if e != nil {
		return fmt.Errorf("gh run list: %w", e)
	}
	var runs []struct {
		ID  int64  `json:"databaseId"`
		SHA string `json:"headSha"`
	}
	e = json.Unmarshal(out, &runs); if e != nil { return e }
	for _, run := range runs {
		if p, _ := read_progress(r.progress_path(run.SHA[:7])); p != nil && p.Status == "complete" {
			fmt.Fprintf(r.Out, "%s was already tested\n", run.SHA[:7])
			return nil
		}
		if e = r.zip_source(run.SHA, fmt.Sprint(run.ID)); e == nil {
			return nil
		}
		fmt.Fprintf(r.Out, "Skipping %s: %v\n", run.SHA[:7], e)
	}
	fmt.Fprintln(r.Out, "No build to test")
	return nil
}

// zip_source unpacks the MiSTer files of <Builds>/<commit>.zip, downloading
// the GitHub artifact of the given run when the zip is missing
func (r *runner) zip_source(commit, run string) (e error) {
	if r.commit, e = r.git("rev-parse", "--verify", commit+"^{commit}"); e != nil {
		return fmt.Errorf("unknown commit %s (git fetch?): %w", commit, e)
	}
	r.key = r.commit[:7]
	zip := filepath.Join(r.Builds, r.key+".zip")
	if _, e = os.Stat(zip); os.IsNotExist(e) && run != "" {
		e = r.download(run, zip)
	}
	if e != nil {
		return e
	}
	out, e := exec.CommandContext(r.ctx, "unzip", "-q", zip, "release/mister/*", "release/cab/*", "release/mra/*.mra",
		"-x", "release/mra/*/*", "-d", r.work).CombinedOutput()
	if e != nil {
		return fmt.Errorf("unzip %s: %w\n%s", zip, e, out)
	}
	return nil
}

func (r *runner) download(run, zip string) error {
	dir, e := os.MkdirTemp(r.Builds, ".download-"); if e != nil { return e }
	defer os.RemoveAll(dir)
	name := filepath.Base(zip)
	out, e := exec.CommandContext(r.ctx, "gh", "run", "download", run, "-R", "jotego/jtcores", "-n", name, "-D", dir).CombinedOutput()
	if e != nil {
		return fmt.Errorf("gh run download %s: %w\n%s", run, e, out)
	}
	return os.Rename(filepath.Join(dir, name), zip)
}

// load_jobs lists release/cab/*.cab and queues the games that need a result
func (r *runner) load_jobs() (e error) {
	if r.progress, e = read_progress(r.progress_path(r.key)); os.IsNotExist(e) {
		r.progress, e = &progress{Commit: r.commit, Dirty: strings.HasSuffix(r.key, "-dirty"), Started: time.Now(), Games: map[string]*progress_game{}}, nil
	}
	if e != nil {
		return e
	}
	mras, e := index_mras(filepath.Join(r.release, "mra")); if e != nil { return e }
	cabs, e := filepath.Glob(filepath.Join(r.release, "cab", "*.cab")); if e != nil { return e }
	sort.Strings(cabs)
	for _, path := range cabs {
		j := &job{set: strings.TrimSuffix(filepath.Base(path), ".cab"), logs: map[string][]byte{}}
		j.core, j.mra = strings.TrimPrefix(mras[j.set][1], "jt"), mras[j.set][0]
		if r.Core != "" {
			j.core = r.Core
		}
		key := j.core + "/" + j.set
		old := r.progress.Games[key]
		if old != nil && r.Core == "" && (old.Result == Pass || old.Result == New || old.Result == Fail || old.Result == Error && r.Poll) {
			continue
		}
		r.progress.Games[key] = &progress_game{Result: Pending}
		if j.cab, e = ReadCab(path); e == nil && !j.cab.HasCapture {
			e = fmt.Errorf("no capture line")
		}
		if e == nil && j.mra == "" {
			e = fmt.Errorf("no MRA for %s", j.set)
		}
		if e != nil {
			r.record(j, "", 0, Error, e.Error())
			continue
		}
		r.queue = append(r.queue, j)
	}
	if len(r.progress.Games) == 0 {
		return fmt.Errorf("no games in %s/cab", r.release)
	}
	r.progress.Status = "running"
	return r.save()
}

// index_mras maps each setname to its MRA file name and RBF name
func index_mras(dir string) (map[string][2]string, error) {
	files, e := filepath.Glob(filepath.Join(dir, "*.mra")); if e != nil { return nil, e }
	mras := map[string][2]string{}
	for _, file := range files {
		var mra struct {
			Setname string `xml:"setname"`
			RBF     string `xml:"rbf"`
		}
		data, e := os.ReadFile(file); if e != nil { return nil, e }
		if e = xml.Unmarshal(data, &mra); e != nil {
			return nil, fmt.Errorf("%s: %w", file, e)
		}
		mras[mra.Setname] = [2]string{filepath.Base(file), mra.RBF}
	}
	return mras, nil
}

func (r *runner) publish() error {
	if r.Core != "" || r.PublishTo == "none" {
		return nil
	}
	p := r.progress
	summary := Summary{RunID: p.Commit, Build: BuildIdentity{Repository: "jotego/jtcores", SHA: p.Commit, Ref: "master", Event: "push"},
		Started: p.Started, Finished: p.Updated, Duration: p.Updated.Sub(p.Started), Status: p.Status, Coverage: map[string]int{}}
	for _, key := range sorted_keys(p.Games) {
		g := p.Games[key]
		core, set, _ := strings.Cut(key, "/")
		summary.Games = append(summary.Games, GameResult{Core: core, Setname: set, Outcome: g.Result, Stage: g.Board, Message: g.Message})
		summary.Coverage[string(g.Result)]++
	}
	var e error
	if r.PublishTo == "gitea" {
		gitea := GiteaPublisher{Server: os.Getenv("GITEA_SERVER_URL"), Repository: os.Getenv("GITEA_REPOSITORY"), Token: os.Getenv("GITEA_TOKEN")}
		if e = gitea.Preflight(summary.Build); e == nil {
			p.GiteaReportURL, e = gitea.Publish(summary, p.GiteaReportURL)
		}
	} else if p.ReportURL == "" {
		github := GitHubPublisher{TempDir: r.work}
		if e = github.Preflight(summary.Build); e == nil {
			p.ReportURL, _, e = github.Publish(summary)
		}
	}
	if e != nil {
		return fmt.Errorf("publish: %w", e)
	}
	return r.save()
}
