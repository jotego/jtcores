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

package sdram

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"jotego/jtframe/macros"
	"jotego/jtframe/mra"
)

var verbose bool

func Run(args []string, v bool) error {
	verbose = v
	var game string
	if len(args) != 0 {
		game = args[0]
	} else {
		var err error
		game, err = deriveGameFromWD()
		if err != nil {
			return err
		}
	}
	if err := validateWD(); err != nil {
		return err
	}
	core, err := deriveCoreFromWD()
	if err != nil {
		return err
	}
	macros.MakeMacros(core, "mist")
	if err := extractSDRAM(core, game); err != nil {
		return err
	}
	makeSymlink(game)
	return nil
}

func deriveGameFromWD() (string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	game := filepath.Base(wd)
	if game == "game" {
		return "", fmt.Errorf("Cannot derive ROM set name from current folder. Use jtutil sdram <game> instead.")
	}
	return game, nil
}

func validateWD() error {
	wd, err := os.Getwd()
	if err != nil {
		return err
	}
	wd = filepath.Join(wd, "..")
	if filepath.Base(wd) != "ver" {
		return fmt.Errorf("jtutil sdram must be called from a ver/game folder")
	}
	return nil
}

func deriveCoreFromWD() (string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	core := filepath.Base(filepath.Join(wd, "../.."))
	jtroot, ok := os.LookupEnv("JTROOT")
	if !ok {
		return "", fmt.Errorf("JTROOT is not defined in the environment")
	}
	corePath := filepath.Join(jtroot, "cores", core)
	info, err := os.Stat(corePath)
	if err != nil {
		return "", fmt.Errorf("core folder not found at %s: %w", corePath, err)
	}
	if !info.IsDir() {
		return "", fmt.Errorf("core path is not a directory: %s", corePath)
	}
	return core, nil
}

func mustEnv(env string) string {
	v, ok := os.LookupEnv(env)
	if !ok {
		fmt.Println(env, "is not defined in the environment.")
		os.Exit(1)
	}
	return v
}

func swapBytes(rom []byte, start int) {
	for k := start; k < len(rom); k += 2 {
		aux := rom[k]
		rom[k] = rom[k+1]
		rom[k+1] = aux
	}
}

func readROM(game string) []byte {
	rom, err := os.ReadFile(filepath.Join(mustEnv("JTROOT"), "rom", game+".rom"))
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	if (len(rom) & 1) != 0 {
		fmt.Println("The ROM length must be even")
		os.Exit(1)
	}
	// Swap the bytes so sdram.bin files get written correctly as 16-bit words.
	swapBytes(rom, 0)
	return rom
}

func extractSDRAM(core, game string) error {
	const eightMB = 8 * 1024 * 1024
	rom := readROM(game)
	mraCfg, err := mra.ParseTomlFile(core)
	if err != nil {
		return err
	}
	regCnt := len(mraCfg.Header.Offset.Regions)
	hinfo := mraCfg.Header.Offset
	offsets, reg := bankOffset(regCnt, hinfo, rom)
	header := macros.GetInt("JTFRAME_HEADER")
	promStart := offsets[4]
	nxStart, err := dump("sdram_bank0.bin", rom, header, offsets[1], promStart, eightMB)
	if err != nil {
		return fmt.Errorf("%w for bank 0", err)
	}
	if nxStart < 0 {
		os.Remove("sdram_bank1.bin")
		os.Remove("sdram_bank2.bin")
		os.Remove("sdram_bank3.bin")
		return nil
	}
	nxStart, err = dump("sdram_bank1.bin", rom, nxStart, offsets[2], promStart, eightMB)
	if err != nil {
		return fmt.Errorf("%w for bank 1", err)
	}
	if nxStart < 0 {
		os.Remove("sdram_bank2.bin")
		os.Remove("sdram_bank3.bin")
		return nil
	}
	nxStart, err = dump("sdram_bank2.bin", rom, nxStart, offsets[3], promStart, eightMB)
	if err != nil {
		return fmt.Errorf("%w for bank 2", err)
	}
	if nxStart < 0 {
		os.Remove("sdram_bank3.bin")
		fmt.Println("Skippin bank3")
		return nil
	}
	nxStart, err = dump("sdram_bank3.bin", rom, nxStart, 0, promStart, eightMB)
	if err != nil {
		return fmt.Errorf("%w for bank 3", err)
	}
	// Extra regions (read with prom_we set).
	if len(reg) > 4 {
		// Undo the swap needed for the SDRAM part of the ROM file.
		swapBytes(rom, offsets[4])
	}
	for k := 4; k < len(reg); k++ {
		nx := 0
		if k+1 < len(reg) {
			nx = offsets[k+1]
		}
		if _, err = dump(reg[k], rom, offsets[k], nx, len(rom), 0); err != nil {
			return err
		}
	}
	return nil
}

