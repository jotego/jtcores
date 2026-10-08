package main

import(
	"fmt"
	"os"
)

func main() {
	fname := get_filename()
	data, e := os.ReadFile(fname); if e!=nil { fmt.Println(e); os.Exit(1) }
	sum := make_sum(data)
	fmt.Printf("%04X\n",sum)
}

func get_filename() string {
	if len(os.Args)<2 {
		fmt.Println("Missing file name in command line")
		os.Exit(1)
	}
	return os.Args[1]
}

func make_sum(data []byte) (sum int) {
	for _, c := range data {
		sum += int(c) & 0xff
	}
	sum &= 0xffff
	return sum
}