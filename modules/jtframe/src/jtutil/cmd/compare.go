/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
package cmd

import (
	"fmt"
	"math"
	"strings"
	"strconv"
	"os"

	"jtutil/vcd"
	"github.com/spf13/cobra"
)

var cmpArgs vcd.CmpArgs
var t0, t0b string

// compareCmd represents the compare command
var compareCmd = &cobra.Command{
	Use:   "compare file1[.vcd] file2[.vcd] [signal-name]",
	Short: "Compare two VCD databases",
	Long:
`Load two VCD databases containing mostly identical scope and signals and
compare specific signals.

Not providing a signal name will compare all signals in the VCD
`,
	Run: func(cmd *cobra.Command, args []string) {
		cmpArgs.Time0a = convert2ps(t0)
		cmpArgs.Time0b = convert2ps(t0b)
		if cmpArgs.Time0a>0 && cmpArgs.Time0b==0 {
			cmpArgs.Time0b = cmpArgs.Time0a
		}
		if len(args)==3 {
			vcd.Compare( args[0:2], args[2], cmpArgs )
		} else {
			vcd.CompareAll( args[0:2], cmpArgs )
		}
	},
	Args: cobra.MinimumNArgs(2),
}

func convert2ps( s string ) uint64 {
	i := 0
	f := 1.0
	sb := s
	for k,each := range []string{"m","u","n","p"} {
		i = strings.Index(s,each)
		if i!=-1 {
			f=math.Pow10((k+1)*-3)
			sb = sb[0:i]
			break
		}
	}
	c,e := strconv.ParseFloat(sb,64)
	if e!=nil {
		fmt.Printf("Cannot convert %s to picoseconds\n",sb)
		os.Exit(1)
	}
	return uint64(c*f*1e12)
}

func init() {
	vcdCmd.AddCommand(compareCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// compareCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	compareCmd.Flags().BoolVarP(&cmpArgs.Ignore_rst, "rst", "r", false, "ignore while any signal called rst is high")
	compareCmd.Flags().IntVarP(&cmpArgs.Mismatch_n,"mismatch", "m", 1, "stop at the given mismatch occurence")
	compareCmd.Flags().StringVarP(&t0,"time", "t", "0", "time at which comparison starts (scientific suffixes accepted)")
	compareCmd.Flags().StringVarP(&t0b,"time_b", "b", "0", "time at which comparison starts for the B (right) VCD. Same as --time if --time_b is ommitted")
}

