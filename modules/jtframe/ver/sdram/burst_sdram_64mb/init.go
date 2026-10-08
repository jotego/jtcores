package main

import (
	"bufio"
	"os"
)

const (
	fileName  = "sdram_bank3.bin"
	fileBytes = 16 * 1024 * 1024
	seed      = uint64(0x64b51d397ac4e812)
)

func next(state *uint64) byte {
	*state ^= *state << 13
	*state ^= *state >> 7
	*state ^= *state << 17
	return byte(*state >> 24)
}

func main() {
	f, err := os.Create(fileName)
	if err != nil {
		panic(err)
	}
	defer f.Close()

	w := bufio.NewWriterSize(f, 1<<20)
	defer w.Flush()

	buf := make([]byte, 1<<16)
	state := seed
	remaining := fileBytes
	for remaining > 0 {
		chunk := len(buf)
		if chunk > remaining {
			chunk = remaining
		}
		for i := 0; i < chunk; i++ {
			buf[i] = next(&state)
		}
		if _, err := w.Write(buf[:chunk]); err != nil {
			panic(err)
		}
		remaining -= chunk
	}
}