func bankOffset(regCnt int, hinfo mra.HeaderOffset, rom []byte) ([]int, []string) {
	header := macros.GetInt("JTFRAME_HEADER")
	if regCnt < 5 {
		regCnt = 5
	}
	offsets := make([]int, regCnt)
	// Default values from macros (if defined).
	offsets[1] = macros.GetInt("JTFRAME_BA1_START") + header
	offsets[2] = macros.GetInt("JTFRAME_BA2_START") + header
	offsets[3] = macros.GetInt("JTFRAME_BA3_START") + header
	offsets[4] = macros.GetInt("JTFRAME_PROM_START") + header
	for k := range offsets {
		if offsets[k] <= header {
			offsets[k] = len(rom)
		}
	}
	// Final values from header (if defined).
	for k := 1; k < len(hinfo.Regions); k++ {
		pos := int(rom[hinfo.Start+(k<<1)]) << 8
		pos |= int(rom[hinfo.Start+(k<<1)+1])
		pos <<= hinfo.Bits
		offsets[k] = pos + header
		if verbose {
			fmt.Printf("%-4d %-20s %X\n", k, hinfo.Regions[k], offsets[k])
		}
	}
	if verbose {
		fmt.Println("Offsets")
		for k := 1; k < len(offsets); k++ {
			fmt.Printf("%d %X\n", k, offsets[k])
		}
		fmt.Println()
	}
	return offsets, hinfo.Regions
}

func dump(name string, rom []byte, p0, p1, lim, fill int) (int, error) {
	if verbose {
		fmt.Printf("%10s p0=%08X p1=%08X lim=%08X fill=%08X\n", name, p0, p1, lim, fill)
	}
	if p1 <= 0 {
		p1 = lim
	}
	if verbose {
		fmt.Printf("%s %X -> %X\n", name, p0, p1)
	}
	if p1 < p0 {
		return 0, fmt.Errorf("start offset was beyond end offset")
	}
	if p1 <= 0 {
		return p0, nil
	}
	if p1 > len(rom) {
		return 0, fmt.Errorf("ROM file is too short to produce file: $%X > $%X", p1, len(rom))
	}
	if p1 == p0 && fill == 0 {
		err := os.Remove(name)
		if err != nil {
			return 0, err
		}
		fmt.Println("Removed file", name)
		return p1, nil
	}
	if err := os.WriteFile(name, rom[p0:p1], 0664); err != nil {
		return 0, err
	}
	// Complement up to 8MB.
	sz := p1 - p0
	if sz >= fill {
		return p1, nil
	}
	f, err := os.OpenFile(name, os.O_APPEND|os.O_WRONLY, 0664)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	blank := make([]byte, fill-sz)
	_, err = f.Write(blank)
	if err != nil {
		return 0, err
	}
	if verbose {
		fmt.Printf("%s done. Next starts at %x\n", name, p1)
	}
	return p1, nil
}

func makeSymlink(game string) {
	// Link ROM files.
	src := filepath.Join(mustEnv("JTROOT"), "rom", game+".rom")
	os.Remove("rom.bin")
	os.Symlink(src, "rom.bin")
	// Link NVRAM files.
	src = filepath.Join(mustEnv("JTROOT"), "rom", strings.ToUpper(game+".RAM"))
	f, err := os.Open(src)
	if err != nil {
		return // No RAM file.
	}
	defer f.Close()
	os.Remove("nvram.bin")
	os.Symlink(src, "nvram.bin")
}
