/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"
	"path/filepath"
	"os"

	"jotego/jtframe/mra"
	"jotego/jtframe/xmlnode"
	"github.com/spf13/cobra"
)

var rom_path string

// mra2romCmd represents the mra2rom command
var mra2romCmd = &cobra.Command{
	Use:   "mra2rom <mra file>",
	Short: "Generate the .rom file for a given .mra file",
	Run: runMRA2ROM,
	Args: cobra.ExactArgs(1),
}

func init() {
	rootCmd.AddCommand(mra2romCmd)
	flag := mra2romCmd.Flags()
	mame_roms := filepath.Join(os.Getenv("HOME"), ".mame", "roms")
	flag.StringVar(&rom_path, "path", mame_roms, "Path to MAME .zip files")
}

func runMRA2ROM(cmd *cobra.Command, args []string) {
	mra_filename := args[0]
	mraxml, e := xmlnode.ReadFile(mra_filename)
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
	save2disk:=true
	e = mra.Mra2rom(mraxml,save2disk,rom_path)
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
}