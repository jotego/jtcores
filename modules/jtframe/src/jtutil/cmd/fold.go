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

var bit2fold *int

// foldCmd represents the fold command
var foldCmd = &cobra.Command{
	Use:   "fold input-file [output-file]",
	Short: "Sorts the file by swapping two bits in the address",
	Long: `Sorts the file by swapping two bits in the address.
Use when a memory is accessed with address bits swapped.
A typicial case is a video memory originally accessed as 8-bit, that
is converted to 16-bit. The bit given with --bit will be used as the
new bit zero, effectively folding the data around it.`,
	Run: func(cmd *cobra.Command, args []string) {
		outfile := args[0]+".out"
		if len(args)>1 {
			outfile = args[1]
		}
		e := runFold(args[0],outfile,*bit2fold)
		if e!=nil {
			fmt.Println(e)
			os.Exit(1)
		}
	},
	Args: cobra.MinimumNArgs(1),
}

func init() {
	rootCmd.AddCommand(foldCmd)
	bit2fold = foldCmd.Flags().IntP("bit", "b", 10, "bit number to swap with bit 0")
}

func swapBits(data []byte, b int) (sorted []byte) {
    sorted = make([]byte, len(data))

    for i := 0; i < len(data); i++ {
		newIndex := (i & ^((1 << (b + 1)) - 1)) | // Leave bits b+1 and above unchanged
            		((i >> b) & 1) |              // Move bit b to position 0
            		((i & ((1 << b) - 1)) << 1)   // Shift bits 0 to b-1 one position to the left
        sorted[newIndex] = data[i]
    }
    return sorted
}

func runFold(infile,outfile string, bit int) error {
	datain, e := os.ReadFile(infile)
	if e!=nil { return e }
	if len(datain)<(1<<(bit+1)) {
		return fmt.Errorf("bit %d goes beyond the limits of the file ($%X bytes)",bit,len(datain))
	}
	dataout := swapBits(datain,bit)
	return os.WriteFile(outfile,dataout,0664)
}