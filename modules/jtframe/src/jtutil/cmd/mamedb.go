/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package cmd

import (
	"fmt"
	"github.com/spf13/cobra"
	"jotego/jtframe/mra"
	"os"
	"path/filepath"
)

var mamedb_cfg mra.ParseCfg

// mamedbCmd represents the mamedb command
var mamedbCmd = &cobra.Command{
	Use:   "mamedb [mame.xml path]",
	Short: "Filter the mame.xml file to show machine names",
	Long:  man_blurb("jtutil-mamedb", "Filter the mame.xml file to show machine names."),
	Args:  cobra.MaximumNArgs(1),
	Run:   mamedb_run,
}

func init() {
	rootCmd.AddCommand(mamedbCmd)

	mamedbCmd.Flags().StringSliceVarP(&mamedb_cfg.Mustbe.Devices, "dev", "d", nil, "Device names that must be used")
	mamedbCmd.Flags().IntVarP(&mamedb_cfg.Older, "older", "y", 0, "This year or older")
}

func mamedb_run(cmd *cobra.Command, args []string) {
	mame_fpath := filepath.Join(os.Getenv("JTROOT"), "doc", "mame.xml")
	if len(args) == 1 {
		mame_fpath = args[0]
	}
	mamedb_cfg.Sourcefile = []string{".*"}
	ex := mra.NewExtractor(mame_fpath)
	m := ex.Extract(mamedb_cfg)
	for m != nil {
		fmt.Println(m.Name)
		m = ex.Extract(mamedb_cfg)
	}
}
