package mra

import (
	"fmt"
)

func make_nvram(root *XMLNode, machine *MachineXML, cfg Mame2MRA) {
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
	if !nvram_verbatim(root, machine,cfg) {
		nvram_file(root,machine,cfg)
	}
	if add_nvram {
		n := root.AddNode("nvram").AddAttr("index", "2")
		n.AddIntAttr("size", cfg.ROM.Nvram.length)
	}
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

func nvram_file(root *XMLNode, machine *MachineXML, cfg Mame2MRA) {
	reg := find_region_cfg(machine,"nvram",cfg,false)
	if reg==nil { return }
	roms := extract_region(reg, machine.Rom, cfg.ROM.Remove)
	if len(roms)==0 { return }
	if len(roms)!=1 {
		fmt.Println("Warning: more than one ROM for NVRAM section in %s. Skipping it\n", machine.Name)
		return
	}
	rom := root.AddNode("rom").AddAttr("index", "2").AddAttr("zip",zipName(machine,cfg))
	p := rom.AddNode("part")
	p.AddAttr("name",roms[0].Name)
	p.AddAttr("crc",roms[0].Crc)
}