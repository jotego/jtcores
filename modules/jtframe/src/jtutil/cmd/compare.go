/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
package cmd

import (
	// "fmt"

	"jtutil/vcd"
	"github.com/spf13/cobra"
)

// compareCmd represents the compare command
var compareCmd = &cobra.Command{
	Use:   "compare file1[.vcd] file2[.vcd] signal-name",
	Short: "Compare two VCD databases",
	Long:
`Load two VCD databases containing mostly identical scope and signals and
compare specific signals.`,
	Run: func(cmd *cobra.Command, args []string) {
		vcd.Compare( args[0:2], args[2] )
	},
	Args: cobra.ExactArgs(3),
}

func init() {
	vcdCmd.AddCommand(compareCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// compareCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// compareCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

