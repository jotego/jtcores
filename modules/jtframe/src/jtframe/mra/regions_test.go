package mra

import (
	"strings"
	"testing"
)

func Test_validate_rom_regions(t *testing.T) {
	for _, tc := range []struct {
		name string
		regions []RegCfg
		order []string
		want string
	}{
		{name: "literal", regions: []RegCfg{{Name: "maincpu"}}},
		{name: "stale literal", regions: []RegCfg{{Name: "oldcpu"}}, want: "oldcpu"},
		{name: "stale with length", regions: []RegCfg{{Name: "oldcpu", Len: 4096}}, want: "oldcpu"},
		{name: "stale order", order: []string{"oldcpu"}, want: "ROM.order"},
		{name: "glob", regions: []RegCfg{{Name: "simm?.?"}}, order: []string{"simm?.?"}},
		{name: "stale glob", regions: []RegCfg{{Name: "absent*"}}, want: "absent*"},
		{name: "rename", regions: []RegCfg{{Name: "maincpu", Rename: "cpu"}}, order: []string{"cpu"}},
		{name: "stale rename source", regions: []RegCfg{{Name: "oldcpu", Rename: "maincpu"}}, want: "oldcpu"},
		{name: "explicit files", regions: []RegCfg{{Name: "firmware", Files: []MameROM{{Name: "fw.bin"}}}}, order: []string{"firmware"}},
		{name: "skip", regions: []RegCfg{{Name: "plds", Skip: true}}, order: []string{"plds"}},
		{name: "generated table", regions: []RegCfg{{Name: "fd1089"}}, order: []string{"fd1089"}},
		{name: "unselected rule", regions: []RegCfg{{Name: "absent", Selectable: Selectable{Setname: "other"}}}},
		{name: "selected missing", regions: []RegCfg{{Name: "simm?.?", Selectable: Selectable{Setname: "second"}}}, want: "second"},
		{name: "shared optional", regions: []RegCfg{{Name: "simm?.?"}}, order: []string{"simm1.0"}},
		{name: "shared optional with override", regions: []RegCfg{
			{Name: "simm1.0"},
			{Name: "simm1.0", Selectable: Selectable{Setname: "first"}, Width: 16},
		}, order: []string{"simm1.0"}},
		{name: "alias consumed by selected rule", regions: []RegCfg{
			{Name: "maincpu", Rename: "cpu", Skip: true},
			{Name: "cpu", Selectable: Selectable{Setname: "first"}, Width: 16},
			{Name: "cpu", Selectable: Selectable{Setname: "second"}, Width: 16},
		}, order: []string{"cpu"}},
		{name: "alias with unmatched source", regions: []RegCfg{
			{Name: "oldcpu", Rename: "cpu", Skip: true},
			{Name: "cpu", Selectable: Selectable{Setname: "first"}},
		}, want: "cpu"},
		{name: "alias outside selector", regions: []RegCfg{
			{Name: "maincpu", Rename: "cpu", Skip: true, Selectable: Selectable{Setname: "first"}},
			{Name: "cpu", Selectable: Selectable{Setname: "second"}},
		}, want: "second"},
		{name: "missing shared region with override", regions: []RegCfg{
			{Name: "absent"},
			{Name: "absent", Selectable: Selectable{Setname: "first"}, Skip: true},
		}, want: "absent"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			cfg := Mame2MRA{}
			cfg.ROM.Regions, cfg.ROM.Order = tc.regions, tc.order
			machines := []ParsedMachine{
				{machine: &MachineXML{Name: "first", Rom: []MameROM{{Region: "maincpu"}, {Region: "simm1.0"}}}},
				{machine: &MachineXML{Name: "second", Rom: []MameROM{{Region: "maincpu"}}}},
			}
			for k := range machines {
				m := &machines[k]
				m.rom_regions = add_unlisted_regions(m.machine.Rom, nil)
				rename_rom_regions(cfg.ROM.Regions, m.machine.Rom, m.machine)
			}
			e := validate_rom_regions(machines, cfg)
			if tc.want == "" && e != nil { t.Fatal(e) }
			if tc.want != "" && (e == nil || !strings.Contains(e.Error(), tc.want)) {
				t.Fatalf("wanted error containing %q, got %v", tc.want, e)
			}
		})
	}
}
