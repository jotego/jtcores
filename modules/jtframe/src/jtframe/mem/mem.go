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
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/jotego/jtframe/common"
	"github.com/jotego/jtframe/macros"
	"github.com/jotego/jtframe/mra"

	"gopkg.in/yaml.v2" // do not upgrade to v3. See issue #904
	"github.com/Masterminds/sprig/v3"	// more template functions
)

func Run(args Args) (e error) {
	var cfg MemConfig
	Verbose = args.Verbose
	macros.MakeMacros(args.Core,args.Target)
	if args.Nodbg {
		if Verbose { fmt.Println("Defining macro JTFRAME_RELEASE")}
		macros.Set("JTFRAME_RELEASE","")
	}
	if !Parse_file(args.Core, "mem.yaml", &cfg) {
		// the mem.yaml file does not exist, that's
		// normally ok
		return
	}
	if e = bankOffset( &cfg, args.Core ); e!=nil { return e }
	// Checks
	if e = check_banks( &cfg ); e!=nil { return e }
	if e = check_bram ( &cfg ); e!=nil { return e }
	// Data arrangement
	fill_implicit_ports( &cfg )
	make_ioctl( &cfg )
	fill_gfx_sort( &cfg )
	// Fill the clock configuration
	make_clocks( &cfg )
	// Audio configuration
	e = Make_audio( &cfg, args.Core, args.get_path("",false) ); if e!=nil { return e }
	// Execute the template
	cfg.Core = args.Core
	e = make_sdram(args, &cfg);     if e!=nil { return e }
	e = add_game_ports(args, &cfg); if e!=nil { return e }
	e = make_dump2bin(args.Core, &cfg ); if e!=nil { return e }
	return nil
}

func (arg Args) get_path(fname string, prefix bool ) string {
	if prefix {
		fname = "jt"  + arg.Core + fname
	}
	if arg.Local {
		return fname
	}
	out_path := filepath.Join(os.Getenv("CORES"), arg.Core, arg.Target )
	os.MkdirAll(out_path, 0777) // derivative cores may not have a permanent hdl folder
	return filepath.Join(out_path, fname)
}

// Template helper functions: implementation of "Bus" interface (see types.go)
func (bus SDRAMBus) Get_aw() int { return bus.Addr_width }
func (bus BRAMBus)  Get_aw() int { return bus.Addr_width }
func (bus AudioCh)  Get_aw() int { return bus.Data_width }
func (bus SDRAMBus) Get_dw() int { return bus.Data_width }
func (bus BRAMBus)  Get_dw() int { return bus.Data_width }
func (bus AudioCh)  Get_dw() int { return bus.Data_width }
func (bus SDRAMBus) Get_dname() string { return bus.Name+"_data" }
func (bus BRAMBus)  Get_dname() string {
	if bus.ROM.Offset!="" {
		return bus.Name+"_data"
	} else {
		return bus.Name+"_dout"
	}
}
func (bus AudioCh) Get_dname() string { return bus.Name }
func (bus SDRAMBus) Is_wr() bool { return bus.Rw }
func (bus AudioCh)  Is_wr() bool { return false }
func (bus BRAMBus)  Is_wr() bool { return bus.Rw || bus.Dual_port.Rw }
func (bus SDRAMBus) Is_nbits(n int) bool { return bus.Data_width==n }
func (bus BRAMBus)  Is_nbits(n int) bool { return bus.Data_width==n }
func (bus AudioCh)  Is_nbits(n int) bool { return bus.Data_width==n }

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

func Parse_file(core, filename string, cfg *MemConfig) bool {
	read_yaml(core,filename,cfg)
	parse_include_files(core,cfg)
	// Reload the YAML to overwrite values that the included files may have set
	read_yaml(core,filename,cfg)
	delete_optional(cfg)
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
					fmt.Printf("Unsupported gfx_sort %s\n", each.Gfx)
					return false
				}
			}
		}
	}
	return true
}

func parse_include_files(core string, cfg *MemConfig) {
	include_copy := make([]Include, len(cfg.Include))
	copy(include_copy, cfg.Include)
	cfg.Include = nil
	for _, entry := range include_copy {
		if entry.File=="" && entry.Core=="" { continue }
		if entry.File == "" { entry.File = "mem.yaml" }
		if entry.Core == "" { entry.Core=core }
		Parse_file(entry.Core, entry.File, cfg)
	}
}

// used for testing the yaml package
func unmarshal( buffer []byte, storage any ) error {
	return yaml.Unmarshal(buffer,storage)
}

