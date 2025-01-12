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
	"math"
	"strconv"

	"github.com/spf13/cobra"
)

var frac_args struct{
	maxbits		*int
	n,m			int
	n0,m0		int
}

// fracCmd represents the frac command
var fracCmd = &cobra.Command{
	Use:   "frac input-frequency output-frequency",
	Short: "Find n/m factors to generate a fractional clock divider",
// 	Long: `A longer description that spans multiple lines and likely contains examples
// and usage of using your command. For example:

// Cobra is a CLI library for Go that empowers applications.
// This application is a tool to generate the needed files
// to quickly create a Cobra application.`,
	Run: func(cmd *cobra.Command, args []string) {
		in, e  := strconv.ParseFloat(args[0],64)
		must(e)
		out, e  := strconv.ParseFloat(args[1],64)
		must(e)
		if out>in {
			x := out
			out = in
			in = x
		}
		fracRun( in, out )
	},
	Args: cobra.MinimumNArgs(2),
}

func init() {
	rootCmd.AddCommand(fracCmd)
	frac_args.maxbits = fracCmd.Flags().IntP("bits", "b", 10, "Bit width for fractional factors")
}

func fracRun( in, out float64) {
	aux := 1<<*frac_args.maxbits
	mmax := float64(aux)
	emin := out
	var n,m float64
	for mt:=1.0; mt<mmax; mt+=1 {
		nt := math.Round((out*mt)/in)
		if nt>=mmax { continue }
		e := math.Abs(in*nt/mt-out)
		// fmt.Println(nt,mt,e)
		if e < emin {
			n = nt
			m = mt
			emin = e
		}
		if e==0 {
			break
		}
	}

	fmt.Printf("%d/%d -> %.0f (%.1f)\n",int(n),int(m),in*n/m, emin)
}