/*  This file is part of JTCORES.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 4-1-2025 */

package cmd

import (
	"fmt"
	"os"
	"bufio"
	"strconv"

	"jtutil/vcd"
	"github.com/spf13/cobra"
)

// delayCmd represents the delay command
var delayCmd = &cobra.Command{
	Use:   "delay",
	Short: "Copy all signals in a VCD file delayed by 1 frame",
	Long: `Delay by 1 frame all signals in the file debug.vcd and store the results into delayed.vcd`,

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
	const FRAME_PERIOD=16652300800
	fin  := &vcd.LnFile{}
	fin.Open("debug.vcd")
	defer fin.Close()

	fout, e := os.Create("delayed.vcd")
	if e!=nil {
		fmt.Println(e)
		return
	}
	wr := bufio.NewWriter(fout)
	defer fout.Close()

	// copy all lines and
	// modify all time stamps by subtracting a whole frame period
	for fin.Scan() {
		txt := fin.Text()
		if txt!="" && txt[0]=='#' {
			told,_ := strconv.ParseUint( txt[1:],10,64 )
			if told!=0 { told += FRAME_PERIOD }
			txt = fmt.Sprintf("#%d",told)
		}
		wr.WriteString(txt)
		wr.WriteString("\n")
	}
}