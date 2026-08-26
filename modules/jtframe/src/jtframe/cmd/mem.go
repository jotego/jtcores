/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-8-20122 */

package cmd

import (
	"fmt"

	. "jotego/jtframe/common"
	"jotego/jtframe/mem"

	"github.com/spf13/cobra"
)

var mem_args mem.Args

func init() {
	memCmd := &cobra.Command{
		Use:   "mem <core-name>",
		Short: "Parses the core's YAML file to generate RTL files",
		Long:  man_blurb("jtframe-mem", "Generate RTL files from the core mem.yaml definition."),
		Run:   run_mem_cmd,
		Args:  cobra.MaximumNArgs(1),
	}
	rootCmd.AddCommand(memCmd)
	flag := memCmd.Flags()

	// mem_args.Def_cfg.Target = "mist"
	// flag.StringVar(&mem_args.Def_cfg.Commit, "commit", "", "result of running 'git rev-parse --short HEAD'")
	flag.StringVarP(&mem_args.Target, "target", "t", "mist", "Target platform: mist, mister, pocket, etc.")
	flag.BoolVarP(&mem_args.Make_inc, "inc", "i", false, "always creates mem_ports.inc")
	flag.BoolVarP(&mem_args.Local, "local", "l", false, "dumps to local folder. Otherwise uses target folder")
	flag.BoolVar(&mem_args.Nodbg, "nodbg", false, "Release mode (sets macro JTFRAME_RELEASE)")
}

func run_mem_cmd(cmd *cobra.Command, args []string) {
	var e error
	mem_args.Core, e = get_corename(args)
	Must(e)
	mem.Verbose = verbose
	mem_file := ConfigFilePath(mem_args.Core, "mem.yaml")
	if !FileExists(mem_file) {
		if verbose {
			fmt.Printf("mem.yaml does not exist for %s\n", mem_args.Core)
		}
		return
	}
	Must(mem.Run(mem_args))
}
