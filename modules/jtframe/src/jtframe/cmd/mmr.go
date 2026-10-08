/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-1-2023 */

package cmd

import (
	"fmt"
	"github.com/spf13/cobra"
	"path/filepath"

	. "jotego/jtframe/common"
	"jotego/jtframe/mmr"
)

func init() {
	var module bool
	var mmrCmd = &cobra.Command{
		Use:   "mmr [core-or-module-name]",
		Short: "Generate verilog modules for memory mapped registers",
		Long:  man_blurb("jtframe-mmr", "Generate Verilog modules for memory mapped registers."),
		Run: func(cmd *cobra.Command, args []string) {
			var e error
			var corename string
			corename, e = get_mmr_name(args, module)
			Must(e)
			mmrpath := mmr.GetMMRPath(corename, module)
			if FileExists(mmrpath) {
				Must(mmr.Generate(corename, verbose, module))
			} else if verbose {
				fmt.Printf("Skipping MMR for %s (%s not present)\n", corename, mmrpath)
			}
		},
		Args: cobra.MaximumNArgs(1),
	}

	mmrCmd.Flags().BoolVarP(&module, "module", "m", false, "Use modules/<name> instead of cores/<name>")
	rootCmd.AddCommand(mmrCmd)
}

func get_mmr_name(args []string, module bool) (string, error) {
	if !module {
		return get_corename(args)
	}
	if len(args) == 0 {
		return "", fmt.Errorf("module name required with --module")
	}
	name := args[0]
	dirname, rest := filepath.Split(name)
	if dirname != "" || rest != name || name == "" || name == "." || name == ".." {
		return "", fmt.Errorf("%s is not a valid module folder name", name)
	}
	return name, nil
}
