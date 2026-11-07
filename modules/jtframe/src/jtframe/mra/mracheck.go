package mra

import(
	"fmt"
	"strconv"
	. "jotego/jtframe/xmlnode"
)

type MRAChecker struct {
	root *XMLNode
	machine *MachineXML
	bad_interleave_sizes []string
}

func MakeMRAChecker(root *XMLNode, machine *MachineXML) *MRAChecker {
	return &MRAChecker{
		root:    root,
		machine: machine,
	}
}

func (ck *MRAChecker)Check() error {
	ck.check_all_interleave_files()
	if len(ck.bad_interleave_sizes)==0 {
		return nil
	}
	return ck.format_error()
}

func (ck *MRAChecker)check_all_interleave_files() {
	ck.bad_interleave_sizes = nil
	all_interleaves := ck.root.FindAll("interleave")
	for _, interleave := range all_interleaves {
		ck.check_interleave_files(interleave)
	}
}

func (ck *MRAChecker)check_interleave_files(interleave *XMLNode) {
	all_parts := interleave.FindAll("part")
	ref := 0
	for k, part := range all_parts {
		cur_size := ck.get_part_size(part)
		map_bytes := ck.get_map_bytes(part)
		if map_bytes == 0 {
			ck.bad_interleave_sizes = append(ck.bad_interleave_sizes, part.GetAttr("name"))
			continue
		}
		cur_size /= map_bytes
		if k==0 {
			ref = cur_size
			continue
		}
		if ref != cur_size {
			ck.bad_interleave_sizes = append(ck.bad_interleave_sizes,part.GetAttr("name"))
		}
	}
}

func (ck *MRAChecker)get_part_size(part *XMLNode) int {
	length := part.GetAttr("length")
	if length!="" {
		as_int64,_ := strconv.ParseInt(length,0,32)
		return int(as_int64)
	}
	if crc := part.GetAttr("crc"); crc!="" {
		return ck.get_size_from_crc(crc)
	}
	return ck.get_size_from_name(part.GetAttr("name"))
}

func (ck *MRAChecker)get_size_from_crc(crc string) int {
	for _,rom := range ck.machine.Rom {
		if rom.Crc==crc {
			return rom.Size
		}
	}
	return 0
}

func (ck *MRAChecker)get_size_from_name(name string) int {
	for _,rom := range ck.machine.Rom {
		if rom.Name==name {
			return rom.Size
		}
	}
	return 0
}

func (ck *MRAChecker)get_map_bytes(part *XMLNode) int {
	mapstr := part.GetAttr("map")
	k:=0
	for _, c := range mapstr {
		if c!='0' { k++ }
	}
	return k
}

func (ck *MRAChecker)format_error() error {
	msg := fmt.Sprintf("In %s, the following part size "+
	 "is not consistent within the interleave", ck.machine.Name)
	for _, name := range ck.bad_interleave_sizes {
		msg = fmt.Sprintf("%s\n- %s",msg,name)
	}
	return fmt.Errorf(msg)
}
