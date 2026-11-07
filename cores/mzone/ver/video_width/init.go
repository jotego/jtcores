// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	var stubs strings.Builder
	for _, name := range []string{"scroll", "fix", "obj"} {
		data, err := os.ReadFile(filepath.Join("..", "..", "hdl", "jtmzone_"+name+".v"))
		if err != nil {
			panic(err)
		}
		source := string(data)
		start := strings.Index(source, "module ")
		end := strings.Index(source[start:], ");")
		if start < 0 || end < 0 {
			panic("missing renderer interface: " + name)
		}
		fmt.Fprintln(&stubs, source[start:start+end+2]+"\nendmodule")
	}
	if err := os.WriteFile("fetchers.vh", []byte(stubs.String()), 0644); err != nil {
		panic(err)
	}
}
