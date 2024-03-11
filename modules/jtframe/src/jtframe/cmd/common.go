package cmd

import (
	"fmt"
	"os"
	"path/filepath"
)

func must( e error ) {
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
}

func doc2string(doc string) string {
	fname := filepath.Join(os.Getenv("JTFRAME"),"doc",doc)
	buf, e := os.ReadFile(fname)
	must(e)
	return string(buf)
}