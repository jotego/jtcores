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

	jtbin := os.Getenv("JTBIN")
	md5Cmd.Flags().StringP("compare","c", "", "json file to compare with")
	md5Cmd.Flags().StringP("path","p", jtbin, "path to the mra folder to explore")
	rootCmd.AddCommand(md5Cmd)
}

func run_md5_command(cmd *cobra.Command, args []string) {
	mrapath,_ := cmd.Flags().GetString("path")
	newfile, e := list_md5(mrapath); must(e,fmt.Errorf("while listing md5"))
	reference,_ := cmd.Flags().GetString("compare")
	if reference!= "" {
		diff, e := compare(newfile,reference); must(e)
		if len(diff)!=0 {
			report_comparison(diff)
			os.Exit(1)
		}
	}
}

func list_md5(mrafolder string) (filename string, e error) {
	var md5 = md5Collector{
		mrafolder: mrafolder,
	}
	e = md5.collect_all_mra(); if e != nil { return "",e }
	md5.sort_by_name()
	_, e = md5.print_report(); if e != nil { return "",e }
	filename = "md5.json"
	e = md5.dump_as_json(filename); if e != nil { return "",e }
	return filename, nil
}

func (clc *md5Collector) collect_all_mra() (e error) {
	all := make( MRACollection, 0, 1024 )
	clc.bycore = make( map[string][]*MRA )

	get_mradata := func (fname string, fi os.DirEntry, err error) error {
		if err != nil {
			fmt.Println(err)
			return nil
		}
		if !strings.HasSuffix(fname,".mra") || fi.IsDir() {
			return nil
		}
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
	e = filepath.WalkDir( clc.mrafolder, get_mradata)
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

func (clc *md5Collector)print_report() (filename string, e error) {
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
	filename = filepath.Join(clc.mrafolder,"md5.md")
	e = os.WriteFile(filename,[]byte(sbuf.String()),0664)
	if e!=nil {
		return "",fmt.Errorf("while print_report(): %w",e)
	}
	return filename,nil
}

func (clc *md5Collector)dump_as_json(filename string) error {
	encoded, e := json.Marshal(clc.all_mra); if e!=nil { return e }
	e = os.WriteFile(filename,encoded,0644)
	if e!=nil {
		return fmt.Errorf("while dumping JSON file: %w",e)
	}
	return nil
}

type md5Collector struct {
	all_mra MRACollection
	bycore map[string][]*MRA
	mrafolder string
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

func compare(newfile, reference string) (diff []string, e error) {
	var new, ref MRACollection
	new, e = read_md5_json(newfile); if e!=nil { return nil,fmt.Errorf("while reading %s\n%w",newfile,e) }
	ref, e = read_md5_json(reference); if e!=nil { return nil,fmt.Errorf("while reading %s\n%w",reference,e) }
	return compare_md5(new,ref),nil
}

func read_md5_json(filename string) (md5 MRACollection,e error) {
	raw, e := os.ReadFile(filename); if e!=nil {return nil,e}
	e = json.Unmarshal(raw,&md5); if e!=nil {return nil,e}
	return md5,nil
}

func compare_md5(new,ref MRACollection) (diff []string) {
	if new==nil || ref==nil { return nil }
	diff=make([]string,0,64)
	for _, newset := range new {
		refset := find_by_setname(ref,newset.Setname)
		if refset == nil { continue }
		if newset.Rom[0].Md5!=refset.Rom[0].Md5 {
			diff=append(diff,newset.Setname)
		}
	}
	if len(diff)==0 {
		diff = nil
	}
	return diff
}

func find_by_setname(all_mra MRACollection, name string) *MRA {
	for _, mra := range all_mra {
		if mra.Setname==name {
			return mra
		}
	}
	return nil
}

func report_comparison( diff []string) {
	fmt.Println("Sets with md5 mismatches")
	for k:=0;k<len(diff); {
		for i:=0;i<4&&k<len(diff);i++ {
			fmt.Printf("%-12s",diff[k])
			k++
		}
		fmt.Println()
	}
}