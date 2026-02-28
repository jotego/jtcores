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

// sdramCmd represents the sdram command
var sdramCmd = &cobra.Command{
	Use:   "sdram [game-name]",
	Short: "Convert .rom files to sdram files for quick simulation",
	Long: `Convert .rom files to sdram files for quick simulation

After you create the .rom files using jtframe mra, you can generate
the sdram*.bin simulation files without having to run a download simulation by
calling jtframe sdram.

jtframe sdram must be called from within a simulation folder, such as ver/game.
If the simulation folder is the ROM set name, that will be used. If the folder
is just "game", then the set name must be provided in the command line.

jtframe sdram will split the .rom file in the right number of sdram*bin files by
inspecting the definitions of JTFRAME_BA?_START, JTFRAME_PROM_START and
JTFRAME_HEADER.

jtframe sdram will also link a rom.bin file to the .rom file used. If rom.bin
already existed, it will be deleted and re-created as a link.

If the core uses the header for SDRAM bank assignment, special care
must be taken for the PROM data as JTFRAME_PROM_START will not be defined. This
utility will create a file for each ROM region after bank 3, so the core can
directly load these files in simulation. You can also force the PROM load in
simulation for these cores by setting the SIM_LOAD_PROM macro.

The result will only be correct for cores that do not transform download data on
the fly.
`,
	Run:  run_sdram,
	Args: cobra.MaximumNArgs(1),
}

func init() {
	rootCmd.AddCommand(sdramCmd)
}

func run_sdram(cmd *cobra.Command, args []string) {
	err := sdramexec.Run(args, verbose)
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
}
