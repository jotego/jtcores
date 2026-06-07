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
)

type seed_config struct {
	max_reps    int
	parallel    int
	jtcore_args []string
	used_seeds  map[int]bool
	seed_count  int
	random      *rand.Rand
	best_slack  float64
	best_valid  bool
}

type seed_job struct {
	seed     int
	cmd      *exec.Cmd
	logfile  *os.File
	logname  string
	output   string
	builddir string
	pass     bool
}

var seed_parallel int

var seedCmd = &cobra.Command{
	Use:   "seed [flags] [max-retries] <core> [jtcore options]",
	Short: "Run jtcore repeatedly with different seeds",
	Long: man_blurb("jtutil-seed", `Runs jtcore repeatedly with different --seed values until one build passes or max-retries is reached.

Options consumed by jtutil seed must appear before max-retries/core:
    --parallel n          Run up to n jtcore seed builds at the same time
    --parallel=n          Same as --parallel n
    --help | -h           Show this summary

After optional max-retries is removed, the remaining arguments are passed to
jtcore. In parallel mode each jtcore run gets a distinct --seed and --output
folder. The Quartus build runs under <output>/build, and its console output is written to <output>/jtcore.log. Parallel
runs invoke jtcore with --nocopy; as jobs finish, jtutil seed copies the best
RBF seen so far into the normal release/<target>/ folder. The default output
base is:
    $JTROOT/cores/<core-name>/seed

Create a jtseed.last file in the current folder to stop after the current batch.`),
	Run:  run_seed,
	Args: cobra.ArbitraryArgs,
}

func init() {
	seedCmd.Flags().IntVar(&seed_parallel, "parallel", 1, "Run up to n jtcore seed builds at the same time")
	seedCmd.Flags().SetInterspersed(false)
	rootCmd.AddCommand(seedCmd)
}

func run_seed(cmd *cobra.Command, args []string) {
	cfg, e := seed_config_from_flags(cmd.Flags(), args)
	must(e)
	e = cfg.run()
	must(e)
}

func seed_config_from_flags(flags *pflag.FlagSet, args []string) (*seed_config, error) {
	parallel, e := flags.GetInt("parallel")
	if e != nil {
		return nil, e
	}
	if parallel <= 0 {
		return nil, fmt.Errorf("Error: use a positive integer after --parallel")
	}
	cfg := &seed_config{
		max_reps:   100,
		parallel:   parallel,
		used_seeds: make(map[int]bool),
		random:     rand.New(rand.NewSource(time.Now().UnixNano())),
	}
	if len(args) > 0 && is_seed_number(args[0]) && !is_194x(args[0]) {
		var e error
		cfg.max_reps, e = strconv.Atoi(args[0])
		if e != nil {
			return nil, e
		}
		args = args[1:]
	} else {
		fmt.Println("Call jtutil seed with a number as the first argument to limit the iterations")
	}
	for _, each := range args {
		switch each {
		case "-s", "--skip":
			return nil, fmt.Errorf("Error: cannot invoke jtutil seed with the -s (skip) option")
		default:
			cfg.jtcore_args = append(cfg.jtcore_args, each)
		}
	}
	return cfg, nil
}

func (cfg *seed_config) run() error {
	fmt.Println("Create a jtseed.last file at this folder to stop at the next compilation")
	os.Remove("jtseed.last")
	if cfg.parallel == 1 {
		return cfg.run_serial()
	}
	return cfg.run_parallel()
}

func (cfg *seed_config) run_serial() error {
	seed := cfg.next_seed()
	for cfg.max_reps > 0 {
		pass, e := run_jtcore(cfg.jtcore_args, seed, "")
		if e != nil {
			return e
		}
		if pass {
			return nil
		}
		if stop_requested() {
			return nil
		}
		seed = cfg.next_seed()
		cfg.max_reps--
	}
	return fmt.Errorf("Maximum number of seed trial reached")
}

func (cfg *seed_config) run_parallel() error {
	output_base, e := cfg.seed_output_base()
	if e != nil {
		return e
	}
	pass := false
	for cfg.max_reps > 0 {
		batch := cfg.parallel
		if cfg.max_reps < batch {
			batch = cfg.max_reps
		}
		jobs := make([]seed_job, 0, batch)
		for k := 0; k < batch; k++ {
			seed := cfg.next_seed()
			output := filepath.Join(output_base, strconv.Itoa(seed))
			job, e := start_jtcore_logged(cfg.jtcore_args, seed, output)
			if e != nil {
				fmt.Printf("Seed %d failed\n", seed)
				fmt.Println(e)
			} else {
				jobs = append(jobs, job)
			}
			cfg.max_reps--
		}
		for _, job := range jobs {
			job.pass = job.wait()
			slack := job.worst_slack()
			copy_msg := cfg.copy_if_best(job, slack)
			if job.pass {
				fmt.Printf("Seed %d passed, worst slack %s, %s\n", job.seed, slack, copy_msg)
				pass = true
			} else {
				fmt.Printf("Seed %d failed, worst slack %s, %s\n", job.seed, slack, copy_msg)
			}
		}
		if pass {
			return nil
		}
		if stop_requested() {
			return nil
		}
	}
	return fmt.Errorf("Maximum number of seed trial reached")
}

