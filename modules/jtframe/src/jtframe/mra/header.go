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
)

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

func bank_offset(headbytes []byte, reg_offsets map[string]int, cfg HeaderCfg) {
	if len(cfg.Offset.Regions) == 0 { return }
	for fill:=len(cfg.Offset.Regions); fill<5;fill++ {
		// fill in with FFFF to cover 4 banks + PROM start
		set_header_offset( headbytes, fill<<1, false, 0, 0xffff )
	}
	unknown_regions := make([]string, 0)
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
	if len(unknown_regions) > 0 {
		fmt.Printf("\tmissing region(s)")
		for _, uk := range unknown_regions {
			fmt.Printf(" %s", uk)
		}
		fmt.Printf(". Offset set to zero in the header\n")
	}
}

func make_header(node *XMLNode, reg_offsets map[string]int, total int, cfg HeaderCfg, machine *MachineXML) error {
	if cfg.Offset.Regions != nil && cfg.len<5 {
		return fmt.Errorf("Header too short for containing offset regions. Make it at least 5:\nJTFRAME_HEADER = 5")
	}
	headbytes := make_byte_slice(byte(cfg.Fill),cfg.len)
	bank_offset( headbytes, reg_offsets, cfg )
	headbytes = cfg.parse_data(headbytes,machine)
	node.SetText(hexdump(headbytes, 8))
	return nil
}

func make_byte_slice(fill byte, length int) []byte {
	buffer := make([]byte, length)
	for k, _ := range buffer {
		buffer[k] = fill
	}
	return buffer
}

func (hdr HeaderCfg) parse_data( headbytes []byte, machine *MachineXML ) []byte {
	for _, each := range hdr.Data {
		if each.Match(machine) == 0 { continue }
		if each.Dev!="" && !has_dev(each.Dev,machine.Devices)  { continue }
		rawbytes := hdr.get_entry_bytes(each,machine)
		pos := each.Offset
		copy(headbytes[pos:], rawbytes)
	}
	return headbytes
}

func has_dev(name string, devs []MameDevice ) bool {
	found := false
	for _, ref := range devs {
		if name == ref.Name {
			found = true
			break
		}
	}
	return found
}

func (cfg HeaderCfg) get_entry_bytes( data_entry HeaderData, machine *MachineXML ) []byte {
	if data_entry.Pcb_id {
		id := machine.Find(cfg.PCBs)
		return []byte{byte(id)}
	} else {
		return rawdata2bytes(data_entry.Data)
	}
}
