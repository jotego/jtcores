/*  This file is part of JTCORES.
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
    Date: 4-1-2025 */

package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	sdramexec "jtutil/sdram"
)

var sdram_sim bool

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
}

func run_sdram(cmd *cobra.Command, args []string) {
	err := sdramexec.Run(args, verbose, sdram_sim)
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
}
