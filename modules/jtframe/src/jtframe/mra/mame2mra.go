package mra

import (
	"bufio"
	"bytes"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io/fs"
	"log"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/jotego/jtframe/betas"
	"github.com/jotego/jtframe/def"
	toml "github.com/komkom/toml"
)

func (this *StartNode) add_length(pos int) {
	if this.node != nil {
		lenreg := pos - this.pos
		if lenreg > 0 {
			this.node.name = fmt.Sprintf("%s - length 0x%X (%d bits)", this.node.name, lenreg,
				int(math.Ceil(math.Log2(float64(lenreg)))))
		}
	}
}

func Run(args Args) {
	pocket_clear()
	defer close_allzip()
	parse_args(&args)
	mra_cfg := parse_toml(&args) // macros become part of args
	if args.Verbose {
		fmt.Println("Parsing", args.Xml_path)
	}
	ex := NewExtractor(args.Xml_path)
	parent_names := make(map[string]string)
	// Set the RBF Name if blank
	// if mra_cfg.Rbf.Name == "" {
	// 	mra_cfg.Rbf.Name = "jt" + args.Def_cfg.Core
	// }
	mra_cfg.rbf = "jt" + args.Def_cfg.Core
	// Set the platform name if blank
	if mra_cfg.Global.Platform == "" {
		mra_cfg.Global.Platform = "jt" + args.Def_cfg.Core
	}
	if args.Show_platform {
		fmt.Printf("%s", mra_cfg.Global.Platform)
		return
	}
	var data_queue []ParsedMachine
	if !args.SkipPocket {
		pocket_init(mra_cfg, args)
	}
extra_loop:
	for {
		machine := ex.Extract(mra_cfg.Parse)
		calc_DIP_bits( machine, mra_cfg.Dipsw )
		if machine == nil {
			break
		}
		if args.Verbose {
			fmt.Print("#####################\n#####################\nFound", machine.Name)
			if machine.Cloneof != "" {
				fmt.Printf(" (%s)", machine.Cloneof)
			}
			fmt.Println()
		}
		cloneof := false
		if machine.Cloneof != "" {
			cloneof = true
		} else {
			parent_names[machine.Name] = machine.Description
		}
		if skip_game(machine, mra_cfg, args) {
			continue extra_loop
		}
		for _, each := range mra_cfg.Global.Overrule {
			if each.Match(machine)>0 {
				if each.Rotate != 0 {
					machine.Display.Rotate = each.Rotate
				}
			}
		}
		for _, reg := range mra_cfg.ROM.Regions {
			for k, r := range machine.Rom {
				if r.Region == reg.Name && reg.Rename != "" && reg.Match(machine)>0 {
					machine.Rom[k].Region = reg.Rename
				}
			}
		}
		mra_xml, def_dipsw, coremod := make_mra(machine, mra_cfg, args)
		pm := ParsedMachine{machine, mra_xml, cloneof, def_dipsw, coremod}
		data_queue = append(data_queue, pm)
	}
	// Add explicit parents to the list
	for _, p := range mra_cfg.Parse.Parents {
		parent_names[p.Name] = p.Description
	}
	// Dump MRA is delayed for later so we get all the parent names collected
	if args.Verbose || len(data_queue) == 0 {
		fmt.Println("Total: ", len(data_queue), " games")
	}
	main_copied := args.SkipMRA
	old_deleted := false
	valid_setnames := []string{}
	for _, d := range data_queue {
		_, good := parent_names[d.machine.Cloneof]
		if good || len(d.machine.Cloneof) == 0 {
			if args.PrintNames {
				fmt.Println(d.machine.Description)
			}
			if !args.SkipMRA {
				// Delete old MRA files
				if !old_deleted {
					filepath.WalkDir(args.outdir, func(path string, d fs.DirEntry, err error) error {
						if err == nil {
							if !d.IsDir() && strings.HasSuffix(path, ".mra") {
								delete_old_mra(args, path)
							}
						}
						return nil
					})
					old_deleted = true
				}
				if !args.SkipROM {
					mra2rom(d.mra_xml,args.Verbose, true)
				} else if args.Md5 {
					mra2rom(d.mra_xml,args.Verbose, false)
				}
				// Do not merge dump_mra and the OR in the same line, or the compiler may skip
				// calling dump_mra if main_copied is already set
				dumped := dump_mra(args, d.machine, mra_cfg, d.mra_xml, parent_names)
				main_copied = dumped || main_copied
				valid_setnames = append( valid_setnames, d.machine.Name )
			}
			if !args.SkipPocket {
				pocket_add(d.machine, mra_cfg, args, d.def_dipsw, d.coremod, d.mra_xml )
			}
		} else {
			fmt.Printf("Skipping derivative '%s' as parent '%s' was not found\n",
				d.machine.Name, d.machine.Cloneof)
		}
	}
	dump_setnames( args.Def_cfg.Core, valid_setnames )
	if !main_copied {
		fmt.Printf("ERROR (%s): No single MRA was highlighted as the main one. Set it in the TOML file parse.main key\n", args.Def_cfg.Core)
		os.Exit(1)
	}
	if !args.SkipPocket {
		pocket_save()
	}
}

