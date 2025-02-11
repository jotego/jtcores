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
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"github.com/spf13/cobra"
)

func init() {
	md5Cmd := &cobra.Command{
		Use:   "md5",
		Short: "Update the MD5 sum value of all MRA files in $JTBIN/md5.md",
		Long: `The asm_md5 attribute in MRA files indicate the right sum for all the
	data in the file. This is affected by file order and interleaving. Keeping track
	of asm_md5 is useful to catch unintentional changes in MRA files`,
		Run: run_md5_command,
	}

	rootCmd.AddCommand(md5Cmd)
}

func run_md5_command(cmd *cobra.Command, args []string) {
	e := list_md5()
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
}

func list_md5() error {
	var md5 md5Collector
	e := md5.collect_all_mra(); if e != nil { return e }
	md5.sort_by_name()
	e = md5.print_report(); if e != nil { return e }
	e = md5.dump_as_json("md5.json")
	return e
}

func (clc *md5Collector) collect_all_mra() (e error) {
	all := make( MRACollection, 0, 1024 )
	clc.bycore = make( map[string][]*MRA )

	get_mradata := func (fname string, fi os.DirEntry, err error) error {
		if err != nil {
			fmt.Println(err)
			return nil
		}
		if fi.IsDir() { return nil }
		// get the information
		var game MRA
		buf, e := os.ReadFile(fname)
		if e!=nil { return e }
		xml.Unmarshal(buf, &game )
		if slc, _ := clc.bycore[game.Rbf]; slc ==nil {
			clc.bycore[game.Rbf] = make([]*MRA,1)
			clc.bycore[game.Rbf][0] = &game
		} else {
			clc.bycore[game.Rbf] = append(clc.bycore[game.Rbf], &game)
		}
		all=append(all,&game)
		return nil
	}
	e = filepath.WalkDir( filepath.Join(os.Getenv("JTBIN"),"mra"), get_mradata)
	if e!=nil {
		return e
	} else {
		clc.all_mra = all
		return nil
	}
}

func (clc *md5Collector) sort_by_name() {
	comparator := func( i,j int ) bool {
		return clc.all_mra[i].Setname < clc.all_mra[j].Setname
	}
	sort.Slice( clc.all_mra, comparator )
}

func (clc *md5Collector)print_report() (e error) {
	var sbuf strings.Builder
	sbuf.WriteString(fmt.Sprintf("| Set Name     | Core       | Assembled MD5 Sum                | Default DIPs |\n"))
	sbuf.WriteString(fmt.Sprintf("|--------------|------------|----------------------------------|--------------|\n"))
	for _, mra := range clc.all_mra {
		md5 := ""
		for _, each_rom := range mra.Rom {
			if each_rom.Index==0 {
				md5 = each_rom.Md5
				break
			}
		}
		sbuf.WriteString(fmt.Sprintf("| %-12s | %-10s | %32s | %-12s |\n", mra.Setname, mra.Rbf, md5, mra.Dip.Default ))
	}
	e = os.WriteFile(filepath.Join(os.Getenv("JTBIN"),"md5.md"),[]byte(sbuf.String()),0664)
	return e
}

func (clc *md5Collector)dump_as_json(filename string) error {
	encoded, e := json.Marshal(clc.all_mra); if e!=nil { return e }
	e = os.WriteFile(filename,encoded,0644)
	return e
}

type md5Collector struct {
	all_mra MRACollection
	bycore map[string][]*MRA
}

type MRACollection []*MRA

type MRA struct{
	Name	string `xml:"name"`
	Setname string `xml:"setname"`
	Rbf     string `xml:"rbf"`
	Rom     []MRAROM `xml:"rom"`
	Dip		struct {
		Default string `xml:"default,attr"`
	} `xml:"switches"`
}

type MRAROM struct {
	Index	int    `xml:"index,attr"`
	Zip		string `xml:"zip,attr"`
	Md5		string `xml:"asm_md5,attr"`
}
