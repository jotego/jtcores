/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 21-1-2023 */

package cmd

import (
	"fmt"
	"path/filepath"
	"github.com/spf13/cobra"

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
			corename, e = get_mmr_name(args,module)
			Must(e)
			mmrpath := mmr.GetMMRPath(corename,module)
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
	if !module { return get_corename(args) }
	if len(args) == 0 { return "", fmt.Errorf("module name required with --module") }
	name := args[0]
	dirname, rest := filepath.Split(name)
	if dirname != "" || rest != name || name == "" || name == "." || name == ".." {
		return "", fmt.Errorf("%s is not a valid module folder name", name)
	}
	return name,nil
}
