/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-11-2026 */

package mra

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	. "jotego/jtframe/xmlnode"
)

func Test_dump_crt_480i_preserves_native(t *testing.T) {
	for _, dial := range []uint{0, COREMOD_DIAL_ENABLE|COREMOD_DIAL_REVERSE} {
		t.Run(fmt.Sprintf("dial=%x", dial), func(t *testing.T) {
			dir := t.TempDir()
			args := Args{outdir: dir, altdir: filepath.Join(dir, "_alternatives")}
			machine := &MachineXML{Name: "narc", Description: "Narc (rev 7.00)"}
			cfg := Mame2MRA{}
			cfg.Video.Interleaved_MRAs = &Selectable{Machine: "narc"}
			root := MakeNode("misterromdescription")
			root.AddNode("name", machine.Description)
			root.AddNode("setname", machine.Name)
			root.AddNode("rbf", "jtnarc")
			root.AddNode("rom").AddAttr("index", "0").AddAttr("asm_md5", "payload-checksum").AddNode("part", "AA BB CC DD")
			mod := coreMOD{coremod: 0xb500|dial}
			mod.makeXML(&root)
			native := root.Dump()
			args.dump_crt_480i_mra(machine, cfg, &root, int(mod.coremod), nil)
			if root.Dump()!=native { t.Fatal("interlaced MRA changed the native tree") }
			path := filepath.Join(dir, "Narc (15kHz) (rev 7.00).mra")
			interlaced, e := ReadFile(path); if e!=nil { t.Fatal(e) }
			part := interlaced.FindMatch(func(n *XMLNode) bool { return n.GetName()=="rom" && n.GetAttr("index")=="1" }).GetNode("part")
			want := "00 B5 04"
			if dial!=0 { want="00 B5 07" }
			if part.GetText()!=want { t.Fatalf("mod bytes: got %q, want %q", part.GetText(), want) }
			interlaced.GetNode("name").SetText(machine.Description)
			part.SetText(mod.hex_string())
			// Parsed XML omits comments, so compare its payload and metadata directly.
			if interlaced.GetNode("rbf").GetText()!="jtnarc" || interlaced.GetNode("setname").GetText()!="narc" { t.Fatal("variant changed RBF or setname") }
			payload := interlaced.GetNode("rom")
			if payload.GetAttr("asm_md5")!="payload-checksum" || payload.GetNode("part").GetText()!="AA BB CC DD" { t.Fatal("variant changed game ROM or its checksum") }
		})
	}
}

