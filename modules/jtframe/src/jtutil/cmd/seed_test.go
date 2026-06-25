package cmd

import (
	"io"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"testing"

	"github.com/spf13/pflag"
)

func Test_new_config(t *testing.T) {
	setup_seed_core_folder(t, "gng")
	flags := new_seed_test_flags(t, "--parallel", "2", "--max-trials", "7")
	cfg, e := new_config(flags, []string{"gng", "--target", "mist"})
	if e != nil {
		t.Fatal(e)
	}
	if cfg.max_trials != 7 || cfg.parallel != 2 {
		t.Fatalf("unexpected seed config: %#v", cfg)
	}
	expected := []string{"gng", "--target", "mist"}
	if !reflect.DeepEqual(cfg.jtcore_args, expected) {
		t.Fatalf("unexpected jtcore args: %#v", cfg.jtcore_args)
	}
}

func Test_new_config_keeps_194x_as_core(t *testing.T) {
	setup_seed_core_folder(t, "1942")
	flags := new_seed_test_flags(t)
	cfg, e := new_config(flags, []string{"1942", "--target", "mist"})
	if e != nil {
		t.Fatal(e)
	}
	if cfg.max_trials != 100 {
		t.Fatalf("194x core name should not be parsed as max reps")
	}
	expected := []string{"1942", "--target", "mist"}
	if !reflect.DeepEqual(cfg.jtcore_args, expected) {
		t.Fatalf("unexpected jtcore args: %#v", cfg.jtcore_args)
	}
}

func Test_new_config_rejects_positional_trials(t *testing.T) {
	setup_seed_core_folder(t, "gng")
	flags := new_seed_test_flags(t)
	_, e := new_config(flags, []string{"7", "gng"})
	if e == nil {
		t.Fatalf("expected positional trial count rejection")
	}
}

func Test_new_config_passes_skip_to_jtcore(t *testing.T) {
	setup_seed_core_folder(t, "gng")
	flags := new_seed_test_flags(t)
	cfg, e := new_config(flags, []string{"gng", "-s"})
	if e != nil {
		t.Fatal(e)
	}
	expected := []string{"gng", "-s"}
	if !reflect.DeepEqual(cfg.jtcore_args, expected) {
		t.Fatalf("unexpected jtcore args: %#v", cfg.jtcore_args)
	}
}

func Test_new_config_rejects_bad_parallel(t *testing.T) {
	flags := new_seed_test_flags(t, "--parallel", "0")
	_, e := new_config(flags, []string{"gng"})
	if e == nil {
		t.Fatalf("expected parallel option rejection")
	}
}

func Test_new_config_rejects_bad_max_trials(t *testing.T) {
	flags := new_seed_test_flags(t, "--max-trials", "0")
	_, e := new_config(flags, []string{"gng"})
	if e == nil {
		t.Fatalf("expected max-trials option rejection")
	}
}

func new_seed_test_flags(t *testing.T, args ...string) *pflag.FlagSet {
	t.Helper()
	flags := pflag.NewFlagSet("seed", pflag.ContinueOnError)
	flags.Int("parallel", 1, "")
	flags.Int("max-trials", 100, "")
	e := flags.Parse(args)
	if e != nil {
		t.Fatal(e)
	}
	return flags
}

func Test_seed_output_base_uses_target_seed_folder(t *testing.T) {
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	e := os.MkdirAll(filepath.Join(root, "cores", "cps3"), 0775)
	if e != nil {
		t.Fatal(e)
	}
	flags := new_seed_test_flags(t, "--parallel", "2")
	cfg, e := new_config(flags, []string{"cps3", "-mr", "--nodbg"})
	if e != nil {
		t.Fatal(e)
	}
	base, e := cfg.output_base()
	if e != nil {
		t.Fatal(e)
	}
	if base != filepath.Join(root, "cores", "cps3", "seed", "mister") {
		t.Fatalf("unexpected seed output base: %s", base)
	}
}

