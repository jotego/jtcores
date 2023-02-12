package main;

import (
	. "fmt"
	"os"
	"strconv"
)

func main() {
	lyrcrl, _ := strconv.ParseInt( os.Args[1], 16, 0 )
	Printf( " -- %X --  \n", lyrcrl)
	Printf(  "15-14 Unknown   = %X\n", lyrcrl>>14 )
	Printf(  "    0 Unknown   = %x\n\n", lyrcrl&1 )
	Printf(  "13-12 layer 0   = %X\n", (lyrcrl>>12)&3 )
	Printf(  "11-10 layer 1   = %X\n", (lyrcrl>>10)&3 )
	Printf(  "10- 9 layer 2   = %X\n", (lyrcrl>> 8)&3 )
	Printf(  " 8- 7 layer 3   = %X\n", (lyrcrl>> 6)&3 )
	if (lyrcrl& 0xe) != 0xe {
		Printf("Not all SCR layers are enabled (%X)\n", (lyrcrl>>1)&0x1f)
	}
}