/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-1-2023 */

package cmd

import (
	"fmt"
	"github.com/spf13/cobra"

	. "jotego/jtframe/common"
	"jotego/jtframe/mmr"
)

func init() {
	var mmrCmd = &cobra.Command{
		Use:   "mmr [core-name]",
		Short: "Generate verilog modules for memory mapped registers",
		Long:  man_blurb("jtframe-mmr", "Generate Verilog modules for memory mapped registers."),
		Run: func(cmd *cobra.Command, args []string) {
			var e error
			var corename string
			corename, e = get_corename(args)
			Must(e)
			mmrpath := mmr.GetMMRPath(corename)
			if FileExists(mmrpath) {
				Must(mmr.Generate(corename, verbose))
			} else if verbose {
				fmt.Printf("Skipping MMR for core %s (%s not present)\n", corename, mmrpath)
			}
		},
		Args: cobra.MaximumNArgs(1),
	}

	rootCmd.AddCommand(mmrCmd)
}
