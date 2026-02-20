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
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"jtutil/vcd"
)

func init() {
	rootCmd.AddCommand(vcdCmd)

	vcdCmd.AddCommand(csvCmd)
	csvCmd.Flags().BoolVarP  (&csv_converter.DumpTime,       "dump-time", "t", true, "dump the VCD as the first CSV column")
	csvCmd.Flags().StringVarP(&csv_converter.OutputFileName, "output", "o", "", "name of the output file")
	csvCmd.Flags().StringSliceVarP(&csv_converter.MustBeSet, "must-be-set", "1", nil, "comma separated list of signals that must be high in order to dump the line")

}

var vcdCmd = &cobra.Command{
	Use:   "vcd",
	Short: "VCD file manipulation",
	Long: `Several tools to manipulate VCD files`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Call vcd with one of the available subcommands")
	},
	Args: cobra.NoArgs,
}

var csvCmd = &cobra.Command{
	Use:   "csv file.vcd",
	Short: "Converts vcd file to csv",
	Run: func(cmd *cobra.Command, args []string) {
		e := csv_converter.Convert(args[0])
		if e!=nil {
			fmt.Println(e)
			os.Exit(1)
		}
	},
	Args: cobra.MinimumNArgs(1),
}

var csv_converter vcd.CSVConverter