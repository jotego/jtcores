package mra

import(
	"testing"

	. "jotego/jtframe/xmlnode"
)

func Test_volume_easy(t *testing.T) {
	var mod coreMOD
	mod.coremod=0x34
	mod.set_volume(0xca)
	if mod.coremod!=0xca34 { t.Error("Could not set volume")}
	if mod.get_volume()!=0xca { t.Error("Could not read volume")}
}

func Test_volume_cfg(t *testing.T) {
	var mod coreMOD
	machine := &MachineXML{
		Name: "mygame",
	}
	var cfg Mame2MRA
	cfg.Audio.Volume = []VolumeCfg{
		VolumeCfg{Value: 0x23},
	}

	mod.encode_volume_cfg(machine,cfg)
	if mod.get_volume()!=0x23 { t.Error("Could not set volume via config")}

	// low volume
	mod.coremod=0x34
	cfg.Audio.Volume = []VolumeCfg{
		VolumeCfg{Value: 0},
	}
	mod.encode_volume_cfg(machine,cfg)
	if mod.get_volume()!=0x80 { t.Error("Did not limit the volume")}
	if mod.coremod!=0x8034 { t.Errorf("Bad encoding: %X",mod.coremod) }
}

func Test_coremod_XML(t *testing.T) {
	var mod coreMOD
	mod.coremod = COREMOD_VERTICAL
	root := MakeNode("mra")
	mod.makeXML(&root)
	rom := root.GetNode("rom")
	if rom==nil {
		t.Error("Missing rom node")
		t.FailNow()
	}
	if rom.GetAttr("index")!="1" {
		t.Error("Missing index attribute")
	}
	part := rom.GetNode("part")
	if part==nil {
		t.Error("Missing part node")
		t.FailNow()
	}
	if text := part.GetText(); text!="01 00" {
		t.Errorf("wrong part content. Got %s",text)
	}
}

func Test_check_parts_consistency(t *testing.T) {
	reg := RegCfg{
		Name: "test_region",
		Parts: []RegParts{
			{ Name: "wide",    Map: "0012", Length: 0x2000 },
			{ Name: "narrow0", Map: "0100", Length: 0x1000 },
			{ Name: "narrow1", Map: "1000", Length: 0x1000 },
		},
	}
	should_panic := false
    defer func(){
        r:= recover()
        if !should_panic && r!=nil {
            t.Errorf("The region should not be deemed invalid")
            return
        }
        if  should_panic && r==nil {
            t.Errorf("The region should be deemed invalid")
            return
        }
    }()
    reg.check_parts_consistency()
    reg.Parts[0].Length=0x1000
    should_panic=true
    reg.check_parts_consistency()
}
