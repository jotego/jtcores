package cmd

import (
	"github.com/spf13/cobra"
	"github.com/jotego/jtframe/mmr"
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
		must(mmr.Generate(corename, verbose))
	},
	Args: cobra.MaximumNArgs(1),
}

func init() {
	rootCmd.AddCommand(mmrCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// mmrCmd.PersistentFlags().String("foo", "", "A help for foo")

	mmrCmd.Flags().BoolVarP( &verbose, "verbose", "v", false, "Verbose output")
}

