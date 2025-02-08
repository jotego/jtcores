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
	. "github.com/jotego/jtframe/common"

	"github.com/spf13/cobra"
)

var mra_args mra.Args
var cmd_args = struct{
	reduce, clear_folders bool
}{}

// mraCmd represents the mra command
var mraCmd = &cobra.Command{
	Use:   "mra <core-name core-name...> or mra --reduce <path-to-mame.xml>",
	Short: "Parses the core's TOML file to generate MRA files. Accepts */? in core name",
	Long: Doc2string("jtframe-mra.md"),
	Run: runMRA,
}

func init() {
	rootCmd.AddCommand(mraCmd)
	flag := mraCmd.Flags()

	mra_args.Target = "mist"
	mame_roms := filepath.Join(os.Getenv("HOME"), ".mame", "roms")
	// flag.StringVar(&mra_args.Xml_path, "xml", os.Getenv("JTROOT")+"/doc/mame.xml", "Path to MAME XML file")
	flag.StringVar(&mra_args.Year,          "year",                  "", "Year string for MRA file comment")
	flag.BoolVarP (&cmd_args.reduce,        "reduce",        "r", false, "Reduce the size of the XML file by creating a new one with only the entries required by the cores.")
	flag.BoolVar  (&cmd_args.clear_folders, "rm",                 false, "Deletes the release and rom folders in $JTROOT before proceeding")
	flag.BoolVarP (&mra_args.SkipMRA,       "skipMRA",       "s", false, "Do not generate MRA files")
	flag.BoolVarP (&mra_args.SkipROM,       "skipROM",       "n", false, "Do not generate .rom files")
	flag.BoolVarP (&mra_args.MainOnly,      "mainonly",      "o", false, "Only parse the main version of each game")
	flag.BoolVar  (&mra_args.Nodbg,         "nodbg",              false, "Do not parse games in debug phase")
	flag.BoolVarP (&mra_args.Md5,           "md5",           "m", false, "Calculate MD5 sum even if the ROM is not saved")
	flag.BoolVar  (&mra_args.PrintNames,    "names",              false, "Print out the title of each game supported")
	flag.BoolVar  (&mra_args.SkipPocket,    "skipPocket",         false, "Do not generate JSON files for the Pocket")
	flag.BoolVarP (&mra_args.Show_platform, "show_platform", "p", false, "Show platform name and quit")
	flag.BoolVarP (&mra_args.JTbin,         "git",           "g", false, "Save files to JTBIN")
	flag.StringVar(&mra_args.Buttons,       "buttons",               "", "Buttons used by the game -upto six-")
	flag.StringVar(&mra_args.URL,           "url",                "https://patreon.com/jotego", "Author's URL")
	flag.StringVar(&mra_args.Rom_path,      "path",           mame_roms, "Path to MAME .zip files")
}


func runMRA(cmd *cobra.Command, args []string) {
	mra.Verbose = verbose
	if cmd_args.reduce {
		if len(args)<1 {
			fmt.Println("Expected one argument with the path mame.xml")
			os.Exit(1)
		}
		mame_xml_path := args[0]
		Must(mra.Reduce(mame_xml_path))
	} else { // regular operation, each core name is an argument
		cores, e := get_corenames(args); Must(e)
		if len(cores)==0 {
			fmt.Println("Provide at least one core name as an argument or run the program from a core folder")
			os.Exit(1)
		}
		if cmd_args.clear_folders {
			clear_folders()
		}
		parse_errors := parse_cores(cores)
		Must(parse_errors)
	}
}

func clear_folders() {
	e1 := os.RemoveAll( MakeJTpath("release") )
	e2 := os.RemoveAll( MakeJTpath("rom") )
	if mra.Verbose {
		ShowErrors( e1, e2 )
	}
}

func parse_cores( corenames []string ) error {
	mra_args.Xml_path=MakeJTpath("doc","mame.xml")
	mra_args.Target="mister"
	entries, e := os.ReadDir(MakeJTpath("cores")); Must(e)
	if verbose {
		fmt.Println("Parsing", mra_args.Xml_path)
	}
	var all_errors error
	for _, entry := range entries {
		if !entry.IsDir() { continue }
		for _, pattern := range corenames {
			if match,_ := filepath.Match(pattern, entry.Name()); !match { continue }
			mra_args.Core = entry.Name()
			if !check_files(mra_args.Core) {
				fmt.Println("Skipping", mra_args.Core,"missing def/toml")
				continue
			}
			core_errors := mra.Convert(mra_args)
			all_errors = JoinErrors( all_errors, core_errors )
		}
	}
	return all_errors
}

func check_files( corename string ) bool {
	required_files := []string{"macros.def", "mame2mra.toml"}
	for _, name := range required_files {
		path := ConfigFilePath(corename,name)
		if !FileExists(path) { return false }
	}
	return true
}
