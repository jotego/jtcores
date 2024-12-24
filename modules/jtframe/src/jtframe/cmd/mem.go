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
    "fmt"
    "os"
    "path/filepath"
	"github.com/jotego/jtframe/mem"

	"github.com/spf13/cobra"
	"github.com/jotego/jtframe/common"
)

var mem_args mem.Args

// memCmd represents the mem command
var memCmd = &cobra.Command{
	Use:   "mem <core-name>",
	Short: "Parses the core's YAML file to generate RTL files",
	Long: common.Doc2string("jtframe-mem.md"),
	Run: func(cmd *cobra.Command, args []string) {
		mem_args.Core = args[0]
        // Check that the core folder exist
        fi, e := os.Stat( filepath.Join(os.Getenv("CORES"),args[0]) )
        if e != nil || !fi.IsDir() {
            fmt.Println("jtframe mem: couldn't find core ", args[0])
            os.Exit(1)
        }
		mem.Run(mem_args)
	},
	Args: cobra.ExactArgs(1),
}

func init() {
	rootCmd.AddCommand(memCmd)
	flag := memCmd.Flags()

	// mem_args.Def_cfg.Target = "mist"
	// flag.StringVar(&mem_args.Def_cfg.Commit, "commit", "", "result of running 'git rev-parse --short HEAD'")
	flag.BoolVarP(&mem_args.Verbose, "verbose","v", false, "verbose")
	flag.StringVarP(&mem_args.Target, "target", "t", "mist", "Target platform: mist, mister, pocket, etc.")
	flag.BoolVarP(&mem_args.Make_inc, "inc","i", false, "always creates mem_ports.inc")
    flag.BoolVarP(&mem_args.Local, "local","l", false, "dumps to local folder. Otherwise uses target folder")
}
