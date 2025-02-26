/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 4-1-2025 */

package mra

import(
	"fmt"
	"strings"

	"jotego/jtframe/macros"
	. "jotego/jtframe/xmlnode"
)

const (
	COREMOD_LIGHTGUN_BIT = 1
	COREMOD_HFRAME_BIT   = 5
	COREMOD_VOLUME_BIT   = 8

	COREMOD_VERTICAL     = 1
	COREMOD_XORFLIP      = 4
	COREMOD_DIAL_ENABLE  = 1<<3
	COREMOD_DIAL_REVERSE = 1<<4
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
	has_frame   := (mod.coremod&COREMOD_HFRAME_MASK) !=0
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
	if has_frame {
		switch mod.get_hframe() {
			case COREMOD_8PXL_FRAME:  sb.WriteString(" 8-pxl black frame on sides. ")
			case COREMOD_16PXL_FRAME: sb.WriteString("16-pxl black frame on sides. ")
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
	if mod.wdiff<0 || mod.hdiff<0 {
		mod.wdiff=0
		mod.hdiff=0
	}
	explicit := false
	if frame_idx := bestMatch(len(cfg.Header.Frames), func(k int) int {
		return cfg.Header.Frames[k].Match(machine)
	}); frame_idx >= 0 {
		mod.wdiff = cfg.Header.Frames[frame_idx].Width
		explicit = true
	}
	if mod.hdiff != 0 && !explicit {
		fmt.Printf("%s: core and MAME screen sizes differ. Remove top/bottom black frame (%d pixels total)\n",
			machine.Name, mod.hdiff)
	}
	switch mod.wdiff {
		case 0: break
		case 8:  mod.coremod |= 1<<COREMOD_HFRAME_BIT
		case 16: mod.coremod |= 3<<COREMOD_HFRAME_BIT
		default: if mod.wdiff>0 {
			fmt.Printf("%s: unsupported black frame of %d pixels around the image\nDefine one explicitly in the TOML file.\n",
				machine.Name,mod.wdiff)
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

func (mod *coreMOD)get_hframe() int {
	frame  := mod.coremod>>COREMOD_HFRAME_BIT
	masked := frame & 3
	return int(masked)
}