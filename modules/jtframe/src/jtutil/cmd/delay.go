/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
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