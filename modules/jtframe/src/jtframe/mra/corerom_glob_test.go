package mra

import (
	"testing"

	"jotego/jtframe/xmlnode"
)

func Test_find_region_cfg_matches_glob(t *testing.T) {
	cfg := Mame2MRA{}
	cfg.ROM.Regions = []RegCfg{
		{Name: "simm3.?"},
	}
	reg_cfg := find_region_cfg(&MachineXML{Name: "sfiiin"}, "simm3.0", cfg)
	if reg_cfg.Name != "simm3.?" {
		t.Fatalf("expected glob config, got %q", reg_cfg.Name)
	}
}

func Test_find_region_cfg_prefers_exact_match(t *testing.T) {
	cfg := Mame2MRA{}
	cfg.ROM.Regions = []RegCfg{
		{Name: "simm3.?"},
		{Name: "simm3.0", Start: "JTFRAME_BA1_START"},
	}
	reg_cfg := find_region_cfg(&MachineXML{Name: "sfiiin"}, "simm3.0", cfg)
	if reg_cfg.Name != "simm3.0" {
		t.Fatalf("expected exact config, got %q", reg_cfg.Name)
	}
}

func Test_extract_region_matches_glob(t *testing.T) {
	reg_cfg := &RegCfg{Name: "simm3.?"}
	roms := []MameROM{
		{Name: "sfiii-simm3.0", Region: "simm3.0"},
		{Name: "skip-me", Region: "simm3.1"},
		{Name: "sfiii-simm3.2", Region: "simm3.2"},
		{Name: "other", Region: "simm4.0"},
	}
	got, e := reg_cfg.extract_region(roms, []string{"skip-me"})
	if e != nil {
		t.Fatalf("unexpected error: %v", e)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 ROMs, got %d", len(got))
	}
	if got[0].Region != "simm3.0" || got[1].Region != "simm3.2" {
		t.Fatalf("unexpected regions: %#v", got)
	}
}

func Test_extract_region_glob_without_matches_errors(t *testing.T) {
	reg_cfg := &RegCfg{Name: "simm3.?"}
	_, e := reg_cfg.extract_region([]MameROM{{Name: "other", Region: "simm4.0"}}, nil)
	if e == nil {
		t.Fatalf("expected missing glob match error")
	}
}

func Test_collect_rom_regions_collapses_globbed_order(t *testing.T) {
	cfg := Mame2MRA{}
	cfg.ROM.Order = []string{"bios", "simm3.0", "simm3.1", "simm3.2", "simm4.0"}
	cfg.ROM.Regions = []RegCfg{
		{Name: "simm3.?"},
		{Name: "simm4.0"},
	}
	roms := []MameROM{
		{Region: "bios"},
		{Region: "simm3.0"},
		{Region: "simm3.1"},
		{Region: "simm3.2"},
		{Region: "simm4.0"},
	}
	got := collect_rom_regions(roms, cfg, &MachineXML{Name: "sfiiin"})
	want := []string{"bios", "simm3.0", "simm4.0"}
	if len(got) != len(want) {
		t.Fatalf("expected %v, got %v", want, got)
	}
	for k := range want {
		if got[k] != want[k] {
			t.Fatalf("expected %v, got %v", want, got)
		}
	}
}

func make_interleave_maps(t *testing.T, reg_cfg *RegCfg) []string {
	t.Helper()
	root := xmlnode.MakeNode("rom")
	roms := []MameROM{
		{Name: "upper-even", Region: "sprites", Size: 0x10, Offset: 0},
		{Name: "upper-odd", Region: "sprites", Size: 0x10, Offset: 1},
	}
	pos := 0
	make_interleave_groups("sprites", roms, reg_cfg, &root, &MachineXML{}, Mame2MRA{}, &pos)
	interleave := root.GetNode("interleave")
	if interleave == nil {
		t.Fatal("missing generated interleave")
	}
	maps := make([]string, 0, 2)
	for _, each := range interleave.GetChildren() {
		maps = append(maps, each.GetAttr("name")+":"+each.GetAttr("map"))
	}
	return maps
}

func Test_get_reverse_group_uses_file_overrule(t *testing.T) {
	reg_cfg := &RegCfg{Reverse: true}
	reg_cfg.Overrules = []struct {
		Names   []string
		Reverse bool
	}{
		{Names: []string{"upper-even", "upper-odd"}, Reverse: false},
	}
	if !get_reverse_group(reg_cfg, []MameROM{{Name: "lower", group: 0}}) {
		t.Fatal("expected the single lower ROM to be reversed")
	}
	upper_group := []MameROM{{Name: "upper-even", group: 1}, {Name: "upper-odd", group: 1}}
	if get_reverse_group(reg_cfg, upper_group) {
		t.Fatal("expected the upper interleave group to use its file overrule")
	}
	if !get_reverse_group(reg_cfg, []MameROM{{Name: "upper-even", group: 1}, {Name: "lower", group: 1}}) {
		t.Fatal("mixed interleave groups must keep the region-wide order")
	}
}

func Test_make_interleave_groups_overrule(t *testing.T) {
	reg_cfg := &RegCfg{Width: 16, Reverse: true}
	reg_cfg.Overrules = []struct {
		Names   []string
		Reverse bool
	}{
		{Names: []string{"upper-even", "upper-odd"}, Reverse: false},
	}
	got := make_interleave_maps(t, reg_cfg)
	want := []string{"upper-even:01", "upper-odd:10"}
	for k := range want {
		if got[k] != want[k] {
			t.Fatalf("part %d: got %q, want %q", k, got[k], want[k])
		}
	}
}

func Test_make_interleave_groups_without_overrule_is_unchanged(t *testing.T) {
	legacy_cfg := &RegCfg{Width: 16, Reverse: true}
	got := make_interleave_maps(t, legacy_cfg)
	want := []string{"upper-odd:01", "upper-even:10"}
	for k := range want {
		if got[k] != want[k] {
			t.Fatalf("part %d: got %q, want %q", k, got[k], want[k])
		}
	}
}
