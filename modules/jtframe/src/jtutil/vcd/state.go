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

import(
    "fmt"
    "strings"
    "sort"
)

type SimState struct{
	data vcdData
	ram []byte
}

type MAMEState struct{
	data NameValue
	mask NameValue
	alias mameAlias
	ram []byte
}

type mameAlias map[string]*VCDSignal
type NameValue map[string]uint64

func (st MAMEState)validate(name string) bool {
    _, valid := st.data[name]
    return valid
}

func (mame_st *MAMEState) get_sorted_name_indexes() (names []string) {
    names = make([]string,len(mame_st.data))
    k := 0
    for n,_ := range mame_st.data {
        names[k]=n
        k++
    }
    sort.Slice(names,func(i,j int) bool { return strings.Compare(names[i],names[j])<0})
    return names
}

func (mame_st *MAMEState) print_registers(all_names []string) {
    for _,name := range all_names {
        format := "%-2s=0x%X\n"
        if name=="frame_cnt" {
            format = "%-2s=%d\n"
        }
        fmt.Printf( format, name, mame_st.data[name] )
    }
}
