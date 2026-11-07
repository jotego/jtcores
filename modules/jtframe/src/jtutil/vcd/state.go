/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package vcd

import (
	"fmt"
	"sort"
	"strings"
)

type SimState struct {
	data VCDData
	ram  []byte
}

type MAMEState struct {
	data  NameValue
	mask  NameValue
	alias mameAlias
	asm   string
	ram   []byte
}

type mameAlias map[string]*VCDSignal
type NameValue map[string]uint64

func (st MAMEState) validate(name string) bool {
	_, valid := st.data[name]
	return valid
}

func (mame_st *MAMEState) get_sorted_name_indexes() (names []string) {
	names = make([]string, len(mame_st.data))
	k := 0
	for n, _ := range mame_st.data {
		names[k] = n
		k++
	}
	sort.Slice(names, func(i, j int) bool { return strings.Compare(names[i], names[j]) < 0 })
	return names
}

func (mame_st *MAMEState) print_registers(all_names []string) {
	for _, name := range all_names {
		format := "%-2s=0x%X\n"
		if name == "frame_cnt" {
			format = "%-2s=%d\n"
		}
		fmt.Printf(format, name, mame_st.data[name])
	}
}
