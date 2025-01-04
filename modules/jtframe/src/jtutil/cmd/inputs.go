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
	"io/ioutil"
	"os"
	// "path/filepath"
	"github.com/spf13/cobra"
)

// inputsCmd represents the inputs command
var inputsCmd = &cobra.Command{
	Use:   "inputs path-to-file",
	Short: "Convert files obtained with JTFRAME_INPUT_RECORD to sim_inputs.hex",
	Long: `Compile with the macro JTFRAME_INPUT_RECORD in MiST to dump
inputs to the NVRAM file. Upto 4096 frames can be captured. Then run this tool
with the path to the file in order to obtain a file that you can use with jtsim

jtutil inputs path-to-file
jtsim -inputs -dipsw hex-value
`,
	Run:  inputs_run,
	Args: cobra.MinimumNArgs(1),
}

var inputArgs struct{
	Verbose *bool
	Offset, Skip *int
}

func init() {
	rootCmd.AddCommand(inputsCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// inputsCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	inputArgs.Verbose = inputsCmd.Flags().BoolP("verbose", "v", false, "verbose")
	inputArgs.Offset = inputsCmd.Flags().IntP("offset", "o", 0, "Add a frame offset to the output (may be negative).")
	inputArgs.Skip = inputsCmd.Flags().IntP("skip", "s", 0, "Completely skip the given number of data points")
}


func inputs_run(cmd *cobra.Command, args []string) {
	// fname := filepath.Join("/media",os.Getenv("USER"),"mist")
	data, e := ioutil.ReadFile(args[0])
	if e != nil {
		fmt.Printf("Error %s\n", e )
		os.Exit(1)
	}
	fout, e := os.Create("sim_inputs.hex")
	if e != nil {
		fmt.Printf("Error %s\n", e )
		os.Exit(1)
	}
	// optional dummy lines at the beginning
	for k := 0; k<*inputArgs.Offset; k++ { fmt.Fprintln(fout,"0") }
	// data conversion
	d := 0
	d_full := 0
	fcnt := 0
	ftotal := 0
	negoff := -1*(*inputArgs.Offset)
	if negoff<0 { negoff = 0 }
	k0 := 0
	if *inputArgs.Skip<(len(data)>>1) {
		k0 = *inputArgs.Skip<<1
	}
	if int(data[0])==0 && int(data[1])!=0 && k0==0 {
		// automatically skip a bad first frame where
		// inputs are not zero for a delta-frame of zero
		k0 = 2
	}
	for k:=k0;k<len(data); k+=2 {
		fdiff := int(data[k])&0xff
		dxor  := int(data[k+1])&0xff
		// skip frame if the supplied offset is negative
		if( fdiff > negoff ) {
			fdiff -= negoff
			negoff = 0
		} else {
			negoff -= fdiff
			d=d^dxor
			continue
		}
		fcnt += fdiff+1
		if dxor==0 { continue }
		ftotal += fcnt
		for ;fcnt>0;fcnt-- {	// fill with old data
			fmt.Fprintf(fout,"%X\n", d_full)
		}
		// calculate the new data
		d = d ^ dxor;
		d_full = (d&0xfc)<<2
		if (d & 1)!=0 { d_full |= 1 }
		if (d & 2)!=0 { d_full |= 4 }
	}
	fmt.Printf( "Input data for %d frames\n", ftotal+*inputArgs.Offset )
	if *inputArgs.Verbose {
		fmt.Println( `Remember to match the DIP switches in simulation.
Look in $ROM/*.dip for the default values. Run jtsim -dipsw hex-value`)
	}
}