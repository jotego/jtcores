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
	"strings"
	"text/template"

	"github.com/jotego/jtframe/jtfiles"
	"github.com/jotego/jtframe/jtdef"

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
	buf, err := ioutil.ReadFile(filename)
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
		for _, each := range bank.Buses {
			if each.Rw {
				ram_cnt++
			}
		}
		if ram_cnt > 0 {
			cfg.SDRAM.Banks[k].MemType = fmt.Sprintf("ram%d", ram_cnt)
		} else {
			cfg.SDRAM.Banks[k].MemType = "rom"
		}
	}
	return true
}

func make_sdram( finder path_finder, cfg *MemConfig) {
	tpath := filepath.Join(os.Getenv("JTFRAME"), "src", "jtframe", "mem", "game_sdram.v")
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

	tpath := filepath.Join(os.Getenv("JTFRAME"), "src", "jtframe", "mem", "ports.v")
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
	var def_cfg jtdef.Config
	def_cfg.Target = target
	def_cfg.Core = core
	// def_cfg.Add = jtcfgstr.Append_args(def_cfg.Add, strings.Split(args.AddMacro, ","))
	return jtdef.Make_macros(def_cfg)
}

func check_banks( macros map[string]string, cfg MemConfig ) {
	// Check that the arguments make sense
	if len(cfg.SDRAM.Banks) > 4 || len(cfg.SDRAM.Banks) == 0 {
		log.Fatalf("jtframe mem: the number of banks must be between 1 and 4 but %d were found.", len(cfg.SDRAM.Banks))
	}
	bad := false
	if len(cfg.SDRAM.Banks)>1 && macros["JTFRAME_BA1_START"]=="" {
		fmt.Println("Missing JTFRAME_BA1_START")
		bad = true
	}
	if len(cfg.SDRAM.Banks)>2 && macros["JTFRAME_BA2_START"]=="" {
		fmt.Println("Missing JTFRAME_BA2_START")
		bad = true
	}
	if len(cfg.SDRAM.Banks)>3 && macros["JTFRAME_BA3_START"]=="" {
		fmt.Println("Missing JTFRAME_BA3_START")
		bad = true
	}
	if bad {
		os.Exit(1)
	}
}

func Run(args Args) {
	var cfg MemConfig
	if !parse_file(args.Core, "mem", &cfg, args) {
		// the mem.yaml file does not exist, that's
		// normally ok
		return
	}
	macros := get_macros( args.Core, args.Target )
	check_banks( macros, cfg )
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
	// Fill the clock configuration
	make_clocks( macros, &cfg )
	// Execute the template
	cfg.Core = args.Core
	make_sdram(args, &cfg)
	add_game_ports(args, &cfg)
}
