package mra

import(
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
