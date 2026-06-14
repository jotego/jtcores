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
    Date: 14-6-2026 */

package cmd

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

const gh_build_workflow = "compile-custom.yaml"
const gh_build_poll_interval = 10 * time.Second

var gh_build_ref string
var gh_build_batch bool
var gh_build_targets []string

var ghBuildCmd = &cobra.Command{
	Use:   "gh-build <core> [core...]",
	Short: "Run a remote GitHub FPGA build and download the artifact",
	Long: man_blurb("jtutil-gh-build", `Triggers the compile-custom GitHub Actions workflow for one or more
cores and a comma-separated target list, waits for the run to finish, and
downloads the matching release artifacts into $JTROOT/release.`),
	Run:  run_gh_build,
	Args: cobra.MinimumNArgs(1),
}

func init() {
	ghBuildCmd.Flags().BoolVar(&gh_build_batch, "batch", false, "Poll without full-screen terminal updates")
	ghBuildCmd.Flags().StringVar(&gh_build_ref, "ref", "", "Git ref that contains the workflow file")
	ghBuildCmd.Flags().StringSliceVarP(&gh_build_targets, "target", "t", nil, "Comma-separated list of FPGA targets")
	_ = ghBuildCmd.MarkFlagRequired("target")
	rootCmd.AddCommand(ghBuildCmd)
}

func run_gh_build(cmd *cobra.Command, args []string) {
	cfg, e := new_gh_build_config(args, gh_build_targets)
	must(e)
	e = cfg.run()
	must(e)
}

type gh_build_config struct {
	cores   []string
	targets []string
	release string
	run_id  string
	batch   bool
}

func new_gh_build_config(cores, targets []string) (*gh_build_config, error) {
	clean_cores := gh_build_clean_values(cores)
	_, e := gh_build_list_slug(clean_cores, "core")
	if e != nil {
		return nil, e
	}
	clean_targets := gh_build_clean_targets(targets)
	_, e = gh_build_list_slug(clean_targets, "target")
	if e != nil {
		return nil, e
	}
	jtroot := os.Getenv("JTROOT")
	if jtroot == "" {
		return nil, fmt.Errorf("JTROOT is not defined in the environment")
	}
	return &gh_build_config{
		cores:   clean_cores,
		targets: clean_targets,
		release: filepath.Join(jtroot, "release"),
		batch:   gh_build_batch,
	}, nil
}

func (cfg *gh_build_config) run() error {
	core_list := strings.Join(cfg.cores, ",")
	target_list := strings.Join(cfg.targets, ",")
	fmt.Printf("Triggering %s for %s on %s\n", gh_build_workflow, core_list, target_list)
	output, e := cfg.gh_output("workflow", "run", gh_build_workflow, "-f", "core="+core_list, "-f", "target="+target_list)
	if e != nil {
		return e
	}
	cfg.run_id, e = gh_build_run_id(output)
	if e != nil {
		return e
	}
	fmt.Printf("Waiting for GitHub run %s\n", cfg.run_id)
	e = cfg.wait()
	if e != nil {
		return e
	}
	e = os.MkdirAll(cfg.release, 0775)
	if e != nil {
		return e
	}
	for _, core := range cfg.cores {
		for _, target := range cfg.targets {
			artifact := "release-" + target + "-" + core
			fmt.Printf("Downloading %s into %s\n", artifact, cfg.release)
			e = cfg.gh_run("run", "download", cfg.run_id, "-n", artifact, "-D", cfg.release)
			if e != nil {
				return e
			}
		}
	}
	return nil
}

func (cfg *gh_build_config) wait() error {
	if cfg.batch {
		return cfg.wait_batch()
	}
	return cfg.gh_run("run", "watch", cfg.run_id, "--compact", "--exit-status", "--interval", "10")
}

func (cfg *gh_build_config) wait_batch() error {
	seen := make(map[string]bool)
	for {
		status, e := cfg.run_status()
		if e != nil {
			return e
		}
		for _, job := range status.Jobs {
			if job.Status != "completed" || seen[job.Name] {
				continue
			}
			seen[job.Name] = true
			fmt.Printf("Completed: %s (%s)\n", job.Name, job.Conclusion)
		}
		if status.Status == "completed" {
			if status.Conclusion != "success" {
				return fmt.Errorf("GitHub run %s finished with conclusion %s", cfg.run_id, status.Conclusion)
			}
			return nil
		}
		time.Sleep(gh_build_poll_interval)
	}
}

func (cfg *gh_build_config) run_status() (*gh_build_run_status, error) {
	output, e := cfg.gh_output("run", "view", cfg.run_id, "--json", "status,conclusion,jobs")
	if e != nil {
		return nil, e
	}
	var status gh_build_run_status
	e = json.Unmarshal([]byte(output), &status)
	if e != nil {
		return nil, e
	}
	return &status, nil
}

type gh_build_run_status struct {
	Status     string                `json:"status"`
	Conclusion string                `json:"conclusion"`
	Jobs       []gh_build_job_status `json:"jobs"`
}

type gh_build_job_status struct {
	Name       string `json:"name"`
	Status     string `json:"status"`
	Conclusion string `json:"conclusion"`
}

func (cfg *gh_build_config) gh_output(args ...string) (string, error) {
	if len(args) >= 2 && args[0] == "workflow" && args[1] == "run" && gh_build_ref != "" {
		args = append(args, "--ref", gh_build_ref)
	}
	cmd := exec.Command("gh", args...)
	cmd.Stderr = os.Stderr
	out, e := cmd.Output()
	if e != nil {
		return "", e
	}
	return string(out), nil
}

func (cfg *gh_build_config) gh_run(args ...string) error {
	cmd := exec.Command("gh", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func gh_build_target_slug(targets []string) (string, error) {
	return gh_build_list_slug(targets, "target")
}

func gh_build_list_slug(values []string, label string) (string, error) {
	fields := gh_build_clean_values(values)
	if len(fields) == 0 {
		return "", fmt.Errorf("%s list must contain at least one value", label)
	}
	return strings.Join(fields, "-"), nil
}

func gh_build_clean_targets(targets []string) []string {
	return gh_build_clean_values(targets)
}

func gh_build_clean_values(values []string) []string {
	clean := make([]string, 0, len(values))
	for _, each := range values {
		each = strings.TrimSpace(each)
		if each != "" {
			clean = append(clean, each)
		}
	}
	return clean
}

func gh_build_run_id(output string) (string, error) {
	for _, field := range strings.Fields(output) {
		parsed, e := url.Parse(field)
		if e != nil || parsed.Host == "" {
			continue
		}
		if strings.Contains(parsed.Path, "/actions/runs/") {
			return path.Base(parsed.Path), nil
		}
	}
	return "", fmt.Errorf("could not find GitHub run id in gh workflow output")
}
