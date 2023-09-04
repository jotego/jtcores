/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// vcdCmd represents the vcd command
var vcdCmd = &cobra.Command{
	Use:   "vcd",
	Short: "VCD file manipulation",
	Long: `Several tools to manipulate VCD files`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Call vcd with one of the available subcommands")
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

