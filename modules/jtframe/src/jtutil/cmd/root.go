/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"jtutil/cmd/wav"
)

var verbose bool

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "jtutil",
	Short: "JTFRAME utility collection",
	Long: `JTFRAME utility collection.

Use "man jtutil" for the overview. Use "man jtutil-<command>" for
top-level commands and "man jtutil-<command>-<subcommand>" for nested
commands, for example "man jtutil-sdram", "man jtutil-vcd", or
"man jtutil-vcd-frame-diff".`,
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
		Long:  man_blurb("jtutil-wav", "Create a WAV file from the given VCD dump."),
		Run:   wav.RunWavCmd,
		Args:  cobra.MaximumNArgs(1),
	}
	wavCmd.Flags().StringP("signal", "s", "", "All signals with partial matches to this name will be dumped")
	wavCmd.Flags().BoolP("skip", "k", false, "skip initial silence in input file")
	rootCmd.AddCommand(wavCmd)
}

func must(e ...error) {
	if e == nil || len(e) == 0 || e[0] == nil {
		return
	}
	for _, each_error := range e {
		fmt.Println(each_error)
	}
	os.Exit(1)
}
