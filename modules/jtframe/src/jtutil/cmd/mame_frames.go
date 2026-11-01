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

var mameFramesSetname string
var mameFramesDryrun bool

var mameFramesCmd = &cobra.Command{
	Use:   "mame-frames",
	Short: "Validate new regression captures against ordered MAME frames",
	Long: `Runs MAME for each completed new regression capture, matching every image
exactly in strictly increasing MAME frame order. Exact matches are promoted
from new to ref after a final progress and digest check. A dry run validates
and reports without changing result folders or logs.

Use --setname to select one game name across all core result folders.`,
	Args: cobra.NoArgs,
	RunE: run_mame_frames_cmd,
}

func init() {
	mameFramesCmd.Flags().StringVar(&mameFramesSetname, "setname", "", "Validate only this game name")
	mameFramesCmd.Flags().BoolVar(&mameFramesDryrun, "dryrun", false, "Report validation results without logging or promoting captures")
	rootCmd.AddCommand(mameFramesCmd)
}

func run_mame_frames_cmd(cmd *cobra.Command, args []string) error {
	if mameFramesSetname != "" && !safe_manual_regression_name(mameFramesSetname) {
		return fmt.Errorf("--setname must contain only letters, digits, underscore or hyphen")
	}
	root := os.Getenv("JOTEGO")
	if root == "" {
		return fmt.Errorf("JOTEGO must name the private regression data directory")
	}
	result_root := filepath.Join(root, "regression")
	ctx := cmd.Context()
	if ctx == nil {
		ctx = context.Background()
	}
	ctx, stop := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
	defer stop()
	results, err := regression.RunMameFrames(ctx, result_root, project_root(), mameFramesSetname, mameFramesDryrun)
	for _, result := range results {
		fmt.Fprintf(cmd.OutOrStdout(), "%-12s %-5s %s\n", result.Setname, result.Verdict, result.Detail)
	}
	if err != nil {
		return err
	}
	if len(results) == 0 {
		fmt.Fprintln(cmd.OutOrStdout(), "No eligible new regression captures found.")
	}
	return nil
}