func dump_setnames( corefolder string, sn []string ) {
	fname := filepath.Join(os.Getenv("CORES"), corefolder, "ver")
	os.MkdirAll(fname,0775)
	fname = filepath.Join(fname, "setnames.txt" )
	f, err := os.Create(fname)
	defer f.Close()
	if err != nil {
		fmt.Println(err)
		return
	}
	for _,each := range sn {
		fmt.Fprintln(f,each)
	}
}

func skip_game(machine *MachineXML, mra_cfg Mame2MRA, args Args) bool {
	if args.MainOnly && machine.Cloneof!="" && !slices.Contains( mra_cfg.Parse.Main_setnames, machine.Name ){
		if args.Verbose {
			fmt.Println("Skipping ", machine.Description, "for it is not the main version of the game")
		}
		return true
	}
	if mra_cfg.Parse.Skip.Bootlegs &&
		strings.Index(
			strings.ToLower(machine.Description), "bootleg") != -1 {
		if args.Verbose {
			fmt.Println("Skipping ", machine.Description, "for it's a bootleg")
		}
		return true
	}
	for _, d := range mra_cfg.Parse.Skip.Descriptions {
		if strings.Index(machine.Description, d) != -1 {
			if args.Verbose {
				fmt.Println("Skipping ", machine.Description, "for its description")
			}
			return true
		}
	}
	for _, each := range mra_cfg.Parse.Skip.Setnames {
		if each == machine.Name {
			if args.Verbose {
				fmt.Println("Skipping ", machine.Description, "for matching setname")
			}
			return true
		}
	}
	if m:=mra_cfg.Parse.Skip.Match(machine);m>1 {
		if args.Verbose {
			fmt.Printf("Skipping %s for level %d matching\n", machine.Description, m)
		}
		return true
	}
	// Parse Must-be conditions
	// Check must-be machine names
	machine_ok := len(mra_cfg.Parse.Mustbe.Machines) == 0
	for _, each := range mra_cfg.Parse.Mustbe.Machines {
		if is_family(each, machine) {
			if args.Verbose {
				fmt.Println("Parsing ", machine.Description, "for matching machine name")
			}
			machine_ok = true
			break
		}
	}
	return !machine_ok
}

func rm_spsp(a string) string {
	re := regexp.MustCompile(" +")
	return re.ReplaceAllString(a, " ") // Remove duplicated spaces
}

////////////////////////////////////////////////////////////////////////
func fix_filename(filename string) string {
	x := strings.ReplaceAll(filename, "World?", "World")
	x = rm_spsp(x)
	return strings.ReplaceAll(x, "?", "x")
}

func delete_old_mra(args Args, path string) {
	mradata, e := os.ReadFile(path)
	if e != nil {
		fmt.Println("Cannot read ", path)
		os.Exit(1)
	}
	var testmra MRA
	e = xml.Unmarshal(mradata, &testmra)
	if e != nil {
		fmt.Println("Cannot Unmarshal ", path, "\n\t", e)
		os.Exit(1)
	}
	if strings.ToUpper(testmra.Rbf) == args.macros["CORENAME"] {
		if e = os.Remove(path); e != nil {
			fmt.Println("Cannot delete ", path)
			os.Exit(1)
		}
		if args.Verbose {
			fmt.Println("Deleted ", path)
		}
	}
}

