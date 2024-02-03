/*  This file is part of JT_FRAME.
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
    Date: 23-9-2022 */

package mem

import (
	"bufio"
	"bytes"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"text/template"

	"github.com/jotego/jtframe/files"
	"github.com/jotego/jtframe/def"

	"gopkg.in/yaml.v2"
)

func (this Args) get_path(fname string, prefix bool ) string {
	if prefix {
		fname = "jt"  + this.Core + fname
	}
	if this.Local {
		return fname
	}
	out_path := filepath.Join(os.Getenv("CORES"), this.Core, this.Target )
	os.MkdirAll(out_path, 0777) // derivative cores may not have a permanent hdl folder
	return filepath.Join(out_path, fname)
}

// Template helper functions
func (bus SDRAMBus) Get_aw() int { return bus.Addr_width }
func (bus BRAMBus)  Get_aw() int { return bus.Addr_width }
func (bus SDRAMBus) Get_dw() int { return bus.Data_width }
func (bus BRAMBus)  Get_dw() int { return bus.Data_width }
func (bus SDRAMBus) Get_dname() string { return bus.Name+"_data" }
func (bus BRAMBus)  Get_dname() string {
	if bus.ROM.Offset!="" {
		return bus.Name+"_data"
	} else {
		return bus.Name+"_dout"
	}
}
func (bus SDRAMBus) Is_wr() bool { return bus.Rw }
func (bus BRAMBus)  Is_wr() bool { return bus.Rw || bus.Dual_port.Rw }
func (bus SDRAMBus) Is_nbits(n int) bool { return bus.Data_width==n }
func (bus BRAMBus)  Is_nbits(n int) bool { return bus.Data_width==n }

func addr_range(bus Bus) string {
	return fmt.Sprintf("[%2d:%d]", bus.Get_aw()-1, bus.Get_dw()>>4)
}

func data_range(bus Bus) string {
	return fmt.Sprintf("[%2d:0]", bus.Get_dw()-1)
}

func slot_addr_width(bus SDRAMBus) string {
	if bus.Data_width == 8 {
		return fmt.Sprintf("%2d", bus.Addr_width)
	} else {
		return fmt.Sprintf("%2d", bus.Addr_width-1)
	}
}

func data_name(bus Bus) string { return bus.Get_dname() }
func writeable(bus Bus) bool { return bus.Is_wr() }
func is_nbits(bus Bus, n int) bool { return bus.Is_nbits(n) }

var funcMap = template.FuncMap{
	"addr_range":      addr_range,
	"data_range":      data_range,
	"slot_addr_width": slot_addr_width,
	"data_name":       data_name,
	"writeable":       writeable,
	"is_nbits":        is_nbits,
}

func parse_file(core, filename string, cfg *MemConfig, args Args) bool {
	filename = jtfiles.GetFilename(core, filename, "")
	buf, err := os.ReadFile(filename)
	if err != nil {
		if args.Verbose {
			log.Printf("jtframe mem: no memory file (%s)", filename)
		}
		return false
	}
	if args.Verbose {
		fmt.Println("Read ", filename)
	}
	err_yaml := yaml.Unmarshal(buf, cfg)
	if err_yaml != nil {
		log.Fatalf("jtframe mem: cannot parse file\n\t%s\n\t%v", filename, err_yaml)
	}
	if args.Verbose {
		fmt.Println("jtframe mem: memory configuration:")
		fmt.Println(*cfg)
	}
	include_copy := make([]Include, len(cfg.Include))
	copy(include_copy, cfg.Include)
	cfg.Include = nil
	for _, each := range include_copy {
		fname := each.File
		if fname == "" {
			fname = "mem"
		}
		parse_file(each.Game, fname, cfg, args)
		fmt.Println(each.Game, fname)
	}
	// Reload the YAML to overwrite values that the included files may have set
	err_yaml = yaml.Unmarshal(buf, cfg)
	if err_yaml != nil {
		log.Fatalf("jtframe mem: cannot parse file\n\t%s\n\t%v for a second time", filename, err_yaml)
	}
	// Update the MemType strings
	for k, bank := range cfg.SDRAM.Banks {
		ram_cnt := 0
		for j, each := range bank.Buses {
			if each.Rw {
				ram_cnt++
			}
			if each.Data_width==0 { cfg.SDRAM.Banks[k].Buses[j].Data_width=8 }
		}
		if ram_cnt > 0 {
			cfg.SDRAM.Banks[k].MemType = fmt.Sprintf("ram%d", ram_cnt)
		} else {
			cfg.SDRAM.Banks[k].MemType = "rom"
		}
	}
	// Make data_width 8 if it is missing
	for k, each := range cfg.BRAM {
		if each.Data_width==0 { cfg.BRAM[k].Data_width=8 }
	}
	// check that gfx_sort expressions are supported
	for _, bank := range cfg.SDRAM.Banks {
		for _, each := range bank.Buses {
			switch each.Gfx {
				case "", "hhvvv", "hhvvvv", "hhvvvx", "hhvvvvx", "hhvvvxx", "hhvvvvxx": break
				default: {
					fmt.Printf("Unsupported gfx_sort %d\n", each.Gfx)
					return false
				}
			}
		}
	}
	return true
}

