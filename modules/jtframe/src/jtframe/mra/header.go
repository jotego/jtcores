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
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"text/template"

	. "jotego/jtframe/xmlnode"
	"github.com/Masterminds/sprig/v3"	// more template functions
)

func (hdr *HeaderCfg) MakeVerilog(corename string) ([]byte,error) {
	if len(hdr.Registers)==0 { return nil, nil }
	info := struct{
		Core string
		Registers []reg_info
	}{
		Core: corename,
		Registers: hdr.make_reg_info(),
	}
	tpath := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc","header.v")
	t := template.New("header.v").Funcs(sprig.FuncMap())
	_, e := t.ParseFiles(tpath)
	wrap := func() error {return fmt.Errorf("%w while parsing file header.v",e)}
	if e!=nil {
		return nil, wrap()
	}
	var buffer bytes.Buffer
	if e = t.Execute(&buffer, info); e!= nil { return nil, wrap() }
	return buffer.Bytes(),nil
}

type reg_info struct{
	Name, Index string
	Msb, Lsb, Offset int
}

func (hdr *HeaderCfg)make_reg_info() (info []reg_info) {
	info = make([]reg_info,len(hdr.Registers))
	for k, reg := range hdr.Registers {
		reg.calc_pos()
		n := &info[k]
		n.Name = reg.Name
		n.Msb = reg.msb
		n.Lsb = reg.lsb
		n.Offset = reg.offset
		if n.Msb==n.Lsb {
			n.Index = fmt.Sprintf("[%d]",n.Lsb)
		} else {
			n.Index = fmt.Sprintf("[%d:%d]",n.Msb,n.Lsb)
		}
	}
	return info
}

func (hdr *HeaderCfg) MakeNode(parent *XMLNode) bool {
	if hdr.len > 0 {
		hdr.make_info_comment(parent)
		hdr.node = parent.AddNode("part")
		hdr.node.SetIndent()
		return true
	}
	return false
}

func (cfg *HeaderCfg)make_info_comment(parent *XMLNode) {
	var info strings.Builder
	if len(cfg.Info) > 0 {
		info.WriteString(cfg.Info)
	}
	for _, reg := range cfg.Registers {
		if reg.Desc=="" { continue }
		info.WriteString(fmt.Sprintf("\n%6s: %-10s %s",reg.Pos,reg.Name,reg.Desc))
	}
	parent.AddComment(info.String())
}

func (hdr *HeaderCfg)FillData(reg_offsets map[string]int, total int, machine *MachineXML) error {
	if hdr.node==nil { return nil }
	if hdr.Offset.Regions != nil && hdr.len<5 {
		return fmt.Errorf("Header too short for containing offset regions. Make it at least 5:\nJTFRAME_HEADER = 5")
	}
	headbytes := make_byte_slice(byte(hdr.Fill),hdr.len)
	hdr.bank_offset( headbytes, reg_offsets)
	headbytes = hdr.parse_data(headbytes,machine)
	headbytes = hdr.parse_regs(headbytes,machine)
	hdr.node.SetText(hexdump(headbytes, 8))
	return nil
}

func make_byte_slice(fill byte, length int) []byte {
	buffer := make([]byte, length)
	for k, _ := range buffer {
		buffer[k] = fill
	}
	return buffer
}

func (cfg HeaderCfg) bank_offset(headbytes []byte, reg_offsets map[string]int) {
	if len(cfg.Offset.Regions) == 0 { return }
	for fill:=len(cfg.Offset.Regions); fill<5;fill++ {
		// fill in with FFFF to cover 4 banks + PROM start
		cfg.set_offset( headbytes, fill<<1, false, 0, 0xffff )
	}
	unknown_regions := make([]string, 0)
	pos := cfg.Offset.Start
	for _, r := range cfg.Offset.Regions {
		offset, ok := reg_offsets[r]
		if !ok {
			unknown_regions = append(unknown_regions, r)
			offset = 0
		}
		cfg.set_offset(headbytes, pos, cfg.Offset.Reverse, cfg.Offset.Bits, offset)
		pos += 2
	}
	if len(unknown_regions) > 0 {
		fmt.Printf("\tmissing region(s)")
		for _, uk := range unknown_regions {
			fmt.Printf(" %s", uk)
		}
		fmt.Printf(". Offset set to zero in the header\n")
	}
}

func (cfg HeaderCfg)set_offset(headbytes []byte, pos int, reverse bool, bits, offset int) {
	offset >>= bits
	headbytes[pos] = byte((offset >> 8) & 0xff)
	headbytes[pos+1] = byte(offset & 0xff)
	if reverse {
		aux := headbytes[pos]
		headbytes[pos] = headbytes[pos+1]
		headbytes[pos+1] = aux
	}
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

func (hdr HeaderCfg) parse_regs( headbytes []byte, machine *MachineXML ) []byte {
	filled := make([]byte,len(headbytes))
	copy(filled,headbytes)
	for _, reg := range hdr.Registers {
		reg.apply(filled,machine)
	}
	return filled
}

func (reg HeaderReg) apply( headbytes []byte, machine *MachineXML) {
	last_match := 0
	fill := 0
	for _, value := range reg.Values {
		match := value.Match(machine)
		if match!=0 && match>=last_match {
			last_match = match
			fill = value.Value
		}
	}
	if last_match==0 { return }
	reg.calc_pos()
	if reg.offset>len(headbytes) {
		msg := fmt.Sprintf("Header register offset %d too big for header length %d",reg.offset,len(headbytes))
		panic(msg)
	}
	headbytes[reg.offset] = (headbytes[reg.offset] & byte(^reg.mask)) | (byte(fill)<<reg.bit)
}

func (reg *HeaderReg) calc_pos() error {
	var aux int64
	rebyte, e := regexp.Compile("^([0-9]+)\\[([0-7]):?([0-7])?\\]$"); must(e)
	chunks := rebyte.FindStringSubmatch(reg.Pos)
	if total:=len(chunks); total!=4 {
		return fmt.Errorf("Wrong position specification for header register %s. Expecting byte[MSB:LSB] or byte[bit], found %s (%d chunks)",
			reg.Name, reg.Pos, total )
	}
	aux, e = strconv.ParseInt(chunks[1],10,32); must(e)
	reg.offset = int(aux)
	aux, e = strconv.ParseInt(chunks[2],10,32); must(e)
	reg.msb = int(aux)
	reg.lsb = reg.msb
	if chunks[3]!="" {
		aux, e = strconv.ParseInt(chunks[3],10,32); must(e)
		reg.lsb = int(aux)
	}
	if reg.lsb>reg.msb {
		return fmt.Errorf("Wrong position specification for header register %s. Expecting byte[MSB:LSB] but found LSB>MSB in %s",
			reg.Name, reg.Pos )
	}
	reg.bit = reg.lsb
	if reg.msb==reg.lsb {
		reg.mask = 1<<reg.msb
	} else {
		reg.mask = (1<<(reg.msb+1))-1
		reg.mask = reg.mask & ^((1<<reg.lsb)-1)
	}
	return nil
}