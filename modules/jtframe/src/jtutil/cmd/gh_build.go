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
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path"
	"strings"

	"github.com/spf13/cobra"
)

const gh_build_workflow = "compile-one.yaml"

var gh_build_ref string
var gh_build_targets []string

var ghBuildCmd = &cobra.Command{
	Use:   "gh-build <core>",
	Short: "Run a remote GitHub FPGA build and download the artifact",
	Long: man_blurb("jtutil-gh-build", `Triggers the compile-one GitHub Actions workflow for a core and
comma-separated target list, waits for the run to finish, and downloads the
matching release artifact into $JTROOT.`),
	Run:  run_gh_build,
	Args: cobra.ExactArgs(1),
}

func init() {
	ghBuildCmd.Flags().StringVar(&gh_build_ref, "ref", "", "Git ref that contains the workflow file")
	ghBuildCmd.Flags().StringSliceVarP(&gh_build_targets, "target", "t", nil, "Comma-separated list of FPGA targets")
	_ = ghBuildCmd.MarkFlagRequired("target")
	rootCmd.AddCommand(ghBuildCmd)
}

func run_gh_build(cmd *cobra.Command, args []string) {
	cfg, e := new_gh_build_config(args[0], gh_build_targets)
	must(e)
	e = cfg.run()
	must(e)
}

type gh_build_config struct {
	core     string
	targets  []string
	artifact string
	jtroot   string
	run_id   string
}

func new_gh_build_config(core string, targets []string) (*gh_build_config, error) {
	clean_targets := gh_build_clean_targets(targets)
	target_slug, e := gh_build_target_slug(clean_targets)
	if e != nil {
		return nil, e
	}
	jtroot := os.Getenv("JTROOT")
	if jtroot == "" {
		return nil, fmt.Errorf("JTROOT is not defined in the environment")
	}
	return &gh_build_config{
		core:     core,
		targets:  clean_targets,
		artifact: "release-" + target_slug + "-" + core,
		jtroot:   jtroot,
	}, nil
}

func (cfg *gh_build_config) run() error {
	target_list := strings.Join(cfg.targets, ",")
	fmt.Printf("Triggering %s for %s on %s\n", gh_build_workflow, cfg.core, target_list)
	output, e := cfg.gh_output("workflow", "run", gh_build_workflow, "-f", "core="+cfg.core, "-f", "target="+target_list)
	if e != nil {
		return e
	}
	cfg.run_id, e = gh_build_run_id(output)
	if e != nil {
		return e
	}
	fmt.Printf("Waiting for GitHub run %s\n", cfg.run_id)
	e = cfg.gh_run("run", "watch", cfg.run_id, "--compact", "--exit-status")
	if e != nil {
		return e
	}
	fmt.Printf("Downloading %s into %s\n", cfg.artifact, cfg.jtroot)
	e = cfg.gh_run("run", "download", cfg.run_id, "-n", cfg.artifact, "-D", cfg.jtroot)
	if e != nil {
		return e
	}
	return nil
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
	fields := gh_build_clean_targets(targets)
	if len(fields) == 0 {
		return "", fmt.Errorf("target flag must contain at least one target")
	}
	has_mist := false
	for _, each := range fields {
		if each == "mist" {
			has_mist = true
		}
	}
	if has_mist && len(fields) != 1 {
		return "", fmt.Errorf("mist uses jotego/jtcore13 and cannot be combined with other targets")
	}
	return strings.Join(fields, "-"), nil
}

func gh_build_clean_targets(targets []string) []string {
	clean := make([]string, 0, len(targets))
	for _, each := range targets {
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