func make_sdram( finder path_finder, cfg *MemConfig) {
	tpath := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc", "game_sdram.v")
	t := template.Must(template.New("game_sdram.v").Funcs(funcMap).ParseFiles(tpath))
	var buffer bytes.Buffer
	t.Execute(&buffer, cfg)
	// Dump the file
	outpath := finder.get_path("_game_sdram.v", true)
	ioutil.WriteFile(outpath, buffer.Bytes(), 0644)
}

func add_game_ports(args Args, cfg *MemConfig) {
	make_inc := false
	found := false

	tpath := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc", "ports.v")
	t := template.Must(template.New("ports.v").Funcs(funcMap).ParseFiles(tpath))
	var buffer bytes.Buffer
	t.Execute(&buffer, cfg)
	outpath := "jt" + args.Core + "_game.v"
	outpath = filepath.Join(os.Getenv("CORES"), args.Core, "hdl", outpath)
	f, err := os.Open(outpath)
	if err != nil {
		log.Println("jtframe mem: cannot update file ", outpath)
		make_inc = true
	} else {
		make_inc = false
		scanner := bufio.NewScanner(f)
		var bout bytes.Buffer
		ignore := false
		for scanner.Scan() {
			line := scanner.Text()
			if ignore && strings.Index(line, ");") >= 0 {
				ignore = false
			}
			if !ignore {
				bout.WriteString(line)
				bout.WriteByte(byte(0xA))
			}
			if !found && strings.Index(line, "/* jtframe mem_ports */") >= 0 { // simple comparison for now, change to regex in future
				found = true
				bout.Write(buffer.Bytes())
				ignore = true // will not copy lines until ); is found
			}
			if strings.Index(line, "`include \"mem_ports.inc\"") >= 0 || // manually added
				strings.Index(line, "`include \"jtframe_game_ports.inc\"") >= 0 /* in main JTFRAME include */ {
				make_inc = true
				break
			}
			if strings.Index(line, "`include \"jtframe_game_ports.inc\"") >= 0 {
				make_inc = true
				break
			}
		}
		f.Close()
		if found {
			ioutil.WriteFile(outpath, bout.Bytes(), 0644)
		}
	}
	if make_inc || args.Make_inc {
		//outpath = filepath.Join(os.Getenv("CORES"), args.Core, "hdl/mem_ports.inc")
		outpath = args.get_path("mem_ports.inc",false)
		ioutil.WriteFile(outpath, buffer.Bytes(), 0644)
	}
	if !found && !make_inc {
		log.Println("jtframe mem: the game file was not updated. jtframe_mem_ports line not found. Declare /* jtframe_mem_ports */ right before the end of the port list in the game module or include mem_ports.inc in the port list.")
	}
}

func get_macros( core, target string ) (map[string]string) {
	var def_cfg def.Config
	def_cfg.Target = target
	def_cfg.Core = core
	// def_cfg.Add = cfgstr.Append_args(def_cfg.Add, strings.Split(args.AddMacro, ","))
	return def.Make_macros(def_cfg)
}

