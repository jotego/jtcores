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
    Version: 1.0
    Date: 7-9-2022 */

package cmd

import (
	"github.com/jotego/jtframe/cfgstr"
	"github.com/jotego/jtframe/def"
	"github.com/spf13/cobra"
)

var cfg def.Config
var extra_def, extra_undef string

// cfgstrCmd represents the cfgstr command
var cfgstrCmd = &cobra.Command{
	Use:   "cfgstr <core-name>",
	Short: "Parse core variables",
	Long: `Parses the jtcore-name.def file in the hdl folder and
creates input files for simulation or synthesis.
Macro names for C++ include files are prefixed by an underscore _`,
	Run: func(cmd *cobra.Command, args []string) {
		cfg.Core = args[0]
		cfgstr.Run(cfg, args, extra_def, extra_undef)
	},
	Args: cobra.MinimumNArgs(1),
}

func init() {
	rootCmd.AddCommand(cfgstrCmd)
	flag := cfgstrCmd.Flags()

	flag.StringVarP(&cfg.Target, "target", "t", "mist", "Target platform (mist, mister, sidi, neptuno, mc2, mcp, pocket, sockit, de1soc, de10std)")
	flag.StringVar(&cfg.Deffile, "parse", "", "Path to .def file")
	flag.StringVar(&cfg.Template, "tpl", "", "Path to template file")
	flag.StringVar(&cfg.Commit, "commit", "nocommit", "Commit ID")
	flag.StringVarP(&extra_def, "def", "d", "", "Defines macros, separated by comma")
	flag.StringVarP(&extra_undef, "undef", "u", "", "Undefines macros, separated by comma")
	flag.StringVarP(&cfg.Output, "output", "o", "cfgstr",
		"Type of output: \n\tcfgstr -> config string\n\tbash -> bash script\n\tquartus -> quartus tcl\n\tsimulator name as specified in jtsim")
	flag.BoolVarP(&cfg.Verbose, "verbose", "v", false, "verbose")
}
