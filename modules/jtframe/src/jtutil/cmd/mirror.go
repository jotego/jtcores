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
)

// mirrorCmd represents the mirror command
var mirrorCmd = &cobra.Command{
	Use:   "mirror",
	Short: "Find mirrored data in a ROM file",
	Long: `If a ROM file contains the same data in more than one address
position, the size of the ROM can be reduced.
jtutil mirror tries to find address bits which are not needed to address
the whole content of the ROM.`,
	Run: func(cmd *cobra.Command, args []string) {
		mirror( args[0] )
	},
	Args: cobra.ExactArgs(1),
}

func init() {
	rootCmd.AddCommand(mirrorCmd)
	// mirrorCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

func mirror( fname string ) {
	buf, e := os.ReadFile(fname)
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
	maxbit := 1
	abits := 0
	last := len(buf)-1
	for maxbit=1; maxbit<0x80000 && (last&maxbit)!=0; maxbit<<=1 { abits++ }
	// Read the file muting different address bits and find if all are needed
	bits := make([]int,abits)
	somegood := false
	for k:=0;k<abits;k++ {
		bad := false
		for j,_ := range buf {
			if buf[j]!=buf[ j&^(1<<k) ] {
				bad=true
				// fmt.Printf("Failed (%d) at %X <-> %X\n", k, j, j&^(1<<k) )
				break
			}
		}
		if !bad {
			bits[k]=1
			somegood = true
		}
	}
	fmt.Printf("%s -> %d bits\n", fname, abits)
	if somegood {
		fmt.Println("Some bits are repeated:", bits)
	} else {
		fmt.Println("No redundancy found")
	}
}