/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-1-2023 */

package cmd

import (
	"strings"

	"github.com/spf13/cobra"
	"jotego/jtframe/ucode"
)

// ucodeCmd represents the ucode command
var ucodeCmd = &cobra.Command{
	Use:   "ucode <module> [variation]",
	Short: "Generate verilog files for microcode",
	Long:  man_blurb("jtframe-ucode", "Generate Verilog microcode outputs from a YAML description."),
	Args:  cobra.RangeArgs(1, 2),
	Run: func(cmd *cobra.Command, args []string) {
		fname := args[0]
		if len(args) == 2 {
			fname = args[1]
		}
		if !strings.HasSuffix(fname, ".yaml") {
			fname = fname + ".yaml"
		}
		ucode.Args.Verbose = verbose
		ucode.Make(args[0], fname)
	},
}

func init() {
	rootCmd.AddCommand(ucodeCmd)
	ucodeCmd.Flags().BoolVarP(&ucode.Args.Report, "report", "r", false, "Report cycle count")
	ucodeCmd.Flags().BoolVarP(&ucode.Args.List, "list", "l", false, "Generate list file")
	ucodeCmd.Flags().BoolVarP(&ucode.Args.GTKWave, "gtkwave", "w", false, "Generate GTKWave files for readable waveform traces")
	ucodeCmd.Flags().StringVarP(&ucode.Args.Output, "output", "o", "", "Prefix to use for output files")
}
