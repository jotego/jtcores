/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-5-2026 */

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
