package main

import (
	"bufio"
	"fmt"
	"os"
)

func main() {
	const (
		saveAW      = 14
		wordCount   = 1 << saveAW
		loFilename  = "save_lo.hex"
		hiFilename  = "save_hi.hex"
	)

	loFile, err := os.Create(loFilename)
	if err != nil {
		panic(err)
	}
	defer loFile.Close()
	lo := bufio.NewWriter(loFile)

	hiFile, err := os.Create(hiFilename)
	if err != nil {
		panic(err)
	}
	defer hiFile.Close()
	hi := bufio.NewWriter(hiFile)

	for w := 0; w < wordCount; w++ {
		loByte := byte((2 * w) & 0xFF)
		hiByte := byte((2*w + 1) & 0xFF)
		fmt.Fprintf(lo, "%02X\n", loByte)
		fmt.Fprintf(hi, "%02X\n", hiByte)
	}

	if err := lo.Flush(); err != nil {
		panic(err)
	}
	if err := hi.Flush(); err != nil {
		panic(err)
	}
}
