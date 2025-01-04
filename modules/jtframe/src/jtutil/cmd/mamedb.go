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
	"os"
	"path/filepath"
	"github.com/spf13/cobra"
	"github.com/jotego/jtframe/mra"
)

var mamedb_cfg mra.ParseCfg

// mamedbCmd represents the mamedb command
var mamedbCmd = &cobra.Command{
	Use:   "mamedb [mame.xml path]",
	Short: "Filter the mame.xml file to show machine names",
	Long: ``,
	Args: cobra.MaximumNArgs(1),
	Run: mamedb_run,
}

func init() {
	rootCmd.AddCommand(mamedbCmd)

	mamedbCmd.Flags().StringSliceVarP( &mamedb_cfg.Mustbe.Devices, "dev", "d", nil, "Device names that must be used")
	mamedbCmd.Flags().IntVarP( &mamedb_cfg.Older, "older", "y", 0, "This year or older")
}

func mamedb_run(cmd *cobra.Command, args []string) {
	mame_fpath := filepath.Join( os.Getenv("JTROOT"), "doc", "mame.xml" )
	if len(args)==1 {
		mame_fpath = args[0]
	}
	mamedb_cfg.Sourcefile = []string{ ".*" }
	ex := mra.NewExtractor(mame_fpath)
	m:=ex.Extract(mamedb_cfg)
	for m!=nil {
		fmt.Println(m.Name)
		m=ex.Extract(mamedb_cfg)
	}
}