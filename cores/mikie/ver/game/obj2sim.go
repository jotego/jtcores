package main

import (
	"io/ioutil"
	"log"
	"os"
)

func save(buff []byte, fname string) {
	f, err := os.Create(fname)
	if err != nil {
		log.Fatal(err)
	}
	f.Write(buff)
	f.Close()
}

func main() {
	filename := os.Args[1]
	datain, err := ioutil.ReadFile(filename)
	if err != nil {
		log.Fatal(err)
	}
	var lo, hi [1024]byte
	for k, j := 0, 0; k < len(datain); k += 4 {
		lo[j+0] = datain[k+0]
		lo[j+1] = datain[k+1]
		hi[j+0] = datain[k+3]
		hi[j+1] = datain[k+2]
		j += 2
	}
	save(lo[:], "obj1.bin")
	save(hi[:], "obj2.bin")
}
