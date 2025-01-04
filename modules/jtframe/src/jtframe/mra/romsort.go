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

import (
	"fmt"
	"log"
	"regexp"
	"strconv"
	"strings"
)

func apply_sort(reg_cfg *RegCfg, roms []MameROM, setname string) []MameROM {
	if len(reg_cfg.Sequence) > 0 {
		return apply_sequence(reg_cfg, roms)
	}
	if len(reg_cfg.Ext_sort) > 0 {
		sort_ext_list(reg_cfg, roms)
		return roms
	}
	if len(reg_cfg.Name_sort) > 0 {
		sort_name_list(reg_cfg, roms)
		return roms
	}
	if reg_cfg.Sort_even {
		sort_even_odd(reg_cfg, roms, true)
		return roms
	}
	return roms
}

func sort_even_odd(reg_cfg *RegCfg, roms []MameROM, even_first bool) {
	if !even_first {
		log.Fatal("even_first==false not implemented")
	}
	base := make([]MameROM, len(roms))
	copy(base, roms)
	// Copy the even ones
	for i := 0; i < len(roms); i += 2 {
		roms[i>>1] = base[i]
	}
	half := len(roms) >> 1
	// Copy the odd ones
	for i := 1; i < len(roms); i += 2 {
		roms[(i>>1)+half] = base[i]
	}
}

func sort_ext_list(reg_cfg *RegCfg, roms []MameROM) {
	base := make([]MameROM, len(roms))
	copy(base, roms)
	k := 0
	for _, ext := range reg_cfg.Ext_sort {
		for i, _ := range base {
			if strings.HasSuffix(base[i].Name, ext) {
				roms[k] = base[i]
				k++
				break
			}
		}
	}
}

func sort_name_list(reg_cfg *RegCfg, roms []MameROM) {
	// fmt.Println("Applying name sorting ", reg_cfg.Name_sort)
	base := make([]MameROM, len(roms))
	copy(base, roms)
	k := 0
	for _, each := range reg_cfg.Name_sort {
		for i, _ := range base {
			if base[i].Name == each {
				roms[k] = base[i]
				k++
				break
			}
		}
	}
}

func apply_sequence(reg_cfg *RegCfg, roms []MameROM) []MameROM {
	kmax := len(roms)
	seqd := make([]MameROM, len(reg_cfg.Sequence))
	if len(roms) == 0 {
		fmt.Printf("Warning: attempting to sort empty region %s\n", reg_cfg.Name)
		return roms
	}
	copy(seqd, roms)
	for i, k := range reg_cfg.Sequence {
		if k >= kmax {
			k = 0 // Not necessarily an error, as some ROM sets may have more files than others
		}
		seqd[i] = roms[k]
	}
	return seqd
}

func cmp_count(a, b string, rmext bool) bool {
	if rmext { // removes the file extension
		// this helps comparing file names like abc123.bin
		k := strings.LastIndex(a, ".")
		if k != -1 {
			a = a[0:k]
		}
		k = strings.LastIndex(b, ".")
		if k != -1 {
			b = b[0:k]
		}
	}
	re := regexp.MustCompile("[0-9]+")
	asub := re.FindAllString(a, -1)
	bsub := re.FindAllString(b, -1)
	kmax := len(asub)
	if len(bsub) < kmax {
		kmax = len(bsub)
	}
	low := true
	for k := 0; k < kmax; k++ {
		aint, _ := strconv.Atoi(asub[k])
		bint, _ := strconv.Atoi(bsub[k])
		if aint > bint {
			low = false
			break
		}
	}
	return low
}
