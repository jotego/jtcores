/*  This file is part of JT_FRAME.
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
	"github.com/jotego/jtframe/msg"
	"github.com/jotego/jtframe/common"

	"github.com/spf13/cobra"
)

var msgCmd = &cobra.Command{
	Use:   "msg <core-name>",
	Short: "Parses the core's msg file to generate a pause screen message",
	Long: `Parses the core's msg file in the config folder to generate a message.
The message will be shown during the pause screen when macro JTFRAME_CREDITS is set.
Two output files are generated: msg.hex and msg.bin

Message text:
- lines cannot be longer than 32 characters.
- Four colours available: red, green, blue and white. Each line starts as white.
  The colour is changed by using \R (red) \G (green) \B (blue) or \W (white)
- \D is replaced by the current date in year-month-day format
- \C is replaced by the string in the --commit argument
`,
	Run: msgRun,
	Args: cobra.ExactArgs(1),
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