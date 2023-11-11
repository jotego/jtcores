package mra

import (
	"fmt"
	"io/ioutil"
	"log"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

func make_ROM(root *XMLNode, machine *MachineXML, cfg Mame2MRA, args Args) {
	if len(machine.Rom) == 0 {
		return
	}
	if args.Verbose {
		fmt.Println("Parsing ", machine.Name)
	}
	// Create nodes
	p := root.AddNode("rom").AddAttr("index", "0")
	zipname := machine.Name + ".zip"
	if len(machine.Cloneof) > 0 {
		zipname += "|" + machine.Cloneof + ".zip"
	}
	if len(cfg.Global.Zip.Alt) > 0 {
		zipname += "|" + cfg.Global.Zip.Alt
	}
	p.AddAttr("zip", zipname)
	p.AddAttr("md5", "None") // We do not know the value yet
	if cfg.ROM.Ddr_load {
		p.AddAttr("address", "0x30000000")
	}
	regions := cfg.ROM.Order
	// Add regions unlisted in the config to the final list
	sorted_regs := make(map[string]bool)
	for _, r := range regions {
		sorted_regs[r] = true
	}
	cur_region := ""
	for _, rom := range machine.Rom {
		if cur_region != rom.Region {
			cur_region = rom.Region
			_, ok := sorted_regs[rom.Region]
			if !ok {
				regions = append(regions, cur_region)
			}
		}
	}
	var header *XMLNode
	if cfg.Header.Len > 0 {
		if len(cfg.Header.Info) > 0 {
			p.AddNode(cfg.Header.Info).comment = true
		}
		header = p.AddNode("part")
		header.indent_txt = true
	}
	pos := 0
	reg_offsets := make(map[string]int)

	var previous StartNode
	for _, reg := range regions {
		reg_cfg := find_region_cfg(machine, reg, cfg, args.Verbose)
		if reg_cfg.Skip {
			continue
		}
		// Warn about unsorted regions
		_, sorted := sorted_regs[reg]
		if !sorted {
			fmt.Printf("\tunlisted region for sorting %s in %s\n", reg, machine.Name)
		}
		reg_roms := extract_region(reg_cfg, machine.Rom, cfg.ROM.Remove)
		// Do not skip empty regions, in case they have a minimum length to fill
		// Skip regions with "nodump" ROMs
		nodump := false
		for _, each := range reg_roms {
			if each.Status == "nodump" {
				nodump = true
			}
		}
		// Proceed with the ROM listing
		if delta := fill_upto(&pos, reg_cfg.start, p); delta < 0 {
			if len(reg_roms)!=0 { fmt.Printf(
				"\tstart offset overcome by 0x%X while parsing region %s in %s\n",
				-delta, reg, machine.Name)
			}
		}
		sdram_bank_comment(p, pos, args.macros)
		// comment with start and length of region
		previous.add_length(pos)
		previous.node = p.AddNode(fmt.Sprintf("%s - starts at 0x%X", reg, pos))
		previous.node.comment = true
		previous.pos = pos
		start_pos := pos

		if nodump {
			if parse_custom(reg_cfg, p, machine, &pos, args) {
				fill_upto(&pos, start_pos+reg_cfg.Len, p)
			} else {
				p.AddNode(fmt.Sprintf("Skipping region %s because there is no dump known",
					reg_cfg.EffName())).comment = true
			}
			continue
		}

		reg_offsets[reg] = pos
		if args.Verbose {
			fmt.Printf("\tbefore sorting %s:\n\t%v\n", reg_cfg.Name, reg_roms)
		}
		reg_roms = apply_sort(reg_cfg, reg_roms, machine.Name, args.Verbose)
		if args.Verbose {
			fmt.Println("\tafter sorting:\n\t", reg_roms)
		}
		// pos_old := pos
		if len(reg_cfg.Parts)!=0 {
			pos += parse_parts( reg_cfg, p )
		} else if reg_cfg.Singleton {
			// Singleton interleave case
			pos += parse_singleton(reg_roms, reg_cfg, p)
		} else {
			split_offset, split_minlen := is_split(reg, machine, cfg)
			// Regular interleave case
			if reg_cfg.Frac.Parts != 0 {
				pos += make_frac(p, reg_cfg, reg_roms)
			} else if (reg_cfg.Width != 0 && reg_cfg.Width != 8) && len(reg_roms) > 1 {
				parse_regular_interleave(split_offset, reg, reg_roms, reg_cfg, p, machine, cfg, args, &pos)
			} else if reg_cfg.Width <= 8 || len(reg_roms) == 1 {
				parse_straight_dump(split_offset, split_minlen, reg, reg_roms, reg_cfg, p, machine, cfg, args, &pos)
			} else {
				fmt.Printf("Error: don't know how to parse region %s (%d roms) in %s\n",
					reg_cfg.Name, len(reg_roms), machine.Name )
				os.Exit(1)
			}
		}
		// if pos_old == pos {
		// 	p.RmNode( previous.node )
		// }
		fill_upto(&pos, start_pos+reg_cfg.Len, p)
	}
	previous.add_length(pos)
	make_devROM(p, machine, cfg, &pos)
	p.AddNode(fmt.Sprintf("Total 0x%X bytes - %d kBytes", pos, pos>>10)).comment = true
	make_patches(p, machine, cfg, args.macros )
	if header != nil {
		make_header(header, reg_offsets, pos, cfg.Header, machine)
	}
}

func make_patches(root *XMLNode, machine *MachineXML, cfg Mame2MRA, macros map[string]string ) {
	header := 0
	if hd_str, f := macros["JTFRAME_HEADER"]; f {
		h, e := strconv.ParseInt( hd_str, 0, 64 )
		if e!=nil {
			fmt.Printf("Cannot parse JTFRAME_HEADER=%s\n", hd_str )
		}
		header = int(h)
	}
	warned := true
	for _, each := range cfg.ROM.Patches {
		if each.Match(machine) > 0 {
			if header != 0 && !warned {
				warned = true
				root.AddNode(fmt.Sprintf("Adding %d bytes to the patch offset to make up for the MRA header",
					header)).comment=true
			}
			// apply the patch
			root.AddNode("patch", each.Data).AddAttr("offset", fmt.Sprintf("0x%X", each.Offset+header))
		}
	}
}

func set_header_offset(headbytes []byte, pos int, reverse bool, bits, offset int) {
	offset >>= bits
	headbytes[pos] = byte((offset >> 8) & 0xff)
	headbytes[pos+1] = byte(offset & 0xff)
	if reverse {
		aux := headbytes[pos]
		headbytes[pos] = headbytes[pos+1]
		headbytes[pos+1] = aux
	}
}

func rawdata2bytes(rawstr string) []byte {
	rawbytes := make([]byte, 0, 1024)
	datastr := strings.ReplaceAll(rawstr, "\n", " ")
	datastr = strings.ReplaceAll(datastr, "\t", " ")
	datastr = strings.TrimSpace(datastr)
	for _, hexbyte := range strings.Split(datastr, " ") {
		if hexbyte == "" {
			continue
		}
		conv, _ := strconv.ParseInt(hexbyte, 16, 0)
		rawbytes = append(rawbytes, byte(conv))
	}
	return rawbytes
}

func make_header(node *XMLNode, reg_offsets map[string]int,
	total int, cfg HeaderCfg, machine *MachineXML) {
	devs := machine.Devices
	headbytes := make([]byte, cfg.Len)
	for k := 0; k < cfg.Len; k++ {
		headbytes[k] = byte(cfg.Fill)
	}
	// Fill ROM offsets
	unknown_regions := make([]string, 0)
	if len(cfg.Offset.Regions) > 0 {
		pos := cfg.Offset.Start
		for _, r := range cfg.Offset.Regions {
			offset, ok := reg_offsets[r]
			if !ok {
				unknown_regions = append(unknown_regions, r)
				offset = 0
			}
			// fmt.Printf("region %s offset %X\n", r, offset)
			set_header_offset(headbytes, pos, cfg.Offset.Reverse, cfg.Offset.Bits, offset)
			pos += 2
		}
		//set_header_offset(headbytes, pos, cfg.Offset.Reverse, cfg.Offset.Bits, total)
	}
	if len(unknown_regions) > 0 {
		fmt.Printf("\tmissing region(s)")
		for _, uk := range unknown_regions {
			fmt.Printf(" %s", uk)
		}
		fmt.Printf(". Offset set to zero in the header (%s)\n", machine.Name)
	}
	// Manual headers
	for _, each := range cfg.Data {
		if each.Match(machine) == 0 {
			continue // skip it
		}
		if each.Dev != "" {
			found := false
			for _, ref := range devs {
				if each.Dev == ref.Name {
					found = true
					break
				}
			}
			if !found {
				continue
			}
		}
		pos := each.Offset
		rawbytes := rawdata2bytes(each.Data)
		// if pos+len(rawbytes) > len(headbytes) {
		//  log.Fatal("Header pointer larger than declared header")
		// }
		copy(headbytes[pos:], rawbytes)
		pos += len(rawbytes)
	}
	node.SetText(hexdump(headbytes, 8))
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

func extract_region(reg_cfg *RegCfg, roms []MameROM, remove []string) (ext []MameROM) {
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

func find_region_cfg(machine *MachineXML, regname string, cfg Mame2MRA, verbose bool) *RegCfg {
	var best *RegCfg
	for k, each := range cfg.ROM.Regions {
		if each.EffName() == regname {
			m := each.Match(machine)
			// if verbose { fmt.Println(machine.Name," checking region config: ", each, "\n\tmatch level=",m)}
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
		if verbose { fmt.Printf("%s: using blank configuration for ROM regions %s\n",machine.Name, regname)}
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

func parse_parts(reg_cfg *RegCfg, p *XMLNode) int {
	dumped := 0
	n := p
	if reg_cfg.Width>8 {
		n = p.AddNode("interleave").AddAttr("output", fmt.Sprintf("%d", reg_cfg.Width))
	}
	for _,each := range reg_cfg.Parts {
		m := n.AddNode("part").AddAttr("name",each.Name)
		m.AddAttr("crc",each.Crc)
		m.AddAttr("map",each.Map)
		m.AddAttr("length", fmt.Sprintf("0x%X",each.Length))
		if( each.Offset != 0 ) {
			m.AddAttr("offset",fmt.Sprintf("0x%X",each.Offset))
		}
		dumped += each.Length
	}
	return dumped
}

func parse_singleton(reg_roms []MameROM, reg_cfg *RegCfg, p *XMLNode) int {
	pos := 0
	if reg_cfg.Width != 16 && reg_cfg.Width != 32 {
		log.Fatal("jtframe mra: singleton only supported for width 16 and 32")
	}
	var n *XMLNode
	p.AddNode("Singleton region. The files are merged with themselves.").comment = true
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

func parse_straight_dump(split_offset, split_minlen int, reg string, reg_roms []MameROM, reg_cfg *RegCfg, p *XMLNode, machine *MachineXML, cfg Mame2MRA, args Args, pos *int) {
	reg_pos := 0
	start_pos := *pos
	for _, r := range reg_roms {
		offset := r.Offset
		if reg_cfg.No_offset || ((offset&^0xf)==0) {
			offset = 0
		} else {
			if delta := fill_upto(pos, ((offset&-2)-reg_pos)+*pos, p); delta < 0 {
				fmt.Printf("Warning: ROM start overcome at 0x%X (expected 0x%X - delta=%X)\n",
					*pos, ((offset&-2)-reg_pos)+*pos, delta)
				fmt.Printf("\t while parsing region %s (%s)\n", reg_cfg.Name, machine.Name)
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
			if args.Verbose {
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
			if reg_cfg.Rom_len != 0 { // length attribute is sometimes needed because the dump size might be wrong
				m.AddAttr("length", fmt.Sprintf("0x%X", reg_cfg.Rom_len))
			}
			if reg_cfg.Rom_len == r.Size*2 {
				if pp != nil {
					p.InsertNode(*pp)
				} else {
					p.InsertNode(*m)
				}
				*pos += r.Size
			}
			*pos += r.Size
		}
		if reg_cfg.Rom_len > r.Size {
			fill_upto(pos, reg_cfg.Rom_len+rom_pos, p)
		}
		reg_pos = *pos - start_pos
		if blank_len := is_blank(reg_pos, reg, machine, cfg); blank_len > 0 {
			fill_upto(pos, *pos+blank_len, p)
			p.AddNode(fmt.Sprintf("Blank ends at 0x%X", *pos)).comment = true
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
	p.AddNode("Using custom firmware (no known dump)").comment = true
	node := p.AddNode("part")
	node.indent_txt = true
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
	p.AddNode("Using custom firmware (no known dump)").comment = true
	node := p.AddNode("part")
	node.indent_txt = true
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
		machine *MachineXML, cfg Mame2MRA, args Args, pos *int) {
	if args.Verbose {
		fmt.Printf("Regular interleave for %s (%s)\n", reg_cfg.Name, machine.Name)
	}
	if split_offset!=0 {
		if args.Verbose {
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
	make_interleave_groups( reg, reg_roms, reg_cfg, p, machine, cfg, args, pos )
}

func make_interleave_groups( reg string,
		reg_roms []MameROM, reg_cfg *RegCfg, p *XMLNode,
		machine *MachineXML, cfg Mame2MRA, args Args, pos *int) {
	if args.Verbose {
		fmt.Printf("\tRegular interleave for %s (%s)\n", reg_cfg.Name, machine.Name)
	}
	if len(reg_roms)==0 {
		return
	}
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
				if args.Verbose {
					fmt.Printf("%12s (%s) - %05X <? %X - %X/%X",reg_roms[k].Name,
					reg_roms[k].Region,
					reg_roms[k].Offset, rom_offset,
					reg_roms[k].used, reg_roms[k].Size )
				}
				if (reg_roms[k].Offset &^ 0xf) <= rom_offset &&
				    reg_roms[k].used < reg_roms[k].Size {
					sel = append( sel, k )
					if args.Verbose { fmt.Printf("   * ") }
				}
				if args.Verbose { fmt.Println("") }
			}
			if len(sel)==0 {
				if reg_used(reg_roms) { break }
				// move the offset to the first unused ROM
				for _,each := range reg_roms {
					if each.used==0 {
						rom_offset = each.Offset
						if args.Verbose { fmt.Printf("Moved offset to %X\n", rom_offset)}
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
			if args.Verbose {
				fmt.Printf("New group. group_size=%X at pos=%X\n",group_size,*pos)
			}
			for j:=0;j<len(sel);j++ {
				if args.Verbose {
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
 				machine, cfg, args, pos, start_pos )
			// Update used bytes
			for j:=0;j<len(sel);j++ {
				reg_roms[sel[j]].used += group_size*reg_roms[sel[j]].wlen
			}
			rom_offset = *pos-old_pos
			if args.Verbose {
				fmt.Printf("-------------------> %X (pos=%0X)\n",rom_offset,*pos)
			}
		}
	} else {
		// If no_offset is set, then assume all are grouped together and the word length is 1 byte
		if (len(reg_roms) % (reg_cfg.Width / 8)) != 0 {
			log.Fatal(fmt.Sprintf("The number of ROMs for the %d-bit region (%s) is not even in %s",
				reg_cfg.Width, reg_cfg.Name, machine.Name))
		}
		for j, _ := range reg_roms {
			reg_roms[j].group = 1
			reg_roms[j].wlen = 1
		}
		interleave_group( reg,
					reg_roms, reg_cfg, p ,
					machine, cfg, args, pos, start_pos )
	}
	if args.Verbose { fmt.Println("*******************") }
}

func interleave_group( reg string,
		reg_roms []MameROM, reg_cfg *RegCfg, p *XMLNode,
		machine *MachineXML, cfg Mame2MRA, args Args, pos *int, start_pos int) {
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
			if args.Verbose {
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
			if args.Verbose {
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
				p.AddNode(fmt.Sprintf("Blank ends at 0x%X", *pos)).comment = true
			}
		}
		if reg_cfg.Reverse {
			if args.Verbose {
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
