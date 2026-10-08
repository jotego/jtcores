/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"
	"os"

	"jt680x/extract"
	"github.com/spf13/cobra"
)

// makeTestCmd represents the makeTest command
var makeTestCmd = &cobra.Command{
	Use:   "makeTest <test-name>",
	Short: "Generation of test benches for jt680x",
	Long: `Reads the tests.yaml file in the current folder and extracts the specified test.
It will:
1. create a temporary file with the assembler code
2. create the verification vector for iverilog
3. create the mem.bin file with the memory contents
`,
	Args: cobra.ExactArgs(1),
	Run: run_test,
}

func init() {
	rootCmd.AddCommand(makeTestCmd)
	makeTestCmd.Flags().BoolP("keep", "k", false, "Do not delete assembly files")
}

func run_test(cmd *cobra.Command, args []string) {
	var ex extract.Extractor
	var e error
	ex.Keep, e = cmd.Flags().GetBool("keep"); must(e)
	e = ex.Extract(args[0]); must(e)
}

func must(e error) {
	if e!=nil {
		fmt.Fprintf(os.Stderr,"%s\n",e.Error())
		os.Exit(1)
	}
}