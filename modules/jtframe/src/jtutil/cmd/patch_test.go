package cmd

import (
	"strings"
	"testing"

	"jotego/jtframe/macros"
)

func Test_build_patches(t *testing.T) {
	macros.MakeFromMap(map[string]string{"JTFRAME_HEADER": "0"})
	base := []byte{0, 1, 2, 3, 4, 5, 6}
	hacked := []byte{0, 9, 8, 3, 4, 7, 6}
	patches, e := build_patches(base, hacked)
	if e != nil {
		t.Fatal(e)
	}
	if len(patches) != 2 {
		t.Fatalf("expected 2 patches, got %d", len(patches))
	}
	if patches[0].offset != 1 || len(patches[0].data) != 2 || patches[0].data[0] != 9 || patches[0].data[1] != 8 {
		t.Fatalf("unexpected first patch: %#v", patches[0])
	}
	if patches[1].offset != 5 || len(patches[1].data) != 1 || patches[1].data[0] != 7 {
		t.Fatalf("unexpected second patch: %#v", patches[1])
	}
}

func Test_build_patches_rejects_size_mismatch(t *testing.T) {
	macros.MakeFromMap(map[string]string{"JTFRAME_HEADER": "0"})
	_, e := build_patches([]byte{0}, []byte{0, 1})
	if e == nil {
		t.Fatalf("expected a size mismatch error")
	}
}

func Test_build_patches_subtracts_header_length(t *testing.T) {
	macros.MakeFromMap(map[string]string{"JTFRAME_HEADER": "0x20"})
	base := make([]byte, 0x50)
	hacked := make([]byte, 0x50)
	copy(hacked, base)
	hacked[0x24] = 0x9a
	patches, e := build_patches(base, hacked)
	if e != nil {
		t.Fatal(e)
	}
	if len(patches) != 1 || patches[0].offset != 0x04 {
		t.Fatalf("unexpected patches: %#v", patches)
	}
}

func Test_build_patches_rejects_header_changes(t *testing.T) {
	macros.MakeFromMap(map[string]string{"JTFRAME_HEADER": "0x20"})
	base := make([]byte, 0x40)
	hacked := make([]byte, 0x40)
	copy(hacked, base)
	hacked[0x10] = 0x55
	_, e := build_patches(base, hacked)
	if e == nil {
		t.Fatalf("expected header-region rejection")
	}
}

func Test_replace_altversion_patches(t *testing.T) {
	toml_data := `[ROM]
patches = [
    { setname="gng", offset=0x10, data="AA" },
    { altversion="old", setname="gng", offset=0x20, data="BB" },
]

[parse]
main_setnames=["gng"]
`
	updated, e := replace_altversion_patches(toml_data, "gng", "old", []rom_patch{
		{offset: 0x30, data: []byte{0x12, 0x34}},
	})
	if e != nil {
		t.Fatal(e)
	}
	if strings.Contains(updated, `offset=0x20`) {
		t.Fatalf("old altversion patch should have been removed:\n%s", updated)
	}
	if !strings.Contains(updated, `offset=0x10`) {
		t.Fatalf("unrelated patch should have been preserved:\n%s", updated)
	}
	if !strings.Contains(updated, `altversion="old"`) || !strings.Contains(updated, `offset=0x30`) {
		t.Fatalf("new patch was not inserted:\n%s", updated)
	}
}

func Test_replace_altversion_patches_inserts_block(t *testing.T) {
	toml_data := `[ROM]
order=["maincpu"]

[parse]
main_setnames=["gng"]
`
	updated, e := replace_altversion_patches(toml_data, "gng", "hack", []rom_patch{
		{offset: 0x44, data: []byte{0x99}},
	})
	if e != nil {
		t.Fatal(e)
	}
	if !strings.Contains(updated, "patches = [") || !strings.Contains(updated, `altversion="hack"`) {
		t.Fatalf("patch block not inserted:\n%s", updated)
	}
}
