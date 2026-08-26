/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-8-20122 */

package cmd

import (
	"github.com/spf13/cobra"
	jtfiles "jotego/jtframe/files"
)

// filesCmd represents the files command
var filesCmd = &cobra.Command{
	Use:   "files <sim|syn|plain> <core-name>",
	Short: "Generates the project compilation and simulation files",
	Long:  man_blurb("jtframe-files", "Generate project file lists for simulation, synthesis, or plain output."),
	Run:   run_files,
	Args:  cobra.ExactArgs(2),
}

var files_args jtfiles.Args

func init() {
	rootCmd.AddCommand(filesCmd)
	flag := filesCmd.Flags()

	flag.StringVarP(&files_args.Target, "target", "t", "", "Target platform: mist, mister, pocket, etc.")
	flag.StringVarP(&files_args.AddMacro, "macro", "m", "", "Add more verilog macros separated by commas")
	flag.BoolVar(&files_args.Rel, "rel", false, "Output relative paths")
	flag.BoolVar(&files_args.Local, "local", false, "Refer to mem.yaml derived files in the local, instead of the target, folder")
}

func run_files(cmd *cobra.Command, args []string) {
	files_args.Corename = args[1]
	files_args.Format = args[0]

	jtfiles.Run(files_args)
}
