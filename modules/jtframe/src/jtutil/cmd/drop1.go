/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"bufio"
	"io"
	"os"

	"github.com/spf13/cobra"
)

var drop1_low bool

// drop1Cmd represents the drop1 command
var drop1Cmd = &cobra.Command{
	Use:   "drop1",
	Short: "Drop one byte out of two from stdin and write to stdout",
	Long: `Use this command when you need to separate a 16-bit memory into two 8-bit halves.
By default, it outputs the higher byte of each 16-bit word`,
	Run: func(cmd *cobra.Command, args []string) {
		if err := drop1(drop1_low); err!=nil {
			panic(err)
		}
	},
}

func init() {
	rootCmd.AddCommand(drop1Cmd)
	drop1Cmd.Flags().BoolVarP(&drop1_low, "lower", "l", false, "output the lower byte")
}


func drop1( sel_low bool ) error {
	reader := bufio.NewReader(os.Stdin)
	writer := bufio.NewWriter(os.Stdout)
	defer writer.Flush()
	var sel0 int
	if sel_low {
		sel0 = 0
	} else {
		sel0 = 1
	}

	buf := make([]byte, 1024)
	for {
		n, err := reader.Read(buf)
		if err != nil && err != io.EOF {
			return err
		}
		if n == 0 {
			break
		}

		// write only odd or even bytes
		for i := sel0; i < n; i+=2 {
			if err := writer.WriteByte(buf[i]); err != nil {
				return err
			}
		}
		if err == io.EOF {
			break
		}
	}
	return nil
}