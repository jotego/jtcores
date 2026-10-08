/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package mra

import(
	"fmt"
	"strings"

	"jotego/jtframe/macros"
	. "jotego/jtframe/xmlnode"
)

const (
	COREMOD_LIGHTGUN_BIT = 1
	COREMOD_VFRAME_BIT   = 3
	COREMOD_HFRAME_BIT   = 5
	COREMOD_VOLUME_BIT   = 8
	COREMOD_DIAL_BIT     = 16

	COREMOD_VERTICAL     = 1
	COREMOD_XORFLIP      = 4
	COREMOD_DIAL_ENABLE  = 1<<COREMOD_DIAL_BIT
	COREMOD_DIAL_REVERSE = 1<<(COREMOD_DIAL_BIT+1)
	COREMOD_VFRAME_MASK  = uint(3)<<COREMOD_VFRAME_BIT
	COREMOD_HFRAME_MASK  = uint(3)<<COREMOD_HFRAME_BIT
	COREMOD_LIGHTGUN     = 1<<COREMOD_LIGHTGUN_BIT
	COREMOD_UNITY_VOLUME = 0x80
	COREMOD_8PXL_FRAME   = 1
	COREMOD_16PXL_FRAME  = 3
)

type coreMOD struct {
	wdiff, hdiff int
	coremod uint
}

func make_coreMOD(root *XMLNode, machine *MachineXML, cfg Mame2MRA) int {
	var mod coreMOD
	mod.encode_settings(machine,cfg)
	mod.makeXML(root)
	return int(mod.coremod)
}

func (mod *coreMOD) encode_settings(machine *MachineXML, cfg Mame2MRA) {
	mod.encode_rotation(machine, cfg.Global.Orientation.Fixed)
	mod.encode_dial(machine, cfg)
	mod.encode_gun(machine)
	mod.screenSize(machine, cfg)
	mod.encode_volume_cfg(machine, cfg)
}

func (mod coreMOD) makeXML(root *XMLNode) {
	if mod.coremod!=0 {
		description := mod.describe_encoding()
		if description != "" {
			root.AddComment(description)
		}
	}
	rom := root.AddNode("rom").AddAttr("index", "1")
	mod.add_ROM_part(rom)
}

func (mod coreMOD) describe_encoding() string {
	var sb strings.Builder
	is_vertical := (mod.coremod&COREMOD_VERTICAL)    !=0
	is_xorflip  := (mod.coremod&COREMOD_XORFLIP)     !=0
	is_dial		:= (mod.coremod&COREMOD_DIAL_ENABLE) !=0
	is_dial_rev := (mod.coremod&COREMOD_DIAL_REVERSE)!=0
	is_gun      := (mod.coremod&COREMOD_LIGHTGUN)    !=0
	has_hframe  := (mod.coremod&COREMOD_HFRAME_MASK) !=0
	has_vframe  := (mod.coremod&COREMOD_VFRAME_MASK) !=0
	if is_vertical {
		sb.WriteString("Vertical screen. ")
	}
	if is_xorflip {
		sb.WriteString("Orientation reversed. ")
	}
	if is_gun {
		sb.WriteString("Light gun ")
	}
	if is_dial {
		sb.WriteString("Dial controller")
		if is_dial_rev {
			sb.WriteString(" reversed")
		}
		sb.WriteString(". ")
	}
	if has_hframe {
		switch mod.get_frame(COREMOD_HFRAME_BIT) {
			case COREMOD_8PXL_FRAME:  sb.WriteString("8-pxl black frame on sides. ")
			case COREMOD_16PXL_FRAME: sb.WriteString("16-pxl black frame on sides. ")
		}
	}
	if has_vframe {
		switch mod.get_frame(COREMOD_VFRAME_BIT) {
			case COREMOD_8PXL_FRAME:  sb.WriteString("8-line black frame on top/bottom. ")
			case COREMOD_16PXL_FRAME: sb.WriteString("16-line black frame on top/bottom. ")
		}
	}
	desc := sb.String()
	if desc=="" { return desc }
	trailing_space := len(desc)-1
	trimmed := desc[0:trailing_space]
	return trimmed
}

