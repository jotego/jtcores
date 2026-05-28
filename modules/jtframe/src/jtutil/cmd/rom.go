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
    Date: 28-5-2026 */

package cmd

import (
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"jotego/jtframe/mra"
	"jotego/jtframe/xmlnode"
)

var rom_path string

// romCmd represents the rom command
var romCmd = &cobra.Command{
	Use:   "rom <mra file>",
	Short: "Generate the .rom file for a given .mra file",
	Long:  man_blurb("jtutil-rom", "Generate a .rom file for a given .mra file."),
	Run:   run_rom,
	Args:  cobra.ExactArgs(1),
}

func init() {
	rootCmd.AddCommand(romCmd)
	flag := romCmd.Flags()
	mame_roms := filepath.Join(os.Getenv("HOME"), ".mame", "roms")
	flag.StringVar(&rom_path, "path", mame_roms, "Path to MAME .zip files")
}

func run_rom(cmd *cobra.Command, args []string) {
	mra_filename := args[0]
	mra.Verbose = verbose
	mraxml, e := xmlnode.ReadFile(mra_filename)
	if e != nil {
		must(e)
	}
	must(mra.Mra2rom(mraxml, true, rom_path))
}
