/*  This file is part of JTFRAME.
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
    Date: 28-8-20122 */

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