func (mod coreMOD) add_ROM_part(rom *XMLNode) {
	hexdump := fmt.Sprintf("%02X %02X", mod.coremod&0xFF, (mod.coremod>>8)&0xff)
	if mod.coremod>>16 != 0 {
		hexdump = fmt.Sprintf("%s %02X", hexdump, (mod.coremod>>16)&0xff)
	}
	rom.AddNode("part").SetText(hexdump)
}

func (mod *coreMOD) encode_rotation(machine *MachineXML, is_fixed bool) {
	if machine.Display.Rotate!=0 && machine.Display.Rotate!=180 {
		mod.coremod |= COREMOD_VERTICAL
		if machine.Display.Rotate != 90 && !is_fixed {
			mod.coremod |= COREMOD_XORFLIP
		}
	}
}

func (mod *coreMOD) encode_dial(machine *MachineXML, cfg Mame2MRA) {
	for _, dial := range cfg.Buttons.Dial {
		if dial.Match(machine)>0 {
			if dial.Raw {
				mod.coremod |= COREMOD_DIAL_ENABLE
			}
			if dial.Reverse {
				mod.coremod |= COREMOD_DIAL_REVERSE
			}
		}
	}
}

func (mod *coreMOD) encode_gun(machine *MachineXML) {
	for _, control := range machine.Input.Control {
		if control.Type=="lightgun" {
			mod.coremod |= COREMOD_LIGHTGUN
			return
		}
	}
}

// compares screen size with MAME
func (mod *coreMOD)screenSize(machine *MachineXML, cfg Mame2MRA) {
	cw := macros.GetInt("JTFRAME_WIDTH")
	ch := macros.GetInt("JTFRAME_HEIGHT")
	mod.wdiff = (int(cw)-machine.Display.Width)/2
	mod.hdiff = (int(ch)-machine.Display.Height)/2
	if frame_idx := bestMatch(len(cfg.Header.Frames), func(k int) int {
		return cfg.Header.Frames[k].Match(machine)
	}); frame_idx >= 0 {
		mod.wdiff = cfg.Header.Frames[frame_idx].Width
	}
	mod.encode_frame(machine,"horizontal",mod.wdiff,COREMOD_HFRAME_BIT)
	mod.encode_frame(machine,"vertical",  mod.hdiff,COREMOD_VFRAME_BIT)
}

func (mod *coreMOD)encode_frame(machine *MachineXML, axis string, frame, bit int) {
	switch frame {
		case 0:  break
		case 8:  mod.coremod |= 1<<bit
		case 16: mod.coremod |= 3<<bit
		default: if frame>0 {
			fmt.Printf("%s: unsupported %s black frame of %d pixels/lines per side\nDefine one explicitly in the TOML file.\n",
				machine.Name,axis,frame)
		}
	}
}

func (mod *coreMOD)encode_volume_cfg(machine *MachineXML, cfg Mame2MRA) {
	best := 0
	for _, volume := range cfg.Audio.Volume {
		if lvl := volume.Match(machine); lvl>best {
			best = lvl
			mod.set_volume(volume.Value)
		}
	}
	const TOO_QUIET=0x10
	is_too_quiet := mod.get_volume() < TOO_QUIET
	if is_too_quiet {
		mod.set_volume(COREMOD_UNITY_VOLUME)
	}
}

func (mod *coreMOD)set_volume(vol int) {
	masked := uint(vol&0xFF)
	mod.coremod &= ^(uint(0xFF)<<COREMOD_VOLUME_BIT)
	mod.coremod |= masked << COREMOD_VOLUME_BIT
}

func (mod *coreMOD)get_volume() int {
	vol := mod.coremod>>COREMOD_VOLUME_BIT
	masked := vol & 0xFF
	return int(masked)
}

func (mod *coreMOD)get_frame(bit int) int {
	frame  := mod.coremod>>bit
	masked := frame & 3
	return int(masked)
}
