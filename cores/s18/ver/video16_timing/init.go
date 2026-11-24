// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"encoding/binary"
	"fmt"
	"os"
)

func main() {
	writeWords("char.bin", charImage())
	writeWords("obj.bin", objectImage())
	mmr, err := os.Create("mmr.hex")
	if err != nil {
		panic(err)
	}
	for i := 0; i < 512; i++ {
		if _, err := fmt.Fprintln(mmr, "0000"); err != nil {
			panic(err)
		}
	}
	if err := mmr.Close(); err != nil {
		panic(err)
	}
}

func charImage() []uint16 {
	words := make([]uint16, 1<<11)
	for addr := range words {
		// A repeating tile code and distinct palette/priority attributes make
		// both the visible character path and scroll-table address shifts visible.
		code := uint16((addr*7 + 3) & 0xff)
		pal := uint16((addr>>2)&7) << 9
		words[addr] = pal | code
		if addr&1 == 0 {
			words[addr] |= 0x8000
		}
	}
	// S16B uses 0x780..0x7bf for column values and 0x7c0..0x7ff
	// for row values plus alternate-map selects. Keep the alternate bit clear
	// while supplying distinct scroll values for both planes.
	for addr := 0x780; addr < 0x7c0; addr++ {
		words[addr] = uint16((addr*13 + 0x35) & 0x01ff)
	}
	for addr := 0x7c0; addr < 0x800; addr++ {
		words[addr] = uint16((addr*7 + 0x12) & 0x03ff)
	}
	return words
}

func objectImage() []uint16 {
	words := make([]uint16, 1<<10)
	// Two objects cover only row 0; 62 more form a dense list for rows 1-2.
	// Each occupies eight words, followed by an explicit S16B end marker.
	for i := 0; i < 64; i++ {
		base := i * 8
		if i < 2 {
			words[base+0] = 0x0100 // top=0, bottom=1
		} else {
			words[base+0] = 0x0301 // top=1, bottom=3
		}
		words[base+1] = uint16(0x00c0 + i*5)
		words[base+2] = 1                           // pitch
		words[base+3] = uint16(0x0100 + i*0x10)     // graphics offset
		words[base+4] = uint16(0x02c0 | (i & 0x3f)) // bank, priority 3, palette
		words[base+5] = 0                           // zoom
		words[base+6] = 0
	}
	words[64*8+2] = 0x8000 // S16B EOT marker is pitch word 2
	if words[2] != 1 || words[3] != 0x0100 || words[4] != 0x02c0 || words[5] != 0 || words[64*8+2] != 0x8000 {
		panic("object table fixture layout does not match jts16_obj_scan word order")
	}
	return words
}

func writeWords(path string, words []uint16) {
	data := make([]byte, len(words)*2)
	for i, word := range words {
		binary.LittleEndian.PutUint16(data[i*2:], word)
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		panic(err)
	}
}
