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

	"github.com/spf13/cobra"
)

// vcdCmd represents the vcd command
var vcdCmd = &cobra.Command{
	Use:   "vcd",
	Short: "VCD file manipulation",
	Long: `Several tools to manipulate VCD files`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Call vcd with one of the available subcommands")
	},
	Args: cobra.NoArgs,
}

func init() {
	rootCmd.AddCommand(vcdCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// vcdCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// vcdCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

