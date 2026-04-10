package main

import "os"

func main() {
	data := make([]byte, 16)
	for i := range data {
		data[i] = byte(0x10 + i)
	}
	if e := os.WriteFile("ram_load.bin", data, 0o644); e != nil {
		panic(e)
	}
}