func check_banks( macros map[string]string, cfg *MemConfig ) {
	// Check that the arguments make sense
	if len(cfg.SDRAM.Banks) > 4 || len(cfg.SDRAM.Banks) == 0 {
		log.Fatalf("jtframe mem: the number of banks must be between 1 and 4 but %d were found.", len(cfg.SDRAM.Banks))
	}
	bad := false
	check_we := func( ba int, macro_name string) {
		for _,each := range cfg.SDRAM.Banks[ba].Buses {
			if each.Rw {
				_, found := macros[macro_name]
				if !found {
					fmt.Printf("Missing %s. Define it if using bank %d for R/W access\n", macro_name, ba)
					bad=true
				}
			}
		}
	}
	region_lut := false
	for _, each := range cfg.SDRAM.Banks {
		if each.Region != "" {
			region_lut = true
			break
		}
	}
	if !region_lut {
		if len(cfg.SDRAM.Banks)>1  {
			if macros["JTFRAME_BA1_START"]=="" {
				fmt.Println("Missing JTFRAME_BA1_START")
				bad = true
			}
			check_we( 1, "JTFRAME_BA1_WEN" )
		}
		if len(cfg.SDRAM.Banks)>2 {
			if macros["JTFRAME_BA2_START"]=="" {
				fmt.Println("Missing JTFRAME_BA2_START")
				bad = true
			}
			check_we( 2, "JTFRAME_BA2_WEN" )
		}
		if len(cfg.SDRAM.Banks)>3 {
			if macros["JTFRAME_BA3_START"]=="" {
				fmt.Println("Missing JTFRAME_BA3_START")
				bad = true
			}
			check_we( 3, "JTFRAME_BA3_WEN" )
		}
	} else {
		if macros["JTFRAME_HEADER"]=="" {
			fmt.Println(`Missing JTFRAME_HEADER but the SDRAM banks are pointing to a region.
Set JTFRAME_HEADER in macros.def and define a [header.offset] in mame2mra.toml
`)
		}
	}
	if bad {
		os.Exit(1)
	}

	// Check that the required files are available
	for k, each := range cfg.SDRAM.Banks {
		total_slots := len(each.Buses)
		if total_slots == 0 {
			continue
		}
		total_ram := 0
		for _, bus := range each.Buses {
			if bus.Rw {
				total_ram++
			}
		}
		filename := "jtframe_"
		if total_ram > 0 {
			filename += fmt.Sprintf("ram%d_", total_ram)
		} else {
			filename += "rom_"
		}
		filename += fmt.Sprintf("%dslot", total_slots)
		if total_slots > 1 {
			filename += "s"
		}
		filename += ".v"
		// Check that the file exists
		fullname := filepath.Join(os.Getenv("JTFRAME"), "hdl", "sdram", filename)
		f, err := os.Open(fullname)
		if err != nil {
			log.Fatalf("jtframe mem: mem.yaml requires the file %s. But this module doesn't exist.\nChecked in %s",
				filename, fullname)
		}
		if total_ram > 4 {
			log.Printf("jtframe mem: bank %d uses %d slots. For better performance balances the load so no bank gets more than 4 slots.", k, total_slots)
		}
		f.Close()
	}
	for k := 0; k < 4; k++ {
		// Mark each bank as used or unused
		if k < len(cfg.SDRAM.Banks) {
			cfg.Unused[k] = len(cfg.SDRAM.Banks[k].Buses) == 0
		} else {
			cfg.Unused[k] = true
		}
	}
}

