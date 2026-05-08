/*  This file is part of JTCORES.
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

package vcd

import (
	"fmt"
	"strings"
)

func find_similar(name string, ss VCDData) string {
	pc := ""
	for _, each := range ss {
		vcd_name := strings.ToLower(each.Name)
		vcd_name = strings.TrimPrefix(vcd_name, "trace_")
		if vcd_name == name {
			pc = each.FullName()
			break
		}
	}
	if pc == "" {
		// Try a partial match at the beginning of the name
		for _, each := range ss {
			if strings.Index(strings.ToLower(each.Name), name) == 0 {
				pc = each.FullName()
				break
			}
		}
	}
	if pc == "" {
		fmt.Printf("Could not find a suitable signal as '%s' in the VCD\n", name)
	} else {
		fmt.Printf("Using %s as '%s'\n", name, pc)
	}
	return pc
}

func MakeAlias(trace *TraceReader, ss VCDData) mameAlias {
	mame_alias := make(mameAlias)
	if trace == nil || len(trace.header) == 0 {
		return mame_alias
	}

	for _, name := range trace.header {
		mame_name := strings.TrimSpace(name)
		if strings.EqualFold(mame_name, "frame_cnt") {
			continue
		}
		var p *VCDSignal
		for _, v := range ss {
			vcd_name := strings.ToLower(strings.TrimPrefix(v.Name, "TRACE_"))
			if strings.EqualFold(vcd_name, mame_name) {
				p = v
				break
			}
		}
		if p == nil {
			fmt.Printf("Cannot alias signal %s\n", mame_name)
			continue
		}
		mame_alias[mame_name] = p
	}
	return mame_alias
}
