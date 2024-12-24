package common

import (
	"fmt"
	"os"
	"path/filepath"
)

func Must( e error ) {
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
}

func Doc2string(doc string) string {
	fname := filepath.Join(os.Getenv("JTFRAME"),"doc",doc)
	buf, e := os.ReadFile(fname)
	Must(e)
	return string(buf)
}

func Find_in_folders( fname string, paths []string, quit bool ) string {
	for _, each := range paths {
		full := filepath.Join(each,fname)
		f, e := os.Open(full)
		if e==nil {
			f.Close()
			return full
		}
	}
	if quit {
		fmt.Printf("Error cannot find file %s in folders:\n",fname)
		for _, each := range paths {
			fmt.Println(each)
		}
		os.Exit(1)
	}
	return ""
}