func is_main( machine *MachineXML, mra_cfg Mame2MRA ) bool {
	if machine.Cloneof=="" {
		return true
	}
	for _,each := range mra_cfg.Parse.Main_setnames {
		if each == machine.Name {
			return true
		}
	}
	return false
}

func dump_mra(args Args, machine *MachineXML, mra_cfg Mame2MRA, mra_xml *XMLNode, parent_names map[string]string) bool {
	fname := args.outdir
	game_name := strings.ReplaceAll(mra_xml.GetNode("name").text, ":", "")
	game_name = strings.ReplaceAll(game_name, "/", "-")
	// Create the output directory
	if args.outdir != "." && args.outdir != "" {
		if args.Verbose {
			fmt.Println("Creating folder ", args.outdir)
		}
		err := os.MkdirAll(args.outdir, 0777)
		if err != nil && !os.IsExist(err) {
			log.Fatal(err, args.outdir)
		}
	}
	// Redirect clones to their own folder
	main_mra := is_main(machine,mra_cfg)
	if machine.Cloneof!="" && !main_mra {
		pure_name := parent_names[machine.Cloneof]
		pure_name = strings.ReplaceAll(pure_name, ":", "")
		if k := strings.Index(pure_name, "("); k != -1 {
			pure_name = pure_name[0:k]
		}
		if k := strings.Index(pure_name, " - "); k != -1 {
			pure_name = pure_name[0:k]
		}
		pure_name = strings.ReplaceAll(pure_name, "/", "") // Prevent the creation of folders!
		pure_name = strings.TrimSpace(pure_name)
		pure_name = rm_spsp(pure_name)
		fname = filepath.Join(args.altdir, "_"+pure_name)

		err := os.MkdirAll(fname, 0775)
		if err != nil && !os.IsExist(err) {
			log.Fatal(err, fname)
		}
	}
	fname += "/" + fix_filename(game_name) + ".mra"
	// fmt.Println("Output to ", fname)
	var b strings.Builder
	b.WriteString(mra_disclaimer(machine, args.Year))
	b.WriteString(mra_xml.Dump())
	b.WriteString("\n")
	os.WriteFile(fname, []byte(b.String()), 0666)
	return main_mra
}

func mra_disclaimer(machine *MachineXML, year string) string {
	var disc strings.Builder
	disc.WriteString("<!--          FPGA arcade hardware by Jotego\n")
	disc.WriteString(`
              This core is available for hardware compatible with MiST and MiSTer
              Other FPGA systems may be supported by the time you read this.
              This work is not mantained by the MiSTer project. Please contact the
              core author for issues and updates.

              (c) Jose Tejada, `)
	if year == "" {
		disc.WriteString(fmt.Sprintf("%d", time.Now().Year()))
	} else {
		disc.WriteString(year)
	}
	disc.WriteString(
		`. Please support this research
              Patreon: https://patreon.com/jotego

              The author does not endorse or participate in illegal distribution
              of copyrighted material. This work can be used with compatible
              software. This software can be homebrew projects or legally
              obtained memory dumps of compatible games.

              This file license is GNU GPLv2.
              You can read the whole license file in
              https://opensource.org/licenses/gpl-2.0.php

-->

`)
	return disc.String()
}

func guess_world_region(name string) string {
	p0 := strings.Index(name, "(")
	if p0 < 0 {
		return "World"
	}
	name = name[p0+1:]
	p1 := strings.Index(name, ")")
	if p1 < 0 {
		return "World"
	}
	name = strings.ToLower(name[:p1])
	if strings.Index(name, "world") > 0 {
		return "World"
	}
	if strings.Index(name, "japan") > 0 {
		return "Japan"
	}
	if strings.Index(name, "euro") > 0 {
		return "Europe"
	}
	if strings.Index(name, "asia") > 0 {
		return "Asia"
	}
	if strings.Index(name, "korea") > 0 {
		return "Korea"
	}
	if strings.Index(name, "taiwan") > 0 {
		return "Taiwan"
	}
	if strings.Index(name, "hispanic") > 0 {
		return "Hispanic"
	}
	if strings.Index(name, "brazil") > 0 {
		return "Brazil"
	}
	return "World"
}

