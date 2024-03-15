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
    Date: 28-8-20122 */

package cmd

import (
	jtfiles "github.com/jotego/jtframe/files"
	"github.com/spf13/cobra"
	"github.com/jotego/jtframe/common"
)

// filesCmd represents the files command
var filesCmd = &cobra.Command{
	Use:   "files <sim|syn|plain> <core-name>",
	Short: "Generates the project compilation and simulation files",
	Long: common.Doc2string("jtframe-files.md"),
	Run:  run_files,
	Args: cobra.ExactArgs(2),
}

var files_args jtfiles.Args

func init() {
	rootCmd.AddCommand(filesCmd)
	flag := filesCmd.Flags()

	flag.StringVarP(&files_args.Target, "target", "t", "", "Target platform: mist, mister, pocket, etc.")
	flag.StringVarP(&files_args.AddMacro, "macro", "m", "", "Add more verilog macros separated by commas")
	flag.BoolVar(&files_args.Rel, "rel", false, "Output relative paths")
	flag.BoolVar(&files_args.Local, "local", false, "Refer to mem.yaml derived files in the local, instead of the target, folder")
}

func run_files(cmd *cobra.Command, args []string) {
	files_args.Corename = args[1]
	files_args.Format = args[0]

	jtfiles.Run(files_args)
}
