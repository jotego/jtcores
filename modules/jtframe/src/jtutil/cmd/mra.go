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
	"encoding/xml"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var mra_args struct{
	zip, core *bool
}

// mraCmd represents the mra command
var mraCmd = &cobra.Command{
	Use:   "mra",
	Short: "MRA inspection utilities",
	Long: `List zip files used in JTBIN's .mra files`,
	Run: func(cmd *cobra.Command, args []string) {
		if( *mra_args.zip  ) { list_zip() }
		if( *mra_args.core ) { list_cores() }
	},
}

func init() {
	rootCmd.AddCommand(mraCmd)

	mra_args.zip  = mraCmd.Flags().BoolP("zip", "z", false, "Shows all zip files used in MRA files")
	mra_args.core = mraCmd.Flags().BoolP("core", "c", false, "Shows games supported by each core")
}

func readin_mra(fname string, fi os.DirEntry, game *MRA, err error) (error) {
	if !strings.HasSuffix(fname,".mra") { return nil }
	if err != nil {
		fmt.Println(err)
		return nil
	}
	if fi.IsDir() {
		return nil
	}
	// get the information
	buf, e := os.ReadFile(fname)
	if e != nil {
		return e
	}
	xml.Unmarshal(buf, game)
	if game.Name=="" {
		fmt.Printf("Warning: no game Name for file %s\n",fname)
		return nil
	}
	return err
}

func list_zip() {
	zipuse := make(map[string]bool)

	get_mradata := func(fname string, fi os.DirEntry, err error) error {
		var game MRA
		readin_mra( fname, fi, &game, err )
		if len(game.Rom)==0 { return nil }
		names := strings.Split(game.Rom[0].Zip, "|")
		if len(names) == 0 {
			return nil
		}
		merged := names[len(names)-1]
		zipuse[merged] = true
		return nil
	}
	e := filepath.WalkDir(filepath.Join(os.Getenv("JTBIN"), "mra"), get_mradata)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	first := true
	for each, _ := range zipuse {
		if !first {
			fmt.Print(" ")
		}
		fmt.Print(each)
		first = false
	}
}

func list_cores() {
	games := make(map[string][]string)
	const delim = "|"

	fmt.Println("| Core | Game | MAME set |")
	fmt.Println("|------|------|----------|")
	get_mradata := func(fname string, fi os.DirEntry, err error) error {
		var game MRA
		readin_mra( fname, fi, &game, err )
		if game.Setname=="" { return nil }
		list, found := games[game.Rbf]
		if !found || list==nil {
			list = make([]string,0,16)
		}
		long_name := fmt.Sprintf("%s%s%s",game.Name,delim,game.Setname)
		games[game.Rbf]=append(list,long_name)
		return nil
	}
	e := filepath.WalkDir(filepath.Join(os.Getenv("JTBIN"), "mra"), get_mradata)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	for key, val := range games {
		for _,each := range val {
			fmt.Printf("|%s%s%s|\n",key[2:],delim,each)
		}
	}
}
