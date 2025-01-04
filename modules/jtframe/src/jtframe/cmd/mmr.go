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
	"github.com/spf13/cobra"

	"github.com/jotego/jtframe/mmr"
	. "github.com/jotego/jtframe/common"
)

// mmrCmd represents the mmr command
var mmrCmd = &cobra.Command{
	Use:   "mmr [core-name]",
	Short: "Generate verilog modules for memory mapped registers",
	Long: `From a core's cfg/mmr.yml file, generate a MMR implementation in verilog`,
	Run: func(cmd *cobra.Command, args []string) {
		var e error
		var corename string
		corename, e = get_corename(args)
		Must(e)
		mmrpath := mmr.GetMMRPath(corename)
		if FileExists(mmrpath) {
			Must(mmr.Generate(corename, verbose))
		} else if verbose {
			fmt.Printf("Skipping MMR for core %s (%s not present)\n",corename,mmrpath)
		}
	},
	Args: cobra.MaximumNArgs(1),
}

func init() {
	rootCmd.AddCommand(mmrCmd)
}

