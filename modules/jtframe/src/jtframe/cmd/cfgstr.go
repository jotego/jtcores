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
	. "github.com/jotego/jtframe/common"

	"github.com/spf13/cobra"
)

var cfg cfgstr.Config
var extra_def, extra_undef string

// cfgstrCmd represents the cfgstr command
var cfgstrCmd = &cobra.Command{
	Use:   "cfgstr [core-name]",
	Short: `Parses the macros.def file in the cfg folder`,
	Long: Doc2string("jtframe-cfgstr.md"),
	Run: func(cmd *cobra.Command, args []string) {
		var e error
		cfg.Core, e = get_corename(args)
		cfgstr.Verbose = verbose
		Must(e)
		Must(cfgstr.Run(cfg, args, extra_def, extra_undef))
	},
	Args: cobra.MaximumNArgs(1),
}

func init() {
	rootCmd.AddCommand(cfgstrCmd)
	flag := cfgstrCmd.Flags()

	flag.StringVarP(&cfg.Target, "target", "t", "mist", "Target platform (mist, mister, sidi, sidi128, neptuno, mc2, mcp, pocket, sockit, de1soc, de10std)")
	flag.StringVar(&cfg.Deffile, "parse", "", "Path to .def file")
	flag.StringVar(&cfg.Template, "tpl", "", "Path to template file")
	flag.StringVarP(&extra_def, "def", "d", "", "Defines macros, separated by comma")
	flag.StringVarP(&extra_undef, "undef", "u", "", "Undefines macros, separated by comma")
	flag.StringVarP(&cfg.Output, "output", "o", "cfgstr",
		"Type of output: \n\tcfgstr -> config string\n\tbash -> bash script\n\tquartus -> quartus tcl\n\tsimulator name as specified in jtsim")
}
