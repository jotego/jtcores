/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"archive/zip"
	"bytes"
	"context"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// fake_lab holds the state shared by the fake boards of one test
type fake_lab struct {
	mu    sync.Mutex
	fail  map[string]int   // capture errors left per setname
	color map[string]uint8 // frame colour per setname
	dead  map[string]bool  // boards whose Main is not running
	hang  map[string]bool  // boards whose deploy never ends
	loads []string
	clean map[string]int // Clean calls per setname
}

type fake_board struct {
	lab           *fake_lab
	name, release string
	st            BoardStatus
}

func (b *fake_board) Name() string { return b.name }

func (b *fake_board) Deploy(ctx context.Context, release, folder string) error {
	b.release = release
	b.lab.mu.Lock()
	hang := b.lab.hang[b.name]
	b.lab.mu.Unlock()
	if hang {
		<-ctx.Done()
		return ctx.Err()
	}
	return nil
}

func (b *fake_board) Health(ctx context.Context) error {
	b.lab.mu.Lock()
	defer b.lab.mu.Unlock()
	if b.lab.dead[b.name] {
		return fmt.Errorf("Main is not running")
	}
	return nil
}

func (b *fake_board) Load(ctx context.Context, mra string) error {
	b.lab.mu.Lock()
	defer b.lab.mu.Unlock()
	b.lab.loads = append(b.lab.loads, filepath.Base(mra))
	b.st = BoardStatus{State: "loaded", MRA: mra, Main: "fake-main"}
	return nil
}

func (b *fake_board) Send(ctx context.Context, command string) error {
	words := strings.Fields(command)
	if len(words) != 3 || words[0] != "cab_session_start" || !strings.HasSuffix(words[2], "/cab/"+words[1]+".cab") {
		return fmt.Errorf("unexpected command %q", command)
	}
	b.lab.mu.Lock()
	defer b.lab.mu.Unlock()
	b.st = BoardStatus{State: "done", ID: words[1], Protocol: 3}
	if b.lab.fail[words[1]] > 0 {
		b.lab.fail[words[1]]--
		b.st = BoardStatus{State: "error", Error: "capture_missed_frame:7"}
	}
	return nil
}

func (b *fake_board) Status(ctx context.Context) (BoardStatus, error) { return b.st, nil }

func (b *fake_board) Fetch(ctx context.Context, id, dir string) error {
	cab, e := ReadCab(filepath.Join(b.release, "cab", id+".cab")); if e != nil { return e }
	b.lab.mu.Lock()
	shade := b.lab.color[id]
	b.lab.mu.Unlock()
	img := image.NewRGBA(image.Rect(0, 0, 4, 4))
	img.Set(1, 1, color.RGBA{shade, 0, 0, 255})
	for _, frame := range cab.CaptureFrames() {
		var data bytes.Buffer
		png.Encode(&data, img)
		e = os.WriteFile(filepath.Join(dir, fmt.Sprintf("frame_%08d.png", frame)), data.Bytes(), 0640); if e != nil { return e }
	}
	return nil
}

func (b *fake_board) Log(ctx context.Context) ([]byte, error) { return []byte("log of " + b.name), nil }
func (b *fake_board) Clean(ctx context.Context, id string) error {
	b.lab.mu.Lock()
	defer b.lab.mu.Unlock()
	b.lab.clean[id]++
	return nil
}
func (b *fake_board) Reboot(ctx context.Context) error        { return b.Health(ctx) }
func (b *fake_board) Close()                                  {}

// fake_run makes a git repository and its compile-all zip with three games
func fake_run(t *testing.T, lab *fake_lab, boards ...string) (Options, *bytes.Buffer) {
	dir := t.TempDir()
	source, builds := filepath.Join(dir, "src"), filepath.Join(dir, "builds")
	os.MkdirAll(builds, 0750)
	for _, args := range [][]string{{"init", "-q", source}, {"-C", source, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "t"}} {
		if out, e := exec.Command("git", args...).CombinedOutput(); e != nil {
			t.Fatalf("git: %v %s", e, out)
		}
	}
	sha, _ := exec.Command("git", "-C", source, "rev-parse", "--short=7", "HEAD").Output()
	f, _ := os.Create(filepath.Join(builds, strings.TrimSpace(string(sha))+".zip"))
	z := zip.NewWriter(f)
	files := map[string]string{"release/mister/jtaaa.rbf": "rbf", "release/mister/jtbbb.rbf": "rbf",
		"release/mra/_alternatives/_A1/A1 (clone).mra": "<misterromdescription><setname>a1c</setname><rbf>jtaaa</rbf></misterromdescription>"}
	for set, core := range map[string]string{"a1": "aaa", "a2": "aaa", "b1": "bbb"} {
		files["release/mra/Game "+set+" (World).mra"] = "<misterromdescription><setname>" + set + "</setname><rbf>jt" + core + "</rbf></misterromdescription>"
		files["release/cab/"+set+".cab"] = "capture 100\n=250\n"
	}
	for name, data := range files {
		w, _ := z.Create(name)
		w.Write([]byte(data))
	}
	z.Close()
	f.Close()
	out := &bytes.Buffer{}
	opts := Options{Commit: "HEAD", Boards: boards, PublishTo: "none", Root: filepath.Join(dir, "regression"), Builds: builds, Source: source, Out: out}
	opts.new_board = func(host, sockets string) Board { return &fake_board{lab: lab, name: host} }
	return opts, out
}

