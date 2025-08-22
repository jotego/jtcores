// creates a random tilemap with a limited number of unique 2x2 tiles
package main

import(
	"fmt"
	"math/rand"
	"os"
)

const max_unique_tiles=6500
const fullsize = 1<<19

var tilemap tilemap_t

type tilemap_t [fullsize]uint32

func main() {
	random_map()
	save_map()
}

func random_map() {
	lower_chunks := make_valid_lower_chunks()
	for k:=0; k<len(tilemap); k+=4 {
		upper := uint32(rand.Int())&0xff
		for j:=0; j<4; j++ {
			full24bit_value := (upper<<16) | random(lower_chunks)
			tilemap[k+j] = full24bit_value
		}
	}
}

func make_valid_lower_chunks() []uint16 {
	const total_upper_chunks=256
	chunks := make([]uint16,max_unique_tiles/total_upper_chunks)
	for k,_ := range chunks {
		chunks[k] = uint16(rand.Int())
	}
	return chunks
}

func random(chunks []uint16) uint32 {
	index := rand.Int()%len(chunks)
	return uint32(chunks[index])
}

func save_map() {
	f,_ := os.Create("pscmap.hex")
	for _,value := range tilemap {
		fmt.Fprintf(f,"%X\n",value)
	}
	f.Close()
}