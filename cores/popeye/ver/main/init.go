// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"os"
)

func main() {
	for board := 0; board < 4; board++ {
		data := make([]byte, 65536)
		for mode := 0; mode < 2; mode++ {
			plain := make([]byte, 32768)
			copy(plain, []byte{0xc3, 0x00, 0x01})
			isr := []byte{0xf5, 0x3a, 0x00, 0x8c, 0x3c, 0x32, 0x00, 0x8c, 0x3e, 0, 0xed, 0x47, 0x3e, 1, 0xed, 0x47, 0xf1, 0xed, 0x45}
			copy(plain[0x66:], isr)
			code := []byte{0x31, 0xff, 0x8f, 0xaf, 0x32, 0x00, 0x8c}
			if mode == 0 {
				code = append(code, 0x3e, 0xa5, 0x32, 0x10, 0x8c, 0xdb, 3, 0x32, 0x11, 0x8c, 0xdb, 2, 0x32, 0x12, 0x8c)
				code = append(code, 0x3e, 7, 0xd3, 0, 0x3e, 0x3c, 0xd3, 1, 0x3e, 0x99, 0x32, 0x10, 0xc0, 0x3e, 0x66, 0x32, 0x20, 0xa0)
				code = append(code, 0x3e, 1, 0xed, 0x47, 0x3e, 0xc3, 0x32, 0x1f, 0x8c, 0x76, 0x18, 0xfd)
			} else {
				code = append(code, 0x3e, 2, 0xed, 0x47, 0x3e, 0x5a, 0x32, 0x1f, 0x8c, 0x76, 0x18, 0xfd)
			}
			copy(plain[0x100:], code)
			for a, v := range plain {
				p := a
				raw := v
				if board != 2 {
					if board == 0 {
						p = bits(a, []int{14, 13, 12, 11, 10, 8, 7, 6, 3, 9, 5, 4, 2, 1, 0}) ^ 0x3f
					} else {
						p = bits(a, []int{14, 13, 12, 11, 10, 8, 7, 0, 1, 2, 4, 5, 9, 3, 6}) ^ 0xfc
					}
					// Invert MAME's data permutation to put a synthetic instruction on pins.
					raw = byte(bits(int(v), []int{0, 2, 4, 6, 7, 5, 3, 1}))
				}
				data[mode*32768+p] = raw
			}
		}
		f, e := os.Create(fmt.Sprintf("main%d.hex", board))
		if e != nil {
			panic(e)
		}
		for _, b := range data {
			fmt.Fprintf(f, "%02x\n", b)
		}
		if e = f.Close(); e != nil {
			panic(e)
		}
	}
}
func bits(a int, order []int) int {
	r := 0
	for _, b := range order {
		r = r<<1 | ((a >> b) & 1)
	}
	return r
}