func fill_implicit_ports( macros map[string]string, cfg *MemConfig, Verbose bool ) {
	implicit := make( map[string]bool )
	// get implicit names
	for _, bank := range cfg.SDRAM.Banks {
		for _, each := range bank.Buses {
			if each.Addr=="" { implicit[each.Name+"_addr"]=true }
			if each.Cs=="" { implicit[each.Name+"_cs"]=true }
			if each.Din=="" { implicit[each.Name+"_din"]=true }
			implicit[each.Name+"_data"]=true
		}
	}
	// Add some other ports
	for _, each := range []string{ "LVBL", "LHBL", "HS", "VS" } {
		implicit[each] = true
	}
	// fmt.Println("Implicit ports:\n",implicit)
	// get explicit names in SDRAM/BRAM buses and added to the port list
	all := make( map[string]Port )
	add := func( p Port ) {
		if p.Name=="" { return }
		if p.Name[0]>='0' && p.Name[0]<='9' { return } // not a name
		if p.Name[0]=='{' { return } // ignore compound buses
		// remove the brackets
		k := strings.Index( p.Name, "[" )
		if k>=0 { p.Name = p.Name[0:k] }
		if t,_:=implicit[p.Name]; t { return }
		old, fnd := all[p.Name]
		if Verbose {
			fmt.Printf("Adding port: %s\n", p.Name)
		}
		if fnd {
			if old.Input || p.Input { // overwrite if the port should be an input
				// required for JTKARNOV's objram_dout signal, which comes from one
				// BRAM and is used on another and is also an input to the game
				p.Input = true
				all[p.Name] = p
			}
		} else {
			all[p.Name] = p
		}
	}
	for _, each := range cfg.Ports {
		all[each.Name] = each
	}
	for _, bank := range cfg.SDRAM.Banks {
		for _, each := range bank.Buses {
			if each.Cs != ""  { add( Port{ Name: each.Cs, } ) }
			if each.Dsn != "" { add( Port{ Name: each.Dsn, MSB: 1, } ) }
			if each.Din != "" { add( Port{ Name: each.Din, MSB: each.Data_width-1, } ) }
		}
	}
	for k, _ := range cfg.BRAM {
		each := &cfg.BRAM[k]
		bram_rom := !each.Rw && !each.Dual_port.Rw // BRAM used as ROM
		if each.Addr == "" { each.Addr = each.Name + "_addr" }
		if each.Din  == "" && each.Rw { each.Din = each.Name + "_din"  }
		if each.We   == "" && each.Rw { each.We  = each.Name + "_we"   }
		if each.Dout == "" {
			if bram_rom {
				each.Dout = each.Name + "_data"
			} else {
				each.Dout = each.Name + "_dout"
			}
		}
		add( Port{
			Name: each.Addr,
			MSB:  each.Addr_width-1,
			LSB:  each.Data_width>>4, // 8->0, 16->1
		})
		add( Port{
			Name: each.Din,
			MSB: each.Data_width-1,
		})
		add( Port{
			Name: each.Dout,
			Input: true,
			MSB: each.Data_width-1,
		})
		if each.Rw {
			name := each.Name + "_we"
			if each.We!="" { name = each.We }
			add( Port{
				Name: name,
				MSB: each.Data_width>>4,
				LSB: 0,
			})
		}
		if each.Dual_port.Name!="" {
			if each.Dual_port.Addr == "" { each.Dual_port.Addr = each.Dual_port.Name + "_addr" }
			if each.Dual_port.Dout == "" { each.Dual_port.Dout = each.Name+"2"+each.Dual_port.Name+"_data" }
			if each.Dual_port.Din  == "" { each.Dual_port.Din  = each.Dual_port.Name+"_dout" }
			add( Port{
				Name: each.Dual_port.Addr,
				MSB:  each.Addr_width-1,
				LSB:  each.Data_width>>4, // 8->0, 16->1
			})
			if each.Dual_port.Rw {
				add( Port{
					Name: each.Dual_port.Din,
					MSB: each.Data_width-1,
				})
			}
			if each.Dual_port.We != "" {
				add( Port{
					Name: each.Dual_port.We,
					MSB: each.Data_width>>4, // 8->0, 16->1
				})
			}
			add( Port{
				Name: each.Dual_port.Dout,
				MSB: each.Data_width-1,
				Input: true,
			})
			// Fill the rest
			if strings.Index(each.Dual_port.Addr,"[")>=0 {
				each.Dual_port.AddrFull = each.Dual_port.Addr
			} else {
				each.Dual_port.AddrFull = fmt.Sprintf("%s[%d:%d]", each.Dual_port.Addr, each.Addr_width-1, each.Data_width>>4)
			}
		}
	}
	cfg.Ports = make( []Port,0, len(all) )
	// fmt.Println("Final ports\n",all)
	for _, each := range all { cfg.Ports=append(cfg.Ports,each) }
}

