/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

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
