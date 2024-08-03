/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>

*/
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
