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

	"github.com/spf13/cobra"
	"jtutil/regression"
)

var mame_frames_opts regression.MameFrameOptions

var mameFramesCmd = &cobra.Command{
	Use:   "mame-frames",
	Short: "Accept new regression frames that match MAME",
	Long: `Compares the new/ frames of each game in $JOTEGO/regression that has no ref/
with the frames that MAME renders for cores/<core>/ver/<setname>/reg.cab.

MAME runs in a window, isolated under /tmp, with the NVRAM defaults of the game
and the CAB inputs applied one line per frame. It runs 500 frames past the last
captured frame, at most 299 emulated seconds. Each frame_<N>.png must equal a
MAME frame later than the one that matched the previous frame, with the colour
channels cut to the JTFRAME_COLORW bits of the core. Frames that are all black
or all identical never match.

A match makes new/ the ref/, as --accept does, and logs ACCEPT by mame in the
game's log. It needs the regression lock: while a regression run holds it, the
match is reported as BUSY and the game is left as it is. A mismatch is reported
as FAIL and changes nothing. --dryrun compares without changing anything.`,
	Args: cobra.NoArgs,
	RunE: run_mame_frames_cmd,
}

func init() {
	flag := mameFramesCmd.Flags()
	flag.StringVar(&mame_frames_opts.Core, "core", "", "Only check the games of this core")
	flag.StringSliceVar(&mame_frames_opts.Setnames, "setname", nil, "Only check these setnames")
	flag.BoolVar(&mame_frames_opts.Dryrun, "dryrun", false, "Compare without promoting")
	flag.IntVar(&mame_frames_opts.Jobs, "jobs", 4, "Games compared at the same time")
	flag.StringVar(&mame_frames_opts.MAME, "mame", "mame", "MAME executable")
	home, _ := os.UserHomeDir()
	flag.StringVar(&mame_frames_opts.ROMPath, "rompath", filepath.Join(home, ".mame", "roms"), "MAME ROM folder")
	rootCmd.AddCommand(mameFramesCmd)
}

func run_mame_frames_cmd(cmd *cobra.Command, args []string) error {
	jotego := os.Getenv("JOTEGO")
	if jotego == "" {
		return fmt.Errorf("JOTEGO must name the private regression data directory")
	}
	for _, name := range append([]string{mame_frames_opts.Core}, mame_frames_opts.Setnames...) {
		if name != "" && !safe_manual_regression_name(name) {
			return fmt.Errorf("%q is not a core or setname", name)
		}
	}
	cmd.SilenceUsage = true
	opts := mame_frames_opts
	opts.Root, opts.Source, opts.Out = filepath.Join(jotego, "regression"), project_root(), cmd.OutOrStdout()
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	results, e := regression.RunMameFrames(ctx, opts)
	count := map[string]int{}
	for _, r := range results {
		count[r.Verdict]++
	}
	fmt.Fprintf(cmd.OutOrStdout(), "%d games: %d PASS, %d FAIL, %d BUSY\n", len(results), count["PASS"], count["FAIL"], count["BUSY"])
	return e
}