func Test_next_seed_starts_at_zero(t *testing.T) {
	cfg := &seed_config{
		used_seeds: make(map[int]bool),
		random:     rand.New(rand.NewSource(1)),
	}
	first := cfg.next_seed()
	second := cfg.next_seed()
	if first != 0 {
		t.Fatalf("first seed should be 0, got %d", first)
	}
	if second == 0 {
		t.Fatalf("second seed should not repeat 0")
	}
}

func Test_parse_worst_slack(t *testing.T) {
	value, found := parse_worst_slack("Worst-case setup slack is -0.123")
	if !found || value != "-0.123" {
		t.Fatalf("unexpected slack parse: %q %v", value, found)
	}
	value, found = parse_worst_slack("Worst-case hold slack is 0.456")
	if !found || value != "0.456" {
		t.Fatalf("unexpected positive slack parse: %q %v", value, found)
	}
	_, found = parse_worst_slack("Total logic elements: 100")
	if found {
		t.Fatalf("non-slack line should not match")
	}
}

func Test_parse_jtcore_error(t *testing.T) {
	msg, found := parse_jtcore_error("ERROR: Unknown option --sidi128")
	if !found || msg != "ERROR: Unknown option --sidi128" {
		t.Fatalf("unexpected error parse: %q %v", msg, found)
	}
	_, found = parse_jtcore_error("Warning: no errors found")
	if found {
		t.Fatalf("lowercase error text should not match jtcore ERROR")
	}
	if !parse_jtcore_done("PASS") || !parse_jtcore_done(" FAIL ") {
		t.Fatalf("expected PASS/FAIL completion parsing")
	}
	if parse_jtcore_done("ERROR: no PASS") {
		t.Fatalf("only standalone PASS/FAIL should complete a jtcore log")
	}
}

func Test_start_jtcore_logged_writes_log(t *testing.T) {
	tmp := t.TempDir()
	fake_jtcore := filepath.Join(tmp, "jtcore")
	script := "#!/bin/sh\necho jtcore args: $*\necho Worst-case setup slack is -1.250\nexit 0\n"
	e := os.WriteFile(fake_jtcore, []byte(script), 0755)
	if e != nil {
		t.Fatal(e)
	}
	t.Setenv("PATH", tmp+":"+os.Getenv("PATH"))
	output := filepath.Join(tmp, "seed", "9")
	cfg := &seed_config{jtcore_args: []string{"gng", "--target", "mist"}}
	cfg.append_nosta_undef()
	job, e := start_jtcore_logged(cfg.jtcore_args, 9, output)
	if e != nil {
		t.Fatal(e)
	}
	if !job.wait() {
		t.Fatalf("fake jtcore should pass")
	}
	if job.logname != filepath.Join(output, "jtcore.log") {
		t.Fatalf("unexpected log path: %s", job.logname)
	}
	log, e := os.ReadFile(job.logname)
	if e != nil {
		t.Fatal(e)
	}
	expected := "jtcore args: gng --target mist -u JTFRAME_NOSTA --nocopy --seed 9 --output " + filepath.Join(output, "build")
	if !strings.Contains(string(log), expected) {
		t.Fatalf("log does not contain expected args %q:\n%s", expected, log)
	}
	if job.builddir != filepath.Join(output, "build") {
		t.Fatalf("unexpected build dir: %s", job.builddir)
	}
	if slack := job.worst_slack(); slack != "-1.250" {
		t.Fatalf("unexpected worst slack: %s", slack)
	}
}

func Test_worst_sta_slack(t *testing.T) {
	output := t.TempDir()
	summary_dir := filepath.Join(output, "output_files")
	e := os.MkdirAll(summary_dir, 0775)
	if e != nil {
		t.Fatal(e)
	}
	summary := "Type  : Setup clk\nSlack : 4.767\nTNS   : 0.000\n\nType  : Hold clk\nSlack : -0.125\nTNS   : -1.000\n"
	e = os.WriteFile(filepath.Join(summary_dir, "test.sta.summary"), []byte(summary), 0644)
	if e != nil {
		t.Fatal(e)
	}
	if slack := worst_sta_slack(output); slack != "-0.125" {
		t.Fatalf("unexpected STA worst slack: %s", slack)
	}
}

