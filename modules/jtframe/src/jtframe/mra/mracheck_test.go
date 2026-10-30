package mra

import (
	"testing"
	. "jotego/jtframe/xmlnode"
)

func Test_MRAChecker_keeps_earlier_errors(t *testing.T) {
	root := MakeNode("rom")
	bad := root.AddNode("interleave")
	bad.AddNode("part").AddAttr("name", "short").AddAttr("length", "16").AddAttr("map", "01")
	bad.AddNode("part").AddAttr("name", "long").AddAttr("length", "32").AddAttr("map", "10")
	good := root.AddNode("interleave")
	good.AddNode("part").AddAttr("length", "16").AddAttr("map", "01")
	good.AddNode("part").AddAttr("length", "16").AddAttr("map", "10")
	if e := MakeMRAChecker(&root, &MachineXML{Name: "test"}).Check(); e == nil {
		t.Fatal("valid final interleave masked an earlier error")
	}
}

func Test_MRAChecker_zero_map(t *testing.T) {
	root := MakeNode("rom")
	root.AddNode("interleave").AddNode("part").AddAttr("name", "bad").AddAttr("map", "00")
	if e := MakeMRAChecker(&root, &MachineXML{Name: "test"}).Check(); e == nil {
		t.Fatal("zero map should return an error")
	}
}
