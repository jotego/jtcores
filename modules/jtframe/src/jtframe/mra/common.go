package mra

import(
	"fmt"
	"os"
	"strings"
	"strconv"
)

func must(e error) {
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
}

func rawdata2bytes(rawstr string) []byte {
	rawbytes := make([]byte, 0, 1024)
	datastr := strings.ReplaceAll(rawstr, "\n", " ")
	datastr = strings.ReplaceAll(datastr, "\t", " ")
	datastr = strings.TrimSpace(datastr)
	for _, hexbyte := range strings.Split(datastr, " ") {
		if hexbyte == "" {
			continue
		}
		conv, _ := strconv.ParseInt(hexbyte, 16, 0)
		rawbytes = append(rawbytes, byte(conv))
	}
	return rawbytes
}