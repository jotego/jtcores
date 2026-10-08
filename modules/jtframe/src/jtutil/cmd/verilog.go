/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package cmd

import (
	"strings"

	"github.com/spf13/cobra"
	"jtutil/vcd"
)

// verilogCmd represents the verilog command
var verilogCmd = &cobra.Command{
	Use:   "verilog file[.vcd]",
	Short: "Converts a VCD to a verilog .bin and .v files for simulation use",
	Long:  man_blurb("jtutil-vcd-verilog", "Convert a VCD file into Verilog simulation assets."),
	Run:   verilogCmdRun,
	Args:  cobra.ExactArgs(1),
}

func verilogCmdRun(cmd *cobra.Command, args []string) {
	fname := args[0]
	if strings.HasSuffix(args[0], ".vcd") {
		fname = args[0][0 : len(args[0])-4]
	}
	var d vcd.LnFile
	d.Open(fname + ".vcd")
	ss := vcd.GetSignals(&d)
	must(d.DumpHex(ss, fname))
}

func init() {
	vcdCmd.AddCommand(verilogCmd)
}