func Test_seed_release_info_paths(t *testing.T) {
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	e := os.MkdirAll(filepath.Join(root, "modules", "jtframe", "target", "sidi128"), 0775)
	if e != nil {
		t.Fatal(e)
	}
	cfg := &seed_config{jtcore_args: []string{"gng", "-sidi128"}}
	info, e := cfg.release_info()
	if e != nil {
		t.Fatal(e)
	}
	if info.target != "sidi128" || info.core != "gng" {
		t.Fatalf("unexpected release info: %#v", info)
	}
	if got := info.source_rbf(filepath.Join(root, "cores", "gng", "seed", "7")); got != filepath.Join(root, "cores", "gng", "seed", "7", "jtgng.rbf") {
		t.Fatalf("unexpected source path: %s", got)
	}
	if got := info.release_rbf(); got != filepath.Join(root, "release", "sidi128", "jtgng.rbf") {
		t.Fatalf("unexpected release path: %s", got)
	}
	t.Setenv("TARGET", "mist")
	cfg = &seed_config{jtcore_args: []string{"gng", "--sidi128"}}
	info, e = cfg.release_info()
	if e != nil {
		t.Fatal(e)
	}
	if info.target != "mist" || info.core != "gng" {
		t.Fatalf("double-dash target shortcut should pass through, got: %#v", info)
	}
	cfg = &seed_config{jtcore_args: []string{"gng", "--target", "pocket"}}
	info, e = cfg.release_info()
	if e != nil {
		t.Fatal(e)
	}
	if got := info.source_rbf(filepath.Join(root, "cores", "gng", "seed", "7")); got != filepath.Join(root, "cores", "gng", "seed", "7", "jtgng.rbf_r") {
		t.Fatalf("unexpected pocket source path: %s", got)
	}
	if got := info.release_rbf(); got != filepath.Join(root, "release", "pocket", "raw", "Cores", "jotego.gng", "jtgng.rbf_r") {
		t.Fatalf("unexpected pocket release path: %s", got)
	}
}

func Test_seed_core_macros_use_macro_loader(t *testing.T) {
	setup_seed_macro_tree(t, "gng", "CORENAME=jtgng\nJTFRAME_NOSTA\nJTFRAME_EASY_STA\n")
	cfg := &seed_config{
		release:     seed_release{core: "gng", target: "mist"},
		jtcore_args: []string{"gng", "--target", "mist"},
	}
	if !cfg.core_has_nosta() {
		t.Fatalf("expected JTFRAME_NOSTA to be detected")
	}
	if !cfg.core_has_easy_sta() {
		t.Fatalf("expected JTFRAME_EASY_STA to be detected")
	}
	setup_seed_macro_tree(t, "gng", "CORENAME=jtgng\n")
	cfg = &seed_config{
		release:     seed_release{core: "gng", target: "mist"},
		jtcore_args: []string{"gng", "--target", "mist"},
	}
	if cfg.core_has_nosta() {
		t.Fatalf("unexpected JTFRAME_NOSTA detection")
	}
	if cfg.core_has_easy_sta() {
		t.Fatalf("unexpected JTFRAME_EASY_STA detection")
	}
}

func Test_prepare_appends_nosta_undef(t *testing.T) {
	setup_seed_macro_tree(t, "gng", "CORENAME=jtgng\nJTFRAME_NOSTA\n")
	cfg := &seed_config{jtcore_args: []string{"gng", "--target", "mist"}}
	e := cfg.prepare()
	if e != nil {
		t.Fatal(e)
	}
	if !cfg.nosta {
		t.Fatalf("expected NOSTA mode")
	}
	if cfg.easy_sta {
		t.Fatalf("unexpected EASY_STA mode")
	}
	if cfg.release.target != "mist" {
		t.Fatalf("unexpected release info: %#v", cfg.release)
	}
	expected := []string{"gng", "--target", "mist", "-u", "JTFRAME_NOSTA"}
	if !reflect.DeepEqual(cfg.jtcore_args, expected) {
		t.Fatalf("unexpected jtcore args: %#v", cfg.jtcore_args)
	}
}

