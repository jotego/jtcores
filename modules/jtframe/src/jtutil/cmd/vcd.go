/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"jtutil/vcd"
)

func init() {
	rootCmd.AddCommand(vcdCmd)

	vcdCmd.AddCommand(csvCmd)
	vcdCmd.AddCommand(frameDiffCmd)
	csvCmd.Flags().BoolVarP(&csv_converter.DumpTime, "dump-time", "t", true, "dump the VCD as the first CSV column")
	csvCmd.Flags().StringVarP(&csv_converter.OutputFileName, "output", "o", "", "name of the output file")
	csvCmd.Flags().StringSliceVarP(&csv_converter.MustBeSet, "must-be-set", "1", nil, "comma separated list of signals that must be high in order to dump the line")
	frameDiffCmd.Flags().Uint64("ref", 2, "reference frame")
	frameDiffCmd.Flags().String("frames", "", "comparison frame or range, such as 5, 8- or 10-12")
	frameDiffCmd.Flags().String("when", "", "only compare rows when the given condition is true, for example wr_en==1")
	frameDiffCmd.Flags().Bool("keep", false, "keep the generated comparison files")

}

var vcdCmd = &cobra.Command{
	Use:   "vcd",
	Short: "VCD file manipulation",
	Long: `Manipulate VCD and FST files.

Use "man jtutil-vcd" for the overview and "man jtutil-vcd-<subcommand>"
for subcommand-specific documentation, for example
"man jtutil-vcd-frame-diff".`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Call vcd with one of the available subcommands")
	},
	Args: cobra.NoArgs,
}

var csvCmd = &cobra.Command{
	Use:   "csv file.vcd",
	Short: "Converts vcd file to csv",
	Long:  man_blurb("jtutil-vcd-csv", "Convert a VCD file to CSV."),
	Run: func(cmd *cobra.Command, args []string) {
		e := csv_converter.Convert(args[0])
		if e != nil {
			fmt.Println(e)
			os.Exit(1)
		}
	},
	Args: cobra.MinimumNArgs(1),
}

var frameDiffCmd = &cobra.Command{
	Use:   "frame-diff scope [file]",
	Short: "Compares frames inside a VCD or FST dump",
	Long:  man_blurb("jtutil-vcd-frame-diff", "Compare one reference frame against later frames in a VCD or FST dump."),
	Run: func(cmd *cobra.Command, args []string) {
		input := "test.fst"
		scope := ""
		switch len(args) {
		case 1:
			scope = args[0]
		case 2:
			scope = args[0]
			input = args[1]
		default:
			fmt.Println("frame-diff expects a scope and an optional file")
			os.Exit(1)
		}
		ref, _ := cmd.Flags().GetUint64("ref")
		frames, _ := cmd.Flags().GetString("frames")
		when, _ := cmd.Flags().GetString("when")
		keep, _ := cmd.Flags().GetBool("keep")
		verbose, _ := cmd.Flags().GetBool("verbose")
		if e := vcd.RunFrameDiff(vcd.FrameDiffOptions{
			InputFile: input,
			Scope:     scope,
			When:      when,
			Ref:       ref,
			Frames:    frames,
			Keep:      keep,
			Verbose:   verbose,
		}); e != nil {
			fmt.Println(e)
			os.Exit(1)
		}
	},
	Args: cobra.RangeArgs(1, 2),
}

var csv_converter vcd.CSVConverter
