/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package cmd

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/spf13/cobra"
	"jtutil/regression"
)

var mameFramesSetname string
var mameFramesDryrun bool
var mameFramesJobs int
var mameFramesConfig string

var mameFramesCmd = &cobra.Command{
	Use:   "mame-frames",
	Short: "Validate new regression captures against ordered MAME frames",
	Long: `Runs MAME for each completed new regression capture, matching every image
at the core's RGB444/RGB555 capture precision in strictly increasing MAME frame order. Exact matches are promoted
from new to ref after a final progress and digest check. A dry run validates
and reports without changing result folders or logs.

Use --setname to select one game name, or a comma-separated list of names. Up to
--jobs games are validated concurrently (default 4); use --jobs 1 for serial execution.
Use --config to select the regression config and its optional global profile.`,
	Args: cobra.NoArgs,
	RunE: run_mame_frames_cmd,
}

func init() {
	mameFramesCmd.Flags().StringVar(&mameFramesSetname, "setname", "", "Validate one game name or a comma-separated list")
	mameFramesCmd.Flags().BoolVar(&mameFramesDryrun, "dryrun", false, "Report validation results without logging or promoting captures")
	mameFramesCmd.Flags().IntVar(&mameFramesJobs, "jobs", 4, "Maximum games to validate concurrently")
	mameFramesCmd.Flags().StringVar(&mameFramesConfig, "config", filepath.Join(project_root(), ".jtutil-regression.yaml"), "Regression profile configuration")
	rootCmd.AddCommand(mameFramesCmd)
}

func run_mame_frames_cmd(cmd *cobra.Command, args []string) error {
	if mameFramesSetname != "" {
		for _, set := range strings.Split(mameFramesSetname, ",") {
			set = strings.TrimSpace(set)
			if !safe_manual_regression_name(set) {
				return fmt.Errorf("--setname values must contain only letters, digits, underscore or hyphen")
			}
		}
	}
	if mameFramesJobs < 1 {
		return fmt.Errorf("--jobs must be positive")
	}
	global_profile, configErr := mame_global_profile(project_root(), mameFramesConfig, cmd.Flags().Changed("config"))
	if configErr != nil {
		return configErr
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
	results, err := regression.RunMameFrames(ctx, result_root, project_root(), mameFramesSetname, mameFramesDryrun, mameFramesJobs, global_profile)
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

func mame_global_profile(source, config_path string, explicit bool) (string, error) {
	default_profile := filepath.Join(source, "modules", "jtframe", "bin", "reg.yaml")
	cfg, err := regression.ReadConfig(config_path)
	if os.IsNotExist(err) {
		if explicit {
			return "", fmt.Errorf("regression config %s does not exist", config_path)
		}
		return default_profile, nil
	}
	if err != nil {
		return "", err
	}
	if cfg.GlobalProfile != "" {
		return cfg.GlobalProfile, nil
	}
	return default_profile, nil
}
