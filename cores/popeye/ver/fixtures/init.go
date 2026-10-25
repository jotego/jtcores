// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-or-later
package main

import "os"

func main() {
	timing := make([]byte, 256)
	// 7J board decode: address {HB,H[7:1]}; outputs serr,VCLK,HSY.
	for a := range timing {
		if a <= 48 || a >= 56 && a <= 127 || a == 224 || a >= 232 {
			timing[a] |= 1
		}
		if a >= 56 && a <= 59 || a >= 232 && a <= 235 {
			timing[a] |= 2
		}
		if a >= 235 && a <= 243 {
			timing[a] |= 4
		}
		if a >= 237 && a <= 245 {
			timing[a] |= 8
		}
	}
	write("timing.bin", timing)
	chars := make([]byte, 4096)
	for a := 2048; a < len(chars); a++ {
		chars[a] = byte(a*73 ^ a>>3 ^ a>>8 ^ 0xa5)
	}
	write("chars.bin", chars)
	for n, name := range []string{"obj0.bin", "obj1.bin", "obj2.bin", "obj3.bin"} {
		data := make([]byte, 8192)
		for a := range data {
			data[a] = byte(a*73 ^ a>>5 ^ n*61 ^ 0x5a)
		}
		write(name, data)
	}
	for n, name := range []string{"txtpal.bin", "bgpal.bin", "objpall.bin", "objpalh.bin"} {
		size := 256
		if n < 2 {
			size = 32
		}
		data := make([]byte, size)
		for a := range data {
			data[a] = byte(a*73 ^ a>>2 ^ n*53 ^ 0xa7)
		}
		write(name, data)
	}
}

func write(name string, data []byte) {
	if err := os.WriteFile(name, data, 0644); err != nil {
		panic(err)
	}
}
