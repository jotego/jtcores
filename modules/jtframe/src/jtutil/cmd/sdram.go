/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"

	"os"
	"strconv"
	"path/filepath"
	"github.com/spf13/cobra"
	"github.com/jotego/jtframe/def"
)

// sdramCmd represents the sdram command
var sdramCmd = &cobra.Command{
	Use:   "sdram [game-name]",
	Short: "Convert .rom files to sdram files for quick simulation",
	Long: `Convert .rom files to sdram files for quick simulation

After you create the .rom files using jtframe mra, you can generate
the sdram*.bin simulation files without having to run a download simulation by
calling jtframe sdram.

jtframe sdram must be called from within a simulation folder, such as ver/game.
If the simulation folder is the ROM set name, that will be used. If the folder
is just "game", then the set name must be provided in the command line.

jtframe sdram will split the .rom file in the right number of sdram*bin files by
inspecting the definitions of JTFRAME_BA?_START, JTFRAME_PROM_START and
JTFRAME_HEADER.

jtframe sdram will also link a rom.bin file to the .rom file used. If rom.bin
already existed, it will be deleted and re-created as a link.

The result will only be correct for cores that do not transform download data on
the fly and that do not depend on the header for SDRAM bank assignment. These
features can be partially support in future development.`,
	Run: func(cmd *cobra.Command, args []string) {
		var game string
		wd, e := os.Getwd()
		if e != nil {
			fmt.Println(e)
			os.Exit(1)
		}
		if len(args)==0 {
			game = filepath.Base(wd)
		} else {
			game = args[0]
		}
		if game=="game" {
			fmt.Println("Cannot derive ROM set name from current folder. Use jtutil sdram <game> instead.")
			os.Exit(1)
		}
		wd = filepath.Join(wd,"..")
		if filepath.Base(wd)!="ver" {
			fmt.Println("jtutil sdram must be called from a ver/game folder")
			os.Exit(1)
		}
		core := filepath.Base(filepath.Join(wd,".."))
		extract_sdram(core,game)
		make_symlink(game)
	},
	Args: cobra.MaximumNArgs(1),
}

func init() {
	rootCmd.AddCommand(sdramCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// sdramCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// sdramCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

func must_env( env string ) string {
	v, e := os.LookupEnv(env)
	if !e {
		fmt.Println(env,"is not defined in the environment.")
		os.Exit(1)
	}
	return v
}

func dump( name string, rom []byte, p0,p1 int) int {
	if p1<=0 { p1 = len(rom)	}
	if p1<=0 { return p0 }
	if p1>len(rom) {
		fmt.Println("ROM file is too short to produce file",name)
		os.Exit(1)
	}
	e := os.WriteFile( name, rom[p0:p1],0664 )
	must(e)
	// complement up to 8MB
	const EIGHT=8*1024*1024
	sz := p1-p0
	if sz >= EIGHT { return p1 }
	f, e := os.OpenFile(name,os.O_APPEND|os.O_WRONLY,0664)
	must(e)
	blank := make([]byte,EIGHT-sz)
	_, e = f.Write(blank)
	must(e)
	f.Close()
	return p1
}

func bank_start(macros map[string]string, name string) int {
	a, e := macros[name]
	if !e { return 0 }
	n, err := strconv.ParseInt(a,0,32)
	if err!=nil {
		fmt.Printf("Cannot convert %s=%s to a number.\n",name,a)
		os.Exit(1)
	}
	return int(n)
}

func read_rom( game string ) []byte {
	rom, e := os.ReadFile( filepath.Join(must_env("JTROOT"),"rom",game+".rom") )
	must(e)
	if (len(rom)&1) != 0 {
		fmt.Println("The ROM length must be even")
		os.Exit(1)
	}
	// swap the bytes so the sdram.bin files get written correctly as 16-bit words
	for k:=0;k<len(rom);k+=2 {
		aux     := rom[k]
		rom[k]   = rom[k+1]
		rom[k+1] = aux
	}
	return rom
}

func extract_sdram( core, game string ) {
	rom := read_rom(game)
	macros := def.Get_Macros( core, "mist" )
	header   := bank_start(macros,"JTFRAME_HEADER")
	nx_bank  := bank_start(macros,"JTFRAME_BA1_START")+header
	nx_start := dump("sdram_bank0.bin",rom,header,nx_bank)
	if nx_start<0 {
		os.Remove("sdram_bank1.bin")
		os.Remove("sdram_bank2.bin")
		os.Remove("sdram_bank3.bin")
		return
	}
	nx_bank  = bank_start(macros,"JTFRAME_BA2_START")+header
	nx_start = dump("sdram_bank1.bin",rom,nx_start,nx_bank)
	if nx_start<0 {
		os.Remove("sdram_bank2.bin")
		os.Remove("sdram_bank3.bin")
		return
	}
	nx_bank  = bank_start(macros,"JTFRAME_BA3_START")+header
	nx_start = dump("sdram_bank2.bin",rom,nx_start,nx_bank)
	if nx_start<0 {
		os.Remove("sdram_bank3.bin")
		return
	}
	nx_bank  = bank_start(macros,"JTFRAME_PROM_START")+header
	nx_start = dump("sdram_bank3.bin",rom,nx_start,nx_bank)
}

func make_symlink( game string ) {
	src := filepath.Join(must_env("JTROOT"),"rom",game+".rom")
	os.Remove("rom.bin")
	os.Symlink(src,"rom.bin")
}