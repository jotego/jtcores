/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"context"
	"encoding/xml"
	"fmt"
	"image"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"jotego/jtframe/macros"
)

// MameFrameOptions selects the games that mame-frames compares with MAME
type MameFrameOptions struct {
	Root     string   // $JOTEGO/regression
	Source   string   // JTROOT, for the reg.cab files, core macros and MRA files
	Core     string   // only the games of this core
	Setnames []string // only these games
	Dryrun   bool     // compare, but promote nothing
	Jobs     int      // games compared at the same time
	MAME     string   // MAME executable
	ROMPath  string   // MAME ROM folder
	Out      io.Writer
	// ColorW gives the JTFRAME_COLORW of a core. The default, CoreColorW,
	// runs the macro parser in this process, which may exit on a bad core
	ColorW  func(core string) (int, error)
	capture func(ctx context.Context, g *mame_game, work string) (mame_capture, error)
}

// MameFrameResult is the outcome of one game: PASS, FAIL or BUSY.
// BUSY is a match that could not be promoted while a regression run held the lock
type MameFrameResult struct {
	Core, Setname, Verdict, Detail string
}

type mame_game struct {
	core, set, dir string
	frames         []mame_frame
	crc            string
	bits           int
	cab            CabScript
}

type mame_frame struct {
	number int // CAB frame
	name   string
}

// mame_capture lists the MAME frames, mame_00000001.png onwards, in order
type mame_capture struct {
	paths   []string
	refresh float64
}

// RunMameFrames compares the new/ frames of each game that has no ref/ with
// the frames that MAME renders for its reg.cab. Each FPGA frame must equal,
// at the precision of the MiSTer captures, a MAME frame later than the one
// that matched the previous FPGA frame. A match promotes new/ to ref/ as
// --accept does, logged as mame. A mismatch leaves the game untouched
func RunMameFrames(ctx context.Context, opts MameFrameOptions) ([]MameFrameResult, error) {
	if opts.Jobs < 1 {
		return nil, fmt.Errorf("jobs must be positive")
	}
	if opts.Out == nil {
		opts.Out = io.Discard
	}
	if opts.ColorW == nil {
		opts.ColorW = func(core string) (int, error) { return CoreColorW(opts.Source, core) }
	}
	if opts.capture == nil {
		mame, e := exec.LookPath(opts.MAME); if e != nil { return nil, fmt.Errorf("MAME executable: %w", e) }
		opts.capture = func(ctx context.Context, g *mame_game, work string) (mame_capture, error) {
			return run_mame(ctx, mame, opts.ROMPath, opts.Source, g, work)
		}
	}
	games, results, e := find_mame_games(opts); if e != nil { return nil, e }
	colorw := map[string]func() (int, error){}
	var pending []*mame_game
	for _, g := range games {
		if colorw[g.core] == nil {
			bits, e := opts.ColorW(g.core)
			colorw[g.core] = func() (int, error) { return bits, e }
		}
		bits, e := colorw[g.core]()
		if e == nil {
			g.bits = capture_bits(bits)
			e = read_game_cab(opts, g)
		}
		if e != nil {
			results = append(results, MameFrameResult{g.core, g.set, "FAIL", compact_mame_error(e.Error())})
			continue
		}
		pending = append(pending, g)
	}
	for _, r := range results {
		fmt.Fprintf(opts.Out, "%-16s %-5s %s\n", r.Core+"/"+r.Setname, r.Verdict, r.Detail)
	}
	var mu, promotion sync.Mutex
	queue := make(chan *mame_game)
	var wg sync.WaitGroup
	for k := 0; k < opts.Jobs && k < len(pending); k++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for g := range queue {
				result := check_mame_game(ctx, opts, g, &promotion)
				mu.Lock()
				fmt.Fprintf(opts.Out, "%-16s %-5s %s\n", g.core+"/"+g.set, result.Verdict, result.Detail)
				results = append(results, result)
				mu.Unlock()
			}
		}()
	}
	for _, g := range pending {
		if ctx.Err() != nil {
			break
		}
		queue <- g
	}
	close(queue)
	wg.Wait()
	sort.Slice(results, func(i, j int) bool {
		if results[i].Core != results[j].Core {
			return results[i].Core < results[j].Core
		}
		return results[i].Setname < results[j].Setname
	})
	return results, ctx.Err()
}