func set_rbfname(root *XMLNode, machine *MachineXML, cfg Mame2MRA, args Args) *XMLNode {
// 	name := cfg.Rbf.Name
// check_devs:
// 	for _, cfg_dev := range cfg.Rbf.Dev {
// 		for _, mac_dev := range machine.Devices {
// 			if cfg_dev.Dev == mac_dev.Name {
// 				name = cfg_dev.Rbf
// 				break check_devs
// 			}
// 		}
// 	}
// 	// Machine definitions override DEV definitions
// 	for _, each := range cfg.Rbf.Machines {
// 		if each.Machine == "" {
// 			continue
// 		}
// 		if machine.Cloneof == each.Machine || machine.Name == each.Machine {
// 			name = each.Rbf
// 			break
// 		}
// 	}
// 	// setname definitions have the highest priority
// 	for _, each := range cfg.Rbf.Machines {
// 		if each.Setname == "" {
// 			continue
// 		}
// 		if machine.Name == each.Setname {
// 			name = each.Rbf
// 			break
// 		}
// 	}
// 	if name == "" {
// 		fmt.Printf("\tWarning: no RBF name defined\n")
// 	}
	return root.AddNode("rbf", cfg.rbf)
}

func mra_name(machine *MachineXML, cfg Mame2MRA) string {
	for _, ren := range cfg.Parse.Rename {
		if ren.Setname == machine.Name {
			return ren.Name
		}
	}
	return machine.Description
}

// Do not pass the macros to make_mra, but instead modifiy the configuration
// based on the macros in parse_toml
func make_mra(machine *MachineXML, cfg Mame2MRA, args Args) (*XMLNode, string, int) {
	root := XMLNode{name: "misterromdescription"}
	n := root.AddNode("about").AddAttr("author", "jotego")
	n.AddAttr("webpage", "https://patreon.com/jotego")
	n.AddAttr("source", "https://github.com/jotego")
	n.AddAttr("twitter", "@topapate")
	root.AddNode("name", mra_name(machine, cfg)) // machine.Description)
	root.AddNode("setname", machine.Name)
	corename := set_rbfname(&root, machine, cfg, args).text[2:] // corename = RBF, skipping the JT part
	root.AddNode("mameversion", Mame_version())
	root.AddNode("year", machine.Year)
	root.AddNode("manufacturer", machine.Manufacturer)
	root.AddNode("players", strconv.Itoa(machine.Input.Players))
	if len(machine.Input.Control) > 0 {
		root.AddNode("joystick", machine.Input.Control[0].Ways)
	}
	n = root.AddNode("rotation")
	switch machine.Display.Rotate {
	case 90:
		n.SetText("vertical (cw)")
	case 270:
		n.SetText("vertical (ccw)")
	default:
		n.SetText("horizontal")
	}
	root.AddNode("region", guess_world_region(machine.Description))
	// Custom tags, sort them first
	info := append(cfg.Global.Info, args.Info...)
	sort.Slice(info, func(p, q int) bool {
		return info[p].Tag[0] < info[q].Tag[0]
	})
	for _, t := range info {
		root.AddNode(t.Tag, t.Value)
	}
	// MRA author
	if len(cfg.Global.Mraauthor) > 0 {
		authors := ""
		for k, a := range cfg.Global.Mraauthor {
			if k > 0 {
				authors += ","
			}
			authors += a
		}
		root.AddNode("mraauthor", authors)
	}
	// ROM load
	make_ROM(&root, machine, cfg, args)
	// Beta
	if betas.All.IsBetaFor(corename,"mister") {
		n := root.AddNode("rom").AddAttr("index", "17")
		// MiSTer makes a mess of md5 calculations, so I am not using that
		n.AddAttr("zip", "jtbeta.zip").AddAttr("md5", "None").AddAttr("asm_md5", betas.Md5sum)
		m := n.AddNode("part").AddAttr("name", "beta.bin")
		m.AddAttr("crc",betas.Crcsum)
	}
	if !cfg.Cheat.Disable {
		skip := false
		filename := ""
		family_match := false
		for _, each := range cfg.Cheat.Files {
			if each.Machine == "" && each.Setname == "" && !family_match {
				filename = each.AsmFile
				skip = each.Skip
			}
			if each.Match(machine)>0 {
				filename = each.AsmFile
				skip = each.Skip
				family_match = true
			}
			if each.Setname == machine.Name {
				filename = each.AsmFile
				skip = each.Skip
				break
			}
		}
		if filename == "" {
			filename = args.Def_cfg.Core + ".s"
		}
		asmhex := picoasm(filename, cfg, args) // the filename is ignored for betas
		if asmhex != nil && len(asmhex) > 0 && !skip {
			root.AddNode("Machine code for the Picoblaze CPU").comment = true
			n := root.AddNode("rom").AddAttr("index", "16")
			if args.JTbin {
				n.AddNode("part").SetText(hexdump(asmhex, 32)).indent_txt = true
			} else {
				re := regexp.MustCompile("\\..*$")
				basename := filepath.Base(re.ReplaceAllString(filename, ""))
				n.AddAttr("zip", basename+"_cheat.zip").AddAttr("md5", "None")
				n.AddNode("part").AddAttr("name", basename+".bin")
			}
			if !args.SkipPocket {
				pocket_pico( asmhex )
			}
		}
	}
	// NVRAM
	if cfg.ROM.Nvram.length != 0 {
		add_nvram := len(cfg.ROM.Nvram.Machines) == 0
		if !add_nvram {
			for _, each := range cfg.ROM.Nvram.Machines {
				if machine.Name == each {
					add_nvram = true
					break
				}
			}
		}
		if add_nvram {
			var raw *RawData
			for k, each := range cfg.ROM.Nvram.Defaults {
				if each.Machine == "" && each.Setname == "" && raw == nil {
					raw = &cfg.ROM.Nvram.Defaults[k]
				}
				if each.Match(machine)>0 {
					raw = &cfg.ROM.Nvram.Defaults[k]
				}
				if each.Setname == machine.Name {
					raw = &cfg.ROM.Nvram.Defaults[k]
					break
				}
			}
			if raw != nil {
				rawbytes := rawdata2bytes(raw.Data)
				root.AddNode("rom").AddAttr("index", "2").SetText("\n" + hexdump(rawbytes, 16))
			}
			n := root.AddNode("nvram").AddAttr("index", "2")
			n.AddIntAttr("size", cfg.ROM.Nvram.length)
		}
	}
	// coreMOD
	coremod := make_coreMOD(&root, machine, cfg)
	// DIP switches
	def_dipsw := make_switches(&root, machine, cfg, args)
	// Buttons
	make_buttons(&root, machine, cfg, args)
	return &root, def_dipsw, coremod
}

