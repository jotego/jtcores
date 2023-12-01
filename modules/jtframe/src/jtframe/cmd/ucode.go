/*
Copyright © 2023 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"strings"

	"github.com/jotego/jtframe/ucode"
	"github.com/spf13/cobra"
)

// ucodeCmd represents the ucode command
var ucodeCmd = &cobra.Command{
	Use:   "ucode <module> [variation]",
	Short: "Generate verilog files for microcode",
	Long: `Parses a YAML file and generates
a Verilog module and a verilog include file.
`,
	Args: cobra.RangeArgs(1, 2),
	Run: func(cmd *cobra.Command, args []string) {
		fname := args[0]
		if len(args) == 2 {
			fname = args[1]
		}
		if !strings.HasSuffix(fname, ".yaml") {
			fname = fname + ".yaml"
		}
		ucode.Make(args[0], fname)
	},
}

func init() {
	rootCmd.AddCommand(ucodeCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// ucodeCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// ucodeCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
