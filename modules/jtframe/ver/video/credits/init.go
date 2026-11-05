package main

import (
	"fmt"
	"os"
)

// Every page, tile row, and tile column gets a distinguishable palette. The
// glyph varies by row and x bit so the pixel oracle can detect both source
// coordinate and glyph-bit reversal errors.
func main() {
	for page := 0; page < 5; page++ {
		f, err := os.Create(fmt.Sprintf("msg%d.bin", page))
		if err != nil {
			panic(err)
		}
		for row := 0; row < 32; row++ {
			for col := 0; col < 32; col++ {
				pal := (page + 3*col + 5*row) & 3
				word := pal<<7 | (page + 1) // each page uses its own glyph
				if _, err := fmt.Fprintf(f, "%09b\n", word); err != nil {
					panic(err)
				}
			}
		}
		if err := f.Close(); err != nil {
			panic(err)
		}
	}

	f, err := os.Create("font0.hex")
	if err != nil {
		panic(err)
	}
	for addr := 0; addr < 1024; addr++ {
		char, row := addr>>3, addr&7
		value := 0
		if char >= 1 && char <= 5 {
			// Page-specific asymmetric glyphs. Source x=0 is font bit 7.
			value = int(byte(0x81 ^ (0x11 << uint((row+char)&3)) ^ (char * 0x13)))
		}
		if _, err := fmt.Fprintf(f, "%02x\n", value&0xff); err != nil {
			panic(err)
		}
	}
	if err := f.Close(); err != nil {
		panic(err)
	}
}
