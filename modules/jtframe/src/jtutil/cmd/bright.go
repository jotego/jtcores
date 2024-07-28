package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var bright_args struct{
	rout, bpp, ow, runit, brw int
	dark bool
}

// brightCmd represents the bright command
var brightCmd = &cobra.Command{
	Use:   "bright",
	Short: "Calculate a LUT for RGB output when brightness is applied",
	Long: `Some arcade PCBs adjust the screen brightness with a resistor DAC
applied in parallel with each RGB DAC. This utility generates a LUT based on
the RGB DAC output impedance and the resistor unit used in the brightness DAC`,
	Run: func(cmd *cobra.Command, args []string) {
		calc_bright()
	},
}

func init() {
	rootCmd.AddCommand(brightCmd)
	brightCmd.Flags().IntVarP( &bright_args.rout,  "rout",  "r", 600, "RGB DAC output impedance (assumed R2R)")
	brightCmd.Flags().IntVarP( &bright_args.bpp,   "bpp",   "b",   6, "bits per color component (at RGB DAC)")
	brightCmd.Flags().IntVarP( &bright_args.brw,   "brw",   "w",   4, "bit width for brightness control")
	brightCmd.Flags().IntVarP( &bright_args.ow,    "ow",    "o",   8, "output bit width per color component")
	brightCmd.Flags().IntVarP( &bright_args.runit, "runit", "u", 250, "Unit resistor for the brightness DAC (assumed binary weighted)")
	brightCmd.Flags().BoolVarP(&bright_args.dark,  "dark",  "d", false, "Change color RDAC gain only, do not increase overall brightness")
}

func dump_lut( fname string, lut [][]int ) {
	f, e := os.Create(fname)
	must(e)
	defer f.Close()
	for k,_ := range(lut) {
		for j,_ := range(lut[k]) {
			fmt.Fprintf(f,"%X\n",lut[k][j])
		}
	}
}

func calc_bright() {
	var lut [][]int
	lut = make([][]int,1<<bright_args.brw)
	for k,_ := range lut {
		lut[k] = make([]int,1<<bright_args.bpp)
	}
	gout  := 1.0/float32(bright_args.rout)
	gunit := 2.0/float32(bright_args.runit)
	max_col := 1<<(bright_args.bpp)-1
	max_br  := 1<<(bright_args.brw)-1
	max_volt := 1<<(bright_args.ow)-1
	for col:=0; col<=max_col; col++ {
		for br:=0; br<=max_br;br++ {
			var volt float32
			if bright_args.dark {
				// uses br+max_br in order to avoid general darkness for low
				// bright values
				volt = float32(col)/float32(max_col)*float32(br+max_br)/float32(max_br*2+1)
			} else {
				volt = (float32(col)/float32(max_col)*gout+float32(br)/float32(max_br)*gunit)/(gout+gunit)
			}
			lut[br][col] = int(volt*float32(max_volt))
			fmt.Printf("%3d ",lut[br][col])
		}
		fmt.Println()
	}
	dump_lut( "collut.hex", lut)
}