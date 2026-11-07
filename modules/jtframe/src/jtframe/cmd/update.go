/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-1-2023 */

package cmd

import (
	goflag "flag"
	"fmt"
	"jotego/jtframe/update"
	"os"
	"strings"

	"github.com/spf13/cobra"
)

var up_cfg update.Config
var up_targets []string
var up_all bool

// memCmd represents the mem command
var updateCmd = &cobra.Command{
	Use:   "update [--cores] core1,core2,... <--target mist|mister...>",
	Short: "Updates compiled files for cores or prepares GitHub action files",
	Long:  man_blurb("jtframe-update", "List or launch update tasks for builds, MRA files, and schematics."),
	Run: func(cmd *cobra.Command, args []string) {
		if len(args) > 0 && up_cfg.CoreList != "" {
			fmt.Fprintln(os.Stderr, "Error: you cannot specify cores using --cores and arguments at the same time")
			os.Exit(1)
		}
		if len(args) > 0 {
			up_cfg.CoreList = strings.Join(args, ",")
		}
		up_cfg.Targets = make(map[string]bool)
		for _, each := range up_targets {
			up_cfg.Targets[each] = true
		}
		if up_all {
			up_cfg.Targets["mist"] = true
			up_cfg.Targets["sidi"] = true
			up_cfg.Targets["sidi128"] = true
			up_cfg.Targets["pocket"] = true
			up_cfg.Targets["mister"] = true
			up_cfg.Targets["neptuno"] = true
			up_cfg.Targets["mcp"] = true
			up_cfg.Targets["mc2"] = true
			up_cfg.Targets["sockit"] = true
			up_cfg.Targets["de1soc"] = true
			up_cfg.Targets["de10std"] = true
		}
		update.Run(&up_cfg, args)
	},
	Args: cobra.ArbitraryArgs,
}

func init() {
	rootCmd.AddCommand(updateCmd)
	flag := updateCmd.Flags()

	target_flag := goflag.NewFlagSet("Target parser", goflag.ContinueOnError)
	target_flag.Func("target", "Adds a new target", func(t string) error { up_cfg.Targets[t] = true; return nil })
	flag.StringSliceVarP(&up_targets, "target", "t", []string{"mist", "sidi", "sidi128", "mister", "pocket"}, "Comma separated list of targets")

	flag.AddGoFlagSet(target_flag)
	// Ignored flags, which are handled on the script side
	flag.Bool("dry", false, "Shows the jobs without running them")
	flag.String("jobs", "", "Limits the number of parallel jobs")
	flag.Bool("network", false, "Use network resources")
	flag.Bool("keep", false, "Do not delete the release folder")
	// Actual flags
	flag.BoolVar(&up_cfg.Nohdmi, "nohdmi", false, "HDMI disabled in MiSTer")
	flag.BoolVar(&up_cfg.Nosnd, "nosnd", false, "define the NOSOUND macro")
	flag.BoolVar(&up_cfg.Nodbg, "nodbg", false, "defines the JTFRAME_RELEASE macro")
	flag.BoolVar(&up_cfg.Git, "git", false, "Sets $JTBIN as the output and defines JTFRAME_RELEASE")
	flag.BoolVar(&up_cfg.Seed, "seed", false, "Random seed iteration used for compilation")
	flag.BoolVar(&up_cfg.Private, "private", false, "Build for JTALPHA team (defines JTFRAME_RELEASE and a red OSD)")
	flag.BoolVarP(&up_cfg.Skip, "skipRBF", "s", false, "Skip RBF generation and update only MRA files")
	flag.BoolVarP(&up_cfg.SkipROM, "skipROM", "n", false, "Skip ROM generation when parsing MRA files")
	flag.BoolVarP(&up_cfg.MainOnly, "mainonly", "o", false, "Only parse the main version of each game")
	flag.StringVar(&up_cfg.Stamp, "corestamp", "", "Date string for RBF file. Passed to jtcore")
	flag.StringVarP(&up_cfg.CoreList, "cores", "c", "", "Comma separated list of cores")
	flag.StringVarP(&up_cfg.Defs, "def", "d", "", "Comma separated list of macros")
	flag.StringVar(&up_cfg.Group, "group", "", "Core group specified in $JTROOT/.jtupdate")
	flag.BoolVar(&up_all, "all", false, "updates all target platforms")
}