func read_yaml(core, filename string, cfg *MemConfig) (e error) {
	filename = common.ConfigFilePath(core, filename)
	buf, e := os.ReadFile(filename)
	if e != nil {
		if errors.Is(e, os.ErrNotExist) {
			log.Println(e)
			return nil
		}
		return e
	}
	if Verbose {
		fmt.Println("Read ", filename)
	}
	e = unmarshal(buf, cfg)
	if e != nil {
		return fmt.Errorf("jtframe mem: cannot parse file\n\t%s\n\t%w", filename, e)
	}
	if Verbose {
		fmt.Println("jtframe mem: memory configuration:")
		fmt.Println(*cfg)
		fmt.Println()
	}
	return nil
}

func delete_optional( cfg *MemConfig ) {
	delete_optional_bram(cfg)
	delete_optional_sdram(cfg)
	delete_optional_ioctl(cfg.BRAM)
}

func delete_optional_sdram(cfg *MemConfig ) {
	for k,_:=range cfg.SDRAM.Banks {
		total := len(cfg.SDRAM.Banks[k].Buses)
		if total==0 { continue }
		optional := make([]Optional,total)
		for j,_ := range cfg.SDRAM.Banks[k].Buses {
			optional[j]=&cfg.SDRAM.Banks[k].Buses[j]
		}
		enabled := find_enabled(optional)
		cfg.SDRAM.Banks[k].Buses = copy_enabled(cfg.SDRAM.Banks[k].Buses,enabled)
	}
}

func delete_optional_bram(cfg *MemConfig ) {
	total := len(cfg.BRAM)
	if total==0 { return }
	optional := make([]Optional,total)
	for k, _ := range cfg.BRAM {
		optional[k]=&cfg.BRAM[k]
	}
	enabled := find_enabled(optional)
	cfg.BRAM = copy_enabled(cfg.BRAM,enabled)
}

func delete_optional_ioctl(all_bram []BRAMBus) {
	for k, _ := range all_bram {
		if !all_bram[k].Ioctl.Enabled() {
			if Verbose {
				fmt.Printf("Delete IOCTL data for BRAM bus %s\n",all_bram[k].Name)
			}
			all_bram[k].Ioctl=BRAMBus_Ioctl{}
		}
	}
}

func find_enabled(all_items []Optional ) (enabled []int) {
	enabled = make([]int,0,len(all_items))
	for k,item := range all_items {
		if item.Enabled() {
			enabled=append(enabled,k)
		}
	}
	return enabled
}

func copy_enabled[Slice ~[]E, E any](ref Slice, valid []int) (copy Slice) {
	if len(valid)>len(ref) {
		panic(fmt.Errorf("Not enough elements in ref slice"))
	}
	if len(valid)==len(ref) { return ref }
	copy = make(Slice,0,len(valid))
	for _,copy_idx := range valid {
		copy=append(copy,ref[copy_idx])
	}
	return copy
}

func make_sdram( finder path_finder, cfg *MemConfig) (e error){
	tpath := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc")
	game_sdram := filepath.Join(tpath,"game_sdram.v")
	game_audio := filepath.Join(tpath,"game_audio.v")
	t := template.New("game_sdram.v").Funcs(funcMap).Funcs(sprig.FuncMap())
	t.Funcs(audio_template_functions)
	_, e = t.ParseFiles(game_audio,game_sdram)
	if e!=nil { return e }
	var buffer bytes.Buffer
	if e = t.Execute(&buffer, cfg); e!= nil { return e }
	// Dump the file
	outpath := finder.get_path("_game_sdram.v", true)
	ioutil.WriteFile(outpath, buffer.Bytes(), 0644)
	return nil
}

func add_game_ports(args Args, cfg *MemConfig) (e error){
	make_inc := false
	found := false

	tpath := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc", "ports.v")
	t,e := template.New("ports.v").Funcs(funcMap).Funcs(sprig.FuncMap()).ParseFiles(tpath); if e!=nil { return e }
	var buffer bytes.Buffer
	if e = t.Execute(&buffer, cfg); e!=nil { return e }
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
	return nil
}


func make_dump2bin( corename string, cfg *MemConfig ) (e error) {
	if len( cfg.Ioctl.Buses )==0 { return }
	tpath := filepath.Join(os.Getenv("JTFRAME"), "src", "jtframe", "mem", "dump2bin.sh")
	t, e := template.New("dump2bin.sh").Funcs(funcMap).Funcs(sprig.FuncMap()).ParseFiles(tpath); if e!=nil { return e }
	var buffer bytes.Buffer
	if e = t.Execute(&buffer, cfg); e!=nil { return e }
	// Dump the file
	outpath := filepath.Join(os.Getenv("CORES"), corename, "ver","game" )
	os.MkdirAll(outpath, 0777) // derivative cores may not have a permanent hdl folder
	outpath = filepath.Join( outpath, "dump2bin.sh" )
	e = ioutil.WriteFile(outpath, buffer.Bytes(), 0755); if e!=nil { return e }
	if Verbose {
		fmt.Printf("%s created\n",outpath)
	}
	return nil
}

