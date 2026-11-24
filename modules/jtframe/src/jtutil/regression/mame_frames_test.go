/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"bytes"
	"context"
	"fmt"
	"image/color"
	"os"
	"path/filepath"
	"os/exec"
	"strings"
	"sync"
	"testing"
)

var mame_test_colors = []color.RGBA{{R: 0x10, G: 0x20, B: 0x30}, {R: 0x40, G: 0x50, B: 0x60}, {R: 0x70, G: 0x80, B: 0x90}}

// mame_test_lab has cps1/good, which MAME matches, cps1/bad, whose MAME
// frames come in the wrong order, cps1/done, which has a ref, and 1942/other
func mame_test_lab(t *testing.T) MameFrameOptions {
	root, source := t.TempDir(), t.TempDir()
	for _, game := range []string{"cps1/good", "cps1/bad", "cps1/done", "1942/other"} {
		for k, c := range mame_test_colors {
			write_test_png(t, filepath.Join(root, game, "new", fmt.Sprintf("frame_%08d.png", 100*(k+1))), c)
		}
		cab := filepath.Join(source, "cores", filepath.Dir(game), "ver", filepath.Base(game), "reg.cab")
		if e := os.MkdirAll(filepath.Dir(cab), 0750); e != nil { t.Fatal(e) }
		if e := os.WriteFile(cab, []byte("capture 100\n50\ncoin\n=400\n"), 0640); e != nil { t.Fatal(e) }
	}
	write_test_png(t, filepath.Join(root, "cps1", "done", "ref", "frame_00000100.png"), mame_test_colors[0])
	capture := func(ctx context.Context, g *mame_game, work string) (mame_capture, error) {
		if g.cab.Lines != 401 { t.Errorf("CAB has %d lines", g.cab.Lines) }
		colors := []color.RGBA{{}, {}, mame_test_colors[0], {}, mame_test_colors[1], mame_test_colors[1], mame_test_colors[2], {}}
		if g.set == "bad" {
			colors[2], colors[6] = colors[6], colors[2]
		}
		var paths []string
		for k, c := range colors {
			c.R, c.G, c.B = c.R|0x0f, c.G|0x0f, c.B|0x0f // below COLORW=4
			path := filepath.Join(work, "snapshots", fmt.Sprintf("mame_%08d.png", k+1))
			write_test_png(t, path, c)
			paths = append(paths, path)
		}
		return mame_capture{paths, 60}, nil
	}
	return MameFrameOptions{Root: root, Source: source, Core: "cps1", Jobs: 2, Out: &bytes.Buffer{}, capture: capture,
		ColorW: func(core string) (int, error) { return 4, nil }}
}

func mame_test_verdicts(results []MameFrameResult) string {
	var s []string
	for _, r := range results {
		s = append(s, r.Setname+"="+r.Verdict)
	}
	return strings.Join(s, " ")
}

func TestMameFramesPromotesMatches(t *testing.T) {
	opts := mame_test_lab(t)
	results, e := RunMameFrames(context.Background(), opts); if e != nil { t.Fatal(e) }
	if got := mame_test_verdicts(results); got != "bad=FAIL good=PASS" {
		t.Fatalf("verdicts %s\n%s", got, opts.Out)
	}
	good := filepath.Join(opts.Root, "cps1", "good")
	if _, e := os.Stat(filepath.Join(good, "new")); e == nil { t.Error("good/new is still there") }
	crc, e := reference_crc(filepath.Join(good, "ref")); if e != nil { t.Fatal(e) }
	if log, _ := os.ReadFile(filepath.Join(good, "log")); !strings.HasSuffix(string(log), " mame          ACCEPT      "+crc+"\n") {
		t.Errorf("good log is %q", log)
	}
	if !strings.Contains(results[1].Detail, "MAME frames 3..7") || !strings.Contains(results[1].Detail, "RGB444") {
		t.Errorf("detail %q", results[1].Detail)
	}
	for _, path := range []string{"cps1/bad/new/frame_00000300.png", "cps1/done/new/frame_00000300.png", "1942/other/new/frame_00000300.png"} {
		if _, e := os.Stat(filepath.Join(opts.Root, path)); e != nil { t.Error(e) }
	}
	for _, path := range []string{"cps1/bad/ref", "cps1/bad/log", "1942/other/ref"} {
		if _, e := os.Stat(filepath.Join(opts.Root, path)); e == nil { t.Errorf("%s was written", path) }
	}
}

