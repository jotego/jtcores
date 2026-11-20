/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package cmd

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/spf13/cobra"
	"jtutil/regression"
)

var regression_opts regression.Options

var regressionCmd = &cobra.Command{
	Use:   "regression",
	Short: "Run the MiSTer hardware regression",
	Long: `Runs every game that has a CAB file on the MiSTer boards and compares the
captured frames with $JOTEGO/regression/<core>/<setname>/ref.

Sources, choose one:
  --commit <hash>  the compile-all zip $JOTEGO/core-builds/<hash>.zip. The games
                   are release/cab/*.cab
  --poll           the newest successful compile-all build, downloaded with gh
                   when its zip is missing. Nothing happens if it was tested
                   already or another regression is running
  --core <core>    the games of one core, from a fresh release folder: the RBF
                   in $JTROOT/release/mister, MRA files from jtframe mra and the
                   cores/<core>/ver/*/reg.cab files. A dirty tree is allowed

The release folder goes to /media/fat/_<hash> of each board with jtbin2mr, which
needs MISTERPASSWD and wipes the core settings; a board whose copy takes over
10 minutes is left out. Each board then takes the next game from a shared
queue: load_core, cab_session_start, wait for the status file
/tmp/jtcap/status.json, fetch the PNGs. The load has its own limit;
the capture limit is 1.2*(M+1)/50 seconds for a CAB whose last line is M (50 Hz
is the lowest refresh rate of the cores). An operational error is retried once,
then recorded as ERROR with /tmp/MiSTer.log; the board reboots after each one
and leaves the run if it does not come back. Frame mismatches are not retried.

Results go to $JOTEGO/regression/<core>/<setname>/{new,fail,error} and the
progress to $JOTEGO/regression/log/<hash>.json (manual-<hash>[-dirty].json for
--core, which never marks a commit as tested). Running the same commit again
resumes it; --commit also reruns its ERROR games.`,
	Args: cobra.NoArgs,
	RunE: run_regression_cmd,
}

func init() {
	flag := regressionCmd.Flags()
	flag.StringVar(&regression_opts.Commit, "commit", "", "Test the compile-all zip of this commit")
	flag.BoolVar(&regression_opts.Poll, "poll", false, "Test the newest successful compile-all build")
	flag.StringVar(&regression_opts.Core, "core", "", "Test one core from the working tree")
	flag.StringSliceVar(&regression_opts.Boards, "boards", []string{"mister.home", "mister2.home", "mister3.home"}, "MiSTer host names")
	flag.DurationVar(&regression_opts.LoadLimit, "load-limit", 30*time.Second, "Time limit to load a game")
	flag.StringVar(&regression_opts.PublishTo, "publish-to", "github", "Report destination for full runs: github, gitea (GITEA_SERVER_URL, GITEA_REPOSITORY, GITEA_TOKEN) or none")
	rootCmd.AddCommand(regressionCmd)
}

func run_regression_cmd(cmd *cobra.Command, args []string) error {
	jotego := os.Getenv("JOTEGO")
	if jotego == "" {
		return fmt.Errorf("JOTEGO must name the private regression data directory")
	}
	if regression_opts.Core != "" && !safe_manual_regression_name(regression_opts.Core) {
		return fmt.Errorf("--core must be a core name")
	}
	cmd.SilenceUsage = true
	opts := regression_opts
	opts.Root, opts.Builds = filepath.Join(jotego, "regression"), filepath.Join(jotego, "core-builds")
	opts.Source, opts.Out = project_root(), cmd.OutOrStdout()
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	return regression.Run(ctx, opts)
}

func safe_manual_regression_name(name string) bool {
	if name == "" {
		return false
	}
	for _, c := range name {
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') {
			return false
		}
	}
	return true
}

func project_root() string {
	root := os.Getenv("JTROOT")
	if root == "" {
		root, _ = os.Getwd()
	}
	root, _ = filepath.Abs(root)
	return root
}
