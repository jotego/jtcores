/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	sdramexec "jtutil/sdram"
)

var sdram_sim bool
var sdram_target string
var sdram_undef []string

// sdramCmd represents the sdram command
var sdramCmd = &cobra.Command{
	Use:   "sdram [game-name]",
	Short: "Convert .rom files to sdram files for quick simulation",
	Long:  man_blurb("jtutil-sdram", "Convert .rom files into SDRAM bank files for simulation."),
	Run:   run_sdram,
	Args:  cobra.MaximumNArgs(1),
}

func init() {
	rootCmd.AddCommand(sdramCmd)
	sdramCmd.Flags().BoolVar(&sdram_sim, "sim", false, "Apply mem.yaml simfile overlays to SDRAM bank files")
	sdramCmd.Flags().StringVarP(&sdram_target, "target", "t", "mister", "Target platform used when parsing macros.def")
	sdramCmd.Flags().StringSliceVarP(&sdram_undef, "undef", "u", nil, "Undefine macros while parsing macros.def")
}

func run_sdram(cmd *cobra.Command, args []string) {
	err := sdramexec.RunWithOptions(args, verbose, sdramexec.RunOptions{
		ApplySim: sdram_sim,
		Target:   sdram_target,
		Undef:    sdram_undef,
	})
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
}