func TestMameFramesDryrunChangesNothing(t *testing.T) {
	opts := mame_test_lab(t)
	opts.Dryrun, opts.Core, opts.Setnames = true, "", []string{"good", "other"}
	results, e := RunMameFrames(context.Background(), opts); if e != nil { t.Fatal(e) }
	if got := mame_test_verdicts(results); got != "other=PASS good=PASS" {
		t.Fatalf("verdicts %s", got)
	}
	for _, game := range []string{"cps1/good", "1942/other"} {
		if _, e := os.Stat(filepath.Join(opts.Root, game, "ref")); e == nil { t.Errorf("%s was promoted", game) }
		if _, e := os.Stat(filepath.Join(opts.Root, game, "log")); e == nil { t.Errorf("%s was logged", game) }
	}
}

func TestMameFramesReportsBusyWhileARunHoldsTheLock(t *testing.T) {
	opts := mame_test_lab(t)
	lock, e := lock_regression(opts.Root); if e != nil { t.Fatal(e) }
	defer lock.Close()
	results, e := RunMameFrames(context.Background(), opts); if e != nil { t.Fatal(e) }
	if got := mame_test_verdicts(results); got != "bad=FAIL good=BUSY" {
		t.Fatalf("verdicts %s", got)
	}
	if _, e := os.Stat(filepath.Join(opts.Root, "cps1", "good", "new", "frame_00000100.png")); e != nil { t.Error(e) }
	if _, e := os.Stat(filepath.Join(opts.Root, "cps1", "good", "ref")); e == nil { t.Error("promoted without the lock") }
}

func TestMameFramesRefusesChangedOrBlankFrames(t *testing.T) {
	opts := mame_test_lab(t)
	inner := opts.capture
	opts.capture = func(ctx context.Context, g *mame_game, work string) (mame_capture, error) {
		write_test_png(t, filepath.Join(g.dir, "frame_00000100.png"), color.RGBA{R: 0xff})
		return inner(ctx, g, work)
	}
	opts.Setnames = []string{"good"}
	results, e := RunMameFrames(context.Background(), opts); if e != nil { t.Fatal(e) }
	if len(results) != 1 || results[0].Verdict != "FAIL" || !strings.Contains(results[0].Detail, "changed") {
		t.Fatalf("results %+v", results)
	}
	dir := filepath.Join(t.TempDir(), "new")
	for k := 0; k < 2; k++ {
		write_test_png(t, filepath.Join(dir, fmt.Sprintf("frame_%08d.png", k)), color.RGBA{})
	}
	frames, e := read_new_frames(dir); if e != nil { t.Fatal(e) }
	if e = check_mame_quality(dir, frames); e == nil || !strings.Contains(e.Error(), "black") { t.Errorf("black frames: %v", e) }
	write_test_png(t, filepath.Join(dir, "frame_00000000.png"), color.RGBA{R: 9})
	write_test_png(t, filepath.Join(dir, "frame_00000001.png"), color.RGBA{R: 9})
	if e = check_mame_quality(dir, frames); e == nil || !strings.Contains(e.Error(), "identical") { t.Errorf("identical frames: %v", e) }
}

func TestReadNewFrames(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"frame_00000250.png", "frame_00000050.png", "frame_00001000.png"} {
		write_test_png(t, filepath.Join(dir, name), color.RGBA{})
	}
	frames, e := read_new_frames(dir); if e != nil { t.Fatal(e) }
	if len(frames) != 3 || frames[0].number != 50 || frames[1].number != 250 || frames[2].number != 1000 {
		t.Errorf("frames %v", frames)
	}
	os.WriteFile(filepath.Join(dir, "MiSTer.log"), nil, 0640)
	if _, e = read_new_frames(dir); e == nil { t.Error("a log file was accepted") }
	if _, e = read_new_frames(t.TempDir()); e == nil { t.Error("an empty new/ was accepted") }
}

func TestMameCaptureLuaReplaysCab(t *testing.T) {
	cab, e := ParseCab(strings.NewReader("capture 10\n5\ncoin 1p\n=20 2b3\n")); if e != nil { t.Fatal(e) }
	lua, e := make_mame_capture_lua(cab, 520, "/snap", "/done", "/fail"); if e != nil { t.Fatal(e) }
	for _, want := range []string{`{ bit = 0, token = "COIN1" }`, `{ bit = 2, token = "START1" }`, `{ bit = 20, token = "P2_BUTTON3" }`,
		"{ 5, 0 }", "{ 1, 5 }", "{ 14, 0 }", "{ 1, 1048576 }", "local frame_limit = 520", "local cab_frames = 21"} {
		if !strings.Contains(lua, want) { t.Errorf("missing %q", want) }
	}
	for _, script := range []string{"test\n", "reset\n", "dipsw=1\n", "cheat=x\n", "dump\n"} {
		cab, e := ParseCab(strings.NewReader(script)); if e != nil { t.Fatal(e) }
		if _, e = make_mame_capture_lua(cab, 10, "", "", ""); e == nil { t.Errorf("%q was mapped", script) }
	}
}

