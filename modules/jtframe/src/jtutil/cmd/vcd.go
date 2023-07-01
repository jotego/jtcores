/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
package cmd

import (
	"jtutil/vcd"
	"github.com/spf13/cobra"
)

// vcdCmd represents the vcd command
var vcdCmd = &cobra.Command{
	Use:   "vcd",
	Short: "Compare VCD file with MAME trace output",
	Long: `Use to debug a simulation against MAME.
Prepare a MAME trace file with register dumps, and a VCD file with the registers
you want to compare.

debug.trace		text file generated with MAME
debug.vcd		VCD file for comparison

File names cannot be overriden.

An automatic matching  between the MAME variables and the VCD signal names will
be attempted. If a signal is not matched to MAME, manually add it with the alias
command.

The comparison is interactive, although a script can also be run to help in
debugging sessions. Type help to obtain the list of commands.
`,
	Run: func(cmd *cobra.Command, args []string) {
		runVCD()
	},
}

func init() {
	rootCmd.AddCommand(vcdCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// vcdCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// vcdCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

func runVCD() { //////////////// command's main function
	trace := &vcd.LnFile{}
	vcdf  := &vcd.LnFile{}
	vcdf.Open("debug.vcd")
	defer vcdf.Close()
	signals := vcd.GetSignals(vcdf)

	trace.Open("debug.trace")
	defer trace.Close()

	trace.Scan()
	mame_alias := vcd.MakeAlias(trace.Text(), signals)
	vcd.Prompt( vcdf, trace, signals, mame_alias  )
}
