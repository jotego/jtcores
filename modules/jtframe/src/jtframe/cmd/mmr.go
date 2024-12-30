package cmd

import (
	"fmt"
	"github.com/spf13/cobra"

	"github.com/jotego/jtframe/mmr"
	"github.com/jotego/jtframe/common"
)

// mmrCmd represents the mmr command
var mmrCmd = &cobra.Command{
	Use:   "mmr [core-name]",
	Short: "Generate verilog modules for memory mapped registers",
	Long: `From a core's cfg/mmr.yml file, generate a MMR implementation in verilog`,
	Run: func(cmd *cobra.Command, args []string) {
		var e error
		var corename string
		corename, e = get_corename(args)
		must(e)
		mmrpath := mmr.GetMMRPath(corename)
		if common.FileExists(mmrpath) {
			must(mmr.Generate(corename, verbose))
		} else if verbose {
			fmt.Printf("Skipping MMR for core %s (%s not present)\n",corename,mmrpath)
		}
	},
	Args: cobra.MaximumNArgs(1),
}

func init() {
	rootCmd.AddCommand(mmrCmd)

	mmrCmd.Flags().BoolVarP( &verbose, "verbose", "v", false, "Verbose output")
}

