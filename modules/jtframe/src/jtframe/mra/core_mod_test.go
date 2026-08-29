package mra

import(
	"testing"

	"jotego/jtframe/macros"
	. "jotego/jtframe/xmlnode"
)

func Test_screen_size_frame_encoding(t *testing.T) {
	macros.MakeFromMap(map[string]string{
		"JTFRAME_WIDTH": "384",
		"JTFRAME_HEIGHT": "256",
	})
	tests := []struct{
		name string
		rotate, width, height int
		want uint
	}{
		{"horizontal 8 pixels",  0, 368, 256, COREMOD_8PXL_FRAME<<COREMOD_FRAME_BIT},
		{"horizontal 16 pixels", 0, 352, 256, COREMOD_16PXL_FRAME<<COREMOD_FRAME_BIT},
		{"vertical 8 lines",     90, 384, 240, COREMOD_VERTICAL | COREMOD_8PXL_FRAME<<COREMOD_FRAME_BIT},
		{"vertical 16 lines",    270, 384, 224, COREMOD_VERTICAL | COREMOD_XORFLIP | COREMOD_16PXL_FRAME<<COREMOD_FRAME_BIT},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			machine := &MachineXML{Display: MameDisplay{
				Rotate: test.rotate, Width: test.width, Height: test.height,
			}}
			var mod coreMOD
			mod.encode_settings(machine,Mame2MRA{})
			if got := mod.coremod&0xff; got!=test.want {
				t.Errorf("wrong core MOD value. Got %02X, want %02X",got,test.want)
			}
		})
	}
}

func Test_explicit_frame_uses_selected_axis(t *testing.T) {
	macros.MakeFromMap(map[string]string{
		"JTFRAME_WIDTH": "384",
		"JTFRAME_HEIGHT": "256",
	})
	cfg := Mame2MRA{}
	cfg.Header.Frames = []FrameCfg{{Width: 8}}
	tests := []struct{
		name string
		machine MachineXML
		want_wdiff, want_hdiff int
		want uint
	}{
		{"horizontal", MachineXML{Display: MameDisplay{Width: 384, Height: 256}}, 8, 0,
			COREMOD_8PXL_FRAME<<COREMOD_FRAME_BIT},
		{"vertical", MachineXML{Display: MameDisplay{Rotate: 90, Width: 384, Height: 256}}, 0, 8,
			COREMOD_VERTICAL | COREMOD_8PXL_FRAME<<COREMOD_FRAME_BIT},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			var mod coreMOD
			mod.encode_settings(&test.machine,cfg)
			if mod.wdiff!=test.want_wdiff || mod.hdiff!=test.want_hdiff {
				t.Errorf("explicit frame applied to wrong axis: wdiff=%d hdiff=%d",mod.wdiff,mod.hdiff)
			}
			if got := mod.coremod&0xff; got!=test.want {
				t.Errorf("wrong core MOD value. Got %02X",got)
			}
		})
	}
}

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