// find_mame_games lists the games with new/ frames and no ref/.
// Games whose new/ cannot be read become FAIL results
func find_mame_games(opts MameFrameOptions) ([]*mame_game, []MameFrameResult, error) {
	selected := map[string]bool{}
	for _, set := range opts.Setnames {
		selected[set] = true
	}
	dirs, e := filepath.Glob(filepath.Join(opts.Root, "*", "*", "new")); if e != nil { return nil, nil, e }
	sort.Strings(dirs)
	var games []*mame_game
	var failed []MameFrameResult
	for _, dir := range dirs {
		game := filepath.Dir(dir)
		g := &mame_game{core: filepath.Base(filepath.Dir(game)), set: filepath.Base(game), dir: dir}
		if g.core == "log" || opts.Core != "" && g.core != opts.Core || len(selected) > 0 && !selected[g.set] {
			continue
		}
		if _, e := os.Lstat(filepath.Join(game, "ref")); e == nil {
			continue
		}
		if g.frames, e = read_new_frames(dir); e == nil {
			g.crc, e = reference_crc(dir)
		}
		if e != nil {
			failed = append(failed, MameFrameResult{g.core, g.set, "FAIL", compact_mame_error(e.Error())})
			continue
		}
		games = append(games, g)
	}
	return games, failed, nil
}

// read_new_frames lists the frame_<CAB frame>.png files of new/ in frame order
func read_new_frames(dir string) ([]mame_frame, error) {
	entries, e := os.ReadDir(dir); if e != nil { return nil, e }
	var frames []mame_frame
	for _, entry := range entries {
		number := 0
		if _, e := fmt.Sscanf(entry.Name(), "frame_%08d.png", &number); e != nil || entry.Name() != fmt.Sprintf("frame_%08d.png", number) {
			return nil, fmt.Errorf("unexpected file %s in new/", entry.Name())
		}
		frames = append(frames, mame_frame{number, entry.Name()})
	}
	if len(frames) == 0 {
		return nil, fmt.Errorf("new/ has no frames")
	}
	sort.Slice(frames, func(i, j int) bool { return frames[i].number < frames[j].number })
	return frames, nil
}

// check_mame_game compares one game and promotes it on a match. Promotions
// take turns: each takes log/lock, which other promotions of this process
// would see as busy
func check_mame_game(ctx context.Context, opts MameFrameOptions, g *mame_game, promotion *sync.Mutex) MameFrameResult {
	result := MameFrameResult{Core: g.core, Setname: g.set, Verdict: "FAIL"}
	detail, e := compare_mame_game(ctx, opts, g)
	if e != nil {
		result.Detail = compact_mame_error(e.Error())
		return result
	}
	result.Verdict, result.Detail = "PASS", detail
	if opts.Dryrun {
		return result
	}
	promotion.Lock()
	e = promote_mame_game(opts.Root, g)
	promotion.Unlock()
	switch {
	case e == errBusy:
		result.Verdict, result.Detail = "BUSY", detail+"; not promoted: a regression run holds the lock"
	case e != nil:
		result.Verdict, result.Detail = "FAIL", detail+"; not promoted: "+compact_mame_error(e.Error())
	default:
		result.Detail += "; promoted to ref"
	}
	return result
}

func compare_mame_game(ctx context.Context, opts MameFrameOptions, g *mame_game) (string, error) {
	work, e := os.MkdirTemp("/tmp", "jtutil-mame-frames-"); if e != nil { return "", e }
	defer os.RemoveAll(work)
	fpga := filepath.Join(work, "fpga")
	if e = os.MkdirAll(fpga, 0700); e != nil { return "", e }
	for _, f := range g.frames {
		if e = copy_file(filepath.Join(g.dir, f.name), filepath.Join(fpga, f.name)); e != nil { return "", e }
	}
	if crc, e := reference_crc(g.dir); e != nil || crc != g.crc {
		return "", fmt.Errorf("new/ changed while it was copied")
	}
	if e = check_mame_quality(fpga, g.frames); e != nil { return "", e }
	capture, e := opts.capture(ctx, g, work); if e != nil { return "", e }
	matched, e := match_mame_pngs(ctx, g.frames, fpga, capture.paths, g.bits); if e != nil { return "", e }
	return fmt.Sprintf("%d frames matched at %s and %g Hz; MAME frames %d..%d", len(matched),
		capture_precision_name(g.bits), capture.refresh, matched[0], matched[len(matched)-1]), nil
}

