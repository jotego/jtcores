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
	"fmt"

	"os"
	"strings"
	"path/filepath"
	"github.com/spf13/cobra"
	"github.com/jotego/jtframe/macros"
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
	Run: run_sdram,
	Args: cobra.MaximumNArgs(1),
}

func init() {
	rootCmd.AddCommand(sdramCmd)
}

func run_sdram(cmd *cobra.Command, args []string) {
	var game string

	if len(args)!=0 {
		game=args[0]
	} else {
		var e error
		game, e = derive_game_from_wd()
		must(e)
	}

	must(validate_wd())
	core := derive_core_from_wd()
	macros.MakeMacros( core, "mist" )
	extract_sdram(core,game)
	make_symlink(game)
}

func derive_game_from_wd() (string,error) {
	wd, e := os.Getwd()
	if e != nil { return "", e }
	game := filepath.Base(wd)
	if game=="game" {
		return "",fmt.Errorf("Cannot derive ROM set name from current folder. Use jtutil sdram <game> instead.")
	}
	return game,nil
}

func validate_wd() (error) {
	wd, e := os.Getwd()
	if e != nil { return e }
	wd = filepath.Join(wd,"..")
	if filepath.Base(wd)!="ver" {
		return fmt.Errorf("jtutil sdram must be called from a ver/game folder")
	}
	return nil
}

func derive_core_from_wd() string {
	wd,_ := os.Getwd()
	return filepath.Base(filepath.Join(wd,"../.."))
}

func must_env( env string ) string {
	v, e := os.LookupEnv(env)
	if !e {
		fmt.Println(env,"is not defined in the environment.")
		os.Exit(1)
	}
	return v
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


func extract_sdram( core, game string ) error {
	const EIGHT_MB=8*1024*1024
	rom        := read_rom(game)

	mra_cfg, e := mra.ParseTomlFile(core)
	reg_cnt := len(mra_cfg.Header.Offset.Regions)
	hinfo := mra_cfg.Header.Offset
	if e!=nil { return e }
	offsets,reg:= bankOffset(reg_cnt,hinfo,rom)

	header     := macros.GetInt("JTFRAME_HEADER")
	prom_start := offsets[4]
	nx_start, e := dump("sdram_bank0.bin",rom,header,offsets[1], prom_start, EIGHT_MB)
	if e!=nil { return fmt.Errorf("%w for bank 0",e) }
	if nx_start<0 {
		os.Remove("sdram_bank1.bin")
		os.Remove("sdram_bank2.bin")
		os.Remove("sdram_bank3.bin")
		return nil
	}
	nx_start, e = dump("sdram_bank1.bin",rom,nx_start,offsets[2], prom_start, EIGHT_MB)
	if e!=nil { return fmt.Errorf("%w for bank 1",e) }
	if nx_start<0 {
		os.Remove("sdram_bank2.bin")
		os.Remove("sdram_bank3.bin")
		return nil
	}
	nx_start, e = dump("sdram_bank2.bin",rom,nx_start,offsets[3], prom_start, EIGHT_MB)
	if e!=nil { return fmt.Errorf("%w for bank 2",e) }
	if nx_start<0 {
		os.Remove("sdram_bank3.bin")
		return nil
	}
	nx_start, e = dump("sdram_bank3.bin",rom,nx_start,0,prom_start, EIGHT_MB)
	if e!=nil { return fmt.Errorf("%w for bank 3",e) }
	// extra regions (read with prom_we set)
	if len(reg)>4 { // undo the swap that was needed for the SDRAM part of the ROM file
		swap_bytes(rom,offsets[4])
	}
	for k:=4; k<len(reg);k++ {
		nx := 0
		if k+1 < len(reg) {
			nx = offsets[k+1]
		}
		_, e = dump(reg[k],rom,offsets[k],nx,len(rom),0)
		if e!=nil { return e }
	}
	return nil
}

func bankOffset( reg_cnt int, hinfo mra.HeaderOffset, rom []byte ) ([]int, []string) {
	header  := macros.GetInt("JTFRAME_HEADER")

	if reg_cnt < 5 {
		reg_cnt=5
	}
	offsets := make([]int,reg_cnt)
	// Default values from macros (if defined)
	offsets[1] = macros.GetInt("JTFRAME_BA1_START")+header
	offsets[2] = macros.GetInt("JTFRAME_BA2_START")+header
	offsets[3] = macros.GetInt("JTFRAME_BA3_START")+header
	offsets[4] = macros.GetInt("JTFRAME_PROM_START")+header
	for k, _ := range offsets {
		if offsets[k] <= header {
			offsets[k] = len(rom)
		}
	}
	// final values from header (if defined)
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

func dump( name string, rom []byte, p0, p1, lim, fill int) (int,error) {
	if p1<=0 { p1 = lim	}
	if verbose { fmt.Printf("%s %X -> %X\n",name,p0,p1) }
	if p1<p0 { return 0,fmt.Errorf("start offset was beyond end offset") }
	if p1<=0 { return p0, nil }
	if p1>len(rom) {
		return 0,fmt.Errorf("ROM file is too short to produce file: $%X > $%X",
			p1, len(rom))
	}
	if( p1==p0 && fill==0 ) {
		e := os.Remove(name)
		if e!=nil {
			return 0,e
		}
		fmt.Println("Removed file",name)
		return p1,nil
	}
	if e := os.WriteFile( name, rom[p0:p1],0664 ); e!=nil { return 0,e }
	// complement up to 8MB
	sz := p1-p0
	if sz >= fill { return p1,nil }
	f, e := os.OpenFile(name,os.O_APPEND|os.O_WRONLY,0664); if e!=nil { return 0,e }
	defer f.Close()
	blank := make([]byte,fill-sz)
	_, e = f.Write(blank); if e!=nil { return 0,e }
	if verbose {
		fmt.Printf("%s done. Next starts at %x\n",name,p1)
	}
	return p1,nil
}

func make_symlink( game string ) {
	// Link ROM files
	src := filepath.Join(must_env("JTROOT"),"rom",game+".rom")
	os.Remove("rom.bin")
	os.Symlink(src,"rom.bin")
	// Link NVRAM files
	src = filepath.Join(must_env("JTROOT"),"rom",strings.ToUpper(game+".RAM"))
	f, e := os.Open(src)
	defer f.Close()
	if e!=nil { return } // No RAM file
	os.Remove("nvram.bin")
	os.Symlink(src,"nvram.bin")
}