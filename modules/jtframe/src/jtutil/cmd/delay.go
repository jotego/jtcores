/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strconv"

	"github.com/spf13/cobra"
	"jtutil/vcd"
)

// delayCmd represents the delay command
var delayCmd = &cobra.Command{
	Use:   "delay",
	Short: "Copy all signals in a VCD file delayed by 1 frame",
	Long:  man_blurb("jtutil-vcd-delay", "Copy all signals in a VCD file delayed by one frame."),

	Run: func(cmd *cobra.Command, args []string) {
		runDelay()
	},
	Args: cobra.NoArgs,
}

func init() {
	vcdCmd.AddCommand(delayCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// delayCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// delayCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

func runDelay() {
	const FRAME_PERIOD = 16652300800
	fin := &vcd.LnFile{}
	fin.Open("debug.vcd")
	defer fin.Close()

	fout, e := os.Create("delayed.vcd")
	if e != nil {
		fmt.Println(e)
		return
	}
	wr := bufio.NewWriter(fout)
	defer fout.Close()

	// copy all lines and
	// modify all time stamps by subtracting a whole frame period
	for fin.Scan() {
		txt := fin.Text()
		if txt != "" && txt[0] == '#' {
			told, _ := strconv.ParseUint(txt[1:], 10, 64)
			if told != 0 {
				told += FRAME_PERIOD
			}
			txt = fmt.Sprintf("#%d", told)
		}
		wr.WriteString(txt)
		wr.WriteString("\n")
	}
}
