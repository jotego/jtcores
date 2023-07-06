/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
package cmd

import (
	"fmt"
	"os"
	"bufio"
	"jtutil/vcd"
	"strconv"

	"github.com/spf13/cobra"
)

// vcdCmd represents the vcd command
var vcdCmd = &cobra.Command{
	Use:   "vcd",
	Short: "Copy all signals in a VCD file delayed by 1 frame",
	Long: `Copy all signals in a VCD file delayed by 1 frame`,
	Run: func(cmd *cobra.Command, args []string) {
		runVCD()
	},
	Args: cobra.NoArgs,
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

func runVCD() {
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