func hexdump(data []byte, cols int) string {
	var bld strings.Builder
	l := len(data)
	bld.Grow(l << 2)
	for k := 0; k < l; k++ {
		fmtstr := "%02X "
		if (k % cols) == (cols - 1) {
			fmtstr = "%02X\n"
		}
		bld.WriteString(fmt.Sprintf(fmtstr, data[k]))
	}
	return bld.String()
}

func make_buttons(root *XMLNode, machine *MachineXML, cfg Mame2MRA, args Args) {
	button_def := "button 1,button 2"
	button_set := false
	for _, b := range cfg.Buttons.Names {
		m := b.Match(machine)
		if (m==1 && !button_set) || m==2 {
			button_def = b.Names
			if args.Verbose {
				fmt.Printf("Buttons set to %s for %s\n", b.Names, machine.Name)
			}
			button_set = true
		}
		if m==3 {
			//fmt.Printf("Explicit assignment for %s to %s\n", b.Setname, b.Names)
			button_def = b.Names
			break
		}
	}
	// an explicit command line argument will override the values in TOML
	if args.Buttons != "" {
		button_def = args.Buttons
	}
	// Generic default value
	if button_def == "" {
		button_def = "Shot,Jump"
	}
	n := root.AddNode("buttons")
	buttons := strings.Split(button_def, ",")
	buttons_str := ""
	count := 0
	for k := 0; k < len(buttons) && k < cfg.Buttons.Core; k++ {
		buttons_str += buttons[k] + ","
		if buttons[k] != "-" {
			count++
			if count > 6 {
				fmt.Println("Warning: cannot support more than 6 buttons")
				break
			}
		}
	}
	pad := "A,B,X,Y,L,R,"
	for k := len(buttons); k < 6 && k < cfg.Buttons.Core; k++ {
		buttons_str += "-,"
	}
	pad = pad[0 : len(buttons)*2]
	buttons_str += "Start,Coin,Core credits"
	n.AddAttr("names", buttons_str)
	n.AddAttr("default", pad+"Start,Select,-")
	n.AddIntAttr("count", count)
}

