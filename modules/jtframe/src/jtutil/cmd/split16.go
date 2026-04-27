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
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var split16_swap *bool

// split16Cmd represents the split16 command
var split16Cmd = &cobra.Command{
	Use:   "split16 <files>",
	Short: "Splits a file in two halves. Intended for 16-bit ROM simulation",
	Long:  man_blurb("jtutil-split16", "Split 16-bit ROM data into low and high byte files."),
	Args:  cobra.MinimumNArgs(1),
	Run:   func(cmd *cobra.Command, args []string) { split_files(args) },
}

func split_files(all_filenames []string) {
	for _, filename := range all_filenames {
		b, e := os.ReadFile(filename)
		if e != nil {
			fmt.Println(e)
			continue
		}
		order := 0
		if *split16_swap {
			order = 1
		}
		base := filepath.Base(filename)
		split16_dump(base, b, order, "_lo")
		split16_dump(base, b, 1-order, "_hi")
	}
}

func split16_dump(fname string, b []byte, order int, suffix string) {
	if k := strings.LastIndex(fname, "."); k > 0 {
		fname = fname[0:k] + suffix + fname[k:]
	} else {
		fname += suffix
	}
	f, e := os.Create(fname)
	if e != nil {
		fmt.Println(e)
		return
	}
	bout := make([]byte, len(b)/2)
	j := 0
	for k := order; k < len(b); k += 2 {
		bout[j] = b[k]
		j++
	}
	f.Write(bout)
	f.Close()
}

func init() {
	rootCmd.AddCommand(split16Cmd)
	split16_swap = split16Cmd.Flags().BoolP("swap", "s", false, "swaps lo and hi files")
}
