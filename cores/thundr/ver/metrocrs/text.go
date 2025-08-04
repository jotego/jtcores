package main

import(
	"fmt"
)

func main() {
	for row:=0;row<28;row++ {
		for col:=0;col<36;col++ {
			ra := row+2
			ca := col-2
			addr := 0
			if (ca&0x20)!=0 {
				addr = ra + ((ca&0x1f)<<5)
			} else {
				addr = ca + (ra<<5)
			}
			fmt.Printf("%02X-%02X ",(addr>>5)&0x1f,addr&0x1f)
		}
		fmt.Println()
	}
	fmt.Println()
}