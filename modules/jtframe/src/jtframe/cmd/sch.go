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
    Date: 21-1-2023 */

package cmd

import (
	 "fmt"
	"io/fs"
	"path/filepath"
	"os"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"
)

var jtbin, verbose bool
var output_folder string

func parse_folder( corename string, cores_fs fs.FS, path string) {
	entries, e := fs.ReadDir( cores_fs, path )
	if e != nil {
		return
	}
	for _, k := range entries {
		if k.IsDir() {
			parse_folder( k.Name(), cores_fs, filepath.Join(path,k.Name()) )
		} else if k.Name() == corename+".kicad_sch" {
			// fullpath := filepath.Join( path, k.Name() )
			os.Chdir(filepath.Join("cores",path))
			cmd_args := []string{
				"kicad-cli-nightly","sch","export","pdf",
				"--output", filepath.Join(output_folder,corename+".pdf"), k.Name(),
			}
			if verbose {
				fmt.Printf("Running %s\n\tin %s\n", strings.Join(cmd_args," "), path)
			}
			cmd := exec.Command( cmd_args[0], cmd_args[1:]... )
			e = cmd.Run()
			if e != nil {
				fmt.Println(e)
			} else if verbose {
				fmt.Printf("\tcompleted.\n")
			}
			os.Chdir(os.Getenv("JTROOT"))
		}
	}
}

// schCmd represents the mra command
var schCmd = &cobra.Command{
	Use:   "sch [core-name...]",
	Short: "Produces PDF views of the schematics associated with a core in the release/sch folder",
	// Long: "",
	Run: func(cmd *cobra.Command, args []string) {
		var cores_fs fs.FS
		os.Chdir(os.Getenv("JTROOT"))
		cores_fs = os.DirFS( filepath.Join(os.Getenv("JTROOT"),"cores") )
		// if e != nil {
		// 	fmt.Println("Cannot open the cores folder ", os.Getenv("CORES") )
		// 	os.Exit(1)
		// }
		if len(args)==0 {
			entries, _ := fs.ReadDir( cores_fs, "." )
			for _, each := range entries {
				if each.IsDir() {
					args = append(args,each.Name())
				}
			}
		}
		if jtbin {
			output_folder = filepath.Join(os.Getenv("JTBIN"),"sch")
		} else {
			output_folder = filepath.Join(os.Getenv("JTROOT"),"release","sch")
		}
		os.MkdirAll(output_folder,0776)
		for _, corename := range args {
			parse_folder( corename, cores_fs, filepath.Join(corename,"sch") )
		}
	},
	Args: cobra.ArbitraryArgs,
}

func init() {
	rootCmd.AddCommand(schCmd)
	flag := schCmd.Flags()

	flag.BoolVarP(&jtbin, "git", "g", false, "Save files to $JTBIN/sch")
	flag.BoolVarP(&verbose, "verbose", "v", false, "Verbose")
}
