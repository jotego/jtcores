package cmd

import (
	"fmt"
	"math"
	"strconv"
	"os"

	"github.com/spf13/cobra"
)

func must( e error ) {
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
}

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