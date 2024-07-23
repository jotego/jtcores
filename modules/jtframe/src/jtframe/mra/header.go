package mra

import (
	"fmt"
	"os"
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

func make_header(node *XMLNode, reg_offsets map[string]int,
	total int, cfg HeaderCfg, machine *MachineXML) {
	devs := machine.Devices
	headbytes := make([]byte, cfg.Len)
	if cfg.Offset.Regions != nil && cfg.Len<5 {
		fmt.Println("Header too short for containing offset regions. Make it at least 5:\nJTFRAME_HEADER = 5")
		os.Exit(1)
	}
	for k := 0; k < cfg.Len; k++ {
		headbytes[k] = byte(cfg.Fill)
	}
	bank_offset( headbytes, reg_offsets, cfg )
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