// check_mame_quality refuses frames that prove nothing: all black, or all equal
func check_mame_quality(dir string, frames []mame_frame) error {
	black, same := true, true
	var first image.Image
	for _, f := range frames {
		img, e := decode_png(filepath.Join(dir, f.name)); if e != nil { return e }
		if first == nil {
			first = img
		} else if same && !ImagesEqualRGB(first, img) {
			same = false
		}
		bounds := img.Bounds()
		for y := bounds.Min.Y; y < bounds.Max.Y && black; y++ {
			for x := bounds.Min.X; x < bounds.Max.X; x++ {
				if r, g, b, _ := img.At(x, y).RGBA(); r|g|b != 0 {
					black = false
					break
				}
			}
		}
	}
	if black {
		return fmt.Errorf("all %d frames are black", len(frames))
	}
	if same && len(frames) > 1 {
		return fmt.Errorf("all %d frames are identical", len(frames))
	}
	return nil
}

// promote_mame_game makes new/ the ref/ under the regression lock, unless the
// game changed during the comparison
func promote_mame_game(root string, g *mame_game) error {
	lock, e := lock_regression(root); if e != nil { return e }
	defer lock.Close()
	game := filepath.Dir(g.dir)
	if _, e := os.Lstat(filepath.Join(game, "ref")); e == nil {
		return fmt.Errorf("ref/ appeared during the comparison")
	}
	if crc, e := reference_crc(g.dir); e != nil || crc != g.crc {
		return fmt.Errorf("new/ changed during the comparison")
	}
	_, e = promote_game(game, "mame")
	return e
}

// read_game_cab reads the reg.cab of the commit that captured new/, the last
// NEW row of the game's log, or that of the working tree when git does not have it
func read_game_cab(opts MameFrameOptions, g *mame_game) error {
	path := "cores/" + g.core + "/ver/" + g.set + "/reg.cab"
	commit := ""
	log, _ := os.ReadFile(filepath.Join(filepath.Dir(g.dir), "log"))
	for _, line := range strings.Split(string(log), "\n") {
		if f := strings.Fields(line); len(f) == 5 && f[3] == "NEW" {
			commit = f[2]
		}
	}
	if commit != "" && !strings.HasSuffix(commit, "-dirty") {
		data, e := exec.Command("git", "-C", opts.Source, "show", commit+":"+path).Output()
		if e == nil {
			g.cab, e = ParseCab(strings.NewReader(string(data)))
			if e != nil { return fmt.Errorf("%s of %s: %w", path, commit, e) }
			return nil
		}
	}
	if commit == "" {
		commit = "no commit in the log"
	}
	fmt.Fprintf(opts.Out, "%-16s uses the reg.cab of the working tree (%s)\n", g.core+"/"+g.set, commit)
	var e error
	g.cab, e = ReadCab(filepath.Join(opts.Source, path))
	return e
}

// capture_bits is the precision of the MiSTer captures of a core. Besides
// 24-bit video, arcade_video keeps only 4 bits per channel. jtframe_mister
// sends COLORW=5 as 24-bit video
func capture_bits(colorw int) int {
	if colorw == 5 || colorw == 8 || colorw < 4 {
		return colorw
	}
	return 4
}

// CoreColorW is the JTFRAME_COLORW of the MiSTer build of core
func CoreColorW(source, core string) (int, error) {
	if _, e := os.Stat(filepath.Join(source, "cores", core, "cfg", "macros.def")); e != nil {
		return 0, e
	}
	for key, value := range map[string]string{"JTROOT": source, "JTFRAME": filepath.Join(source, "modules", "jtframe"),
		"CORES": filepath.Join(source, "cores"), "MODULES": filepath.Join(source, "modules")} {
		if e := os.Setenv(key, value); e != nil { return 0, e }
	}
	macros.MakeMacros(core, "mister")
	bits, e := strconv.Atoi(macros.Get("JTFRAME_COLORW")); if e != nil { return 0, e }
	if bits < 1 || bits > 8 {
		return 0, fmt.Errorf("%d is outside 1..8", bits)
	}
	return bits, nil
}

func capture_precision_name(bits int) string {
	return fmt.Sprintf("RGB%d%d%d", bits, bits, bits)
}