func Test_prepare_keeps_long_target_shortcut(t *testing.T) {
	root := setup_seed_macro_tree(t, "gng", "CORENAME=jtgng\n")
	e := os.MkdirAll(filepath.Join(root, "modules", "jtframe", "target", "sidi128"), 0775)
	if e != nil {
		t.Fatal(e)
	}
	cfg := &seed_config{jtcore_args: []string{"gng", "--sidi128", "--nodbg"}}
	e = cfg.prepare()
	if e != nil {
		t.Fatal(e)
	}
	expected := []string{"gng", "--sidi128", "--nodbg", "-u", "JTFRAME_NOSTA"}
	if !reflect.DeepEqual(cfg.jtcore_args, expected) {
		t.Fatalf("unexpected jtcore args: %#v", cfg.jtcore_args)
	}
}

func Test_prepare_uses_target_core_name_for_rbf_paths(t *testing.T) {
	root := setup_seed_macro_tree(t, "ngp", "CORENAME=JTNGP\n[mister]\nCORENAME=NeoGeoPocket\n")
	cfg := &seed_config{jtcore_args: []string{"ngp", "--target", "mister"}}
	e := cfg.prepare()
	if e != nil {
		t.Fatal(e)
	}
	if cfg.release.rbf != "neogeopocket" {
		t.Fatalf("unexpected RBF name: %#v", cfg.release)
	}
	builddir := filepath.Join(root, "cores", "ngp", "seed", "mister", "0", "build")
	if got := cfg.release.source_rbf(builddir); got != filepath.Join(builddir, "output_files", "neogeopocket.rbf") {
		t.Fatalf("unexpected source path: %s", got)
	}
	if got := cfg.release.release_rbf(); got != filepath.Join(root, "release", "mister", "neogeopocket.rbf") {
		t.Fatalf("unexpected release path: %s", got)
	}
}

func Test_run_parallel_one_uses_seed_output(t *testing.T) {
	root := setup_seed_macro_tree(t, "gng", "CORENAME=jtgng\n")
	install_fake_jtcore(t, 0)
	flags := new_seed_test_flags(t, "--max-trials", "1")
	cfg, e := new_config(flags, []string{"gng", "--target", "mist"})
	if e != nil {
		t.Fatal(e)
	}
	var run_e error
	out := capture_seed_stdout(t, func() {
		run_e = cfg.run()
	})
	if run_e != nil {
		t.Fatal(run_e)
	}
	if !strings.Contains(out, "Seed     0 passed in ") {
		t.Fatalf("missing seed walltime report:\n%s", out)
	}
	if !strings.Contains(out, "Average compilation walltime per job: ") {
		t.Fatalf("missing average walltime report:\n%s", out)
	}
	output := filepath.Join(root, "cores", "gng", "seed", "mist", "0")
	if _, e := os.Stat(filepath.Join(output, "jtcore.log")); e != nil {
		t.Fatalf("missing jtcore log: %v", e)
	}
	dst := filepath.Join(root, "release", "mist", "jtgng.rbf")
	data, e := os.ReadFile(dst)
	if e != nil {
		t.Fatal(e)
	}
	if string(data) != "fake-rbf\n" {
		t.Fatalf("unexpected release data: %q", data)
	}
}