func (cfg *seed_config) copy_if_best(job seed_job, slack string) string {
	value, ok := parse_slack_value(slack)
	if !ok || (cfg.best_valid && value <= cfg.best_slack) {
		return ""
	}
	info, e := seed_release_info(cfg.jtcore_args)
	if e != nil {
		return fmt.Sprintf(", release copy skipped: %v", e)
	}
	src := info.source_rbf(job.builddir)
	if _, e := os.Stat(src); e != nil {
		return fmt.Sprintf(", release copy skipped: %v", e)
	}
	dst := info.release_rbf()
	e = copy_file(src, dst)
	if e != nil {
		return fmt.Sprintf(", release copy failed: %v", e)
	}
	cfg.best_slack = value
	cfg.best_valid = true
	return fmt.Sprintf(", RBF copied to release")
}

func parse_slack_value(slack string) (float64, bool) {
	value, e := strconv.ParseFloat(slack, 64)
	return value, e == nil
}

func seed_release_info(jtcore_args []string) (seed_release, error) {
	info := seed_release{target: default_seed_target()}
	for k := 0; k < len(jtcore_args); k++ {
		each := jtcore_args[k]
		switch each {
		case "--target", "-t":
			k++
			if k >= len(jtcore_args) {
				return info, fmt.Errorf("missing target after %s", each)
			}
			info.target = jtcore_args[k]
		case "--credits", "--quicker", "-qq", "-mr", "-mrq":
			info.target = "mister"
		default:
			if strings.HasPrefix(each, "--target=") {
				info.target = strings.TrimPrefix(each, "--target=")
			} else if strings.HasPrefix(each, "-") && seed_target_exists(each[1:]) {
				info.target = each[1:]
			} else if info.core == "" && !strings.HasPrefix(each, "-") {
				info.core = each
			}
		}
	}
	if info.core == "" {
		return info, fmt.Errorf("cannot determine core name")
	}
	root, e := seed_root()
	if e != nil {
		return info, e
	}
	info.root = root
	info.core = strings.ToLower(info.core)
	return info, nil
}

func default_seed_target() string {
	if target := os.Getenv("TARGET"); target != "" {
		return target
	}
	return "mist"
}

func seed_target_exists(target string) bool {
	root, e := seed_root()
	if e != nil {
		return false
	}
	_, e = os.Stat(filepath.Join(root, "modules", "jtframe", "target", target))
	return e == nil
}

func seed_root() (string, error) {
	if root := os.Getenv("JTROOT"); root != "" {
		return root, nil
	}
	return os.Getwd()
}

func (info seed_release) source_rbf(output string) string {
	base := output
	name := "jt" + info.core + ".rbf"
	if is_mister_seed_target(info.target) || info.target == "neptuno" {
		base = filepath.Join(base, "output_files")
	}
	if info.target == "pocket" {
		return filepath.Join(base, name+"_r")
	}
	return filepath.Join(base, name)
}

func (info seed_release) release_rbf() string {
	if info.target == "pocket" {
		return filepath.Join(info.root, "release", "pocket", "raw", "Cores", "jotego."+info.core, "jt"+info.core+".rbf_r")
	}
	return filepath.Join(info.root, "release", info.target, "jt"+info.core+".rbf")
}

func is_mister_seed_target(target string) bool {
	switch target {
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

type seed_release struct {
	root   string
	core   string
	target string
}

func (cfg *seed_config) next_seed() int {
	seed := 0
	if cfg.seed_count != 0 {
		seed = cfg.random.Intn(32768)
		for cfg.used_seeds[seed] {
			seed = cfg.random.Intn(32768)
		}
	}
	cfg.used_seeds[seed] = true
	cfg.seed_count++
	return seed
}

func run_jtcore(jtcore_args []string, seed int, output string) (bool, error) {
	job, e := start_jtcore(jtcore_args, seed, output)
	if e != nil {
		return false, e
	}
	return job.wait(), nil
}

func start_jtcore(jtcore_args []string, seed int, output string) (seed_job, error) {
	args := append([]string{}, jtcore_args...)
	args = append(args, "--seed", strconv.Itoa(seed))
	if output != "" {
		args = append(args, "--output", output)
	}
	cmd := exec.Command("jtcore", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	e := cmd.Start()
	if e != nil {
		return seed_job{}, e
	}
	return seed_job{seed: seed, cmd: cmd}, nil
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
	e := cmd.Start()
	if e != nil {
		return seed_job{}, e
	}
	return seed_job{seed: seed, cmd: cmd}, nil
}

func (job seed_job) wait() bool {
	e := job.cmd.Wait()
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

func (cfg *seed_config) seed_output_base() (string, error) {
	info, e := seed_release_info(cfg.jtcore_args)
	if e != nil {
		return "", e
	}
	return filepath.Join(info.root, "cores", info.core, "seed"), nil
}

func is_seed_number(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

func is_194x(s string) bool {
	return len(s) == 4 && s[0] == '1' && s[1] == '9' && s[2] == '4'
}