// run_mame renders the frames of g in MAME, isolated in work, with the NVRAM
// defaults of the core and the inputs of reg.cab
func run_mame(ctx context.Context, mame, rompath, source string, g *mame_game, work string) (mame_capture, error) {
	var capture mame_capture
	for _, dir := range []string{"cfg", "snapshots", "input", "state", "diff", "ini"} {
		if e := os.MkdirAll(filepath.Join(work, dir), 0700); e != nil { return capture, e }
	}
	refresh, e := mame_refresh(ctx, mame, g.set, filepath.Join(work, "cfg")); if e != nil { return capture, e }
	frame_limit, startup, e := mame_comparison_frame_limit(g.frames[len(g.frames)-1].number, refresh); if e != nil { return capture, e }
	timeout := MameFrameTimeout(frame_limit, refresh)
	if e = prepare_mame_nvram(ctx, mame, g.set, rompath, work, source, g.core); e != nil { return capture, e }
	if e = capture_mame_frames(ctx, mame, g.set, rompath, work, frame_limit, startup, timeout, g.cab); e != nil { return capture, e }
	paths, e := filepath.Glob(filepath.Join(work, "snapshots", "mame_*.png")); if e != nil { return capture, e }
	if len(paths) != frame_limit {
		return capture, fmt.Errorf("MAME saved %d frames; expected %d", len(paths), frame_limit)
	}
	for k, path := range paths {
		if filepath.Base(path) != fmt.Sprintf("mame_%08d.png", k+1) {
			return capture, fmt.Errorf("MAME frame sequence is missing or duplicated at frame %d", k+1)
		}
	}
	return mame_capture{paths, refresh}, nil
}

const mameStartupScreenBypassMaxSeconds = 299