func Test_run_nosta_core_uses_all_trials_and_passes(t *testing.T) {
	root := setup_seed_macro_tree(t, "gng", "CORENAME=jtgng\nJTFRAME_NOSTA\n")
	install_fake_jtcore(t, 1)
	flags := new_seed_test_flags(t, "--max-trials", "2")
	cfg, e := new_config(flags, []string{"gng", "--target", "mist"})
	if e != nil {
		t.Fatal(e)
	}
	cfg.random = rand.New(rand.NewSource(1))
	e = cfg.run()
	if e != nil {
		t.Fatal(e)
	}
	logs, e := filepath.Glob(filepath.Join(root, "cores", "gng", "seed", "mist", "*", "jtcore.log"))
	if e != nil {
		t.Fatal(e)
	}
	if len(logs) != 2 {
		t.Fatalf("expected two seed attempts, got %d: %#v", len(logs), logs)
	}
}

func Test_run_easy_sta_passes_with_relaxed_slack(t *testing.T) {
	setup_seed_macro_tree(t, "gng", "CORENAME=jtgng\nJTFRAME_EASY_STA\n")
	install_fake_jtcore_sequence_with_slack(t, "-0.400", 1)
	flags := new_seed_test_flags(t, "--max-trials", "1")
	cfg, e := new_config(flags, []string{"gng", "--target", "mist"})
	if e != nil {
		t.Fatal(e)
	}
	var run_e error
	out := capture_seed_stdout(t, func() {
		run_e = cfg.run()
	})
	if run_e != nil {
		t.Fatal(run_e)
	}
	if !strings.Contains(out, "PASS: best STA slack -0.400 ns") {
		t.Fatalf("missing EASY_STA pass report:\n%s", out)
	}
}

func Test_run_easy_sta_fails_at_limit(t *testing.T) {
	setup_seed_macro_tree(t, "gng", "CORENAME=jtgng\nJTFRAME_EASY_STA\n")
	install_fake_jtcore_sequence_with_slack(t, "-0.500", 1)
	flags := new_seed_test_flags(t, "--max-trials", "1")
	cfg, e := new_config(flags, []string{"gng", "--target", "mist"})
	if e != nil {
		t.Fatal(e)
	}
	e = cfg.run()
	if e == nil || !strings.Contains(e.Error(), "best slack -0.500 ns") {
		t.Fatalf("expected EASY_STA limit failure, got %v", e)
	}
}

func Test_run_nosta_core_stops_on_clean_sta(t *testing.T) {
	root := setup_seed_macro_tree(t, "gng", "CORENAME=jtgng\nJTFRAME_NOSTA\n")
	install_fake_jtcore_sequence(t, 1, 0, 1)
	flags := new_seed_test_flags(t, "--max-trials", "3")
	cfg, e := new_config(flags, []string{"gng", "--target", "mist"})
	if e != nil {
		t.Fatal(e)
	}
	cfg.random = rand.New(rand.NewSource(1))
	e = cfg.run()
	if e != nil {
		t.Fatal(e)
	}
	logs, e := filepath.Glob(filepath.Join(root, "cores", "gng", "seed", "mist", "*", "jtcore.log"))
	if e != nil {
		t.Fatal(e)
	}
	if len(logs) != 2 {
		t.Fatalf("expected stop after clean STA, got %d attempts: %#v", len(logs), logs)
	}
}

func Test_run_reports_jtcore_error(t *testing.T) {
	root := setup_seed_macro_tree(t, "gng", "CORENAME=jtgng\n")
	install_fake_jtcore_error(t, "ERROR: Unknown option --bad")
	flags := new_seed_test_flags(t, "--max-trials", "2")
	cfg, e := new_config(flags, []string{"gng", "--target", "mist"})
	if e != nil {
		t.Fatal(e)
	}
	e = cfg.run()
	if e == nil || !strings.Contains(e.Error(), "ERROR: Unknown option --bad") {
		t.Fatalf("expected logged jtcore error, got %v", e)
	}
	logs, e := filepath.Glob(filepath.Join(root, "cores", "gng", "seed", "mist", "*", "jtcore.log"))
	if e != nil {
		t.Fatal(e)
	}
	if len(logs) != 1 {
		t.Fatalf("expected abort after first jtcore error, got %d attempts: %#v", len(logs), logs)
	}
}

