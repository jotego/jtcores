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
    Date: 21-1-2023 */

package cmd

import (
	"strings"

	"github.com/jotego/jtframe/ucode"
	"github.com/spf13/cobra"
)

// ucodeCmd represents the ucode command
var ucodeCmd = &cobra.Command{
	Use:   "ucode <module> [variation]",
	Short: "Generate verilog files for microcode",
	Long: `Parses a YAML file and generates
a Verilog module and a verilog include file.
`,
	Args: cobra.RangeArgs(1, 2),
	Run: func(cmd *cobra.Command, args []string) {
		fname := args[0]
		if len(args) == 2 {
			fname = args[1]
		}
		if !strings.HasSuffix(fname, ".yaml") {
			fname = fname + ".yaml"
		}
		ucode.Args.Verbose = verbose
		ucode.Make(args[0], fname)
	},
}

func init() {
	rootCmd.AddCommand(ucodeCmd)
	ucodeCmd.Flags().BoolVarP(&ucode.Args.Report,"report", "r", false, "Report cycle count")
	ucodeCmd.Flags().BoolVarP(&ucode.Args.List,"list", "l", false, "Generate list file")
	ucodeCmd.Flags().BoolVarP(&ucode.Args.GTKWave,"gtkwave", "w", false, "Generate GTKWave files for readable waveform traces")
	ucodeCmd.Flags().StringVarP(&ucode.Args.Output,"output", "o", "", "Prefix to use for output files")
}
