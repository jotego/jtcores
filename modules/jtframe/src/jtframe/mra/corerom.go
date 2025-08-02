/*  This file is part of JTFRAME.
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

package mra

import (
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"

	"jotego/jtframe/macros"
	. "jotego/jtframe/xmlnode"
)

// first XML node of a ROM region
type StartNode struct {
	node *XMLNode
	pos  int
}

func (this *StartNode) add_length(pos int) {
	if this.node == nil { return }
	lenreg := pos - this.pos
	if lenreg > 0 {
		bits_needed := int(math.Ceil(math.Log2(float64(lenreg))))
		length_message := fmt.Sprintf("%s - length 0x%X (%d bits)",
			this.node.GetName(), lenreg, bits_needed)
		this.node.Rename(length_message)
	}
}

func make_ROM(root *XMLNode, machine *MachineXML, cfg Mame2MRA, args Args) error {
	if len(machine.Rom) == 0 {
		return nil
	}
	if Verbose {
		fmt.Println("Parsing ", machine.Name)
	}
	// Create nodes
	p := make_rom_parent_node(root,machine,cfg.Global.Zip.Alt)
	sorted_regs := make(map[string]bool)
	for _, r := range cfg.ROM.Order {
		sorted_regs[r] = true
	}
	regions := add_unlisted_regions(machine.Rom,cfg.ROM.Order)
	cfg.Header.MakeNode(p)
	pos := 0
	reg_offsets := make(map[string]int)

	var previous StartNode
	for reg_k, reg := range regions {
		reg_cfg := find_region_cfg(machine, reg, cfg)
		if reg_cfg.Skip || reg_cfg.Name=="nvram" {
			continue
		}
		// Warn about unsorted regions
		_, sorted := sorted_regs[reg]
		if !sorted {
			fmt.Printf("\tunlisted region for sorting %s in %s\n", reg, machine.Name)
		}
		reg_roms := reg_cfg.extract_region( machine.Rom, cfg.ROM.Remove)
		// Do not skip empty regions, in case they have a minimum length to fill
		// Proceed with the ROM listing
		if delta := fill_upto(&pos, reg_cfg.start, p); delta < 0 {
			if len(reg_roms)!=0 { fmt.Printf(
				"\tstart offset overcome by 0x%X while parsing region %s in %s\n",
				-delta, reg, machine.Name)
			}
		}
		sdram_bank_comment(p, pos, macros.CopyToMap())
		// comment with start and length of region
		previous.add_length(pos)
		previous.node = p.AddComment(fmt.Sprintf("%s - starts at 0x%X", reg, pos))
		previous.pos = pos
		start_pos := pos

		// Skip regions with "nodump" ROMs
		if is_rom_dump_missing(reg_roms) {
			if parse_custom(reg_cfg, p, machine, &pos, args) {
				fill_upto(&pos, start_pos+reg_cfg.Len, p)
			} else {
				p.AddComment(fmt.Sprintf("Skipping region %s because there is no dump known",
					reg_cfg.EffName()))
			}
			continue
		}

		reg_offsets[reg] = pos
		if Verbose {
			fmt.Printf("\tbefore sorting %s:\n\t%v\n", reg_cfg.Name, reg_roms)
		}
		reg_roms = apply_sort(reg_cfg, reg_roms, machine.Name)
		if Verbose {
			fmt.Println("\tafter sorting:\n\t", reg_roms)
		}
		parts, e := make_region_parts(reg, reg_cfg, reg_roms, machine, cfg)
		if e!=nil { return e }
		if reg_cfg.Mirror {
			reg_len := derive_region_length(reg_cfg, start_pos, reg_k, regions, machine, cfg)
			pos += parts.mirror_into(p, reg_len)
		} else {
			pos += parts.copy_into(p)
		}
		fill_upto(&pos, start_pos+reg_cfg.Len, p)
	}
	previous.add_length(pos)
	make_devROM(p, machine, cfg, &pos)
	p.AddComment(fmt.Sprintf("Total 0x%X bytes - %d kBytes", pos, pos>>10))
	make_patches(p, machine, cfg )
	if e:=cfg.Header.FillData(reg_offsets, pos, machine); e!= nil { return e }
	return nil
}

type region_parts struct{
	node XMLNode
	length int				// length of the parts, without filling or repetition
}

func make_region_parts(reg string, reg_cfg *RegCfg, reg_roms []MameROM, machine *MachineXML, cfg Mame2MRA) (parts region_parts, e error) {
	parts.node = MakeNode("parts")
	if len(reg_cfg.Parts)!=0 {
		parts.length += reg_cfg.parse_parts(&parts.node, reg_roms)
	} else if reg_cfg.Singleton {
		// Singleton interleave case
		parts.length += parse_singleton(reg_roms, reg_cfg, &parts.node)
	} else {
		split_offset, split_minlen := is_split(reg, machine, cfg)
		// Regular interleave case
		if reg_cfg.Frac.Parts != 0 {
			parts.length += make_frac(&parts.node, reg_cfg, reg_roms)
		} else if (reg_cfg.Width != 0 && reg_cfg.Width != 8) && len(reg_roms) > 1 {
			parse_regular_interleave(split_offset, reg, reg_roms, reg_cfg, &parts.node, machine, cfg, &parts.length)
		} else if reg_cfg.Width <= 8 || len(reg_roms) == 1 {
			parse_straight_dump(split_offset, split_minlen, reg, reg_roms, reg_cfg, &parts.node, machine, cfg, &parts.length)
		} else {
			return parts, fmt.Errorf("Error: don't know how to parse region %s (%d roms) in %s\n",
				reg_cfg.Name, len(reg_roms), machine.Name )
		}
	}
	return parts, nil
}

func derive_region_length(reg_cfg *RegCfg, start_pos, reg_k int, regions []string, machine *MachineXML, cfg Mame2MRA) int {
	if has_explicit_length := reg_cfg.Len!=0; has_explicit_length { return reg_cfg.Len }
	// derive from the start of the next region
	if is_not_last:=reg_k < len(regions)-1; is_not_last {
		next_reg := find_region_cfg(machine, regions[reg_k+1], cfg)
		if this_len := next_reg.start-start_pos; this_len>0 {
			return this_len
		}
	}
	const unknown_length=0
	return unknown_length
}

func (parts *region_parts)mirror_into(p *XMLNode, reg_len int) (pos int) {
	if reg_len <=0 {
		reg_len = parts.length
	}
	for copied:=0;(reg_len-copied)>=parts.length && parts.length>0; copied+=parts.length {
		pos += parts.copy_into(p)
	}
	return pos
}

func (parts *region_parts)copy_into(p *XMLNode) int {
	p.CopyChildren(&parts.node)
	return parts.length
}

func make_rom_parent_node(root *XMLNode, machine *MachineXML, altzip string) (p *XMLNode) {
	p = root.AddNode("rom").AddAttr("index", "0")
	zip_name := make_zip_name(machine,altzip)
	p.AddAttr("zip", zip_name)
	p.AddAttr("md5", "None") // We do not know the value yet
	if macros.IsSet("JTFRAME_MR_DDRLOAD") {
		p.AddAttr("address", "0x30000000")
	}
	return p
}

func make_zip_name(machine *MachineXML, altzip string) string {
	zipname := machine.Name + ".zip"
	if len(machine.Cloneof) > 0 {
		zipname += "|" + machine.Cloneof + ".zip"
	}
	if len(altzip) > 0 {
		zipname += "|" + altzip
	}
	return zipname
}

func add_unlisted_regions(machine_roms []MameROM, initial_regions []string) (regions []string) {
	regions = initial_regions
	cur_region := ""
	for _, rom := range machine_roms {
		if cur_region != rom.Region {
			cur_region = rom.Region
			if !slices.Contains(initial_regions,cur_region) {
				regions = append(regions, cur_region)
			}
		}
	}
	return regions
}

func is_rom_dump_missing( reg_roms []MameROM) bool {
	for _, each := range reg_roms {
		if each.Status == "nodump" {
			return true
		}
	}
	return false
}

func sdram_bank_comment(root *XMLNode, pos int, macros map[string]string) {
	for k, v := range macros { // []string{"JTFRAME_BA1_START","JTFRAME_BA2_START","JTFRAME_BA3_START"} {
		start, _ := strconv.ParseInt(v, 0, 32)
		if start == 0 {
			continue
		}
		// add the comment only once
		if int(start) == pos && root.FindMatch(func( n*XMLNode) bool { return k == n.GetName() })==nil {
			root.AddComment(k)
		}
	}
}

func make_patches(root *XMLNode, machine *MachineXML, cfg Mame2MRA) {
	header := macros.GetInt("JTFRAME_HEADER")
	warned := true
	for _, each := range cfg.ROM.Patches {
		if each.Match(machine) > 0 {
			if header != 0 && !warned {
				warned = true
				root.AddComment(fmt.Sprintf("Adding %d bytes to the patch offset to make up for the MRA header",
					header))
			}
			// apply the patch
			root.AddNode("patch", each.Data).AddAttr("offset", fmt.Sprintf("0x%X", each.Offset+header))
		}
	}
}

func make_frac(parent *XMLNode, reg_cfg *RegCfg, reg_roms []MameROM) int {
	dumped := 0
	if (len(reg_roms) % reg_cfg.Frac.Parts) != 0 {
		// There are not enough ROMs, so repeat the last one
		// This is useful in cases such as having 3bpp graphics
		missing := reg_cfg.Frac.Parts - (len(reg_roms) % reg_cfg.Frac.Parts)
		// filled contains the original ROM list with
		// fillers inserted at the end of each group of ROMs
		var filled []MameROM
		step := len(reg_roms) / missing
		for k := 0; k < missing; k++ {
			filled = append(filled, reg_roms[k*step:(k+1)*step]...)
			filled = append(filled, filled[len(filled)-1])
		}
		reg_roms = filled
		////fmt.Println("Added ", missing, " roms to the end")
		//for k, r := range reg_roms {
		//  fmt.Println(k, " - ", r.Name)
		//}
	}
	output_bytes := reg_cfg.Frac.Parts / reg_cfg.Frac.Bytes
	if (output_bytes % 2) != 0 {
		log.Fatal(fmt.Sprintf(
			"Region %s: frac output_bytes (%d) is not a multiple of 2",
			reg_cfg.Name, output_bytes))
	}
	// ROM entries
	var n *XMLNode
	group_size := 0
	group_start := 0
	frac_groups := len(reg_roms) / reg_cfg.Frac.Parts
	for k, r := range reg_roms {
		cnt := k / reg_cfg.Frac.Parts
		mod := k % reg_cfg.Frac.Parts
		if mod == 0 {
			if k != 0 && (reg_cfg.Rom_len != 0 || reg_cfg.Len != 0) {
				exp_size := reg_cfg.Rom_len * reg_cfg.Frac.Parts
				if reg_cfg.Len/frac_groups > exp_size {
					exp_size = reg_cfg.Len / frac_groups
				}
				fill_upto(&dumped, group_start+exp_size*cnt, parent)
			}
			n = parent.AddNode("interleave").AddIntAttr("output", output_bytes*8)
			group_size = 0
			group_start = dumped
		}
		m := n.AddNode("part").AddAttr("name", r.Name)
		if len(r.Crc) > 0 {
			m.AddAttr("crc", r.Crc)
		}
		m.AddAttr("map", make_frac_map(reg_cfg.Reverse, reg_cfg.Frac.Bytes,
			output_bytes, mod))
		dumped += r.Size
		group_size += r.Size
	}
	return dumped
}

func make_frac_map(reverse bool, bytes, total, step int) string {
	mapstr := make([]byte, total)
	for k := 0; k < total; k++ {
		mapstr[k] = '0'
	}
	c := byte('1')
	j := step * bytes
	js := 1
	if !reverse {
		j = total - j - 1
		js = -1
	}
	// fmt.Println("Reverse = ", reverse, "j = ", j, "total = ", total, " step = ", step)
	for i := 0; i < bytes; {
		mapstr[j] = c
		c = c + 1
		i++
		j += js
	}
	var builder strings.Builder
	builder.Grow(total)
	builder.Write(mapstr)
	return builder.String()
}

func (reg_cfg *RegCfg) extract_region(roms []MameROM, remove []string) (ext []MameROM) {
	eff_name := reg_cfg.EffName()
	// Custom list
	if len(reg_cfg.Files) > 0 {
		// fmt.Println("Using custom files for ", reg_cfg.Name)
		ext = make([]MameROM, len(reg_cfg.Files))
		copy(ext, reg_cfg.Files)
		for k, _ := range ext {
			ext[k].Region = eff_name
		}
		return
	}
	// MAME list
roms_loop:
	for _, r := range roms {
		if r.Region == eff_name {
			for _, rm := range remove {
				if rm == r.Name {
					continue roms_loop
				}
			}
			ext = append(ext, r)
		}
	}
	return
}

func add_rom(parent *XMLNode, rom MameROM) *XMLNode {
	n := parent.AddNode("part").AddAttr("name", rom.Name)
	if len(rom.Crc) > 0 {
		n.AddAttr("crc", rom.Crc)
	}
	return n
}

func fill_upto(pos *int, fillto int, parent *XMLNode) int {
	if fillto == 0 {
		return 0
	}
	delta := fillto - *pos
	if delta <= 0 {
		return delta
	}
	// fmt.Printf("fill_upto: at %x, upto %x, delta=%x\n", *pos, fillto, delta)
	parent.AddNode("part", " FF").AddAttr("repeat", fmt.Sprintf("0x%X", fillto-*pos))
	*pos += delta
	return delta
}

func find_region_cfg(machine *MachineXML, regname string, cfg Mame2MRA) *RegCfg {
	var best *RegCfg
	for k, each := range cfg.ROM.Regions {
		if each.EffName() == regname {
			m := each.Match(machine)
			if m == 3 {
				best = &cfg.ROM.Regions[k]
				break
			} else if m == 2 || (m == 1 && best == nil) {
				best = &cfg.ROM.Regions[k]
			}
		}
	}
	// the region does not have a configuration in the TOML file, set a default one:
	if best == nil {
		if Verbose { fmt.Printf("%s: using blank configuration for ROM regions %s\n",machine.Name, regname)}
		best = &RegCfg{
			Name: regname,
		}
	}
	return best
}

func get_reverse(reg_cfg *RegCfg, name string) bool {
	for _, k := range reg_cfg.Overrules {
		for _, j := range k.Names {
			if j == name {
				// fmt.Printf("Reverse overruled for %s\n",name)
				return k.Reverse
			}
		}
	}
	return reg_cfg.Reverse
}

func get_reverse_width(reg_cfg *RegCfg, name string, width int) bool {
	rev_w := reg_cfg.Reverse_only == nil || len(reg_cfg.Reverse_only) == 0
	for _, each := range reg_cfg.Reverse_only {
		if width == each {
			rev_w = true
		}
	}
	for _, k := range reg_cfg.Overrules {
		for _, j := range k.Names {
			if j == name {
				// fmt.Printf("Reverse overruled for %s\n",name)
				return k.Reverse
			}
		}
	}
	return reg_cfg.Reverse && rev_w
}

// if the region is marked for a blank at this point returns its length
// otherwise, zero
func is_blank(curpos int, reg string, machine *MachineXML, cfg Mame2MRA) (blank_len int) {
	blank_len = 0
	offset := 0
	for _, each := range cfg.ROM.Blanks {
		if each.Match(machine) > 0 && reg == each.Region {
			offset = each.Offset
			blank_len = each.Len
		}
	}
	if offset != 0 && offset == curpos {
		return blank_len
	} else {
		return 0
	}
}

func (reg_cfg *RegCfg)parse_parts(p *XMLNode, roms []MameROM) int {
	dumped := 0
	n := p
	reg_cfg.check_width_vs_parts()
	mask := 0
	if reg_cfg.Width>8 {
		switch(reg_cfg.Width) {
		case 16:  mask=0x3
		case 32:  mask=0xf
		case 64:  mask=0xff
		default: {
			msg := fmt.Sprintf("Unexpected value of width %d",reg_cfg.Width)
			panic(msg)
		}}
		if mask!=0 {
			n = reg_cfg.add_interleave(p)
		}
	}
	mapped := 0
	for k,_ := range reg_cfg.Parts {
		if (mapped&mask)==mask && mask!=0 {
			n = reg_cfg.add_interleave(p)
			mapped=0
		}
		each := &reg_cfg.Parts[k]
		m := n.AddNode("part").AddAttr("name",each.Name)
		m.AddAttr("crc",each.Crc)
		if each.Map!=""{
			m.AddAttr("map",each.Map)
			for k, char := range each.Map {
				if char!='0' {
					mapped |= 1<<k
				}
			}
		}
		if each.Length == 0 {
			each.get_size_from_mame(roms)
		} else {
			e := each.verify_size(roms)
			if e!=nil {
				fmt.Println(roms)
				panic(fmt.Errorf("While parsing region %s:\n\t%s",reg_cfg.Name,e))
			}
		}
		m.AddAttr("length", fmt.Sprintf("0x%X",each.Length))
		if( each.Offset != 0 ) {
			m.AddAttr("offset",fmt.Sprintf("0x%X",each.Offset))
		}
		dumped += each.Length
	}
	reg_cfg.check_parts_consistency()
	return dumped
}

func (reg_cfg *RegCfg)add_interleave(p *XMLNode) *XMLNode {
	return p.AddNode("interleave").AddAttr("output", fmt.Sprintf("%d", reg_cfg.Width))
}

func (part *RegParts)get_size_from_mame(roms []MameROM) {
	idx := part.find_rom(roms)
	if idx==-1 { panic(part.error_unknown_rom()) }
	part.Length = roms[idx].Size
}

func (reg_cfg *RegCfg)check_parts_consistency() {
	for k:=1; k<len(reg_cfg.Parts); k++ {
		if reg_cfg.Parts[k].equivalent_size()!=reg_cfg.Parts[k-1].equivalent_size() {
			msg := fmt.Sprintf("Different length for parts %s (%X) and %s (%X) in region %s",
				reg_cfg.Parts[k-1].Name, reg_cfg.Parts[k-1].Length,
				reg_cfg.Parts[k].Name,   reg_cfg.Parts[k].Length, reg_cfg.Name )
			panic(msg)
		}
	}
}

func (part *RegParts)equivalent_size() int {
	if part.Map=="" {
		return part.Length
	}
	times:=0;
	for _, char := range part.Map {
		if char!='0' {
			times++
		}
	}
	if times==0 {
		return 0
	}
	return part.Length/times
}

func (part *RegParts)find_rom(all_roms []MameROM) (k int) {
	for k, rom := range all_roms {
		if part.Name==rom.Name || part.Crc==rom.Crc {
			return k
		}
	}
	return -1
}

func (part *RegParts)verify_size(roms []MameROM) error {
	idx := part.find_rom(roms)
	if idx==-1 { return part.error_unknown_rom() }
	if part.Length+part.Offset > roms[idx].Size {
		part.panic_rom_too_small(roms[idx].Size)
	}
	return nil
}

func (part *RegParts)error_unknown_rom() error{
	return fmt.Errorf("Unknown ROM length for ROM %s (CRC %s)",part.Name,part.Crc)
}

func (part *RegParts)panic_rom_too_small(ref int) {
	msg := fmt.Sprintf("ROM length+offset set in TOML for ROM %s as 0x%X, but the file is only 0x%X in MAME",part.Name,part.Length,ref)
	panic(msg)
}

func (cfg *RegCfg)check_width_vs_parts() {
	bytemap_len := 0
	for _,part := range cfg.Parts {
		if this_len := len(part.Map); this_len>bytemap_len {
			bytemap_len = this_len
		}
	}
	derived_width := bytemap_len*8
	if cfg.Width == 0 {
		cfg.Width = derived_width
	} else if cfg.Width!=derived_width {
		msg := fmt.Sprintf("Expected interleave of width %d for region %s",derived_width,cfg.Name)
		panic(msg)
	}
}

func parse_singleton(reg_roms []MameROM, reg_cfg *RegCfg, p *XMLNode) int {
	pos := 0
	if reg_cfg.Width != 16 && reg_cfg.Width != 32 {
		log.Fatal("jtframe mra: singleton only supported for width 16 and 32")
	}
	var n *XMLNode
	p.AddComment("Singleton region. The files are merged with themselves.")
	msb := (reg_cfg.Width / 8) - 1
	divider := reg_cfg.Width >> 3
	mapfmt := fmt.Sprintf("%%0%db", divider)
	for _, r := range reg_roms {
		n = p.AddNode("interleave").AddAttr("output", fmt.Sprintf("%d", reg_cfg.Width))
		mapbyte := 1
		if reg_cfg.Reverse {
			mapbyte = 1 << msb // 2 for 16 bits, 8 for 32 bits
		}
		for k := 0; k < divider; k++ {
			m := add_rom(n, r)
			m.AddAttr("offset", fmt.Sprintf("0x%04x", r.Size/divider*k))
			m.AddAttr("map", fmt.Sprintf(mapfmt, mapbyte))
			m.AddAttr("length", fmt.Sprintf("0x%04X", r.Size/divider))
			// Second half
			if reg_cfg.Reverse {
				mapbyte >>= 1
			} else {
				mapbyte <<= 1
			}
		}
		pos += r.Size
	}
	return pos
}

func parse_straight_dump(split_offset, split_minlen int, reg string, reg_roms []MameROM, reg_cfg *RegCfg, p *XMLNode, machine *MachineXML, cfg Mame2MRA, pos *int) {
	reg_pos := 0
	start_pos := *pos
	for _, r := range reg_roms {
		offset := r.Offset
		if reg_cfg.No_offset || ((offset&^0xf)==0) {
			offset = 0
		} else {
			if delta := fill_upto(pos, ((offset&-2)-reg_pos)+*pos, p); delta < 0 {
				log.Printf("Warning: ROM start overcome at 0x%X (expected 0x%X - delta=%X)\n",
					*pos, ((offset&-2)-reg_pos)+*pos, delta)
				log.Printf("\t while parsing region %s (%s)\n", reg_cfg.Name, machine.Name)
			}
		}
		rom_pos := *pos
		// check if the next ROM should be split
		rom_len := 0
		var m, pp *XMLNode
		if get_reverse(reg_cfg, r.Name) {
			pp = p.AddNode("interleave").AddAttr("output", "16")
			m = add_rom(pp, r)
			m.AddAttr("map", "12")
		} else {
			m = add_rom(p, r)
		}
		// Parse ROM splits by marking the dumped ROM above
		// as only the first half, filling in a blank, and
		// adding the second half
		if *pos-start_pos <= split_offset && *pos-start_pos+r.Size > split_offset && split_minlen > (r.Size>>1) {
			if Verbose {
				fmt.Printf("\t-split on single ROM file at %X\n", split_offset)
			}
			rom_len = r.Size >> 1
			m.AddAttr("length", fmt.Sprintf("0x%X", rom_len))
			*pos += rom_len
			fill_upto(pos, *pos+split_minlen-rom_len, p)
			// second half
			if get_reverse(reg_cfg, r.Name) {
				pp := p.AddNode("interleave").AddAttr("output", "16")
				m = add_rom(pp, r)
				m.AddAttr("map", "12")
			} else {
				m = add_rom(p, r)
			}
			m.AddAttr("length", fmt.Sprintf("0x%X", rom_len))
			m.AddAttr("offset", fmt.Sprintf("0x%X", rom_len))
			*pos += rom_len
		} else {
			filled := false
			if reg_cfg.Rom_len!=0 && r.Size!=0 {
				mirror_cnt := reg_cfg.Rom_len / r.Size
				// fill with mirror images of the current file when it makes sense
				// some games expect to have these mirrors either during game play or ROM checks
				// examples in jtshouse core: quester, wldcourt, ws89. See issue #656
				if (mirror_cnt==2 || mirror_cnt==4 || mirror_cnt==8) && reg_cfg.Rom_len%mirror_cnt==0 {
					filled = true
					for k:=1;k<mirror_cnt;k=k+1 {
						if pp != nil {
							p.InsertNode(*pp)
						} else {
							p.InsertNode(*m)
						}
						*pos += r.Size
					}
				}
			}
			if reg_cfg.Rom_len != 0 && !filled { // length attribute is sometimes needed because the dump size might be wrong
				m.AddAttr("length", fmt.Sprintf("0x%X", reg_cfg.Rom_len))
			}
			*pos += r.Size
		}
		if reg_cfg.Rom_len > r.Size {
			fill_upto(pos, reg_cfg.Rom_len+rom_pos, p)
		}
		reg_pos = *pos - start_pos
		if blank_len := is_blank(reg_pos, reg, machine, cfg); blank_len > 0 {
			fill_upto(pos, *pos+blank_len, p)
			p.AddComment(fmt.Sprintf("Blank ends at 0x%X", *pos))
		}
		reg_pos = *pos - start_pos
	}
}

func parse_i8751(reg_cfg *RegCfg, p *XMLNode, machine *MachineXML, pos *int, args Args) bool {
	path := filepath.Join(args.firmware_dir, machine.Name+".s")
	f, e := os.Open(path)
	if e != nil {
		path := filepath.Join(args.firmware_dir, machine.Cloneof+".s")
		f, e = os.Open(path)
		if e != nil {
			log.Println("jtframe mra: cannot find custom firmware for ", machine.Name)
			return false
		}
	}
	f.Close()
	binname := fmt.Sprintf("mra%X%X.bin", rand.Int(), rand.Int())
	cmd := exec.Command("as31", "-Fbin", "-O"+binname, path)
	cmd.Stdout = os.Stdout
	e = cmd.Run()
	if e != nil {
		fmt.Printf("\tjtframe mra, as31 returned %v for %s:\n", e, path)
		return false
	}
	// Read the result and add it as data
	bin, e := ioutil.ReadFile(binname)
	if e != nil {
		log.Println("jtframe mra, problem reading as31 output:\n\t", e)
		return false
	}
	*pos += len(bin)
	p.AddComment("Using custom firmware (no known dump)")
	node := p.AddNode("part")
	node.SetIndent()
	node.SetText(hexdump(bin, 16))
	return true
}

func parse_asl(reg_cfg *RegCfg, p *XMLNode, machine *MachineXML, pos *int, args Args) bool {
	path := filepath.Join(args.firmware_dir, machine.Name+".s")
	f, e := os.Open(path)
	if e != nil {
		path = filepath.Join(args.firmware_dir, machine.Cloneof+".s")
		f, e = os.Open(path)
		if e != nil {
			log.Println("jtframe mra: cannot find custom firmware for ", machine.Name)
			return false
		}
	}
	f.Close()
	binname := strings.TrimSuffix(path,".s")+".bin"
	// Assemble
	cmd := exec.Command("asl", "-cpu", reg_cfg.Custom.Dev, path)
	//cmd.Stdout = os.Stdout
	e = cmd.Run()
	if e != nil {
		fmt.Printf("\tjtframe mra: asl returned %v for %s:\n", e, path)
		return false
	}
	// Convert to binary
	cmd = exec.Command("p2bin", strings.TrimSuffix(path,".s")+".p")
	//cmd.Stdout = os.Stdout
	e = cmd.Run()
	if e != nil {
		fmt.Printf("\tjtframe mra: p2bin returned %v for %s:\n", e, path)
		return false
	}
	// Read the result and add it as data
	bin, e := ioutil.ReadFile(binname)
	if e != nil {
		log.Println("jtframe mra, problem reading asl/p2bin output:\n\t", e)
		return false
	}
	*pos += len(bin)
	p.AddComment("Using custom firmware (no known dump)")
	node := p.AddNode("part")
	node.SetIndent()
	node.SetText(hexdump(bin, 16))
	return true
}

func parse_custom(reg_cfg *RegCfg, p *XMLNode, machine *MachineXML, pos *int, args Args) bool {
	if reg_cfg.Custom.Dev == "" {
		return false
	}
	switch reg_cfg.Custom.Dev {
	case "i8751": return parse_i8751(reg_cfg, p, machine, pos, args)
	default: return parse_asl( reg_cfg, p, machine, pos, args)
	}
	// default:
	// 	log.Fatal("jtframe mra: unsupported custom.dev=", reg_cfg.Custom.Dev)
	// }
	return false
}

func reg_used( reg_roms []MameROM ) bool {
	for _, each := range reg_roms {
		if each.used < each.Size {
			return false
		}
	}
	return true
}

func parse_regular_interleave(split_offset int, reg string,
		reg_roms []MameROM, reg_cfg *RegCfg, p *XMLNode,
		machine *MachineXML, cfg Mame2MRA, pos *int) {
	if Verbose {
		fmt.Printf("Regular interleave for %s (%s)\n", reg_cfg.Name, machine.Name)
	}
	if split_offset!=0 {
		if Verbose {
			fmt.Printf("\tsplit at %X\n", split_offset)
		}
		// Split the ROMs in two
		base := reg_roms
		reg_roms = make([]MameROM,0,len(base)*2)
		for _, each := range base {
			each.Size /= 2
			each.show_len = true
			reg_roms = append(reg_roms, each)
		}
		// second half
		for _, each := range base {
			each.Size /= 2
			each.Offset += split_offset
			each.show_len = true
			each.add_offset = each.Size
			each.split_offset = split_offset
			reg_roms = append(reg_roms, each)
		}
	}
	make_interleave_groups( reg, reg_roms, reg_cfg, p, machine, cfg, pos )
}

func make_interleave_groups( reg string,
		reg_roms []MameROM, reg_cfg *RegCfg, p *XMLNode,
		machine *MachineXML, cfg Mame2MRA, pos *int) {
	if Verbose {
		fmt.Printf("\tRegular interleave for %s (%s)\n", reg_cfg.Name, machine.Name)
	}
	if len(reg_roms)==0 { return }
	start_pos := *pos
	if !reg_cfg.No_offset {
		// Try to determine from the offset the word-length of each ROM
		// as well as the isolated ones
		// fmt.Println("Parsing ", reg_cfg.Name)
		rom_offset := reg_roms[0].Offset &^ 0xf
		old_pos := *pos
		main_loop:
		for {
			sel := make([]int,0,16)
			for k := 0; k < len(reg_roms); k++ {
				if Verbose {
					fmt.Printf("%12s (%s) - %05X <? %X - %X/%X",reg_roms[k].Name,
					reg_roms[k].Region,
					reg_roms[k].Offset, rom_offset,
					reg_roms[k].used, reg_roms[k].Size )
				}
				if (reg_roms[k].Offset &^ 0xf) <= rom_offset &&
				    reg_roms[k].used < reg_roms[k].Size {
					sel = append( sel, k )
					if Verbose { fmt.Printf("   * ") }
				}
				if Verbose { fmt.Println("") }
			}
			if len(sel)==0 {
				if reg_used(reg_roms) { break }
				// move the offset to the first unused ROM
				for _,each := range reg_roms {
					if each.used==0 {
						rom_offset = each.Offset
						if Verbose { fmt.Printf("Moved offset to %X\n", rom_offset)}
						continue main_loop
					}
				}
				fmt.Printf("Don't know how to parse all ROMs")
				break
			}
			// Sort by offset LSB, because if a ROM comes from a previous
			// group, it will appear as the first one unless we sort it
			for i:=0; i<len(sel); i++ {
				for j:=i+1; j<len(sel);j++ {
					if (reg_roms[sel[j]].Offset&0xf) < (reg_roms[sel[i]].Offset&0xf) {
						aux := sel[j]
						sel[j] = sel[i]
						sel[i] = aux
					}
				}
			}
			group_size := reg_roms[sel[0]].Size
			//wlen_min := 1
			reg_roms[sel[0]].wlen=1  // for len(sel)==1
			if( len(sel) > 1 ) {
				// Mark the width in bytes of each ROM
				last := sel[len(sel)-1]
				reg_roms[last].wlen = (reg_cfg.Width/8)-(reg_roms[last].Offset&0xf)
				for j:=len(sel)-2; j>=0; j-- {
					reg_roms[sel[j]].wlen = (reg_roms[sel[j+1]].Offset-reg_roms[sel[j]].Offset) & 0xf
				}
				// Check that widths make sense
				for j:=0; j<len(sel); j++ {
					if reg_roms[sel[j]].wlen==0 || (reg_roms[sel[j]].wlen != 1 && (reg_roms[sel[j]].wlen % 2) != 0) {
						fmt.Printf("Bad number of ROMs for interleave in %s, region %s (%s)\n",
							machine.Name, reg_cfg.Name, machine.Description )
						for k:=0; k<len(sel); k++ {
							fmt.Printf("%12s (%s) - %d\n", reg_roms[sel[k]].Name,
								reg_roms[sel[k]].Region,
								reg_roms[sel[k]].wlen)
						}
						os.Exit(1)
					}
				}
				// Create the mapstr
				aux := 0
				for k:=0; k<len(sel); k++ {
					r := &reg_roms[sel[k]]
					r.mapstr=""
					for j := r.wlen; j > 0; j-- {
						r.mapstr = r.mapstr + strconv.Itoa(j)
					}
					for j:=0; j<aux; j++ {
						r.mapstr+="0"
					}
					for j := len(r.mapstr); j < (reg_cfg.Width >> 3); j++ {
						r.mapstr = "0" + r.mapstr
					}
					aux += r.wlen
				}
				// Find the size of the smallest ROM
				group_size = 0
				//wlen_min   = reg_roms[sel[0]].wlen
				reg_roms[sel[0]].group=1
				for j:=0; j<len(sel); j++ {
					jsize := (reg_roms[sel[j]].Size-reg_roms[sel[j]].used) /reg_roms[sel[j]].wlen
					if j==0 || group_size >  jsize {
						group_size = jsize
						// fmt.Printf("group_size=%X (%s)\n",jsize,reg_roms[sel[j]].Name)
						//wlen_min   = reg_roms[sel[j]].wlen
					}
					reg_roms[sel[j]].group = 1
				}
			}
			// Create new array for this group
			new_group := make([]MameROM, 0, len(sel))
			if Verbose {
				fmt.Printf("New group. group_size=%X at pos=%X\n",group_size,*pos)
			}
			for j:=0;j<len(sel);j++ {
				if Verbose {
					fmt.Printf("\t%12s (%s) - %d - %s\n", reg_roms[sel[j]].Name,
						reg_roms[sel[j]].Region,
						reg_roms[sel[j]].wlen, reg_roms[sel[j]].mapstr)
				}
				reg_roms[sel[j]].clen=group_size*reg_roms[sel[j]].wlen
				new_group = append(new_group,reg_roms[sel[j]])
			}
			if( reg_cfg.Reverse ) {
				rev_str := func (s string) string {
				    runes := []rune(s)
				    for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
				        runes[i], runes[j] = runes[j], runes[i]
				    }
				    return string(runes)
				}
				rev := make([]MameROM,0,len(new_group))
				//for j:=len(new_group)-1; j>=0; j-- {
				for j:=0; j<len(new_group); j++ {
					new_group[j].mapstr = rev_str(new_group[j].mapstr)
					rev = append(rev, new_group[j] )
				}
				new_group = rev
			}
			interleave_group( reg,
				new_group, reg_cfg, p ,
 				machine, cfg, pos, start_pos )
			// Update used bytes
			for j:=0;j<len(sel);j++ {
				reg_roms[sel[j]].used += group_size*reg_roms[sel[j]].wlen
			}
			rom_offset = *pos-old_pos
			if Verbose {
				fmt.Printf("-------------------> %X (pos=%0X)\n",rom_offset,*pos)
			}
		}
	} else {
		// If no_offset is set, then assume all are grouped together and the word length is 1 byte
		if (len(reg_roms) % (reg_cfg.Width / 8)) != 0 {
			log.Fatal(fmt.Sprintf("The number of ROMs for the %d-bit region (%s) is not even in %s",
				reg_cfg.Width, reg_cfg.Name, machine.Name))
		}
		assign_1byte_length_as_single_group(reg_roms)
		interleave_group( reg,
					reg_roms, reg_cfg, p,
					machine, cfg, pos, start_pos )
	}
	if Verbose { fmt.Println("*******************") }
}

func assign_1byte_length_as_single_group(reg_roms []MameROM) {
	for j, _ := range reg_roms {
		reg_roms[j].group = 1
		reg_roms[j].wlen  = 1
	}
}

func interleave_group( reg string,
		reg_roms []MameROM, reg_cfg *RegCfg, p *XMLNode,
		machine *MachineXML, cfg Mame2MRA, pos *int, start_pos int) {
	reg_pos := 0
	n := p
	deficit := 0

	for k := 0; k < len(reg_roms); {
		r := reg_roms[k]
		mapstr := ""
		rom_cnt := len(reg_roms)
		if r.group != 0 {
			// make interleave node at the expected position
			if deficit > 0 {
				fill_upto(pos, *pos+deficit, p)
			}
			reg_pos = *pos - start_pos
			offset := r.Offset
			if reg_cfg.No_offset {
				offset = r.split_offset
			}
			// p.AddNode(fmt.Sprintf("Fill offset at reg_pos=%X",reg_pos) ).comment=true
			fill_upto(pos, ((offset&-2)-reg_pos)+*pos, p)
			deficit = 0
			n = p.AddNode("interleave").AddAttr("output", fmt.Sprintf("%d", reg_cfg.Width))
			if Verbose {
				fmt.Printf("Made %d-bit interleave for %s\n", reg_cfg.Width, reg_cfg.Name)
			}
			// Prepare the map
			for j := r.wlen; j > 0; j-- {
				mapstr = mapstr + strconv.Itoa(j)
			}
			for j := r.wlen; j < (reg_cfg.Width >> 3); j++ {
				mapstr = "0" + mapstr
			}
			if reg_cfg.No_offset {
				rom_cnt = (reg_cfg.Width >> 3) / r.wlen
			}
		}
		process_rom := func(j int) {
			r = reg_roms[j]
			if Verbose {
				fmt.Printf("\tparsing %s (%d-byte words - mapstr=%s)\n", r.Name, r.wlen, mapstr)
			}
			m := add_rom(n, r)
			if r.mapstr=="" && mapstr != "" {
				m.AddAttr("map", mapstr)
				mapstr = mapstr[r.wlen:] + mapstr[0:r.wlen] // rotate the active byte
			} else if r.mapstr!="" {
				m.AddAttr("map", r.mapstr)
			}
			chunk_size := r.Size
			if r.clen>0 {
				chunk_size=r.clen
			}
			*pos += chunk_size
			if chunk_size<r.Size || r.show_len {
				m.AddAttr("length", fmt.Sprintf("0x%X", chunk_size))
				if offset := r.used+r.add_offset; offset>0 {
					m.AddAttr("offset", fmt.Sprintf("0x%X", offset ))
				}
			}
			if reg_cfg.Rom_len > chunk_size {
				deficit += reg_cfg.Rom_len - chunk_size
			}
			reg_pos = *pos - start_pos
			if blank_len := is_blank(reg_pos, reg, machine, cfg); blank_len > 0 {
				fill_upto(pos, *pos+blank_len, p)
				p.AddComment(fmt.Sprintf("Blank ends at 0x%X", *pos))
			}
		}
		if reg_cfg.Reverse {
			if Verbose {
				fmt.Printf("Got %d ROMs, with rom_cnt=%d, k=%d\n",len(reg_roms), rom_cnt, k)
			}
			for j := k + rom_cnt - 1; j >= k; j-- {
				if reg_roms[j].group == 0 && get_reverse_width(reg_cfg, reg_roms[j].Name, 16) {
					mapstr = "12" // Should this try to contemplate other cases different from 16 bits?
					n = p.AddNode("interleave").AddAttr("output", "16")
				}
				process_rom(j)
			}
		} else {
			for j := k; j < k+rom_cnt; j++ {
				process_rom(j)
			}
		}
		n = p
		k += rom_cnt
	}
}