// mame_comparison_frame_limit gives MAME 500 frames beyond the last FPGA frame
// to find matches, and the emulated seconds that skip its startup screens
func mame_comparison_frame_limit(last int, refresh float64) (int, int, error) {
	if last < 1 || math.IsNaN(refresh) || math.IsInf(refresh, 0) || refresh <= 0 {
		return 0, 0, fmt.Errorf("invalid MAME frame budget inputs: last frame=%d refresh=%g", last, refresh)
	}
	limit := last + 500
	seconds := int(math.Ceil(float64(limit) / refresh))
	if seconds > mameStartupScreenBypassMaxSeconds {
		return 0, 0, fmt.Errorf("frame %d plus the 500-frame MAME search grace requires %d emulated seconds; the limit is %d", last, seconds, mameStartupScreenBypassMaxSeconds)
	}
	return limit, seconds, nil
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

// MameFrameTimeout is the wall-clock limit of a MAME capture: the emulated
// time plus 10%, at most five minutes
func MameFrameTimeout(frame_limit int, refresh float64) time.Duration {
	if frame_limit <= 0 || refresh <= 0 || math.IsNaN(refresh) || math.IsInf(refresh, 0) {
		return 0
	}
	seconds := math.Ceil(1.1 * float64(frame_limit) / refresh)
	if seconds > 300 {
		return 5 * time.Minute
	}
	return time.Duration(seconds) * time.Second
}

func capture_mame_frames(parent context.Context, mame, set, rompath, work string, frame_limit, startup_seconds int, timeout time.Duration, cab CabScript) error {
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
	count, err := os.ReadFile(complete)
	if err != nil {
		return fmt.Errorf("MAME frame capture did not write a completion marker")
	}
	if strings.TrimSpace(string(count)) != fmt.Sprint(frame_limit) {
		return fmt.Errorf("MAME frame capture completion count is invalid")
	}
	return nil
}

// mame_inputs maps the CAB input bits to MAME input tokens
var mame_inputs = map[uint]string{
	0: "COIN1", 1: "SERVICE1", 2: "START1", 3: "START2",
	4: "P1_JOYSTICK_RIGHT", 5: "P1_JOYSTICK_LEFT", 6: "P1_JOYSTICK_DOWN", 7: "P1_JOYSTICK_UP",
	8: "P1_BUTTON1", 9: "P1_BUTTON2", 10: "P1_BUTTON3",
	13: "COIN2", 14: "P2_JOYSTICK_RIGHT", 15: "P2_JOYSTICK_LEFT", 16: "P2_JOYSTICK_DOWN", 17: "P2_JOYSTICK_UP",
	18: "P2_BUTTON1", 19: "P2_BUTTON2", 20: "P2_BUTTON3",
}

// make_mame_capture_lua replays the CAB inputs, one CAB line per MAME frame,
// and saves every frame. Inputs are released after the last CAB line
func make_mame_capture_lua(cab CabScript, frame_limit int, snapshot_dir, complete, failure string) (string, error) {
	used := make(map[uint]bool)
	for _, run := range cab.Runs {
		for bit := uint(0); bit < 21; bit++ {
			if run.Inputs&(1<<bit) == 0 {
				continue
			}
			if _, ok := mame_inputs[bit]; !ok {
				return "", fmt.Errorf("CAB action bit %d (test or reset) is not mapped for MAME", bit)
			}
			used[bit] = true
		}
		switch {
		case run.HasDIPSW:
			return "", fmt.Errorf("CAB DIP switch actions are not mapped for MAME")
		case run.Dump:
			return "", fmt.Errorf("CAB dump actions are not mapped for MAME")
		case len(run.Cheats) > 0:
			return "", fmt.Errorf("CAB cheats are not mapped for MAME")
		}
	}
	var controls strings.Builder
	for bit := uint(0); bit < 21; bit++ {
		if token, ok := mame_inputs[bit]; ok && used[bit] {
			fmt.Fprintf(&controls, "  { bit = %d, token = %q },\n", bit, token)
		}
	}
	var runs strings.Builder
	for _, run := range cab.Runs {
		fmt.Fprintf(&runs, "  { %d, %d },\n", run.Frames, run.Inputs)
	}
	return fmt.Sprintf(`local machine = manager.machine
local ioports = machine.ioport
local controls = {
%s}
local runs = {
%s}
local frame_limit = %d
local cab_frames = %d
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
  if frame < 0 or frame >= cab_frames then return 0 end
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
`, controls.String(), runs.String(), frame_limit, cab.Lines, snapshot_dir, complete, failure), nil
}

func isolated_mame_env(work string) []string {
	env := make([]string, 0, len(os.Environ())+1)
	for _, value := range os.Environ() {
		if !strings.HasPrefix(value, "XDG_CONFIG_HOME=") {
			env = append(env, value)
		}
	}
	return append(env, "XDG_CONFIG_HOME="+filepath.Join(work, "xdg"))
}

// match_mame_pngs maps each FPGA frame to the earliest MAME frame after the
// previous match that is equal at the given precision
func match_mame_pngs(ctx context.Context, frames []mame_frame, fpga_dir string, mame_paths []string, bits int) ([]int, error) {
	signature := func(path string, frame int) (FrameSignature, error) {
		img, e := decode_png(path); if e != nil { return FrameSignature{}, fmt.Errorf("decode %s: %w", filepath.Base(path), e) }
		return SignatureImageAtCapturePrecision(frame, img, bits)
	}
	reference := make([]FrameSignature, 0, len(frames))
	for _, f := range frames {
		s, e := signature(filepath.Join(fpga_dir, f.name), f.number); if e != nil { return nil, e }
		reference = append(reference, s)
	}
	candidates := make([]FrameSignature, 0, len(mame_paths))
	for k, path := range mame_paths {
		if e := ctx.Err(); e != nil { return nil, e }
		s, e := signature(path, k+1); if e != nil { return nil, e }
		candidates = append(candidates, s)
	}
	matched, err := MatchFramesOrdered(reference, candidates)
	if err != nil {
		if matched != nil {
			last := -1
			if len(matched) > 0 {
				last = matched[len(matched)-1]
			}
			index := len(matched)
			boundary, e := mame_boundary_match(ctx, reference[index], candidates, last, filepath.Join(fpga_dir, frames[index].name), mame_paths, bits)
			if e != nil {
				return nil, e
			}
			if boundary {
				return nil, fmt.Errorf("boundary differences at frame %d", reference[index].Frame)
			}
		}
		return nil, err
	}
	for k, frame := range matched {
		mame_img, e := decode_png(mame_paths[frame-1]); if e != nil { return nil, e }
		fpga_img, e := decode_png(filepath.Join(fpga_dir, frames[k].name)); if e != nil { return nil, e }
		if !ImagesEqualAtCapturePrecision(fpga_img, mame_img, bits) {
			return nil, fmt.Errorf("MAME frame %d hash candidate failed the full %s comparison", frame, capture_precision_name(bits))
		}
	}
	return matched, nil
}

// mame_boundary_match tells whether the first unmatched frame equals a later
// MAME frame except for its outer pixel border. It only explains a failure
func mame_boundary_match(ctx context.Context, reference FrameSignature, candidates []FrameSignature, last int, fpga_path string, mame_paths []string, bits int) (bool, error) {
	if reference.Width <= 2 || reference.Height <= 2 {
		return false, nil
	}
	fpga_img, e := decode_png(fpga_path); if e != nil { return false, e }
	for _, candidate := range candidates {
		if e := ctx.Err(); e != nil {
			return false, e
		}
		if candidate.Frame <= last || candidate.Width != reference.Width || candidate.Height != reference.Height || candidate.Interior != reference.Interior {
			continue
		}
		img, e := decode_png(mame_paths[candidate.Frame-1]); if e != nil { return false, e }
		if images_equal_capture_region(fpga_img, img, bits, 1) && !ImagesEqualAtCapturePrecision(fpga_img, img, bits) {
			return true, nil
		}
	}
	return false, nil
}

func compact_mame_error(detail string) string {
	detail = strings.Join(strings.Fields(detail), " ")
	if len(detail) > 240 {
		return detail[:237] + "..."
	}
	return detail
}
