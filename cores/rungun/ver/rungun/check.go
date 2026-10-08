package main

import(
	"fmt"
	"os"
)

func main() {
	dump, e := os.ReadFile("hot1.bin"); if e!=nil { fmt.Println(e); os.Exit(1) }
	rom,  e := os.ReadFile("rom.bin");  if e!=nil { fmt.Println(e); os.Exit(1) }
	found := false
	longest := 0
	for rom0 := 0; rom0<len(rom)-len(dump); rom0++ {
		var cur int
		found, cur = matched(dump,rom,rom0)
		if cur > longest { longest = cur }
		if found {
			fmt.Printf("Found at $%X\n",rom0)
			break
		}
	}
	if !found {
		fmt.Printf("Not found. Longest match = %d\n",longest)
	}
}

func matched(dump, rom []byte, rom0 int) (found bool,k int) {
	ref := rom0
	for k=0;k<len(dump);k++ {
		if dump[k]!=rom[ref] { break }
		ref++
	}
	found = k==len(dump)
	return found,k
}