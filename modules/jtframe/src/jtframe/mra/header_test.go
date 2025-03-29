package mra

import(
	"bytes"
	// "fmt"
	"path/filepath"
	"os"
	"runtime"
	"testing"
)

func Test_parse_data(t *testing.T) {
	hdr := HeaderCfg{
		PCBs: []Selectable{
			{ Machine: "a" },
			{ Machine: "b" },
			{ Machine: "c" },
		},
		Data: []HeaderData{
			{ Pcb_id: true },
			{
				RawData: RawData{ Data: "12 34 56 78"},
			  	Offset: 1,
			},
		},
	}
	headbytes := make([]byte,16)
	b_machine := &MachineXML{ Name: "b", }
	parsed := hdr.parse_data(headbytes, b_machine )
	if parsed[0]!=byte(1) {t.Errorf("Game id failed. Found %d",parsed[0])}
	if parsed[1]!=byte(0x12) ||
	   parsed[2]!=byte(0x34) ||
	   parsed[3]!=byte(0x56) ||
	   parsed[4]!=byte(0x78) {t.Errorf("raw data failed")}
}

func Test_header_regs(t *testing.T) {
	hdr := HeaderCfg{
		Registers: []HeaderReg{ HeaderReg{
			Name: "enable",
			Pos: "1[2]",
			Desc: "Enabler",
			Values: []HeaderRegValue{
				HeaderRegValue{
					Selectable{
						Machine: "gng",
					},
					1,
				},
			},
		},},
	}
	headbytes := make([]byte,16)
	machine := &MachineXML{ Name: "gng", }
	parsed := hdr.parse_regs(headbytes, machine)
	if len(parsed)!=len(headbytes) { t.Errorf("Wrong length") }
	if parsed[1]!=4 { t.Errorf("bit not set correctly") }
	for k,value := range parsed {
		if k==1 { continue }
		if value!=0 { t.Errorf("wrong byte modified") }
	}
}

func Test_calc_pos(t *testing.T) {
	reg := HeaderReg{
		Name: "foo",
		Pos: "3[5]",
	}
	e := reg.calc_pos()
	if e!=nil { t.Error(e) }
	if reg.offset != 3  { t.Errorf("Wrong offset for %s. Got %d",reg.Pos,reg.offset)}
	if reg.bit != 5     { t.Errorf("Wrong bit for %s. Got %d",reg.Pos,reg.bit)}
	if reg.mask != 0x20 { t.Errorf("Wrong mask for %s. Got %X",reg.Pos, reg.mask)}

	reg.Pos = "4[7:6]"
	e = reg.calc_pos()
	if e!=nil { t.Error(e) }
	if reg.offset != 4  { t.Errorf("Wrong offset for %s. Got %d",reg.Pos,reg.offset)}
	if reg.bit != 6     { t.Errorf("Wrong bit for %s. Got %d",reg.Pos,reg.bit)}
	if reg.mask != 0xc0 { t.Errorf("Wrong mask for %s. Got %X",reg.Pos, reg.mask)}

	reg.Pos = "7[1:0]"
	e = reg.calc_pos()
	if e!=nil { t.Error(e) }
	if reg.offset != 7  { t.Errorf("Wrong offset for %s. Got %d",reg.Pos,reg.offset)}
	if reg.bit != 0     { t.Errorf("Wrong bit for %s. Got %d",reg.Pos,reg.bit)}
	if reg.mask != 0x3 { t.Errorf("Wrong mask for %s. Got %X",reg.Pos, reg.mask)}
}

func Test_header_template(t *testing.T) {
	cfg := HeaderCfg{ Registers: []HeaderReg{
		HeaderReg{
			Name: "gfx",
			Pos: "1[2]",
		},
		HeaderReg{
			Name: "snd",
			Pos: "3[4:2]",
		},
	}}
	verilog, e := cfg.MakeVerilog("xx")
	if e!=nil { t.Error(e) }
	// fmt.Println(string(verilog))
	_,file,_,_ := runtime.Caller(0)
	dir := filepath.Dir(file)
	refname := filepath.Join(dir,"header.ref")
	ref, e := os.ReadFile(refname)
	if e!=nil { t.Error(e) }
	if bytes.Compare(ref,verilog)!=0 { t.Error("header template generation is producing a different result. Review it")}
}