/*  This file is part of JTCORES.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 4-1-2025 */

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
	Long:  `Several tools to manipulate VCD files`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Call vcd with one of the available subcommands")
	},
	Args: cobra.NoArgs,
}

var csvCmd = &cobra.Command{
	Use:   "csv file.vcd",
	Short: "Converts vcd file to csv",
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
	Long: `Compares one reference frame against one or more later frames for a signal scope.

Scope syntax:
  - Use . to describe the hierarchy path inside the VCD, for example u_obj or u_video.u_obj.
  - Use / only once, at the end, to separate the scope from the signal glob.
  - The part before / matches an instance path inside the VCD hierarchy.
  - The part after / is a glob applied to signal names inside that scope.
  - Brace expansion is supported in the signal glob, for example wr_{a,b}.
  - Wildcards follow shell-style globbing, so wr_* matches wr_en, wr_data, etc.

Examples:
  jtutil vcd frame-diff u_obj
  jtutil vcd frame-diff u_obj/wr_*
  jtutil vcd frame-diff u_video.u_obj/wr_{a,b} test.fst
  jtutil vcd frame-diff --when wr_en==1 u_obj/wr_*`,
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