func new_lab() *fake_lab {
	return &fake_lab{fail: map[string]int{}, color: map[string]uint8{}, dead: map[string]bool{}, hang: map[string]bool{}, clean: map[string]int{}}
}

func run_games(t *testing.T, opts Options, out *bytes.Buffer) *progress {
	if e := Run(context.Background(), opts); e != nil {
		t.Fatalf("%v\n%s", e, out)
	}
	logs, _ := filepath.Glob(filepath.Join(opts.Root, "log", "*.json"))
	if len(logs) != 1 {
		t.Fatalf("progress files %v", logs)
	}
	p, e := read_progress(logs[0]); if e != nil { t.Fatal(e) }
	return p
}

func check_results(t *testing.T, p *progress, want map[string]Outcome) {
	for game, outcome := range want {
		if g := p.Games[game]; g == nil || g.Result != outcome {
			t.Errorf("%s: %+v, want %s", game, g, outcome)
		}
	}
	if len(p.Games) != len(want) {
		t.Errorf("%d games in the progress, want %d", len(p.Games), len(want))
	}
}

func TestRunNewPassFail(t *testing.T) {
	lab := new_lab()
	opts, out := fake_run(t, lab, "m1", "m2")
	p := run_games(t, opts, out)
	check_results(t, p, map[string]Outcome{"aaa/a1": New, "aaa/a2": New, "bbb/b1": New})
	if p.Status != "complete" || p.Main != "fake-main" || len(p.Commit) != 40 {
		t.Errorf("progress header %+v", p)
	}
	if pngs, _ := filepath.Glob(filepath.Join(opts.Root, "aaa", "a1", "new", "*.png")); len(pngs) != 2 {
		t.Errorf("new PNGs %v", pngs)
	}
	for _, set := range []string{"aaa/a1", "aaa/a2", "bbb/b1"} {
		game := filepath.Join(opts.Root, set)
		if e := os.Rename(filepath.Join(game, "new"), filepath.Join(game, "ref")); e != nil {
			t.Fatal(e)
		}
	}
	os.Remove(filepath.Join(opts.Root, "log", p.Commit[:7]+".json"))
	lab.color["a2"] = 9
	p = run_games(t, opts, out)
	check_results(t, p, map[string]Outcome{"aaa/a1": Pass, "aaa/a2": Fail, "bbb/b1": Pass})
	if p.Games["aaa/a2"].Message != "2/2 frames differ" {
		t.Errorf("fail message %q", p.Games["aaa/a2"].Message)
	}
	if _, e := os.Stat(filepath.Join(opts.Root, "aaa", "a2", "fail", "MiSTer.log")); e != nil {
		t.Error("the fail folder has no MiSTer.log")
	}
	if _, e := os.Stat(filepath.Join(opts.Root, "aaa", "a1", "new")); !os.IsNotExist(e) {
		t.Error("new folder left after a pass")
	}
}

func TestRunRetryOnce(t *testing.T) {
	lab := new_lab()
	lab.fail["a1"], lab.fail["a2"] = 1, 5
	opts, out := fake_run(t, lab, "m1", "m2")
	p := run_games(t, opts, out)
	check_results(t, p, map[string]Outcome{"aaa/a1": New, "aaa/a2": Error, "bbb/b1": New})
	if lab.clean["a1"] != 2 || lab.clean["a2"] != 2 || lab.clean["b1"] != 1 {
		t.Errorf("/tmp/jtcap/<id> removals %v", lab.clean)
	}
	if lab.fail["a2"] != 3 {
		t.Errorf("a2 ran %d times, want 2", 5-lab.fail["a2"])
	}
	if p.Games["aaa/a2"].Message != "capture: capture_missed_frame:7" {
		t.Errorf("error message %q", p.Games["aaa/a2"].Message)
	}
	logs, _ := filepath.Glob(filepath.Join(opts.Root, "aaa", "a2", "error", "MiSTer-*.log"))
	if len(logs) != 2 {
		t.Errorf("error logs %v", logs)
	}
	if strings.Contains(logs[0], "-m1.log") == strings.Contains(logs[1], "-m1.log") {
		t.Errorf("both attempts on the same board: %v", logs)
	}
	// --commit reruns the ERROR games only
	lab.fail["a2"], lab.loads = 0, nil
	p = run_games(t, opts, out)
	check_results(t, p, map[string]Outcome{"aaa/a1": New, "aaa/a2": New, "bbb/b1": New})
	if len(lab.loads) != 1 || lab.loads[0] != "Game a2 (World).mra" {
		t.Errorf("loads %v", lab.loads)
	}
	if _, e := os.Stat(filepath.Join(opts.Root, "aaa", "a2", "error")); !os.IsNotExist(e) {
		t.Error("error folder left after a good result")
	}
}

