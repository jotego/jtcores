/*  This file is part of JTCORES.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 7-6-2026 */

package cmd

import (
	"bufio"
	"fmt"
	"io"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	"jotego/jtframe/macros"
)

type seed_config struct {
	max_trials  int
	parallel    int
	jtcore_args []string
	used_seeds  map[int]bool
	seed_count  int
	random      *rand.Rand
	best_slack  float64
	best_valid  bool
	release     seed_release
	nosta      bool
	easy_sta   bool
	sta_slack  float64
	sta_valid  bool
	walltime   time.Duration
	walljobs   int
}

type seed_release struct {
	core   string
	target string
	rbf    string
}

type seed_job struct {
	seed     int
	cmd      *exec.Cmd
	logfile  *os.File
	logname  string
	output   string
	builddir string
	pass     bool
	start    time.Time
	walltime time.Duration
}

const seed_easy_sta_limit = -0.5

var seed_parallel, seed_max_trials int
var seed_stop, seed_zero bool

var seedCmd = &cobra.Command{
	Use:   "seed [flags] <core> [jtcore options]",
	Short: "Run jtcore repeatedly with different seeds",
	Long: man_blurb("jtutil-seed", `Runs jtcore repeatedly with different --seed values until one build passes or --max-trials is reached.

Options consumed by jtutil seed must appear before core:
    --max-trials n        Stop after n seed builds
    --parallel n          Run up to n jtcore seed builds at the same time
    --parallel=n          Same as --parallel n
    --help | -h           Show this summary

The remaining arguments are passed to jtcore. Each jtcore run gets a distinct
--seed and --output folder. The Quartus build runs under <output>/build, and
its console output is written to <output>/jtcore.log. Runs invoke jtcore with
--nocopy and -u JTFRAME_NOSTA; as jobs finish, jtutil seed copies the best RBF
seen so far into the normal release/<target>/ folder. The default output base is:
	    $JTROOT/cores/<core-name>/seed/<target>

Create a jtseed.last file in the current folder to stop after the current batch.`),
	Run:  run_seed,
	Args: cobra.ArbitraryArgs,
}

func init() {
	seedCmd.Flags().IntVar(&seed_max_trials, "max-trials", 4, "Stop after n seed builds")
	seedCmd.Flags().IntVar(&seed_parallel, "parallel", 1, "Run up to n jtcore seed builds at the same time")
	seedCmd.Flags().BoolVar(&seed_stop, "stop", true, "Stop when a build is STA clean")
	seedCmd.Flags().BoolVar(&seed_zero, "zero", true, "Start with seed zero")
	seedCmd.Flags().SetInterspersed(false)
	rootCmd.AddCommand(seedCmd)
}

func run_seed(cmd *cobra.Command, args []string) {
	cfg, e := new_config(cmd.Flags(), args)
	must(e)
	e = cfg.run()
	must(e)
}

func new_config(flags *pflag.FlagSet, args []string) (*seed_config, error) {
	parallel, e := flags.GetInt("parallel")
	if e != nil {
		return nil, e
	}
	if parallel <= 0 {
		return nil, fmt.Errorf("Error: use a positive integer after --parallel")
	}
	max_trials, e := flags.GetInt("max-trials")
	if e != nil {
		return nil, e
	}
	if max_trials <= 0 {
		return nil, fmt.Errorf("Error: use a positive integer after --max-trials")
	}
	cfg := &seed_config{
		max_trials: max_trials,
		parallel:   parallel,
		used_seeds: make(map[int]bool),
		random:     rand.New(rand.NewSource(time.Now().UnixNano())),
	}
	e = validate_core_name(args)
	if e != nil {
		return nil, e
	}
	cfg.jtcore_args = append(cfg.jtcore_args, args...)
	return cfg, nil
}

func validate_core_name(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("Error: specify a core name")
	}
	root, e := get_jtroot()
	if e != nil {
		return e
	}
	info, e := os.Stat(filepath.Join(root, "cores", args[0]))
	if e != nil || !info.IsDir() {
		return fmt.Errorf("Error: %s is not a valid core folder under cores/", args[0])
	}
	return nil
}

