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
	"strings"

	"jtutil/vcd"
	"github.com/spf13/cobra"
)

// verilogCmd represents the verilog command
var verilogCmd = &cobra.Command{
	Use:   "verilog file[.vcd]",
	Short: "Converts a VCD to a verilog .bin and .v files for simulation use",
	//Long:
	Run: verilogCmdRun,
	Args: cobra.ExactArgs(1),
}

func verilogCmdRun(cmd *cobra.Command, args []string) {
	fname := args[0]
	if strings.HasSuffix(args[0],".vcd") {
		fname = args[0][0:len(args[0])-4]
	}
	var d vcd.LnFile
	d.Open(fname+".vcd")
	ss := vcd.GetSignals(&d)
	must(d.DumpHex(ss,fname))
}

func init() {
	vcdCmd.AddCommand(verilogCmd)
}

