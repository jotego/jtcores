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
	"log"
	"path/filepath"
	"os"

	"github.com/jotego/jtframe/common"
)

func make_nvram(root *XMLNode, machine *MachineXML, cfg Mame2MRA, corename string) {
	if cfg.ROM.Nvram.length == 0 { return }
	add_nvram := len(cfg.ROM.Nvram.Machines) == 0
	if !add_nvram {
		for _, each := range cfg.ROM.Nvram.Machines {
			if machine.Name == each {
				add_nvram = true
				break
			}
		}
	}
	if rawbytes, e := nvram_file(machine, corename); e==nil { // look in cfg folder for matching file
		root.AddNode("rom").AddAttr("index", "2").AddNode("part").SetText("\n" + hexdump(rawbytes, 16))
	} else if !nvram_verbatim(root, machine,cfg) { // explicit defaults in the TOML
		nvram_rom(root,machine,cfg)  // get the defaults from MAME
	}
	if add_nvram {
		n := root.AddNode("nvram").AddAttr("index", "2")
		n.AddIntAttr("size", cfg.ROM.Nvram.length)
	}
}

func nvram_file( machine *MachineXML, core string) ([]byte, error) {
	cfgdir :=  common.ConfigFilePath(core,"")
	fname := filepath.Join(cfgdir,machine.Name+".nvm")
	f, e := os.Open(fname)
	if e!=nil {
		f.Close()
		if machine.Cloneof=="" { return nil, e }
		fname := filepath.Join(cfgdir,machine.Cloneof+".nvm")
		f, e = os.Open(fname)
		if e!= nil {
			f.Close()
			return nil,e	// not found
		}
	}
	f.Close()
	return os.ReadFile(fname)
}

func nvram_verbatim(root *XMLNode, machine *MachineXML, cfg Mame2MRA) bool {
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
		root.AddNode("rom").AddAttr("index", "2").AddNode("part").SetText("\n" + hexdump(rawbytes, 16))
		return true
	}
	return false
}

func nvram_rom(root *XMLNode, machine *MachineXML, cfg Mame2MRA) {
	reg := find_region_cfg(machine,"nvram",cfg)
	if reg==nil { return }
	roms := extract_region(reg, machine.Rom, cfg.ROM.Remove)
	if len(roms)==0 { return }
	if len(roms)!=1 {
		log.Printf("Warning: more than one ROM for NVRAM section in %s. Skipping it\n", machine.Name)
		return
	}
	rom := root.AddNode("rom").AddAttr("index", "2").AddAttr("zip",zipName(machine,cfg))
	p := rom.AddNode("part")
	p.AddAttr("name",roms[0].Name)
	p.AddAttr("crc",roms[0].Crc)
}