func (cfg *seed_config) run() error {
	fmt.Println("Create a jtseed.last file at this folder to stop at the next compilation")
	os.Remove("jtseed.last")
	e := cfg.prepare()
	if e != nil {
		return e
	}
	return cfg.run_trials()
}

func (cfg *seed_config) prepare() error {
	info, e := cfg.release_info()
	if e != nil {
		return e
	}
	cfg.release = info
	cfg.load_core_macros()
	cfg.release.rbf = strings.ToLower(macros.Get("CORENAME"))
	cfg.nosta = macros.IsSet("JTFRAME_NOSTA")
	cfg.easy_sta = macros.IsSet("JTFRAME_EASY_STA")
	cfg.append_nosta_undef()
	return nil
}

func (cfg *seed_config) core() string {
	if len(cfg.jtcore_args) == 0 {
		return ""
	}
	return cfg.jtcore_args[0]
}

func (cfg *seed_config) run_trials() error {
	output_base, e := cfg.output_base()
	if e != nil {
		return e
	}
	defer cfg.report_walltime()
	pass := false
	for cfg.max_trials > 0 {
		batch := cfg.parallel
		if cfg.max_trials < batch {
			batch = cfg.max_trials
		}
		jobs := cfg.start_batch(output_base, batch)
		batch_pass, e := cfg.wait_batch(jobs, &pass)
		if e != nil {
			return e
		}
		if batch_pass && seed_stop {
			return cfg.finish_trials(pass)
		}
		if stop_requested() {
			return cfg.finish_trials(pass)
		}
	}
	return cfg.finish_trials(pass)
}

func (cfg *seed_config) finish_trials(pass bool) error {
	if pass || cfg.nosta {
		fmt.Println("PASS")
		return nil
	}
	if cfg.easy_sta && cfg.sta_passes_easy_limit() {
		fmt.Printf("PASS: best STA slack %.3f ns is better than %.3f ns\n", cfg.sta_slack, seed_easy_sta_limit)
		return nil
	}
	if cfg.sta_valid {
		return fmt.Errorf("STA timing was not met by any seed build, best slack %.3f ns", cfg.sta_slack)
	}
	return fmt.Errorf("STA timing was not met by any seed build")
}

func (cfg *seed_config) sta_passes_easy_limit() bool {
	return cfg.sta_valid && cfg.sta_slack > seed_easy_sta_limit
}

func (cfg *seed_config) start_batch(output_base string, batch int) []seed_job {
	jobs := make([]seed_job, 0, batch)
	for k := 0; k < batch; k++ {
		seed := cfg.next_seed()
		output := filepath.Join(output_base, strconv.Itoa(seed))
		job, e := start_jtcore_logged(cfg.jtcore_args, seed, output)
		if e != nil {
			fmt.Printf("Seed %5d failed\n", seed)
			fmt.Println(e)
		} else {
			jobs = append(jobs, job)
		}
		cfg.max_trials--
	}
	return jobs
}

func (cfg *seed_config) wait_batch(jobs []seed_job, pass *bool) (bool, error) {
	batch_pass := false
	var first_error error
	for _, job := range wait_seed_jobs(jobs) {
		cfg.add_walltime(job.walltime)
		report := job.log_report()
		if report.error_msg != "" {
			fmt.Printf("Seed %5d error after %s: %s\n", job.seed, job.walltime, report.error_msg)
			if first_error == nil {
				first_error = fmt.Errorf("jtcore error in %s: %s", job.logname, report.error_msg)
			}
			continue
		}
		if !job.pass && !report.done {
			msg := report.last_line
			if msg == "" {
				msg = "jtcore exited without PASS/FAIL"
			}
			fmt.Printf("Seed %5d error after %s: %s\n", job.seed, job.walltime, msg)
			if first_error == nil {
				first_error = fmt.Errorf("jtcore stopped before PASS/FAIL in %s: %s", job.logname, msg)
			}
			continue
		}
		slack := job.worst_slack()
		cfg.record_sta_slack(slack)
		copy_msg := cfg.copy_if_best(job, slack)
		if job.pass {
			fmt.Printf("Seed %5d passed in %s, worst slack %s%s\n", job.seed, job.walltime, slack, copy_msg)
			*pass = true
			batch_pass = true
		} else {
			fmt.Printf("Seed %5d failed in %s, worst slack %s%s\n", job.seed, job.walltime, slack, copy_msg)
		}
	}
	if first_error != nil {
		return false, first_error
	}
	return batch_pass || *pass, nil
}