func make_ioctl( macros map[string]string, cfg *MemConfig, verbose bool ) int {
	found := false
	dump_size := 0
	total_blocks := 0
	tosave := make([]*BRAMBus, len(cfg.BRAM))
	for k, each := range cfg.BRAM {
		if each.Ioctl.Order>=len(tosave) {
			fmt.Printf("ioctl.order is too big for element %s in mem.yaml\n",each.Name)
			os.Exit(1)
		}
		if each.Ioctl.Save {
			found = true
			tosave[each.Ioctl.Order] = &cfg.BRAM[k]
		}
	}
	for _, each := range tosave {
		if each == nil { continue }
		each.Sim_file=true
		ioinfo := &cfg.Ioctl.Buses[each.Ioctl.Order] // fill data for ioctl_dump module
		ioinfo.Name = each.Name
		ioinfo.AW   = each.Addr_width
		ioinfo.AWl  = each.Data_width>>4
		ioinfo.Amx  = each.Name+"_amux"
		ioinfo.A    = each.Name+"_addr"
		if each.Addr!="" { ioinfo.A = each.Addr }
		ioinfo.DW   = each.Data_width
		ioinfo.Dout = each.Name+"_dout"
		ioinfo.Din  = each.Din
		each.Addr   = each.Name+"_amux"
		// restore
		if ioinfo.DW==8 {
			ioinfo.We = "1'b0"
		} else {
			ioinfo.We = "2'b0"
		}
		if each.Ioctl.Restore {
			if each.Rw {
				ioinfo.We = each.We
				if each.We == "" {
					ioinfo.We = "2'b0"
				}
			}
			each.We  = each.Name+"_wemx"
			if each.Data_width==8 {
				each.We+="[0]"
			}
			each.Din = each.Name+"_dimx"
		}
		// size
		dump_size     += 1<<each.Addr_width
		ioinfo.Size   = 1<<each.Addr_width
		ioinfo.SizekB = ioinfo.Size >> 10
		ioinfo.Blocks = ioinfo.Size >> 8
		ioinfo.SkipBlocks = total_blocks
		total_blocks  += ioinfo.Blocks
	}
	cfg.Ioctl.SkipAll = total_blocks
	if found {
		cfg.Ioctl.Dump = true
		cfg.Ioctl.DinName = "ioctl_aux" // block game module output
	} else {
		cfg.Ioctl.DinName = "ioctl_din"	// let it come from game module
	}
	// fill in blank ones
	for k, _ := range cfg.Ioctl.Buses {
		each := &cfg.Ioctl.Buses[k]
		if each.DW==0 {
			each.DW=8
			each.Dout = "8'd0"
			each.A    = "1'b0"
			each.We   = "1'b0"
		}
	}
	// warn if JTFRAME_IOCTL_RD is below the required one
	ioctl_rd, fnd := macros["JTFRAME_IOCTL_RD"]
	suggest := (ioctl_rd=="" && dump_size!=0) || verbose
	if fnd {
		aux2, _ := strconv.ParseInt(ioctl_rd,0,32)
		aux := int(aux2)
		if aux < dump_size {
			suggest = true
			fmt.Printf("WARNING: JTFRAME_IOCTL_RD in macros.def is %d too short.\n", dump_size-aux)
		}
	}
	if suggest {
		fmt.Printf("Set:\tJTFRAME_IOCTL_RD=%d\n", dump_size)
	}
	return dump_size
}

func make_dump2bin( args Args, cfg *MemConfig ) {
	if len( cfg.Ioctl.Buses )==0 { return }
	tpath := filepath.Join(os.Getenv("JTFRAME"), "src", "jtframe", "mem", "dump2bin.sh")
	t := template.Must(template.New("dump2bin.sh").Funcs(funcMap).ParseFiles(tpath))
	var buffer bytes.Buffer
	t.Execute(&buffer, cfg)
	// Dump the file
	outpath := filepath.Join(os.Getenv("CORES"), args.Core, "ver","game" )
	os.MkdirAll(outpath, 0777) // derivative cores may not have a permanent hdl folder
	outpath = filepath.Join( outpath, "dump2bin.sh" )
	e := ioutil.WriteFile(outpath, buffer.Bytes(), 0755)
	if e!=nil {
		fmt.Println(e)
	} else {
		if args.Verbose {
			fmt.Printf("%s created\n",outpath)
		}
	}
}