func TestMameFramesPromotesParallelMatches(t *testing.T) {
	opts := mame_test_lab(t)
	var sets []string
	for k := 0; k < 8; k++ {
		set := fmt.Sprintf("good%d", k)
		sets = append(sets, set)
		for _, dir := range []string{filepath.Join(opts.Root, "cps1"), filepath.Join(opts.Source, "cores", "cps1", "ver")} {
			if e := exec.Command("cp", "-r", filepath.Join(dir, "good"), filepath.Join(dir, set)).Run(); e != nil { t.Fatal(e) }
		}
	}
	opts.Setnames, opts.Jobs = sets, 4
	var mu sync.Mutex
	count, together := 0, make(chan struct{})
	inner := opts.capture
	opts.capture = func(ctx context.Context, g *mame_game, work string) (mame_capture, error) {
		capture, e := inner(ctx, g, work)
		mu.Lock()
		if count++; count == opts.Jobs {
			close(together) // the first games finish together
		}
		mu.Unlock()
		<-together
		return capture, e
	}
	results, e := RunMameFrames(context.Background(), opts); if e != nil { t.Fatal(e) }
	if len(results) != len(sets) {
		t.Fatalf("%d results", len(results))
	}
	for _, r := range results {
		if r.Verdict != "PASS" { t.Errorf("%s is %s: %s", r.Setname, r.Verdict, r.Detail) }
		if _, e := os.Stat(filepath.Join(opts.Root, "cps1", r.Setname, "ref")); e != nil { t.Error(e) }
	}
}

func TestMameFramesFailsOnlyTheGamesOfABadCore(t *testing.T) {
	opts := mame_test_lab(t)
	opts.Core, opts.Dryrun = "", true
	opts.ColorW = func(core string) (int, error) {
		if core == "1942" { return 0, fmt.Errorf("broken macros") }
		return 4, nil
	}
	results, e := RunMameFrames(context.Background(), opts); if e != nil { t.Fatal(e) }
	if got := mame_test_verdicts(results); got != "other=FAIL bad=FAIL good=PASS" {
		t.Fatalf("verdicts %s", got)
	}
	if !strings.Contains(results[0].Detail, "broken macros") { t.Errorf("detail %q", results[0].Detail) }
}

func TestMameFramesReplaysTheCapturedCab(t *testing.T) {
	opts := mame_test_lab(t)
	git := func(args ...string) string {
		out, e := exec.Command("git", append([]string{"-C", opts.Source, "-c", "user.name=t", "-c", "user.email=t@t"}, args...)...).Output()
		if e != nil { t.Fatal(args, e) }
		return strings.TrimSpace(string(out))
	}
	git("init", "-q")
	git("add", ".")
	git("commit", "-qm", "cabs")
	commit := git("rev-parse", "--short=7", "HEAD")
	cab := filepath.Join(opts.Source, "cores", "cps1", "ver", "good", "reg.cab")
	if e := os.WriteFile(cab, []byte("capture 100\n=900\n"), 0640); e != nil { t.Fatal(e) }
	row := "2026-11-23 14:01:07 " + commit + "       NEW         --------\n"
	if e := os.WriteFile(filepath.Join(opts.Root, "cps1", "good", "log"), []byte(row), 0640); e != nil { t.Fatal(e) }
	opts.Setnames, opts.Dryrun = []string{"good", "bad"}, true
	results, e := RunMameFrames(context.Background(), opts); if e != nil { t.Fatal(e) }
	if got := mame_test_verdicts(results); got != "bad=FAIL good=PASS" {
		t.Fatalf("verdicts %s\n%s", got, opts.Out)
	}
	out := opts.Out.(*bytes.Buffer).String()
	if strings.Contains(out, "cps1/good        uses") || !strings.Contains(out, "cps1/bad         uses the reg.cab of the working tree (no commit in the log)") {
		t.Errorf("output:\n%s", out)
	}
}
