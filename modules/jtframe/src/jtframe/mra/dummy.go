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

//go:build !pocket

package mra

import "fmt"

var pocket_warning bool

func pocket_add(machine *MachineXML, cfg Mame2MRA, args Args, def_dipsw string, coremod int, mra *XMLNode) {
	if Verbose && !pocket_warning {
		fmt.Println("****  Skipping Pocket file generation ****")
		pocket_warning = true
	}
	// Does nothing
}

func pocket_init(cfg Mame2MRA, args Args) {
	// Does nothing
}

func pocket_save() {
	// Does nothing
}

func pocket_pico( data []byte ) {
	// Does nothing
}

func pocket_clear() {
	// Does nothing
}
