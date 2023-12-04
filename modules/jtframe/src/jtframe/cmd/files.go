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
)

// filesCmd represents the files command
var filesCmd = &cobra.Command{
	Use:   "files <sim|syn|plain> <core-name>",
	Short: "Generates the project compilation and simulation files",
	Long: `The project files are defined in cores/corename/game.yaml.
jtframe files command will also add the required files for the
selected compilation or simulation target.

The first argument selects simulation (sim) or synthesis (output). The
synthesis output consists of .qip files compatible with Intel Quartus.

A third option is "plain", which simply generates a plain text file with
the file names and path used.

The simulation output creates two files:
- game.f for all verilog files
- jtsim_vhdl.f for all VHDL files

The yaml file is composed of several sections, which can only appear once:

- game: get files from a given core hdl folder
- jtframe: get files from jtframe/hdl folders
- modules: get files from the modules folder

For modules, there is a shortcut for JT ones and a generic way

modules:
  jt:
    - name: jt51
      when: MACRO name
    - name: jtkcpu
      unless: MACRO name
  other:
  	- from: foo
  	  get: [ hdl/foo.v ]

# Conditional file parsing:

Each file list can be parsed conditionally using the keys:
- unless: will always parse it unless the macro is defined
- when: will only parse it when the macro is defined

`,
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
