package mra

import (
	"strings"
	"testing"

	. "jotego/jtframe/xmlnode"
)

func Test_button_defaults(t *testing.T) {
	for _, tc := range []struct {
		name, names, mapping, want_names, want_pad, count string
		core int
	}{
		{"legacy", "Shot,Jump", "", "Shot,Jump", "A,B", "2", 2},
		{"directions", "Shoot left,Shoot centre,Shoot right", "YXA", "Shoot left,Shoot centre,Shoot right", "Y,X,A", "3", 3},
		{"shoulders", "Shot,Bomb,Turn left,Turn right", "YBLR", "Shot,Bomb,Turn left,Turn right", "Y,B,L,R", "4", 4},
		{"unused input", "Left,-,Right", "Y-A", "Left,-,Right", "Y,A", "2", 3},
		{"unused named key", "Left,-,Right", "YBA", "Left,-,Right", "Y,A", "2", 3},
		{"core padding", "Rotate left,Rotate right", "LR", "Rotate left,Rotate right,-,-,-,-", "L,R", "2", 6},
		{"dynasty wars", "Attack left,Attack right,Special", "YAB", "Attack left,Attack right,Special,-,-,-", "Y,A,B", "3", 6},
		{"final fight", "Attack,Jump,Evade", "", "Attack,Jump,Evade,-,-,-", "A,B,X", "3", 6},
		{"core limit", "Left,Centre,Right", "YXA", "Left,Centre", "Y,X", "2", 2},
	} {
		t.Run(tc.name, func(t *testing.T) {
			cfg := button_test_cfg(t, tc.names, tc.mapping, tc.core)
			root := MakeNode("misterromdescription")
			make_buttons(&root, &MachineXML{Name: "test"}, cfg, Args{})
			b := root.GetNode("buttons")
			if got := b.GetAttr("names"); got != tc.want_names+",Start,Coin,Core credits" { t.Errorf("names: %s", got) }
			if got := b.GetAttr("default"); got != tc.want_pad+",Start,Select,-" { t.Errorf("default: %s", got) }
			if got := b.GetAttr("count"); got != tc.count { t.Errorf("count: %s", got) }
		})
	}
}

func Test_button_selection(t *testing.T) {
	cfg, e := NewMRAcfgFromTOML(strings.NewReader(`[buttons]
names = [
  {names="Default", map="B"},
  {machine="parent", names="Family", map="Y"},
  {setname="clone", names="Clone", map="X"},
  {machines=["listed"], names="Listed", map="R"},
  {setnames=["listedclone"], names="Listed clone", map="L"},
  {machine="legacy", names="Legacy"}
]`))
	if e != nil { t.Fatal(e) }
	for _, tc := range []struct { name, parent, names, mapping string }{
		{"other", "", "Default", "B"},
		{"parent", "", "Family", "Y"},
		{"sibling", "parent", "Family", "Y"},
		{"clone", "parent", "Clone", "X"},
		{"listed", "", "Listed", "R"},
		{"child", "listed", "Listed", "R"},
		{"listedclone", "listed", "Listed clone", "L"},
		{"legacy", "", "Legacy", ""},
	} {
		got := cfg.select_buttons(&MachineXML{Name: tc.name, Cloneof: tc.parent})
		if got == nil || got.Names != tc.names || got.Map != tc.mapping { t.Errorf("%s: %+v", tc.name, got) }
	}
}

func Test_button_fallback(t *testing.T) {
	for _, tc := range []struct { toml, names string }{
		{"", "button 1,button 2"},
		{`[buttons]
names=[{names=""}]`, "Shot,Jump"},
	} {
		cfg, e := NewMRAcfgFromTOML(strings.NewReader(tc.toml))
		if e != nil { t.Fatal(e) }
		cfg.Buttons.Core = 2
		root := MakeNode("misterromdescription")
		make_buttons(&root, &MachineXML{Name:"test"}, cfg, Args{})
		if got := root.GetNode("buttons").GetAttr("names"); got != tc.names+",Start,Coin,Core credits" { t.Errorf("names: %s", got) }
	}
}

func Test_button_map_validation(t *testing.T) {
	for _, tc := range []struct { names, mapping string }{
		{"Left,Right", "Y"},
		{"Left,Right", "YAB"},
		{"Left,Right", "YY"},
		{"Left,Right", "YA!"},
		{"Left,Right", "Y?"},
		{"Left,Right", "yA"},
		{"Left,Right", "Y-"},
		{"", "A"},
		{"1,2,3,4,5,6,7", "ABXYLR-"},
	} {
		_, e := NewMRAcfgFromTOML(strings.NewReader(`[buttons]
names=[{names="`+tc.names+`", map="`+tc.mapping+`"}]`))
		if e == nil { t.Errorf("accepted names=%q map=%q", tc.names, tc.mapping) }
	}
}

func Test_button_command_override(t *testing.T) {
	cfg := button_test_cfg(t, "Left,Centre,Right", "YXA", 3)
	root := MakeNode("misterromdescription")
	make_buttons(&root, &MachineXML{Name: "test"}, cfg, Args{Buttons: "One,Two,Three"})
	b := root.GetNode("buttons")
	if b.GetAttr("names") != "One,Two,Three,Start,Coin,Core credits" || b.GetAttr("default") != "A,B,X,Start,Select,-" {
		t.Fatal("command-line buttons did not replace the configured names and map")
	}
}

func button_test_cfg(t *testing.T, names, mapping string, core int) Mame2MRA {
	t.Helper()
	cfg, e := NewMRAcfgFromTOML(strings.NewReader(`[buttons]
names=[{names="`+names+`", map="`+mapping+`"}]`))
	if e != nil { t.Fatal(e) }
	cfg.Buttons.Core = core
	return cfg
}
