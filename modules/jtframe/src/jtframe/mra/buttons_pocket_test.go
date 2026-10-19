package mra

import (
	"encoding/json"
	"testing"
)

func Test_pocket_button_register(t *testing.T) {
	for _, tc := range []struct { names, mapping, data string }{
		{"Shot,Jump", "", "0x543210"},
		{"Left,Centre,Right", "YXA", "0xFFF023"},
		{"Shot,Bomb,Turn left,Turn right", "YBLR", "0xFF5413"},
		{"Left,-,Right", "Y-A", "0xFFF0F3"},
		{"A,B,X,Y,L,R", "ABXYLR", "0x543210"},
	} {
		cfg := button_test_cfg(t, tc.names, tc.mapping, 6)
		got := pocket_button_map(&MachineXML{Name:"test"}, cfg)
		if got.Address != "0xfc000000" || got.Data != tc.data { t.Errorf("map %q: %+v", tc.mapping, got) }
	}
	got := pocket_button_map(&MachineXML{Name:"test"}, Mame2MRA{})
	if got.Data != "0x543210" { t.Fatal("unconfigured games must restore the identity map") }
}

func Test_pocket_button_maps(t *testing.T) {
	for _, tc := range []struct {
		name, names, mapping string
		want []ContMapping
	}{
		{"legacy", "Shot,Jump", "", []ContMapping{{0,"Shot","pad_btn_a"},{1,"Jump","pad_btn_b"}}},
		{"directions", "Left,Centre,Right", "YXA", []ContMapping{{0,"Left","pad_btn_y"},{1,"Centre","pad_btn_x"},{2,"Right","pad_btn_a"}}},
		{"shoulders", "Shot,Bomb,Turn left,Turn right", "YBLR", []ContMapping{{0,"Shot","pad_btn_y"},{1,"Bomb","pad_btn_b"},{2,"Turn left","pad_trig_l"},{3,"Turn right","pad_trig_r"}}},
		{"unused input", "Left,-,Right", "Y-A", []ContMapping{{0,"Left","pad_btn_y"},{2,"Right","pad_btn_a"}}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			cfg := button_test_cfg(t, tc.names, tc.mapping, 6)
			out := pocket_parse_inputs(&MachineXML{Name:"test"}, cfg)
			data, e := json.Marshal(out)
			if e != nil { t.Fatal(e) }
			var decoded InputMap
			if e = json.Unmarshal(data, &decoded); e != nil { t.Fatal(e) }
			if decoded.Magic != APF_Version || len(decoded.Controllers) != 1 { t.Fatalf("invalid input JSON: %s", data) }
			got := decoded.Controllers[0].Mappings
			if len(got) != len(tc.want) { t.Fatalf("mappings: %+v", got) }
			for k := range got {
				if got[k] != tc.want[k] { t.Errorf("mapping %d: %+v, want %+v", k, got[k], tc.want[k]) }
			}
		})
	}
}
