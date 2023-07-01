/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
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
	Offset *int
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
	inputArgs.Offset = inputsCmd.Flags().IntP("offset", "s", 0, "Add a frame offset to the output.")
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
	for k:=0;k<len(data); k+=2 {
		fdiff := int(data[k])&0xff
		dxor  := int(data[k+1])&0xff
		fcnt += fdiff
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