func make_coreMOD(root *XMLNode, machine *MachineXML, cfg Mame2MRA) int {
	coremod := 0
	if machine.Display.Rotate!=0 && machine.Display.Rotate!=180 {
		root.AddNode("Vertical game").comment = true
		coremod |= 1
		if machine.Display.Rotate != 90 {
			coremod |= 4
		}
	}
	for _, each := range cfg.Buttons.Dial {
		if each.Match(machine)>0 {
			if each.Raw {
				coremod |= 1<<3
			}
			if each.Reverse {
				coremod |= 1<<4
			}
		}
	}
	n := root.AddNode("rom").AddAttr("index", "1")
	n = n.AddNode("part")
	n.SetText(fmt.Sprintf("%02X", coremod))
	return coremod
}

func make_devROM(root *XMLNode, machine *MachineXML, cfg Mame2MRA, pos *int) {
	for _, dev := range machine.Devices {
		if strings.Contains(dev.Name, "fd1089") {
			reg_cfg := find_region_cfg(machine, "fd1089", cfg, true)
			if delta := fill_upto(pos, reg_cfg.start, root); delta < 0 {
				fmt.Printf(
					"\tstart offset overcome by 0x%X while adding FD1089 LUT\n", -delta)
			}
			root.AddNode(fmt.Sprintf(
				"FD1089 base table starts at 0x%X", *pos)).comment = true
			root.AddNode("part").SetText(hexdump(fd1089_bin[:], 16)).indent_txt = true
			*pos += len(fd1089_bin)
		}
	}
}

// if the region is marked for splitting returns the
// offset at which it must occur. Otherwise, zero
// only one split per region will be applied
func is_split(reg string, machine *MachineXML, cfg Mame2MRA) (offset, min_len int) {
	offset = 0
	min_len = 0
	for _, split := range cfg.ROM.Splits {
		if (split.Region != "" && split.Region != reg) ||
			split.Match(machine)==0  {
			continue
		}
		offset = split.Offset
		min_len = split.Min_len
	}
	return offset, min_len
}

func sdram_bank_comment(root *XMLNode, pos int, macros map[string]string) {
	for k, v := range macros { // []string{"JTFRAME_BA1_START","JTFRAME_BA2_START","JTFRAME_BA3_START"} {
		start, _ := strconv.ParseInt(v, 0, 32)
		if start == 0 {
			continue
		}
		// add the comment only once
		if int(start) == pos && root.FindMatch(func( n*XMLNode) bool { return k == n.name })==nil {
			root.AddNode(k).comment = true
		}
	}
}

type flag_info struct {
	pargs *Args
}

func (p *flag_info) String() string {
	s := ""
	if p.pargs != nil {
		for _, i := range p.pargs.Info {
			if len(s) > 0 {
				s += ";"
			}
			s = s + i.Tag + "=" + i.Value
		}
	}
	return s
}

func (p *flag_info) Set(a string) error {
	s := strings.Split(a, "=")
	var i Info
	i.Tag = s[0]
	if len(s) > 1 {
		i.Value = s[1]
	}
	p.pargs.Info = append(p.pargs.Info, i)
	return nil
}

