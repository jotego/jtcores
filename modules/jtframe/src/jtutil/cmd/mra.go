/*
Copyright © 2023 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"encoding/xml"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

// mraCmd represents the mra command
var mraCmd = &cobra.Command{
	Use:   "mra",
	Short: "MRA inspection utilities",
	Long: `List zip files used in JTBIN's .mra files`,
	Run: func(cmd *cobra.Command, args []string) {
		list_zip()
	},
}

func init() {
	rootCmd.AddCommand(mraCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// mraCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// mraCmd.Flags().BoolP("zip", "z", false, "Shows all zip files used in MRA files")
}

func list_zip() {
	zipuse := make(map[string]bool)

	get_mradata := func(fname string, fi os.DirEntry, err error) error {
		if err != nil {
			fmt.Println(err)
			return nil
		}
		if fi.IsDir() {
			return nil
		}
		// get the information
		var game MRA
		buf, e := os.ReadFile(fname)
		if e != nil {
			return e
		}
		xml.Unmarshal(buf, &game)
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
