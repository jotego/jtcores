package main

import (
	"fmt"
	"io/ioutil"
	"log"
)

func main() {
	buffer, e := ioutil.ReadFile("rom.bin")
	if e != nil {
		log.Fatal(e)
	}
	var sum uint16
	for k := 0x10000; k < 0x14000; k++ {
		sum += uint16(buffer[k])
	}
	fmt.Printf("%X\n", sum)
}