func parse_toml(args *Args) (mra_cfg Mame2MRA) {
	macros := def.Make_macros(args.Def_cfg)
	// fmt.Println(macros)
	// Replaces words starting with $ with the corresponding macro
	// and translates the hexadecimal 0x to 'h where needed
	// This functionality is tagged for deletion in favour of
	// using macro names as strings in the TOML, so the TOML
	// syntax does not get broken
	str := def.Replace_Macros(args.Toml_path, macros)
	str = Replace_Hex(str)
	if args.Verbose {
		fmt.Println("TOML file after replacing the macros:")
		fmt.Println(str)
	}

	json_enc := toml.New(bytes.NewBufferString(str))
	dec := json.NewDecoder(json_enc)

	err := dec.Decode(&mra_cfg)
	if err != nil {
		fmt.Println("jtframe mra: problem while parsing TOML file after JSON transformation:\n\t", err)
		fmt.Println(json_enc)
		os.Exit(1)
	}
	mra_cfg.Dipsw.base, _ = strconv.Atoi(macros["JTFRAME_DIPBASE"])
	// Set the number of buttons to the definition in the macros.def
	if mra_cfg.Buttons.Core == 0 {
		mra_cfg.Buttons.Core, _ = strconv.Atoi(macros["JTFRAME_BUTTONS"])
	}
	if mra_cfg.Header.Len > 0 {
		fmt.Println(`The use of header.len in the TOML file is deprecated.
Set JTFRAME_HEADER=length in macros.def instead`)
	}
	aux, _ := strconv.ParseInt(macros["JTFRAME_HEADER"], 0, 32)
	mra_cfg.Header.Len = int(aux)
	if len(mra_cfg.Dipsw.Delete) == 0 {
		mra_cfg.Dipsw.Delete = []DIPswDelete{
			{ Names: []string{"Unused", "Unknown"} },
		}
	}
	// Add the NVRAM section if it was in the .def file
	if macros["JTFRAME_IOCTL_RD"] != "" {
		aux, err := strconv.ParseInt(macros["JTFRAME_IOCTL_RD"], 0, 32)
		mra_cfg.ROM.Nvram.length = int(aux)
		if err != nil {
			fmt.Println("JTFRAME_IOCTL_RD was ill defined")
			fmt.Println(err)
		}
	}
	// For each ROM region, set the no_offset flag if a
	// sorting option was selected
	// And translate the Start macro to the private start integer value
	for k := 0; k < len(mra_cfg.ROM.Regions); k++ {
		this := &mra_cfg.ROM.Regions[k]
		if this.Start != "" {
			start_str, good1 := macros[this.Start]
			if !good1 {
				fmt.Printf("ERROR: ROM region %s uses undefined macro %s in core %s\n", this.Name, this.Start, args.Def_cfg.Core)
				os.Exit(1)
			}
			aux, err := strconv.ParseInt(start_str, 0, 64)
			if err != nil {
				fmt.Println("ERROR: Macro %s is used as a ROM start, but its value (%s) is not a number\n",
					this.Start, start_str)
				os.Exit(1)
			}
			this.start = int(aux)
			if args.Verbose {
				fmt.Printf("Start in .ROM set to %X for region %s",this.start, this.Name)
				if this.Rename!="" { fmt.Printf(" (%s)",this.Rename)}
				fmt.Println()
			}
		}
		if  this.Sort_even ||
			this.Singleton || len(this.Ext_sort) > 0 ||
			len(this.Name_sort) > 0 || len(this.Sequence) > 0 {
			this.No_offset = true
		}
	}
	args.macros = macros
	return mra_cfg
}

func Replace_Hex(orig string) string {
	scanner := bufio.NewScanner(strings.NewReader(orig))
	var builder strings.Builder
	re := regexp.MustCompile(`0x[0-9a-fA-F]*`)
	for scanner.Scan() {
		t := scanner.Text()
		matches := re.FindAll([]byte(t), -1)
		for _, match := range matches {
			val, _ := strconv.ParseInt(string(match[2:]), 16, 0)
			conv := fmt.Sprintf("%d", val)
			t = strings.Replace(t, string(match), conv, -1)
		}
		builder.WriteString(t + "\n")
	}
	return builder.String()
}

