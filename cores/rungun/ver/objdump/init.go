package main

import "os"

func main() {
	data := make([]byte, 8192)
	for i := range data {
		data[i] = byte(i*37 + 13)
	}
	if err := os.WriteFile("objdump.bin", data, 0o644); err != nil {
		panic(err)
	}
}