func bankOffset( cfg *MemConfig, corename string) (e error) {
	mra_cfg, e := mra.ParseTomlFile( corename )
	if e!=nil { return e }
	if len(mra_cfg.Header.Offset.Regions)==0 { return nil }
	cfg.Balut = 1
	cfg.Lutsh = mra_cfg.Header.Offset.Bits
	return nil
}

func check_banks( cfg *MemConfig ) error {
	// Check that the arguments make sense
	if len(cfg.SDRAM.Banks) > 4 || len(cfg.SDRAM.Banks) == 0 {
		log.Fatalf("jtframe mem: the number of banks must be between 1 and 4 but %d were found.", len(cfg.SDRAM.Banks))
	}
	bad := false
	if cfg.Balut==0 {
		for bank_count:=1; bank_count<4; bank_count++ {
			if len(cfg.SDRAM.Banks)>bank_count  {
				bank_str := fmt.Sprintf("JTFRAME_BA%d",bank_count)
				bad = bad || report_bad_int( bank_str+"_START")
				wen_macro := bank_str+"_WEN"
				for _,bank_bus := range cfg.SDRAM.Banks[bank_count].Buses {
					if bank_bus.Rw {
						if !macros.IsSet(wen_macro) {
							fmt.Printf("Missing %s. Define it if using bank %d for R/W access\n", wen_macro, bank_count)
							bad=true
						}
					}
				}
			}

		}
	} else {
		if !macros.IsInt("JTFRAME_HEADER") {
			fmt.Println(`Missing JTFRAME_HEADER but the SDRAM banks are pointing to a region.
Set JTFRAME_HEADER in macros.def and define a [header.offset] in mame2mra.toml`)
		}
	}
	if bad {
		return fmt.Errorf("Errors detected in SDRAM definition in mem.yaml")
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
	return nil
}

func report_bad_int(macro_name string) bool {
	if !macros.IsInt(macro_name) {
		fmt.Printf("Missing or invalid %s\n",macro_name)
		return true
	}
	return false
}

func check_bram( cfg *MemConfig ) error {
	prom_cnt := 0
	for _, bram := range cfg.BRAM {
		if !bram.Prom { continue }
		if prom_cnt!=0 {
			return fmt.Errorf("Currently only support for a single PROM BRAM block is implemented")
		}
		if bram.Data_width>8 {
			return fmt.Errorf("PROM BRAM blocks must be 8-bit wide or less but BRAM %s requires %d bits",bram.Name, bram.Data_width )
		}
		prom_cnt++
	}
	return nil
}

func fill_implicit_ports( cfg *MemConfig ) {
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
		if each.Rw {
			if each.Din  == "" { each.Din = each.Name + "_din"  }
		} else {
			each.Din = fmt.Sprintf("%d'd0",each.Data_width)
		}
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
			we_port := Port{ Name: name }
			// only 16 bit memories have byte select
			if each.Data_width==16 { we_port.MSB=1 }
			add( we_port )
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
				if each.Dual_port.We != "" {
					add( Port{
						Name: each.Dual_port.We,
						MSB: each.Data_width>>4, // 8->0, 16->1
					})
				}
			} else {
				each.Dual_port.Din = fmt.Sprintf("%d'd0",each.Data_width)
				each.Dual_port.We  = fmt.Sprintf("%d'd0",each.Data_width>>3)
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

func make_ioctl( cfg *MemConfig ) int {
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
		if each.Ioctl.Order >= len(cfg.Ioctl.Buses) {
			fmt.Printf("mem.yaml: too many IOCTL buses for BRAM\n")
			os.Exit(1)
		}
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
	check_ioctl_size( dump_size )
	return dump_size
}

// warn if JTFRAME_IOCTL_RD is below the required one
func check_ioctl_size(dump_size int) {
	if dump_size==0 { return }
	ioctl_rd := macros.GetInt("JTFRAME_IOCTL_RD")
	suggest := ioctl_rd<dump_size || Verbose
	if ioctl_rd < dump_size {
		suggest = true
		fmt.Printf("WARNING: JTFRAME_IOCTL_RD in macros.def is %d too short.\n", dump_size-ioctl_rd)
	}
	if suggest {
		fmt.Printf("Set:\tJTFRAME_IOCTL_RD=%d\n", dump_size)
	}
}

func fill_gfx_sort( cfg *MemConfig ) {
	// this will not merge correctly hhvvv and hhvvvx used together, that's
	// not supported in jtframe_dwnld at the moment
	appendif := func( ss *[]string, mac string ) {
		if macros.IsSet(mac) { *ss = append(*ss, "`"+mac) }
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
					if macros.IsSet(fmt.Sprintf("JTFRAME_BA%d_START",k+1)) { // is there another bank
						appendif( &offsets2, "JTFRAME_HEADER" )
						offsets2 = append(offsets2,fmt.Sprintf("`JTFRAME_BA%d_START",k+1))
					} else if macros.IsSet("JTFRAME_PROM_START") {
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