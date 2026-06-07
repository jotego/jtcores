package cmd

import (
	"math/rand"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/spf13/pflag"
)

func Test_seed_config_from_flags(t *testing.T) {
	flags := new_seed_test_flags(t, "--parallel", "2")
	cfg, e := seed_config_from_flags(flags, []string{"7", "gng", "--target", "mist"})
	if e != nil {
		t.Fatal(e)
	}
	if cfg.max_reps != 7 || cfg.parallel != 2 {
		t.Fatalf("unexpected seed config: %#v", cfg)
	}
	expected := []string{"gng", "--target", "mist"}
	if !reflect.DeepEqual(cfg.jtcore_args, expected) {
		t.Fatalf("unexpected jtcore args: %#v", cfg.jtcore_args)
	}
}

func Test_seed_config_from_flags_keeps_194x_as_core(t *testing.T) {
	flags := new_seed_test_flags(t)
	cfg, e := seed_config_from_flags(flags, []string{"1942", "--target", "mist"})
	if e != nil {
		t.Fatal(e)
	}
	if cfg.max_reps != 100 {
		t.Fatalf("194x core name should not be parsed as max reps")
	}
	expected := []string{"1942", "--target", "mist"}
	if !reflect.DeepEqual(cfg.jtcore_args, expected) {
		t.Fatalf("unexpected jtcore args: %#v", cfg.jtcore_args)
	}
}

func Test_seed_config_from_flags_rejects_skip(t *testing.T) {
	flags := new_seed_test_flags(t)
	_, e := seed_config_from_flags(flags, []string{"gng", "-s"})
	if e == nil {
		t.Fatalf("expected skip option rejection")
	}
}

func Test_seed_config_from_flags_rejects_bad_parallel(t *testing.T) {
	flags := new_seed_test_flags(t, "--parallel", "0")
	_, e := seed_config_from_flags(flags, []string{"gng"})
	if e == nil {
		t.Fatalf("expected parallel option rejection")
	}
}

func new_seed_test_flags(t *testing.T, args ...string) *pflag.FlagSet {
	t.Helper()
	flags := pflag.NewFlagSet("seed", pflag.ContinueOnError)
	flags.Int("parallel", 1, "")
	e := flags.Parse(args)
	if e != nil {
		t.Fatal(e)
	}
	return flags
}

func Test_seed_output_base_uses_core_seed_folder(t *testing.T) {
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	flags := new_seed_test_flags(t, "--parallel", "2")
	cfg, e := seed_config_from_flags(flags, []string{"cps3", "-mr", "--nodbg"})
	if e != nil {
		t.Fatal(e)
	}
	base, e := cfg.seed_output_base()
	if e != nil {
		t.Fatal(e)
	}
	if base != filepath.Join(root, "cores", "cps3", "seed") {
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
	job, e := start_jtcore_logged([]string{"gng", "--target", "mist"}, 9, output)
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
	expected := "jtcore args: gng --target mist --nocopy --seed 9 --output " + filepath.Join(output, "build")
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
	info, e := seed_release_info([]string{"gng", "-sidi128"})
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
	info, e = seed_release_info([]string{"gng", "--target", "pocket"})
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
	cfg := &seed_config{jtcore_args: []string{"gng", "--target", "mister"}}
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
