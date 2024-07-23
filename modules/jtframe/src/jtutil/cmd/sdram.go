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
	"github.com/jotego/jtframe/mra"
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

If the core uses the header for SDRAM bank assignment, special care
must be taken for the PROM data as JTFRAME_PROM_START will not be defined. This
utility will create a file for each ROM region after bank 3, so the core can
directly load these files in simulation. You can also force the PROM load in
simulation for these cores by setting the SIM_LOAD_PROM macro.

The result will only be correct for cores that do not transform download data on
the fly.
`,
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

func dump( name string, rom []byte, p0,p1, lim, fill int) int {
	if p1<=0 { p1 = lim	}
	if verbose { fmt.Printf("%s %X -> %X\n",name,p0,p1) }
	if p1<p0 { return -1 }
	if p1<=0 { return p0 }
	if p1>len(rom) {
		fmt.Println("ROM file is too short to produce file",name)
		os.Exit(1)
	}
	if( p1==p0 && fill==0 ) {
		e := os.Remove(name)
		if e==nil {
			fmt.Println("Removed file",name)
		}
		return p1
	}
	e := os.WriteFile( name, rom[p0:p1],0664 )
	must(e)
	// complement up to 8MB
	sz := p1-p0
	if sz >= fill { return p1 }
	f, e := os.OpenFile(name,os.O_APPEND|os.O_WRONLY,0664)
	must(e)
	blank := make([]byte,fill-sz)
	_, e = f.Write(blank)
	must(e)
	f.Close()
	if verbose {
		fmt.Printf("%s done. Next starts at %x\n",name,p1)
	}
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

func swap_bytes( rom []byte, start int ) {
	for k:=start;k<len(rom);k+=2 {
		aux     := rom[k]
		rom[k]   = rom[k+1]
		rom[k+1] = aux
	}
}

func read_rom( game string ) []byte {
	rom, e := os.ReadFile( filepath.Join(must_env("JTROOT"),"rom",game+".rom") )
	must(e)
	if (len(rom)&1) != 0 {
		fmt.Println("The ROM length must be even")
		os.Exit(1)
	}
	// swap the bytes so the sdram.bin files get written correctly as 16-bit words
	swap_bytes(rom,0)
	return rom
}

func bankOffset( core string, macros map[string]string, rom []byte ) ([]int, []string) {
	header  := bank_start(macros,"JTFRAME_HEADER")
	mra_cfg := mra.ParseToml(mra.TomlPath(core), macros, core, false)
	reg_cnt := len(mra_cfg.Header.Offset.Regions)
	if reg_cnt < 5 {
		reg_cnt=5
	}
	offsets := make([]int,reg_cnt)
	// Default values from macros (if defined)
	offsets[1] = bank_start(macros,"JTFRAME_BA1_START")+header
	offsets[2] = bank_start(macros,"JTFRAME_BA2_START")+header
	offsets[3] = bank_start(macros,"JTFRAME_BA3_START")+header
	offsets[4] = bank_start(macros,"JTFRAME_PROM_START")+header
	if offsets[4] <= header {
		offsets[4] = len(rom)
	}
	// final values from header (if defined)
	hinfo := &mra_cfg.Header.Offset
	for k:=1; k<len(hinfo.Regions); k++ {
		var pos int
		pos  = int(rom[hinfo.Start+(k<<1)])<<8
		pos |= int(rom[hinfo.Start+(k<<1)+1])
		pos <<= hinfo.Bits
		offsets[k]=pos+header
		if verbose {
			fmt.Printf("%-4d %-20s %X\n",k,hinfo.Regions[k], offsets[k])
		}
	}
	if verbose {
		fmt.Println("Offsets")
		for k, _ := range offsets {
			fmt.Printf("%d %X\n",k,offsets[k])
		}
	}
	return offsets,hinfo.Regions
}

func extract_sdram( core, game string ) {
	const EIGHT=8*1024*1024
	rom        := read_rom(game)
	macros     := def.Get_Macros( core, "mist" )
	offsets,reg:= bankOffset(core,macros,rom)
	header     := bank_start(macros,"JTFRAME_HEADER")
	prom_start := offsets[4]
	nx_start := dump("sdram_bank0.bin",rom,header,offsets[1], prom_start, EIGHT)
	if nx_start<0 {
		os.Remove("sdram_bank1.bin")
		os.Remove("sdram_bank2.bin")
		os.Remove("sdram_bank3.bin")
		return
	}
	nx_start = dump("sdram_bank1.bin",rom,nx_start,offsets[2], prom_start, EIGHT)
	if nx_start<0 {
		os.Remove("sdram_bank2.bin")
		os.Remove("sdram_bank3.bin")
		return
	}
	nx_start = dump("sdram_bank2.bin",rom,nx_start,offsets[3], prom_start, EIGHT)
	if nx_start<0 {
		os.Remove("sdram_bank3.bin")
		return
	}
	nx_start = dump("sdram_bank3.bin",rom,nx_start,0,prom_start, EIGHT)
	// extra regions (read with prom_we set)
	if len(reg)>4 { // undo the swap that was needed for the SDRAM part of the ROM file
		swap_bytes(rom,offsets[4])
	}
	for k:=4; k<len(reg);k++ {
		nx := 0
		if k+1 < len(reg) {
			nx = offsets[k+1]
		}
		dump(reg[k],rom,offsets[k],nx,len(rom),0)
	}

}

func make_symlink( game string ) {
	src := filepath.Join(must_env("JTROOT"),"rom",game+".rom")
	os.Remove("rom.bin")
	os.Symlink(src,"rom.bin")
}