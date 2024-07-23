/*  This file is part of JT_FRAME.
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
    Date: 28-8-2022 */

package cmd

import (
	"fmt"
	"path/filepath"
	"os"
	"github.com/jotego/jtframe/mra"
	"github.com/jotego/jtframe/common"

	"github.com/spf13/cobra"
)

var mra_args mra.Args
var reduce, clear_folders bool

// mraCmd represents the mra command
var mraCmd = &cobra.Command{
	Use:   "mra <core-name core-name...> or mra --reduce <path-to-mame.xml>",
	Short: "Parses the core's TOML file to generate MRA files",
	Long: common.Doc2string("jtframe-mra.md"),
	Run: func(cmd *cobra.Command, args []string) {
		if reduce {
			mra.Reduce(args[0], mra_args.Verbose)
		} else { // regular operation, core names are separated by commas
			if clear_folders {
				root := os.Getenv("JTROOT")
				if root=="" {
					fmt.Println("Environment variable JTROOT is not set")
					os.Exit(1)
				}
				e := os.RemoveAll( filepath.Join(root,"release") )
				if mra_args.Verbose && e!= nil { fmt.Println(nil) }
				e = os.RemoveAll( filepath.Join(root,"rom") )
				if mra_args.Verbose && e!= nil { fmt.Println(nil) }
			}
			mra_args.Xml_path=filepath.Join(os.Getenv("JTROOT"),"doc","mame.xml")
			mra_args.Def_cfg.Target="mister"
			for _, each := range args {
				mra_args.Def_cfg.Core = each
				mra.Run(mra_args)
			}
		}
	},
	Args: cobra.MinimumNArgs(1),
}

func init() {
	rootCmd.AddCommand(mraCmd)
	flag := mraCmd.Flags()

	mra_args.Def_cfg.Target = "mist"
	flag.StringVar(&mra_args.Def_cfg.Commit, "commit", "", "result of running 'git rev-parse --short HEAD'")
	// flag.StringVar(&mra_args.Xml_path, "xml", os.Getenv("JTROOT")+"/doc/mame.xml", "Path to MAME XML file")
	flag.StringVar(&mra_args.Year, "year", "", "Year string for MRA file comment")
	flag.BoolVarP(&mra_args.Verbose, "verbose", "v", false, "verbose")
	flag.BoolVarP(&reduce, "reduce", "r", false, "Reduce the size of the XML file by creating a new one with only the entries required by the cores.")
	flag.BoolVar(&clear_folders, "rm", false, "Deletes the release and rom folders in $JTROOT before proceeding")
	flag.BoolVarP(&mra_args.SkipMRA, "skipMRA", "s", false, "Do not generate MRA files")
	flag.BoolVarP(&mra_args.SkipROM, "skipROM", "n", false, "Do not generate .rom files")
	flag.BoolVarP(&mra_args.MainOnly, "mainonly", "o", false, "Only parse the main version of each game")
	flag.BoolVar(&mra_args.Nodbg, "nodbg", false, "Do not parse games in debug phase")
	flag.BoolVarP(&mra_args.Md5, "md5", "m", false, "Calculate MD5 sum even if the ROM is not saved")
	flag.BoolVar(&mra_args.PrintNames, "names", false, "Print out the title of each game supported")
	flag.BoolVar(&mra_args.SkipPocket, "skipPocket", false, "Do not generate JSON files for the Pocket")
	flag.BoolVarP(&mra_args.Show_platform, "show_platform", "p", false, "Show platform name and quit")
	flag.BoolVarP(&mra_args.JTbin, "git", "g", false, "Save files to JTBIN")
	flag.StringVar(&mra_args.Buttons, "buttons", "", "Buttons used by the game -upto six-")
	flag.StringVar(&mra_args.URL, "url", "https://patreon.com/jotego", "Author's URL")
	flag.StringVar(&mra_args.Rom_path,"path",filepath.Join(os.Getenv("HOME"), ".mame", "roms"),"Path to MAME .zip files")
}
