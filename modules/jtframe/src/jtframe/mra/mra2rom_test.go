package mra

import (
	"bytes"
	"testing"

	"jotego/jtframe/xmlnode"
)

func Test_RomBytes_accepts_embedded_part_without_zip(t *testing.T) {
	root := xmlnode.MakeNode("misterromdescription")
	root.AddNode("setname", "embedded")
	rom := root.AddNode("rom").AddAttr("index", "0").AddAttr("zip", "missing.zip")
	rom.AddNode("part", "85 00 5A FF")
	got, e := RomBytes(&root, t.TempDir(), false); if e!=nil { t.Fatal(e) }
	want := []byte{0x85, 0x00, 0x5a, 0xff}
	if !bytes.Equal(got, want) {
		t.Fatalf("embedded ROM mismatch: got % X want % X", got, want)
	}
}

func Test_RomBytes_still_requires_zip_for_named_part(t *testing.T) {
	root := xmlnode.MakeNode("misterromdescription")
	root.AddNode("setname", "named")
	rom := root.AddNode("rom").AddAttr("index", "0").AddAttr("zip", "missing.zip")
	rom.AddNode("part").AddAttr("name", "missing.bin")
	_, e := RomBytes(&root, t.TempDir(), false); if e==nil {
		t.Fatal("expected named ROM part to require a zip file")
	}
}