func Test_run_reports_jtcore_exit_without_pass_fail(t *testing.T) {
	root := setup_seed_macro_tree(t, "gng", "CORENAME=jtgng\n")
	install_fake_jtcore_exit_without_status(t, "missing.v did not match any file")
	flags := new_seed_test_flags(t, "--max-trials", "2")
	cfg, e := new_config(flags, []string{"gng", "--target", "mist"})
	if e != nil {
		t.Fatal(e)
	}
	e = cfg.run()
	if e == nil || !strings.Contains(e.Error(), "missing.v did not match any file") {
		t.Fatalf("expected early jtcore exit error, got %v", e)
	}
	logs, e := filepath.Glob(filepath.Join(root, "cores", "gng", "seed", "mist", "*", "jtcore.log"))
	if e != nil {
		t.Fatal(e)
	}
	if len(logs) != 1 {
		t.Fatalf("expected abort after first early exit, got %d attempts: %#v", len(logs), logs)
	}
}

func Test_copy_if_best_updates_release(t *testing.T) {
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	output := filepath.Join(root, "cores", "gng", "seed", "0")
	builddir := filepath.Join(output, "build")
	src := filepath.Join(builddir, "output_files", "jtgng.rbf")
	e := os.MkdirAll(filepath.Dir(src), 0775)
	if e != nil {
		t.Fatal(e)
	}
	e = os.WriteFile(src, []byte("first"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	release_cfg := &seed_config{jtcore_args: []string{"gng", "--target", "mister"}}
	info, e := release_cfg.release_info()
	if e != nil {
		t.Fatal(e)
	}
	cfg := &seed_config{jtcore_args: []string{"gng", "--target", "mister"}, release: info}
	msg := cfg.copy_if_best(seed_job{output: output, builddir: builddir}, "-0.5")
	if !strings.Contains(msg, "copied") {
		t.Fatalf("expected copy message, got %q", msg)
	}
	dst := filepath.Join(root, "release", "mister", "jtgng.rbf")
	data, e := os.ReadFile(dst)
	if e != nil {
		t.Fatal(e)
	}
	if string(data) != "first" {
		t.Fatalf("unexpected copied data: %q", data)
	}
	e = os.WriteFile(src, []byte("worse"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	msg = cfg.copy_if_best(seed_job{output: output, builddir: builddir}, "-1.0")
	if msg != "" {
		t.Fatalf("worse slack should not copy, got %q", msg)
	}
	data, e = os.ReadFile(dst)
	if e != nil {
		t.Fatal(e)
	}
	if string(data) != "first" {
		t.Fatalf("worse result overwrote release: %q", data)
	}
	e = os.WriteFile(src, []byte("better"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	msg = cfg.copy_if_best(seed_job{output: output, builddir: builddir}, "0.1")
	if !strings.Contains(msg, "copied") {
		t.Fatalf("better slack should copy, got %q", msg)
	}
	data, e = os.ReadFile(dst)
	if e != nil {
		t.Fatal(e)
	}
	if string(data) != "better" {
		t.Fatalf("better result was not copied: %q", data)
	}
}

func capture_seed_stdout(t *testing.T, fn func()) string {
	t.Helper()
	old := os.Stdout
	r, w, e := os.Pipe()
	if e != nil {
		t.Fatal(e)
	}
	os.Stdout = w
	fn()
	w.Close()
	os.Stdout = old
	out, e := io.ReadAll(r)
	if e != nil {
		t.Fatal(e)
	}
	return string(out)
}

func setup_seed_macro_tree(t *testing.T, core, macro_text string) string {
	t.Helper()
	root := t.TempDir()
	core_cfg := filepath.Join(root, "cores", core, "cfg")
	target_cfg := filepath.Join(root, "modules", "jtframe", "target", "mist")
	e := os.MkdirAll(core_cfg, 0775)
	if e != nil {
		t.Fatal(e)
	}
	e = os.MkdirAll(target_cfg, 0775)
	if e != nil {
		t.Fatal(e)
	}
	e = os.WriteFile(filepath.Join(core_cfg, "macros.def"), []byte(macro_text), 0644)
	if e != nil {
		t.Fatal(e)
	}
	init_test_git(t, root)
	t.Setenv("JTROOT", root)
	t.Setenv("CORES", filepath.Join(root, "cores"))
	t.Setenv("JTFRAME", filepath.Join(root, "modules", "jtframe"))
	return root
}

func setup_seed_core_folder(t *testing.T, core string) string {
	t.Helper()
	root := t.TempDir()
	e := os.MkdirAll(filepath.Join(root, "cores", core), 0775)
	if e != nil {
		t.Fatal(e)
	}
	t.Setenv("JTROOT", root)
	return root
}

func init_test_git(t *testing.T, root string) {
	t.Helper()
	run_test_git(t, root, "init")
	run_test_git(t, root, "-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "--allow-empty", "-m", "init")
}

func run_test_git(t *testing.T, root string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", root}, args...)...)
	out, e := cmd.CombinedOutput()
	if e != nil {
		t.Fatalf("git %s failed: %v\n%s", strings.Join(args, " "), e, out)
	}
}

func install_fake_jtcore(t *testing.T, code int) {
	t.Helper()
	install_fake_jtcore_sequence(t, code)
}

func install_fake_jtcore_sequence(t *testing.T, codes ...int) {
	t.Helper()
	install_fake_jtcore_sequence_with_slack(t, "-1.250", codes...)
}

func install_fake_jtcore_sequence_with_slack(t *testing.T, slack string, codes ...int) {
	t.Helper()
	tmp := t.TempDir()
	fake_jtcore := filepath.Join(tmp, "jtcore")
	code_text := make([]string, len(codes))
	for k, code := range codes {
		code_text[k] = strconv.Itoa(code)
	}
	script := `#!/bin/sh
out=
while [ $# -gt 0 ]; do
    if [ "$1" = "--output" ]; then
        shift
        out="$1"
    fi
    shift
done
count_file="` + filepath.Join(tmp, "count") + `"
count=0
if [ -e "$count_file" ]; then
    count=$(cat "$count_file")
fi
set -- ` + strings.Join(code_text, " ") + `
code=${1:-1}
idx=0
for each in "$@"; do
    if [ "$idx" = "$count" ]; then
        code=$each
        break
    fi
    idx=$((idx+1))
done
echo $((count+1)) > "$count_file"
mkdir -p "$out"
echo fake-rbf > "$out/jtgng.rbf"
echo "Worst-case setup slack is ` + slack + `"
if [ "$code" = 0 ]; then
    echo PASS
else
    echo FAIL
fi
exit $code
`
	e := os.WriteFile(fake_jtcore, []byte(script), 0755)
	if e != nil {
		t.Fatal(e)
	}
	t.Setenv("PATH", tmp+":"+os.Getenv("PATH"))
}

func install_fake_jtcore_error(t *testing.T, line string) {
	t.Helper()
	tmp := t.TempDir()
	fake_jtcore := filepath.Join(tmp, "jtcore")
	script := "#!/bin/sh\necho " + strconv.Quote(line) + "\nexit 0\n"
	e := os.WriteFile(fake_jtcore, []byte(script), 0755)
	if e != nil {
		t.Fatal(e)
	}
	t.Setenv("PATH", tmp+":"+os.Getenv("PATH"))
}

func install_fake_jtcore_exit_without_status(t *testing.T, line string) {
	t.Helper()
	tmp := t.TempDir()
	fake_jtcore := filepath.Join(tmp, "jtcore")
	script := "#!/bin/sh\necho " + strconv.Quote(line) + "\nexit 1\n"
	e := os.WriteFile(fake_jtcore, []byte(script), 0755)
	if e != nil {
		t.Fatal(e)
	}
	t.Setenv("PATH", tmp+":"+os.Getenv("PATH"))
}