////////////////// Devices
var fd1089_bin = [256]byte{
	0x00, 0x1c, 0x76, 0x6a, 0x5e, 0x42, 0x24, 0x38, 0x4b, 0x67, 0xad, 0x81,
	0xe9, 0xc5, 0x03, 0x2f, 0x45, 0x69, 0xaf, 0x83, 0xe7, 0xcb, 0x01, 0x2d,
	0x02, 0x1e, 0x78, 0x64, 0x5c, 0x40, 0x2a, 0x36, 0x32, 0x2e, 0x44, 0x58,
	0xe4, 0xf8, 0x9e, 0x82, 0x29, 0x05, 0xcf, 0xe3, 0x93, 0xbf, 0x79, 0x55,
	0x3f, 0x13, 0xd5, 0xf9, 0x85, 0xa9, 0x63, 0x4f, 0xb8, 0xa4, 0xc2, 0xde,
	0x6e, 0x72, 0x18, 0x04, 0x0c, 0x10, 0x7a, 0x66, 0xfc, 0xe0, 0x86, 0x9a,
	0x47, 0x6b, 0xa1, 0x8d, 0xbb, 0x97, 0x51, 0x7d, 0x17, 0x3b, 0xfd, 0xd1,
	0xeb, 0xc7, 0x0d, 0x21, 0xa0, 0xbc, 0xda, 0xc6, 0x50, 0x4c, 0x26, 0x3a,
	0x3e, 0x22, 0x48, 0x54, 0x46, 0x5a, 0x3c, 0x20, 0x25, 0x09, 0xc3, 0xef,
	0xc1, 0xed, 0x2b, 0x07, 0x6d, 0x41, 0x87, 0xab, 0x89, 0xa5, 0x6f, 0x43,
	0x1a, 0x06, 0x60, 0x7c, 0x62, 0x7e, 0x14, 0x08, 0x0a, 0x16, 0x70, 0x6c,
	0xdc, 0xc0, 0xaa, 0xb6, 0x4d, 0x61, 0xa7, 0x8b, 0xf7, 0xdb, 0x11, 0x3d,
	0x5b, 0x77, 0xbd, 0x91, 0xe1, 0xcd, 0x0b, 0x27, 0x80, 0x9c, 0xf6, 0xea,
	0x56, 0x4a, 0x2c, 0x30, 0xb0, 0xac, 0xca, 0xd6, 0xee, 0xf2, 0x98, 0x84,
	0x37, 0x1b, 0xdd, 0xf1, 0x95, 0xb9, 0x73, 0x5f, 0x39, 0x15, 0xdf, 0xf3,
	0x9b, 0xb7, 0x71, 0x5d, 0xb2, 0xae, 0xc4, 0xd8, 0xec, 0xf0, 0x96, 0x8a,
	0xa8, 0xb4, 0xd2, 0xce, 0xd0, 0xcc, 0xa6, 0xba, 0x1f, 0x33, 0xf5, 0xd9,
	0xfb, 0xd7, 0x1d, 0x31, 0x57, 0x7b, 0xb1, 0x9d, 0xb3, 0x9f, 0x59, 0x75,
	0x8c, 0x90, 0xfa, 0xe6, 0xf4, 0xe8, 0x8e, 0x92, 0x12, 0x0e, 0x68, 0x74,
	0xe2, 0xfe, 0x94, 0x88, 0x65, 0x49, 0x8f, 0xa3, 0x99, 0xb5, 0x7f, 0x53,
	0x35, 0x19, 0xd3, 0xff, 0xc9, 0xe5, 0x23, 0x0f, 0xbe, 0xa2, 0xc8, 0xd4,
	0x4e, 0x52, 0x34, 0x28}

////////////////////////////////////
// Command line arguments

func parse_args(args *Args) {
	cores := os.Getenv("CORES")
	if args.Toml_path == "" && args.Def_cfg.Core != "" {
		if len(cores) == 0 {
			log.Fatal("JTFILES: environment variable CORES is not defined")
		}
		args.Toml_path = filepath.Join(cores, args.Def_cfg.Core, "cfg", "mame2mra.toml")
	}
	if args.Verbose {
		fmt.Println("Parsing ", args.Toml_path)
	}
	release_dir := filepath.Join(os.Getenv("JTROOT"), "release")
	if args.JTbin {
		release_dir = os.Getenv("JTBIN")
		if release_dir == "" {
			log.Fatal("jtframe mra: JTBIN path must be defined")
		}
	}
	args.cheatdir = filepath.Join(release_dir, "games", "mame")
	args.outdir = filepath.Join(release_dir, "mra")
	args.altdir = filepath.Join(args.outdir, "_alternatives")
	args.pocketdir = filepath.Join(release_dir, "pocket", "raw")
	args.firmware_dir = filepath.Join(cores, args.Def_cfg.Core, "firmware")
}
