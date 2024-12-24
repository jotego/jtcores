/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
package cmd

import (
	"fmt"

	"jtutil/vcd"
	"github.com/spf13/cobra"
)

var ignore_rst bool
var mismatch_n int

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
		if ignore_rst {
			fmt.Println("Warning: --rst is not implemented")
		}
		if len(args)==3 {
			vcd.Compare( args[0:2], args[2], ignore_rst, mismatch_n )
		} else {
			vcd.CompareAll( args[0:2], mismatch_n )
		}
	},
	Args: cobra.ExactArgs(2),
}

func init() {
	vcdCmd.AddCommand(compareCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// compareCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	compareCmd.Flags().BoolVarP(&ignore_rst, "rst", "r", false, "ignore while any signal called rst is high")
	compareCmd.Flags().IntVarP(&mismatch_n,"mismatch", "m", 1, "stop at the given mismatch occurence")
}

