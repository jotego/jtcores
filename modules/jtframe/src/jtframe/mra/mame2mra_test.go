package mra

import(
	"testing"
)

func Test_get_altdir_name(t *testing.T) {
	dirname := get_altdir_name("Teenage Mutant Hero Turtles - Turtles in Time (2 Players ver EBA)")
	if dirname!="Turtles in Time" {
		t.Log(dirname)
		t.Errorf("Bad dir name")
	}
}

func Test_collect_alt_versions(t *testing.T) {
	machine := &MachineXML{Name: "gng"}
	cfg := Mame2MRA{}
	cfg.ROM.Patches = []struct {
		Selectable
		Altversion       string
		Offset           int
		Data             string
	}{
		{ Selectable: Selectable{Setname: "gng"}, Altversion: "color", Offset: 0x10, Data: "AA" },
		{ Selectable: Selectable{Setname: "gng"}, Altversion: "color", Offset: 0x20, Data: "BB" },
		{ Selectable: Selectable{Setname: "gng"}, Altversion: "boss",  Offset: 0x30, Data: "CC" },
		{ Selectable: Selectable{Setname: "other"}, Altversion: "skip", Offset: 0x40, Data: "DD" },
	}
	versions := collect_alt_versions(machine, cfg)
	if len(versions) != 2 || versions[0] != "color" || versions[1] != "boss" {
		t.Fatalf("unexpected altversions: %#v", versions)
	}
}

func Test_patch_is_skipped(t *testing.T) {
	if !patch_is_skipped("", "hack") {
		t.Fatalf("main patch should be skipped in alt mode")
	}
	if patch_is_skipped("", "") {
		t.Fatalf("main patch should be kept in regular mode")
	}
	if patch_is_skipped("hack", "hack") {
		t.Fatalf("selected altversion should be kept")
	}
	if !patch_is_skipped("other", "hack") {
		t.Fatalf("different altversion should be skipped")
	}
}
