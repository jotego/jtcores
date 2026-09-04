/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-8-20122 */

package cmd

import (
	"jotego/jtframe/common"
	"jotego/jtframe/msg"

	"github.com/spf13/cobra"
)

var msgCmd = &cobra.Command{
	Use:   "msg <core-name>",
	Short: "Parses the core's msg file to generate a pause screen message",
	Long:  man_blurb("jtframe-msg", "Generate pause-screen message assets from cfg/msg."),
	Run:   msgRun,
	Args:  cobra.ExactArgs(1),
}

func init() {
	rootCmd.AddCommand(msgCmd)
}

func msgRun(cmd *cobra.Command, args []string) {
	corename := args[0]
	cmp := msg.MakeCompiler(corename)
	e := cmp.Convert()
	common.Must(e)
}
