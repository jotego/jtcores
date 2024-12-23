/*
Copyright © 2023 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	// "fmt"

	"github.com/spf13/cobra"
	"github.com/jotego/jtframe/mmr"
)

// mmrCmd represents the mmr command
var mmrCmd = &cobra.Command{
	Use:   "mmr <core-name>",
	Short: "Generate verilog modules for memory mapped registers",
	Long: `From a core's cfg/mmr.yml file, generate a MMR implementation in verilog`,
	Run: func(cmd *cobra.Command, args []string) {
		mmr.Generate(args[0], verbose)
	},
	Args: cobra.ExactArgs(1),
}

func init() {
	rootCmd.AddCommand(mmrCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// mmrCmd.PersistentFlags().String("foo", "", "A help for foo")

	mmrCmd.Flags().BoolVarP( &verbose, "verbose", "v", false, "Verbose output")
}

