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
var mameFramesLegacySiDi128 bool

var mameFramesCmd = &cobra.Command{
	Use:   "mame-frames",
	Short: "Validate new regression captures against ordered MAME frames",
Long: `Runs MAME for each completed new regression capture in a visible window,
using a finite emulation duration to bypass information and warning screens,
and matching every image at the target's
native per-channel precision in strictly increasing MAME frame order. Exact matches are promoted
from new to ref after a final progress and provenance check. MiSTer promotion
requires a matching finalized capture generation and qualification. A dry run validates
and reports without changing result folders or logs. Legacy SiDi128 result writes
require explicit --legacy-sidi128. A working graphical display is required.

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
	mameFramesCmd.Flags().BoolVar(&mameFramesLegacySiDi128, "legacy-sidi128", false, "Explicitly opt in to legacy SiDi128 MAME log/promotion writes")
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
	cfg, err := regression.ReadConfig(mameFramesConfig)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	target := cfg.Target
	if target == "" {
		if archived, present, markerErr := regression.ReadCaptureTarget(result_root); markerErr != nil {
			return markerErr
		} else if present {
			target = archived
		} else if mameFramesLegacySiDi128 {
			target = "sidi128"
		} else if mameFramesDryrun {
			target = "sidi128"
		} else {
			return fmt.Errorf("mame-frames writes require target=mister or explicit --legacy-sidi128")
		}
	}
	if target == "sidi128" && !mameFramesDryrun && !mameFramesLegacySiDi128 {
		return fmt.Errorf("writing legacy SiDi128 MAME results requires --legacy-sidi128")
	}
	if target == "mister" && mameFramesLegacySiDi128 {
		return fmt.Errorf("--legacy-sidi128 cannot be combined with target=mister")
	}
	options := regression.MameFrameOptions{Target: target, LegacySiDi128: mameFramesLegacySiDi128}
	if cfg.CaptureContract != nil {
		options.Generation = cfg.CaptureContract.Generation
		options.QualificationID = cfg.CaptureContract.QualificationID
	}
	ctx := cmd.Context()
	if ctx == nil {
		ctx = context.Background()
	}
	ctx, stop := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
	defer stop()
	results, err := regression.RunMameFrames(ctx, result_root, project_root(), mameFramesSetname, mameFramesDryrun, mameFramesJobs, global_profile, options)
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
