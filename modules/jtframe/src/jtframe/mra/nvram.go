/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package mra

import (
	"log"
	"os"
	"path/filepath"

	"jotego/jtframe/common"
	. "jotego/jtframe/xmlnode"
)

func make_nvram(root *XMLNode, machine *MachineXML, cfg Mame2MRA, corename string) {
	if cfg.ROM.Nvram.length == 0 {
		return
	}
	add_nvram := len(cfg.ROM.Nvram.Machines) == 0
	if !add_nvram {
		for _, each := range cfg.ROM.Nvram.Machines {
			if machine.Name == each {
				add_nvram = true
				break
			}
		}
	}
	if rawbytes, e := nvram_file(machine, corename); e == nil { // look in cfg folder for matching file
		root.AddNode("rom").AddAttr("index", "2").AddNode("part").SetText("\n" + hexdump(rawbytes, 16))
	} else if !nvram_verbatim(root, machine, cfg) { // explicit defaults in the TOML
		nvram_rom(root, machine, cfg) // get the defaults from MAME
	}
	if add_nvram {
		n := root.AddNode("nvram").AddAttr("index", "2")
		n.AddIntAttr("size", cfg.ROM.Nvram.length)
	}
}

func nvram_file(machine *MachineXML, core string) ([]byte, error) {
	cfgdir := common.ConfigFilePath(core, "")
	fname := filepath.Join(cfgdir, machine.Name+".nvm")
	f, e := os.Open(fname)
	if e != nil {
		f.Close()
		if machine.Cloneof == "" {
			return nil, e
		}
		fname := filepath.Join(cfgdir, machine.Cloneof+".nvm")
		f, e = os.Open(fname)
		if e != nil {
			f.Close()
			return nil, e // not found
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
		if each.Match(machine) > 0 {
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
	reg := find_region_cfg(machine, "nvram", cfg)
	if reg == nil {
		return
	}
	roms, e := reg.extract_region(machine.Rom, cfg.ROM.Remove)
	if e != nil {
		log.Printf("Warning: cannot parse NVRAM region in %s: %v\n", machine.Name, e)
		return
	}
	if len(roms) == 0 {
		return
	}
	if len(roms) != 1 {
		log.Printf("Warning: more than one ROM for NVRAM section in %s. Skipping it\n", machine.Name)
		return
	}
	zip_name := make_zip_name(machine, cfg.Global.Zip.Alt)
	rom := root.AddNode("rom").AddAttr("index", "2").AddAttr("zip", zip_name)
	p := rom.AddNode("part")
	p.AddAttr("name", roms[0].Name)
	p.AddAttr("crc", roms[0].Crc)
}