func wait_seed_jobs(jobs []seed_job) []seed_job {
	done := make(chan seed_job, len(jobs))
	for _, job := range jobs {
		go func(job seed_job) {
			job.pass = job.wait()
			done <- job
		}(job)
	}
	waited := make([]seed_job, 0, len(jobs))
	for range jobs {
		waited = append(waited, <-done)
	}
	return waited
}

func (cfg *seed_config) add_walltime(elapsed time.Duration) {
	cfg.walltime += elapsed
	cfg.walljobs++
}

func (cfg *seed_config) report_walltime() {
	if cfg.walljobs == 0 {
		return
	}
	fmt.Printf("Average compilation walltime per job: %s\n", (cfg.walltime/time.Duration(cfg.walljobs)).Round(time.Second))
}

func (cfg *seed_config) record_sta_slack(slack string) {
	value, ok := parse_slack_value(slack)
	if ok && (!cfg.sta_valid || value > cfg.sta_slack) {
		cfg.sta_slack = value
		cfg.sta_valid = true
	}
}

func (cfg *seed_config) copy_if_best(job seed_job, slack string) string {
	value, ok := parse_slack_value(slack)
	if !ok || (cfg.best_valid && value <= cfg.best_slack) {
		return ""
	}
	src := cfg.release.source_rbf(job.builddir)
	if _, e := os.Stat(src); e != nil {
		return fmt.Sprintf(", release copy skipped: %v", e)
	}
	dst := cfg.release.release_rbf()
	e := copy_file(src, dst)
	if e != nil {
		return fmt.Sprintf(", release copy failed: %v", e)
	}
	cfg.best_slack = value
	cfg.best_valid = true
	return fmt.Sprintf(", RBF copied to release")
}

func (cfg *seed_config) core_has_nosta() bool {
	cfg.load_core_macros()
	return macros.IsSet("JTFRAME_NOSTA")
}

func (cfg *seed_config) core_has_easy_sta() bool {
	cfg.load_core_macros()
	return macros.IsSet("JTFRAME_EASY_STA")
}

func (cfg *seed_config) load_core_macros() {
	macros.MakeMacros(cfg.release.core, cfg.release.target, cfg.convert_args_to_macros()...)
}

func (cfg *seed_config) convert_args_to_macros() []string {
	defs := make([]string, 0, 4)
	for k := 0; k < len(cfg.jtcore_args); k++ {
		each := cfg.jtcore_args[k]
		switch each {
		case "--nodbg":
			defs = append(defs, "JTFRAME_RELEASE=1")
		case "--def", "-d":
			k++
			if k < len(cfg.jtcore_args) {
				defs = append(defs, strings.Split(cfg.jtcore_args[k], ",")...)
			}
		default:
			if strings.HasPrefix(each, "--def=") {
				defs = append(defs, strings.Split(strings.TrimPrefix(each, "--def="), ",")...)
			}
		}
	}
	return defs
}

func (cfg *seed_config) append_nosta_undef() {
	cfg.jtcore_args = append(cfg.jtcore_args, "-u", "JTFRAME_NOSTA")
}

func parse_slack_value(slack string) (float64, bool) {
	value, e := strconv.ParseFloat(slack, 64)
	return value, e == nil
}

func (cfg *seed_config) release_info() (seed_release, error) {
	info := seed_release{core: cfg.core(), target: default_target()}
	for k := 0; k < len(cfg.jtcore_args); k++ {
		each := cfg.jtcore_args[k]
		switch each {
		case "--target", "-t":
			k++
			if k >= len(cfg.jtcore_args) {
				return info, fmt.Errorf("missing target after %s", each)
			}
			info.target = cfg.jtcore_args[k]
		case "--credits", "--quicker", "-qq", "-mr", "-mrq":
			info.target = "mister"
		default:
			if strings.HasPrefix(each, "--target=") {
				info.target = strings.TrimPrefix(each, "--target=")
			} else if target, ok := info.target_from_arg(each); ok {
				info.target = target
			}
		}
	}
	if info.core == "" {
		return info, fmt.Errorf("cannot determine core name")
	}
	info.core = strings.ToLower(info.core)
	return info, nil
}

