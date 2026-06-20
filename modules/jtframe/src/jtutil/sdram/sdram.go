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
	"regexp"
	"strconv"
	"strings"

	"jotego/jtframe/macros"
	"jotego/jtframe/mem"
	"jotego/jtframe/mra"
)

var verbose bool
var size_re = regexp.MustCompile(`^(\d+)(?:\s*(B|k|kB|M|MB))?$`)

func Run(args []string, v, apply_sim bool) error {
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
	memCfg, err := parseMemConfig(core)
	if err != nil {
		return err
	}
	if err := extractSDRAM(memCfg, core, game); err != nil {
		return err
	}
	if apply_sim {
		if err := applySimFiles(memCfg); err != nil {
			return err
		}
	}
	if err := makeSymlink(game); err != nil {
		return err
	}
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
	return rom
}

func extractSDRAM(memCfg *mem.MemConfig, core, game string) error {
	rom := readROM(game)
	var err error
	if memCfg.Download.Pre_addr || memCfg.Download.Post_addr || memCfg.Download.Post_data {
		return fmt.Errorf("jtutil sdram does not support download address/data transforms (pre_addr/post_addr/post_data) in mem.yaml")
	}
	mraCfg, err := mra.ParseTomlFile(core)
	if err != nil {
		return err
	}
	regCnt := len(mraCfg.Header.Offset.Regions)
	hinfo := mraCfg.Header.Offset
	offsets, reg, err := bankOffset(regCnt, hinfo, rom)
	if err != nil {
		return err
	}
	if err = applyGfxSort(memCfg, game, rom, offsets); err != nil {
		return err
	}
	// Swap the bytes so sdram.bin files get written correctly as 16-bit words.
	swapBytes(rom, 0)
	header := macros.GetInt("JTFRAME_HEADER")
	bankFill := sdramBankSize()
	promStart := offsets[4]
	nxStart, err := dump("sdram_bank0.bin", rom, header, offsets[1], promStart, bankFill)
	if err != nil {
		return fmt.Errorf("%w for bank 0", err)
	}
	if nxStart < 0 {
		os.Remove("sdram_bank1.bin")
		os.Remove("sdram_bank2.bin")
		os.Remove("sdram_bank3.bin")
		return nil
	}
	nxStart, err = dump("sdram_bank1.bin", rom, nxStart, offsets[2], promStart, bankFill)
	if err != nil {
		return fmt.Errorf("%w for bank 1", err)
	}
	if nxStart < 0 {
		os.Remove("sdram_bank2.bin")
		os.Remove("sdram_bank3.bin")
		return nil
	}
	nxStart, err = dump("sdram_bank2.bin", rom, nxStart, offsets[3], promStart, bankFill)
	if err != nil {
		return fmt.Errorf("%w for bank 2", err)
	}
	if nxStart < 0 {
		os.Remove("sdram_bank3.bin")
		fmt.Println("Skippin bank3")
		return nil
	}
	nxStart, err = dump("sdram_bank3.bin", rom, nxStart, 0, promStart, bankFill)
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

type sim_file_entry struct {
	kind       string
	name       string
	path       string
	bank       int
	offset     int
	length     int
	data_width int
	big_endian bool
}

func applySimFiles(cfg *mem.MemConfig) error {
	all, err := collectSimFiles(cfg)
	if err != nil {
		return err
	}
	for _, each := range all {
		if err := applySimFile(each); err != nil {
			return err
		}
	}
	return nil
}

func collectSimFiles(cfg *mem.MemConfig) ([]sim_file_entry, error) {
	resolver := newExpressionResolver(cfg.Params)
	all := make([]sim_file_entry, 0)
	for bank_idx, bank := range cfg.SDRAM.Banks {
		for _, bus := range bank.Buses {
			entry, ok, err := makeBusSimFileEntry(resolver, bank_idx, bus)
			if err != nil {
				return nil, err
			}
			if ok {
				all = append(all, entry)
			}
		}
	}
	for _, line := range cfg.SDRAM.Cache_lanes {
		entry, ok, err := makeCacheLaneSimFileEntry(resolver, line)
		if err != nil {
			return nil, err
		}
		if ok {
			all = append(all, entry)
		}
	}
	return all, nil
}

func makeBusSimFileEntry(resolver *expressionResolver, bank_idx int, bus mem.SDRAMBus) (sim_file_entry, bool, error) {
	simfile := strings.TrimSpace(bus.Simfile.Name)
	if simfile == "" {
		return sim_file_entry{}, false, nil
	}
	sim_data_width, err := mem.ResolveSimfileDataWidth("bus", bus.Name, bus.Data_width, bus.Simfile.Data_type, bus.Simfile.Big_endian)
	if err != nil {
		return sim_file_entry{}, false, err
	}
	if bus.Addr_width < 0 || bus.Addr_width >= strconv.IntSize {
		return sim_file_entry{}, false, fmt.Errorf("invalid addr_width %d for bus %s", bus.Addr_width, bus.Name)
	}
	offset, err := resolveSimOffset(resolver, bus.Offset, "bus", bus.Name)
	if err != nil {
		return sim_file_entry{}, false, err
	}
	length := 1 << bus.Addr_width
	if err := validateSimBounds(bank_idx, offset, length, "bus", bus.Name); err != nil {
		return sim_file_entry{}, false, err
	}
	return sim_file_entry{
		kind:       "bus",
		name:       bus.Name,
		path:       simfile,
		bank:       bank_idx,
		offset:     offset,
		length:     length,
		data_width: sim_data_width,
		big_endian: bus.Simfile.Big_endian,
	}, true, nil
}

func makeCacheLaneSimFileEntry(resolver *expressionResolver, line mem.SDRAMCacheLine) (sim_file_entry, bool, error) {
	simfile := strings.TrimSpace(line.Simfile.Name)
	if simfile == "" {
		return sim_file_entry{}, false, nil
	}
	sim_data_width, err := mem.ResolveSimfileDataWidth("cache-lane", line.Name, line.Data_width, line.Simfile.Data_type, line.Simfile.Big_endian)
	if err != nil {
		return sim_file_entry{}, false, err
	}
	offset, err := resolveSimOffset(resolver, line.At.Offset, "cache-lane", line.Name)
	if err != nil {
		return sim_file_entry{}, false, err
	}
	length, err := parseSimSize(line.At.Length)
	if err != nil {
		return sim_file_entry{}, false, fmt.Errorf("invalid length for cache-lane %s: %w", line.Name, err)
	}
	if err := validateSimBounds(line.At.Bank, offset, length, "cache-lane", line.Name); err != nil {
		return sim_file_entry{}, false, err
	}
	return sim_file_entry{
		kind:       "cache-lane",
		name:       line.Name,
		path:       simfile,
		bank:       line.At.Bank,
		offset:     offset,
		length:     length,
		data_width: sim_data_width,
		big_endian: line.Simfile.Big_endian,
	}, true, nil
}

func resolveSimOffset(resolver *expressionResolver, text, kind, name string) (int, error) {
	text = strings.TrimSpace(text)
	if text == "" {
		return 0, nil
	}
	if value, err := parseIntLiteral(text); err == nil {
		if value < 0 {
			return 0, fmt.Errorf("negative offset for %s %s: %d", kind, name, value)
		}
		return value << 1, nil
	}
	offset_words, err := resolver.eval(text)
	if err != nil {
		return 0, fmt.Errorf("cannot evaluate offset for %s %s: %w", kind, name, err)
	}
	if offset_words < 0 {
		return 0, fmt.Errorf("negative offset for %s %s: %d", kind, name, offset_words)
	}
	return offset_words << 1, nil
}

func validateSimBounds(bank, offset, length int, kind, name string) error {
	bank_size := sdramBankSize()
	if bank < 0 || bank > 3 {
		return fmt.Errorf("%s %s targets invalid SDRAM bank %d", kind, name, bank)
	}
	if offset < 0 || length < 0 {
		return fmt.Errorf("%s %s uses invalid offset/length", kind, name)
	}
	if offset+length > bank_size {
		return fmt.Errorf("%s %s exceeds bank %d size (%d + %d > %d)", kind, name, bank, offset, length, bank_size)
	}
	return nil
}

func parseSimSize(text string) (int, error) {
	text = strings.TrimSpace(text)
	if text == "" {
		return 0, fmt.Errorf("size cannot be empty")
	}
	parts := size_re.FindStringSubmatch(text)
	if parts == nil {
		return 0, fmt.Errorf("size must be an integer number of bytes, or use the exact suffixes B, k, kB, M or MB")
	}
	size_value, err := strconv.Atoi(parts[1])
	if err != nil {
		return 0, fmt.Errorf("size must be an integer number of bytes, or use the exact suffixes B, k, kB, M or MB")
	}
	if size_value <= 0 {
		return 0, fmt.Errorf("size must be greater than zero")
	}
	multiplier := 1
	switch parts[2] {
	case "k", "kB":
		multiplier = 1024
	case "M", "MB":
		multiplier = 1024 * 1024
	}
	return size_value * multiplier, nil
}

func applySimFile(each sim_file_entry) (err error) {
	data, err := os.ReadFile(each.path)
	if err != nil {
		return fmt.Errorf("cannot read simfile %s for %s %s: %w", each.path, each.kind, each.name, err)
	}
	if len(data) != each.length {
		return fmt.Errorf("simfile %s for %s %s must be %d bytes but is %d", each.path, each.kind, each.name, each.length, len(data))
	}
	byte_swapped := false
	if byte_swapped, err = swapSimFileData(data, each.data_width, each.big_endian); err != nil {
		return fmt.Errorf("cannot prepare simfile %s for %s %s: %w", each.path, each.kind, each.name, err)
	}
	name := fmt.Sprintf("sdram_bank%d.bin", each.bank)
	bank_data, err := readBankFile(name)
	if err != nil {
		return err
	}
	copy(bank_data[each.offset:each.offset+each.length], data)
	if err := os.WriteFile(name, bank_data, 0664); err != nil {
		return err
	}
	if verbose {
		fmt.Printf("Applied simfile %-16s to bank=%d offset=%X length=%X", each.path, each.bank, each.offset, each.length)
		if byte_swapped {
			fmt.Printf(" (bytes swapped)")
		}
		fmt.Printf("\n")
	}
	return nil
}

func swapSimFileData(data []byte, data_width int, big_endian bool) (bool, error) {
	if !big_endian {
		return false, nil
	}
	word_bytes := data_width >> 3
	if word_bytes <= 1 {
		return false, fmt.Errorf("simfile.big_endian requires 16-bit or 32-bit data width")
	}
	if (len(data) % word_bytes) != 0 {
		return false, fmt.Errorf("file length %d is not divisible by %d-byte words", len(data), word_bytes)
	}
	for k := 0; k < len(data); k += word_bytes {
		for a, b := k, k+word_bytes-1; a < b; a, b = a+1, b-1 {
			data[a], data[b] = data[b], data[a]
		}
	}
	return true, nil
}

func readBankFile(name string) ([]byte, error) {
	bank_size := sdramBankSize()
	data, err := os.ReadFile(name)
	if err != nil {
		if os.IsNotExist(err) {
			return make([]byte, bank_size), nil
		}
		return nil, err
	}
	if len(data) != bank_size {
		return nil, fmt.Errorf("%s must be %d bytes but is %d", name, bank_size, len(data))
	}
	return data, nil
}

func sdramBankSize() int {
	const (
		eightMB   = 8 * 1024 * 1024
		sixteenMB = 2 * eightMB
	)
	if macros.IsSet("JTFRAME_SDRAM_LARGE") {
		return sixteenMB
	}
	return eightMB
}

func bankOffset(regCnt int, hinfo mra.HeaderOffset, rom []byte) ([]int, []string, error) {
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
		idx := hinfo.Start + (k << 1)
		if idx+1 >= len(rom) {
			return nil, nil, fmt.Errorf("wrong header: offset index %d for %s is outside ROM length %X", idx, hinfo.Regions[k], len(rom))
		}
		pos := (int(rom[idx]) << 8) | int(rom[idx+1])
		if hinfo.Reverse {
			pos = (int(rom[idx+1]) << 8) | int(rom[idx])
		}
		pos <<= hinfo.Bits
		if pos+header > len(rom) {
			return nil, nil, fmt.Errorf("wrong header: computed offset %X for %s exceeds ROM length %X", pos+header, hinfo.Regions[k], len(rom))
		}
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
	return offsets, hinfo.Regions, nil
}

func parseMemConfig(core string) (*mem.MemConfig, error) {
	var cfg mem.MemConfig
	if err := mem.ParseFile(core, "mem.yaml", &cfg); err != nil {
		return nil, fmt.Errorf("cannot parse mem.yaml: %w", err)
	}
	return &cfg, nil
}

func applyGfxSort(cfg *mem.MemConfig, game string, rom []byte, offsets []int) error {
	if len(cfg.SDRAM.Banks) == 0 {
		return nil
	}
	resolver := newExpressionResolver(cfg.Params)
	for bankIdx := 0; bankIdx < len(cfg.SDRAM.Banks) && bankIdx < 4; bankIdx++ {
		bankStart, bankEnd := bankBounds(bankIdx, offsets, len(rom))
		if bankEnd <= bankStart {
			continue
		}
		buses := cfg.SDRAM.Banks[bankIdx].Buses
		for busIdx, bus := range buses {
			gfx := strings.TrimSpace(bus.Gfx)
			if gfx == "" {
				continue
			}
			if strings.TrimSpace(bus.Gfx_en) != "" {
				if !shouldApplyGfxEn(bus.Gfx_en, game) {
					if verbose {
						fmt.Printf("Skipping conditional gfx_sort %-8s on bus=%s (gfx_sort_en=%s)\n", gfx, bus.Name, bus.Gfx_en)
					}
					continue
				}
			}
			busStart := bankStart
			if strings.TrimSpace(bus.Offset) != "" {
				offsetWords, err := resolver.eval(bus.Offset)
				if err != nil {
					return fmt.Errorf("cannot evaluate offset for bus %s in bank %d: %w", bus.Name, bankIdx, err)
				}
				if offsetWords < 0 {
					return fmt.Errorf("negative offset for bus %s in bank %d: %d", bus.Name, bankIdx, offsetWords)
				}
				busStart += offsetWords << 1
			}
			if busStart >= bankEnd {
				continue
			}
			if bus.Addr_width < 0 || bus.Addr_width >= strconv.IntSize {
				return fmt.Errorf("invalid addr_width %d for bus %s", bus.Addr_width, bus.Name)
			}
			size := 1 << bus.Addr_width
			if size <= 0 {
				return fmt.Errorf("invalid addr_width %d for bus %s", bus.Addr_width, bus.Name)
			}
			busEnd := busStart + size
			if busEnd > bankEnd || busEnd < busStart {
				busEnd = bankEnd
			}
			if busIdx+1 < len(buses) && strings.TrimSpace(bus.Gfx_en) == "" {
				nextOffsetText := strings.TrimSpace(buses[busIdx+1].Offset)
				if nextOffsetText != "" {
					nextOffsetWords, err := resolver.eval(nextOffsetText)
					if err != nil {
						return fmt.Errorf("cannot evaluate next offset for bus %s in bank %d: %w", buses[busIdx+1].Name, bankIdx, err)
					}
					nextStart := bankStart + (nextOffsetWords << 1)
					if nextStart >= busStart && nextStart < busEnd {
						busEnd = nextStart
					}
				}
			}
			if err := applyGfxSortRange(rom, busStart, busEnd, gfx); err != nil {
				return fmt.Errorf("cannot apply gfx_sort %s on bus %s in bank %d: %w", gfx, bus.Name, bankIdx, err)
			}
			if verbose {
				fmt.Printf("Applied gfx_sort %-8s to bank=%d bus=%s range=%X-%X\n", gfx, bankIdx, bus.Name, busStart, busEnd)
			}
		}
	}
	return nil
}

func shouldApplyGfxEn(expr, game string) bool {
	name := strings.TrimSpace(strings.ToLower(expr))
	if name == "" {
		return true
	}
	g := strings.ToLower(game)
	if strings.HasPrefix(name, "not_") {
		term := strings.TrimPrefix(name, "not_")
		return !strings.Contains(g, term)
	}
	return strings.Contains(g, name)
}

func bankBounds(bankIdx int, offsets []int, romLen int) (int, int) {
	header := macros.GetInt("JTFRAME_HEADER")
	start := header
	switch bankIdx {
	case 1:
		start = offsets[1]
	case 2:
		start = offsets[2]
	case 3:
		start = offsets[3]
	}
	end := romLen
	switch bankIdx {
	case 0:
		end = offsets[1]
	case 1:
		end = offsets[2]
	case 2:
		end = offsets[3]
	case 3:
		end = offsets[4]
	}
	if start < 0 {
		start = 0
	}
	if end < 0 {
		end = 0
	}
	if start > romLen {
		start = romLen
	}
	if end > romLen {
		end = romLen
	}
	return start, end
}

func applyGfxSortRange(rom []byte, start, end int, pattern string) error {
	if start < 0 || end < start || end > len(rom) {
		return fmt.Errorf("invalid range %d:%d for ROM len %d", start, end, len(rom))
	}
	gfx, err := parseGfxPattern(pattern)
	if err != nil {
		return err
	}
	section := make([]byte, end-start)
	copy(section, rom[start:end])
	sorted := make([]byte, len(section))
	header := macros.GetInt("JTFRAME_HEADER")
	for srcIdx := range section {
		srcAbs := start + srcIdx
		srcNoHdr := srcAbs - header
		dstNoHdr := remapAddressBits(srcNoHdr, gfx)
		dstAbs := dstNoHdr + header
		dstIdx := dstAbs - start
		if dstIdx < 0 || dstIdx >= len(section) {
			return fmt.Errorf("mapped index %d outside range of %d", dstIdx, len(section))
		}
		sorted[dstIdx] = section[srcIdx]
	}
	copy(rom[start:end], sorted)
	return nil
}

type gfxPattern struct {
	mode string
	b0   int
}

func parseGfxPattern(pattern string) (gfxPattern, error) {
	pattern = strings.TrimSpace(pattern)
	if pattern == "" {
		return gfxPattern{}, nil
	}
	b0 := 0
	for strings.HasSuffix(pattern, "x") {
		b0++
		pattern = strings.TrimSuffix(pattern, "x")
	}
	switch pattern {
	case "hvvv":
		return gfxPattern{mode: "gfx4", b0: b0}, nil
	case "hvvvv":
		return gfxPattern{mode: "gfx16c", b0: b0}, nil
	case "hhvvv":
		return gfxPattern{mode: "gfx8", b0: b0}, nil
	case "hhvvvv":
		return gfxPattern{mode: "gfx16", b0: b0}, nil
	case "vhhvvv":
		return gfxPattern{mode: "gfx16b", b0: b0}, nil
	default:
		return gfxPattern{}, fmt.Errorf("unsupported gfx_sort pattern %q", pattern)
	}
}

func remapAddressBits(addr int, gfx gfxPattern) int {
	if gfx.mode == "" {
		return addr
	}
	b0 := gfx.b0
	switch gfx.mode {
	case "gfx4":
		return remapBits(addr, b0, []int{3, 0, 1, 2})
	case "gfx16c":
		return remapBits(addr, b0, []int{4, 0, 1, 2, 3})
	case "gfx8":
		return remapBits(addr, b0, []int{3, 4, 0, 1, 2})
	case "gfx16":
		return remapBits(addr, b0, []int{4, 5, 0, 1, 2, 3})
	case "gfx16b":
		return remapBits(addr, b0, []int{3, 4, 0, 1, 2, 5})
	default:
		return addr
	}
}

func remapBits(addr, b0 int, dstToSrc []int) int {
	maxBit := b0 + len(dstToSrc)
	if maxBit >= strconv.IntSize {
		return addr
	}
	mask := ((1 << len(dstToSrc)) - 1) << b0
	out := addr & ^mask
	for dstOffset, srcOffset := range dstToSrc {
		if ((addr >> (b0 + srcOffset)) & 1) != 0 {
			out |= 1 << (b0 + dstOffset)
		}
	}
	return out
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
	// Complement up to the SDRAM bank size.
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

func makeSymlink(game string) error {
	// Link ROM files.
	src := filepath.Join(mustEnv("JTROOT"), "rom", game+".rom")
	os.Remove("rom.bin")
	if err := os.Symlink(src, "rom.bin"); err != nil {
		return err
	}
	// Link NVRAM files.
	src = filepath.Join(mustEnv("JTROOT"), "rom", strings.ToUpper(game+".RAM"))
	f, err := os.Open(src)
	if err != nil {
		return nil // No RAM file.
	}
	defer f.Close()
	os.Remove("nvram.bin")
	if err := os.Symlink(src, "nvram.bin"); err != nil {
		return err
	}
	return nil
}
