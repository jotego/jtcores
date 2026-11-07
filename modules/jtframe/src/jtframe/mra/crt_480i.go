/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-11-2026 */

package mra

import (
	"strings"

	. "jotego/jtframe/xmlnode"
)

func (args Args) dump_crt_480i_mra(machine *MachineXML, cfg Mame2MRA, root *XMLNode, coremod int, parent_names map[string]string) {
	if cfg.Video.Interleaved_MRAs==nil || !machine.IsMatch(cfg.Video.Interleaved_MRAs) { return }
	name := root.GetNode("name")
	rom := root.FindMatch(func(n *XMLNode) bool { return n.GetName()=="rom" && n.GetAttr("index")=="1" })
	part := rom.GetNode("part")
	native_name, native_mod := name.GetText(), part.GetText()
	// Restore the native tree before Pocket generation or other consumers use it.
	defer func() {
		name.SetText(native_name)
		part.SetText(native_mod)
	}()
	name.SetText(crt_480i_name(native_name))
	mod := coreMOD{coremod: uint(coremod)|COREMOD_CRT480I}
	part.SetText(mod.hex_string())
	dump_mra(args, machine, cfg, root, parent_names)
}

func crt_480i_name(name string) string {
	version := strings.Index(name, "(")
	if version<0 { return name+" (15kHz)" }
	return strings.TrimRight(name[:version], " ")+" (15kHz) "+name[version:]
}