func default_target() string {
	if target := os.Getenv("TARGET"); target != "" {
		return target
	}
	return "mist"
}

func (info seed_release) target_exists(target string) bool {
	root, e := get_jtroot()
	if e != nil {
		return false
	}
	_, e = os.Stat(filepath.Join(root, "modules", "jtframe", "target", target))
	return e == nil
}

func (info seed_release) target_from_arg(arg string) (string, bool) {
	if !strings.HasPrefix(arg, "-") || strings.HasPrefix(arg, "--") {
		return "", false
	}
	target := strings.TrimPrefix(arg, "-")
	if !info.target_exists(target) {
		return "", false
	}
	return target, true
}

func get_jtroot() (string, error) {
	if root := os.Getenv("JTROOT"); root != "" {
		return root, nil
	}
	return "", fmt.Errorf("JTROOT must be defined")
}

func (info seed_release) source_rbf(output string) string {
	base := output
	name := info.rbf_name() + ".rbf"
	if info.is_mister_target() || info.target == "neptuno" {
		base = filepath.Join(base, "output_files")
	}
	if info.target == "pocket" {
		return filepath.Join(base, name+"_r")
	}
	return filepath.Join(base, name)
}

func (info seed_release) release_rbf() string {
	root, e := get_jtroot()
	if e != nil {
		return ""
	}
	if info.target == "pocket" {
		return filepath.Join(root, "release", "pocket", "raw", "Cores", "jotego."+info.core, info.rbf_name()+".rbf_r")
	}
	return filepath.Join(root, "release", info.target, info.rbf_name()+".rbf")
}

func (info seed_release) rbf_name() string {
	if info.rbf != "" {
		return info.rbf
	}
	return "jt" + info.core
}

func (info seed_release) is_mister_target() bool {
	switch info.target {
	case "mister", "sockit", "de1soc", "de10std":
		return true
	}
	return false
}

func copy_file(src, dst string) error {
	e := os.MkdirAll(filepath.Dir(dst), 0775)
	if e != nil {
		return e
	}
	in, e := os.Open(src)
	if e != nil {
		return e
	}
	defer in.Close()
	out, e := os.Create(dst)
	if e != nil {
		return e
	}
	_, e = io.Copy(out, in)
	close_e := out.Close()
	if e != nil {
		return e
	}
	return close_e
}

func (cfg *seed_config) next_seed() int {
	seed := 0
	if cfg.seed_count != 0 || !seed_zero {
		seed = cfg.random.Intn(32768)
		for cfg.used_seeds[seed] {
			seed = cfg.random.Intn(32768)
		}
	}
	cfg.used_seeds[seed] = true
	cfg.seed_count++
	return seed
}

func start_jtcore_logged(jtcore_args []string, seed int, output string) (seed_job, error) {
	e := os.MkdirAll(output, 0775)
	if e != nil {
		return seed_job{}, e
	}
	logname := filepath.Join(output, "jtcore.log")
	logfile, e := os.Create(logname)
	if e != nil {
		return seed_job{}, e
	}
	builddir := filepath.Join(output, "build")
	job, e := start_jtcore_with_io(jtcore_args, seed, builddir, logfile, logfile)
	if e != nil {
		logfile.Close()
		return seed_job{}, e
	}
	job.logfile = logfile
	job.logname = logname
	job.output = output
	job.builddir = builddir
	return job, nil
}

