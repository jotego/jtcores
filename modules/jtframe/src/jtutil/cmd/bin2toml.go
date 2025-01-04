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
    Date: 4-1-2025 */

package cmd

import (
	"fmt"
	"path"
	"os"
	"strings"

	"github.com/spf13/cobra"
)

// bin2tomlCmd represents the bin2toml command
var bin2tomlCmd = &cobra.Command{
	Use:   "bin2toml <files to convert>",
	Short: "Convert binary files to data statements, usable in mame2mra.toml files",
	Args: cobra.MinimumNArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		for _, each := range args {
			bin2toml(each)
		}
	},
}

func init() {
	rootCmd.AddCommand(bin2tomlCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// bin2tomlCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// bin2tomlCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

func bin2toml( fname string ) {
	data, e := os.ReadFile(fname)
	must(e)
	var b strings.Builder
	for k, each := range data {
		if k!=0 {
			if (k&15)==0 {
				b.WriteString("\n\t")
			} else {
				b.WriteString(" ")
			}
		}
		b.WriteString(fmt.Sprintf("%02X",each))
	}
	setname := path.Base(fname)
	if k := strings.Index(setname,"."); k!=-1 {
		setname = setname[0:k]
	}
	setname = strings.ReplaceAll(setname,"_","")
	fmt.Printf("\t{ setname=\"%s\", data=\"\"\"\\\n\t%s\"\"\"},\n", setname, b.String())
}