func fill_gfx_sort( macros map[string]string, cfg *MemConfig ) {
	// this will not merge correctly hhvvv and hhvvvx used together, that's
	// not supported in jtframe_dwnld at the moment
	appendif := func( ss *[]string, mac string ) {
		if def.Defined(macros,mac) { *ss = append(*ss, "`"+mac) }
	}
	make_gfx := func( match string ) (string, int) {
		ranges :=  make([]string,0)
		b0 := 0
		for k, bank := range cfg.SDRAM.Banks {
			offsets := make([]string,0)
			appendif(&offsets, "JTFRAME_HEADER" )
			appendif(&offsets,fmt.Sprintf("JTFRAME_BA%d_START",k))
			for j, each := range bank.Buses {
				if each.Offset != "" { offsets = append(offsets, fmt.Sprintf("(%s<<1)",each.Offset) )}
				if each.Gfx!=match && each.Gfx!=(match+"x") && each.Gfx!=(match+"xx") { continue }
				// bit 0 should be the one containing the first H bit
				if strings.HasSuffix(each.Gfx,"x")  { b0=1 }
				if strings.HasSuffix(each.Gfx,"xx") { b0=2 }
				new_range := ""
				if len(offsets)>0 {
					addr0 := fmt.Sprintf("(%s)",strings.Join(offsets,"+"))
					new_range = fmt.Sprintf("ioctl_addr>=(%s)", addr0 )
				}
				addr1 := ""
				offsets2 := make([]string,0)
				if j+1<len(bank.Buses) { // is there another entry in the same bank?
					if bank.Buses[j+1].Offset == ""	{
						fmt.Printf("Error: missing offset of bus entry %s (bank %d)\n", bank.Buses[j+1].Name, k)
						fmt.Println("You need to define it as the previous entry has gfx_sort definition")
						os.Exit(1)
					}
					offsets2 = append(offsets,fmt.Sprintf("(%s<<1)",bank.Buses[j+1].Offset))
				} else {
					if def.Defined(macros,fmt.Sprintf("JTFRAME_BA%d_START",k+1)) { // is there another bank
						appendif( &offsets2, "JTFRAME_HEADER" )
						offsets2 = append(offsets2,fmt.Sprintf("`JTFRAME_BA%d_START",k+1))
					} else if def.Defined(macros,"JTFRAME_PROM_START") {
						appendif( &offsets2, "JTFRAME_HEADER" )
						offsets2 = append(offsets2,"JTFRAME_PROM_START")
					}
				}
				if len(offsets2)>0 {
					addr1 = strings.Join(offsets2,"+")
					new_range = fmt.Sprintf("%s && ioctl_addr<(%s)", new_range, addr1 )
				}
				new_range = fmt.Sprintf("(%s) /* %s */", new_range, each.Name )
				ranges = append(ranges, new_range)
			}
		}
		if len(ranges)>0 {
			aux := strings.Join(ranges,"||\n    ")
			aux += ";"
			return aux,b0
		} else {
			return "0;",0
		}
	}
	cfg.Gfx8, cfg.Gfx8b0  = make_gfx("hhvvv")
	cfg.Gfx16,cfg.Gfx16b0 = make_gfx("hhvvvv")
}

func Run(args Args) {
	var cfg MemConfig
	if !parse_file(args.Core, "mem", &cfg, args) {
		// the mem.yaml file does not exist, that's
		// normally ok
		return
	}
	macros := get_macros( args.Core, args.Target )
	check_banks( macros, &cfg )
	fill_implicit_ports( macros, &cfg, args.Verbose )
	make_ioctl( macros, &cfg, args.Verbose )
	fill_gfx_sort( macros, &cfg )
	// Fill the clock configuration
	make_clocks( macros, &cfg )
	// Execute the template
	cfg.Core = args.Core
	make_sdram(args, &cfg)
	add_game_ports(args, &cfg)
	make_dump2bin(args, &cfg )
}