func TestRunRetiresBoard(t *testing.T) {
	lab := new_lab()
	lab.dead["m1"] = true
	opts, out := fake_run(t, lab, "m1", "m2")
	p := run_games(t, opts, out)
	check_results(t, p, map[string]Outcome{"aaa/a1": New, "aaa/a2": New, "bbb/b1": New})
	for _, g := range p.Games {
		if g.Board != "m2" {
			t.Errorf("result from %s", g.Board)
		}
	}
	if !strings.Contains(out.String(), "m1: recovery failed, board retired") {
		t.Errorf("m1 not retired:\n%s", out)
	}
	// with every board gone the run stops and the games left stay pending
	lab.dead["m2"] = true
	opts.Boards = []string{"m2"}
	os.Remove(filepath.Join(opts.Root, "log", p.Commit[:7]+".json"))
	if e := Run(context.Background(), opts); e == nil || !strings.Contains(e.Error(), "3 games were not run") {
		t.Errorf("got %v", e)
	}
	p, _ = read_progress(filepath.Join(opts.Root, "log", p.Commit[:7]+".json"))
	check_results(t, p, map[string]Outcome{"aaa/a1": Pending, "aaa/a2": Pending, "bbb/b1": Pending})
	if p.Status != "incomplete" {
		t.Errorf("status %s\n%s", p.Status, out)
	}
}

// a deploy that times out leaves its board out and the others finish the run
func TestRunDeployTimeout(t *testing.T) {
	lab := new_lab()
	lab.hang["m1"] = true
	opts, out := fake_run(t, lab, "m1", "m2")
	opts.deploy_limit = 50 * time.Millisecond
	p := run_games(t, opts, out)
	check_results(t, p, map[string]Outcome{"aaa/a1": New, "aaa/a2": New, "bbb/b1": New})
	if !strings.Contains(out.String(), "m1: deploy failed, board left out: context deadline exceeded") {
		t.Errorf("m1 not left out:\n%s", out)
	}
}

// game errors never retire a board, however many there are in a row
func TestRunGameErrorsKeepBoard(t *testing.T) {
	lab := new_lab()
	lab.fail["a1"], lab.fail["a2"], lab.fail["b1"] = 5, 5, 5
	opts, out := fake_run(t, lab, "m1")
	p := run_games(t, opts, out)
	check_results(t, p, map[string]Outcome{"aaa/a1": Error, "aaa/a2": Error, "bbb/b1": Error})
	if strings.Contains(out.String(), "retired") {
		t.Errorf("board retired:\n%s", out)
	}
}

func TestRunResumes(t *testing.T) {
	lab := new_lab()
	opts, out := fake_run(t, lab, "m1")
	sha, _ := exec.Command("git", "-C", opts.Source, "rev-parse", "HEAD").Output()
	commit := strings.TrimSpace(string(sha))
	os.MkdirAll(filepath.Join(opts.Root, "log"), 0750)
	old := fmt.Sprintf(`{"commit":"%s","status":"running","games":{"aaa/a1":{"result":"pass"},"aaa/a2":{"result":"pending"}}}`, commit)
	os.WriteFile(filepath.Join(opts.Root, "log", commit[:7]+".json"), []byte(old), 0640)
	p := run_games(t, opts, out)
	check_results(t, p, map[string]Outcome{"aaa/a1": Pass, "aaa/a2": New, "bbb/b1": New})
	if len(lab.loads) != 2 {
		t.Errorf("loads %v", lab.loads)
	}
	if _, e := ReadProgress(opts.Root, commit); e != nil {
		t.Errorf("mame-frames cannot read the progress: %v", e)
	}
}

func TestRunPollWhileBusy(t *testing.T) {
	opts, out := fake_run(t, new_lab(), "m1")
	lock, e := lock_regression(opts.Root); if e != nil { t.Fatal(e) }
	defer lock.Close()
	opts.Commit, opts.Poll = "", true
	if e = Run(context.Background(), opts); e != nil || !strings.Contains(out.String(), errBusy.Error()) {
		t.Errorf("got %v, %q", e, out)
	}
}

// manual runs keep their progress apart from the commit's full run
func TestManualProgressKey(t *testing.T) {
	opts, _ := fake_run(t, new_lab(), "m1")
	os.WriteFile(filepath.Join(opts.Source, "untracked"), nil, 0640)
	opts.Core = "zzz"
	r := &runner{Options: opts, ctx: context.Background(), release: t.TempDir()}
	if e := r.manual_source(); e == nil || !strings.Contains(e.Error(), "jtcore zzz -mr") {
		t.Errorf("got %v", e)
	}
	if r.key != "manual-"+r.commit[:7]+"-dirty" || r.folder != "_"+r.commit[:7]+"-dirty" {
		t.Errorf("key %s, folder %s", r.key, r.folder)
	}
}