func Test_Convert_crt_480i(t *testing.T) {
	root := t.TempDir()
	init_test_git(t, root)
	t.Setenv("JTROOT", root)
	t.Setenv("CORES", filepath.Join(root, "cores"))
	t.Setenv("JTFRAME", filepath.Join(root, "modules", "jtframe"))
	write := func(name, data string) {
		t.Helper()
		path := filepath.Join(root, name)
		if e := os.MkdirAll(filepath.Dir(path), 0775); e!=nil { t.Fatal(e) }
		if e := os.WriteFile(path, []byte(data), 0664); e!=nil { t.Fatal(e) }
	}
	write("cores/video/cfg/macros.def", "CORENAME=JTVIDEO\nJTFRAME_WIDTH=512\nJTFRAME_HEIGHT=400\nJTFRAME_LF_HW=9\nJTFRAME_LF_VW=9\nJTFRAME_PXLCLK=6\nJTFRAME_CRT480I\n")
	config := `[parse]
sourcefile=["video.cpp"]
%s
[cheat]
disable=true
[Audio]
volume=[{value=0xB5}]
[ROM]
order=["maincpu"]
regions=[{name="maincpu"}]
patches=[{altversion="test", offset=0, data="FF"}]
`
	write("doc/mame.xml", `<mame build="0.280">
<machine name="video" sourcefile="video.cpp"><description>Video (rev 2)</description><rom name="code.bin" size="16" region="maincpu" offset="0"/><display width="512" height="400" rotate="0"/></machine>
<machine name="video1" cloneof="video" sourcefile="video.cpp"><description>Video (rev 1)</description><rom name="code.bin" size="16" region="maincpu" offset="0"/><display width="512" height="400" rotate="0"/></machine>
</mame>`)
	args := Args{Core: "video", Target: "mister", SkipROM: true, SkipPocket: true, Xml_path: filepath.Join(root,"doc/mame.xml")}
	for _, selection := range []struct{
		name, selector string
		parent, clone, promoted bool
	}{
		{name: "omitted"},
		{name: "machine", selector: `machine="video"`, parent: true, clone: true},
		{name: "machines", selector: `machines=["other","video"]`, parent: true, clone: true},
		{name: "setname parent", selector: `setname="video"`, parent: true},
		{name: "setname clone", selector: `setname="video1"`, clone: true},
		{name: "promoted clone", selector: `setname="video1"`, clone: true, promoted: true},
		{name: "setnames", selector: `setnames=["video","video1"]`, parent: true, clone: true},
		{name: "unmatched", selector: `machine="other"`},
	} {
		t.Run(selection.name, func(t *testing.T) {
			video := ""
			if selection.selector!="" { video="[video]\ninterleaved_MRAs={"+selection.selector+"}" }
			selected_config := fmt.Sprintf(config, video)
			if selection.promoted { selected_config=strings.Replace(selected_config,"[parse]","[parse]\nmain_setnames=[\"video1\"]",1) }
			write("cores/video/cfg/mame2mra.toml", selected_config)
			if e := os.RemoveAll(filepath.Join(root,"release/mra")); e!=nil { t.Fatal(e) }
			if e := args.Convert(); e!=nil { t.Fatal(e) }
			for _, set := range []struct{
				name, folder string
				enabled bool
			}{
				{"Video (rev 2)", "", selection.parent},
				{"Video (rev 1)", "_alternatives/_Video", selection.clone},
			} {
				if selection.promoted { set.folder="" }
				dir := filepath.Join(root,"release/mra",set.folder)
				native, e := os.ReadFile(filepath.Join(dir,set.name+".mra")); if e!=nil { t.Fatal(e) }
				if !strings.Contains(string(native),"<part>00 B5</part>") { t.Fatal("native mod changed") }
				variant, e := os.ReadFile(filepath.Join(dir,crt_480i_name(set.name)+".mra"))
				if !set.enabled {
					if !os.IsNotExist(e) { t.Fatalf("disabled option generated variant: %v",e) }
					continue
				}
				if e!=nil { t.Fatal(e) }
				want := strings.Replace(string(native),"<name>"+set.name+"</name>","<name>"+crt_480i_name(set.name)+"</name>",1)
				want = strings.Replace(want,"<part>00 B5</part>","<part>00 B5 04</part>",1)
				if string(variant)!=want { t.Fatal("variant changed more than name and mod bit 18") }
			}
		})
	}
	video := "[video]\ninterleaved_MRAs={machine=\"video\"}"
	write("cores/video/cfg/mame2mra.toml", fmt.Sprintf(config,video))
	if e := args.Convert(); e!=nil { t.Fatal(e) }
	args.Alt=true
	if e := args.Convert(); e!=nil { t.Fatal(e) }
	for _, name := range []string{"Video (15kHz) (rev 2)","Video (15kHz) (rev 1)"} {
		path := filepath.Join(root,"release/mra/_alternatives/_Video","(test)"+name+".mra")
		if _, e := os.Stat(path); e!=nil { t.Fatal(e) }
	}
	args.SkipMRA=true
	args.Alt=false
	if e := os.RemoveAll(filepath.Join(root,"release/mra")); e!=nil { t.Fatal(e) }
	if e := args.Convert(); e!=nil { t.Fatal(e) }
	if _, e := os.Stat(filepath.Join(root,"release/mra")); !os.IsNotExist(e) { t.Fatal("--skipMRA generated MRAs") }
}
