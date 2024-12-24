/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
package cmd

import (
	"encoding/xml"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"github.com/spf13/cobra"
)

// md5Cmd represents the md5 command
var md5Cmd = &cobra.Command{
	Use:   "md5",
	Short: "Update the MD5 sum value of all MRA files in $JTBIN/md5.md",
	Long: `The asm_md5 attribute in MRA files indicate the right sum for all the
data in the file. This is affected by file order and interleaving. Keeping track
of asm_md5 is useful to catch unintentional changes in MRA files`,
	Run: func(cmd *cobra.Command, args []string) {
		list_md5()
	},
}

func init() {
	rootCmd.AddCommand(md5Cmd)
}

type MRAROM struct {
	Index	int    `xml:"index,attr"`
	Zip		string `xml:"zip,attr"`
	Md5		string `xml:"asm_md5,attr"`
}

type MRA struct{
	Setname string `xml:"setname"`
	Rbf     string `xml:"rbf"`
	Rom     []MRAROM `xml:"rom"`
	Dip		struct {
		Default string `xml:"default,attr"`
	} `xml:"switches"`
}


func list_md5() {
	bycore := make( map[string][]*MRA )
	all := make( []*MRA, 0, 1024 )

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
		if slc, _ := bycore[game.Rbf]; slc ==nil {
			bycore[game.Rbf] = make([]*MRA,1)
			bycore[game.Rbf][0] = &game
		} else {
			bycore[game.Rbf] = append(bycore[game.Rbf], &game)
		}
		all=append(all,&game)
		return nil
	}
	e := filepath.WalkDir( filepath.Join(os.Getenv("JTBIN"),"mra"), get_mradata)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	sort.Slice(all,func( i,j int ) bool { return all[i].Setname < all[j].Setname } )
	var sbuf strings.Builder
	sbuf.WriteString(fmt.Sprintf("| Set Name     | Core       | Assembled MD5 Sum                | Default DIPs |\n"))
	sbuf.WriteString(fmt.Sprintf("|--------------|------------|----------------------------------|--------------|\n"))
	for _, each := range all {
		md5 := ""
		for _, each_rom := range each.Rom {
			if each_rom.Index==0 {
				md5 = each_rom.Md5
				break
			}
		}
		sbuf.WriteString(fmt.Sprintf("| %-12s | %-10s | %32s | %-12s |\n", each.Setname, each.Rbf, md5, each.Dip.Default ))
	}
	e = os.WriteFile(filepath.Join(os.Getenv("JTBIN"),"md5.md"),[]byte(sbuf.String()),0664)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
}