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
	"slices"
	"strings"

	"github.com/spf13/cobra"
)

var mra_args struct{
	zip, core, main_only *bool
}

// mraCmd represents the mra command
var mraCmd = &cobra.Command{
	Use:   "mra",
	Short: "MRA inspection utilities",
	Long: `List zip files used in JTBIN's .mra files`,
	Run: runMRA,
}

func init() {
	rootCmd.AddCommand(mraCmd)

	mra_args.zip       = mraCmd.Flags().BoolP("zip",       "z", false, "Shows all zip files used in MRA files")
	mra_args.core      = mraCmd.Flags().BoolP("core",      "c", false, "Shows games supported by each core")
	mra_args.main_only = mraCmd.Flags().BoolP("main-only", "m", false, "Parse only the main games")
}

func runMRA(cmd *cobra.Command, args []string) {
	if( *mra_args.zip  ) { list_zip();   return }
	if( *mra_args.core ) { list_cores(); return }
	cmd.Help()
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

type game_info struct {
	name, mame_set string
}

type jtcores map[string][]game_info

func cmp_games( a, b game_info) int {
	return strings.Compare(a.name,b.name)
}

func list_cores() {
	const delim = "|"
	games, e := get_coregames(delim)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	sorted_cores := sort_cores(games)
	sort_games(games)
	report_games(sorted_cores, games)
}

func get_coregames(delim string) (jtcores,error) {
	games := make(jtcores)
	get_mradata := func(fname string, fi os.DirEntry, err error) error {
		var game MRA
		if is_alternative(fname) && *mra_args.main_only { return nil }
		readin_mra( fname, fi, &game, err )
		if game.Setname=="" { return nil }
		list, found := games[game.Rbf]
		if !found || list==nil {
			list = make([]game_info,0,16)
		}
		info := game_info {
			name: game.Name,
			mame_set: game.Setname,
		}
		games[game.Rbf]=append(list,info)
		return nil
	}
	e := filepath.WalkDir(filepath.Join(os.Getenv("JTBIN"), "mra"), get_mradata)
	if e!=nil { return nil, e }
	return games, nil
}

func is_alternative(fname string) bool {
	up2levels := filepath.Dir(filepath.Dir(fname))
	dirname := filepath.Base(up2levels)
	return dirname=="_alternatives"
}

func sort_cores(all_cores jtcores) []string {
	sorted_names := make([]string,0,len(all_cores))
	for name,_ := range all_cores {
		sorted_names = append(sorted_names,name)
	}
	slices.Sort(sorted_names)
	return sorted_names
}

func sort_games(all_games jtcores) {
	for _, core_games := range all_games {
		slices.SortFunc(core_games,cmp_games)
	}
}

func report_games(cores []string, games jtcores) {
	game_count := 0
	core_len, game_len, set_len := find_longest_names(games)
	format := make_format_string(core_len, game_len, set_len)
	print_header(format)
	for _, corename := range cores {
		core_games := games[corename]
		for _,info := range core_games {
			fmt.Printf(format,corename[2:],info.name,info.mame_set)
			game_count++
		}
	}
	fmt.Printf("\n%d cores, supporting %d games\n",len(cores),game_count)
}

func find_longest_names(all_games jtcores) (core_len, game_len, set_len int) {
	for corename, coregames := range all_games {
		core_len = max_length(corename, core_len)
		for _, info := range coregames {
			game_len = max_length(info.name, game_len)
			set_len  = max_length(info.mame_set, set_len)
		}
	}
	const JTPREFIX_LEN = 2
	core_len -= JTPREFIX_LEN
	return core_len, game_len, set_len
}

func max_length(name string, previous_max int) int {
	name_length := len(name)
	if name_length>previous_max {
		return name_length
	} else {
		return previous_max
	}
}

func make_format_string(core_len, game_len, set_len int) string {
	return fmt.Sprintf("| %%-%ds | %%-%ds | %%-%ds |\n", core_len, game_len, set_len)
}

func print_header(format string) {
	header := fmt.Sprintf(format,"Core","Game","MAME set")
	dashline := make([]rune,len(header))
	for k,_ := range dashline {
		if header[k]=='|' || header[k]=='\n'{
			dashline[k]=rune(header[k])
		} else {
			dashline[k]='-'
		}
	}
	fmt.Printf(header)
	fmt.Printf(string(dashline))
}
