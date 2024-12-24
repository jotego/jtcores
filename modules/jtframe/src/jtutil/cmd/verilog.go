/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
package cmd

import (
	"strings"

	"jtutil/vcd"
	"github.com/spf13/cobra"
)

// verilogCmd represents the verilog command
var verilogCmd = &cobra.Command{
	Use:   "verilog file[.vcd]",
	Short: "Converts a VCD to a verilog .bin and .v files for simulation use",
	//Long:
	Run: verilogCmdRun,
	Args: cobra.ExactArgs(1),
}

func verilogCmdRun(cmd *cobra.Command, args []string) {
	fname := args[0]
	if strings.HasSuffix(args[0],".vcd") {
		fname = args[0][0:len(args[0])-4]
	}
	var d vcd.LnFile
	d.Open(fname+".vcd")
	ss := vcd.GetSignals(&d)
	d.DumpHex(ss,fname)
}

func init() {
	vcdCmd.AddCommand(verilogCmd)
}

