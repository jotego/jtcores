/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package cmd

import (
	"fmt"
	"math"
	"strconv"

	"github.com/spf13/cobra"
)

var frac_args struct {
	maxbits *int
	n, m    int
	n0, m0  int
}

// fracCmd represents the frac command
var fracCmd = &cobra.Command{
	Use:   "frac input-frequency output-frequency",
	Short: "Find n/m factors to generate a fractional clock divider",
	Long:  man_blurb("jtutil-frac", "Find n/m factors to generate a fractional clock divider."),
	Run: func(cmd *cobra.Command, args []string) {
		in, e := strconv.ParseFloat(args[0], 64)
		must(e)
		out, e := strconv.ParseFloat(args[1], 64)
		must(e)
		if out > in {
			x := out
			out = in
			in = x
		}
		fracRun(in, out)
	},
	Args: cobra.MinimumNArgs(2),
}

func init() {
	rootCmd.AddCommand(fracCmd)
	frac_args.maxbits = fracCmd.Flags().IntP("bits", "b", 10, "Bit width for fractional factors")
}

func fracRun(in, out float64) {
	aux := 1 << *frac_args.maxbits
	mmax := float64(aux)
	emin := out
	var n, m float64
	for mt := 1.0; mt < mmax; mt += 1 {
		nt := math.Round((out * mt) / in)
		if nt >= mmax {
			continue
		}
		e := math.Abs(in*nt/mt - out)
		// fmt.Println(nt,mt,e)
		if e < emin {
			n = nt
			m = mt
			emin = e
		}
		if e == 0 {
			break
		}
	}

	fmt.Printf("%d/%d -> %.0f (%.1f)\n", int(n), int(m), in*n/m, emin)
}
