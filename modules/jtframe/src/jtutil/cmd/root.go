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

	"jtutil/cmd/wav"
	"github.com/spf13/cobra"
)

var verbose bool

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "jtutil",
}

func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "Verbose")
	add_wav_cmd()
}

func add_wav_cmd() {
	var wavCmd = &cobra.Command{
		Use:   "wav [test.vcd]",
		Short: "Creates a WAV file from the given VCD dump",
		Run: wav.RunWavCmd,
		Args: cobra.MaximumNArgs(1),
	}
	wavCmd.Flags().StringP("output","o","vcd.wav","output file name")
	wavCmd.Flags().StringP("signal","s","","signal name")
	wavCmd.Flags().BoolP  ("skip","k",false,"skip initial silence in input file")
	rootCmd.AddCommand(wavCmd)
}

func must(e... error) {
	if e==nil || len(e)==0 || e[0]==nil { return }
	for _, each_error := range e {
		fmt.Println(each_error)
	}
	os.Exit(1)
}