func start_jtcore_with_io(jtcore_args []string, seed int, output string, stdout, stderr *os.File) (seed_job, error) {
	args := append([]string{}, jtcore_args...)
	args = append(args, "--nocopy", "--seed", strconv.Itoa(seed))
	if output != "" {
		args = append(args, "--output", output)
	}
	cmd := exec.Command("jtcore", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	start := time.Now()
	e := cmd.Start()
	if e != nil {
		return seed_job{}, e
	}
	return seed_job{seed: seed, cmd: cmd, start: start}, nil
}

func (job *seed_job) wait() bool {
	e := job.cmd.Wait()
	job.walltime = time.Since(job.start)
	if job.logfile != nil {
		job.logfile.Close()
	}
	return e == nil
}

func (job seed_job) worst_slack() string {
	if slack := worst_sta_slack(job.builddir); slack != "" {
		return slack
	}
	if slack := worst_log_slack(job.logname); slack != "" {
		return slack
	}
	return "n/a"
}

type jtcore_log_report struct {
	error_msg string
	done      bool
	last_line string
}

func (job seed_job) log_report() jtcore_log_report {
	report := jtcore_log_report{}
	f, e := os.Open(job.logname)
	if e != nil {
		return report
	}
	defer f.Close()
	scan := bufio.NewScanner(f)
	for scan.Scan() {
		line := scan.Text()
		if strings.TrimSpace(line) != "" {
			report.last_line = strings.TrimSpace(line)
		}
		if msg, found := parse_jtcore_error(line); found && report.error_msg == "" {
			report.error_msg = msg
		}
		if parse_jtcore_done(line) {
			report.done = true
		}
	}
	return report
}

func worst_sta_slack(output string) string {
	worst := ""
	worst_value := 0.0
	check_summary := func(fname string) {
		f, e := os.Open(fname)
		if e != nil {
			return
		}
		defer f.Close()
		scan := bufio.NewScanner(f)
		for scan.Scan() {
			if value, found := parse_sta_slack(scan.Text()); found {
				parsed, e := strconv.ParseFloat(value, 64)
				if e == nil && (worst == "" || parsed < worst_value) {
					worst = value
					worst_value = parsed
				}
			}
		}
	}
	walk := func(fname string, d os.DirEntry, e error) error {
		if e != nil || d.IsDir() || !strings.HasSuffix(fname, ".sta.summary") {
			return nil
		}
		check_summary(fname)
		return nil
	}
	filepath.WalkDir(output, walk)
	return worst
}

func worst_log_slack(logname string) string {
	slack := ""
	f, e := os.Open(logname)
	if e != nil {
		return slack
	}
	defer f.Close()
	scan := bufio.NewScanner(f)
	for scan.Scan() {
		if value, found := parse_worst_slack(scan.Text()); found {
			slack = value
		}
	}
	return slack
}

func parse_sta_slack(line string) (string, bool) {
	match := sta_slack_re.FindStringSubmatch(line)
	if match == nil {
		return "", false
	}
	return match[1], true
}

func parse_worst_slack(line string) (string, bool) {
	lower := strings.ToLower(line)
	if !strings.Contains(lower, "worst-case") || !strings.Contains(lower, "slack") {
		return "", false
	}
	match := worst_slack_re.FindStringSubmatch(line)
	if match == nil {
		return strings.TrimSpace(line), true
	}
	return match[1], true
}

func parse_jtcore_error(line string) (string, bool) {
	if !strings.Contains(line, "ERROR") {
		return "", false
	}
	return strings.TrimSpace(line), true
}

func parse_jtcore_done(line string) bool {
	switch strings.TrimSpace(line) {
	case "PASS", "FAIL":
		return true
	}
	return false
}

var sta_slack_re = regexp.MustCompile(`(?i)^\s*Slack\s*:\s*([-+]?[0-9]+(?:\.[0-9]+)?)`)
var worst_slack_re = regexp.MustCompile(`(?i)worst-case.*slack[^-+0-9]*([-+]?[0-9]+(?:\.[0-9]+)?)`)

func stop_requested() bool {
	_, e := os.Stat("jtseed.last")
	if e != nil {
		return false
	}
	os.Remove("jtseed.last")
	return true
}

func (cfg *seed_config) output_base() (string, error) {
	info := cfg.release
	if info.core == "" {
		var e error
		info, e = cfg.release_info()
		if e != nil {
			return "", e
		}
	}
	root, e := get_jtroot()
	if e != nil {
		return "", e
	}
	return filepath.Join(root, "cores", info.core, "seed", info.target), nil
}
