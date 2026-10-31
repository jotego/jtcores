/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 31-10-2026 */

package mra

import (
	"strings"
	"testing"

	"jotego/jtframe/xmlnode"
)

func Test_dipsw_altversion(t *testing.T) {
	config := `[dipsw]
defaults = [
    { setname="forgottn", value="ff,fc,ff" },
    { setname="forgottn", altversion="Right stick", value="ff,fc,ff,fd" },
]
extra = [
    { name="PCB type", options="88617A,89626A", bits="24" },
    { setname="forgottn", altversion="Right stick", name="Aim control", options="Dial,Right stick", bits="25" },
]`
	cfg, err := NewMRAcfgFromTOML(strings.NewReader(config))
	if err != nil {
		t.Fatal(err)
	}
	cfg.Dipsw.Bitcnt = 24
	cfg.Dipsw.base = 16
	machine := &MachineXML{
		Name: "forgottn",
		Dipswitch: []MachineDIP{{
			Name: "Test", Tag: "DSWA", Mask: 1,
			Dipvalue: []MAMEDIPValue{{Name: "Off", Value: 0}, {Name: "On", Value: 1, Default: "yes"}},
		}},
	}
	for _, test := range []struct {
		version, defaults string
		aim               bool
	}{
		{"", "ff,fc,ff", false},
		{"Right stick", "ff,fc,ff,fd", true},
		{"Other patch", "ff,fc,ff", false},
	} {
		t.Run(test.version, func(t *testing.T) {
			root := xmlnode.MakeNode("misterromdescription")
			got := make_switches(&root, machine, cfg, Args{cur_alt_version: test.version})
			if got != test.defaults {
				t.Fatalf("default %q, want %q", got, test.defaults)
			}
			xml := root.Dump()
			if strings.Contains(xml, `name="Aim control"`) != test.aim {
				t.Fatalf("incorrect aim option: %s", xml)
			}
			if !strings.Contains(xml, `name="PCB type"`) {
				t.Fatal("common DIP option is missing")
			}
			if test.version == "" {
				base := cfg
				base.Dipsw.Defaults = base.Dipsw.Defaults[:1]
				base.Dipsw.Extra = base.Dipsw.Extra[:1]
				original := xmlnode.MakeNode("misterromdescription")
				make_switches(&original, machine, base, Args{})
				if xml != original.Dump() {
					t.Fatal("normal switches changed after adding an alternative")
				}
			}
		})
	}
}
