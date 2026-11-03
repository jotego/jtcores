package main

import (
	"os"
	"os/exec"
	"regexp"
)

const baseline = "3dc6b88e0204fd3abbb462b34f428757f8596e94"

func main() {
	paths := []string{
		"cores/s18/hdl/jts18_vdp.v",
		"cores/s18/hdl/ym7101.v",
		"cores/s18/hdl/ym_lib.v",
		"cores/s18/hdl/vram.sv",
	}
	mods := regexp.MustCompile(`(?m)^module\s+(\w+)`).FindAllStringSubmatch(read(paths[0])+read(paths[1])+read(paths[2])+read(paths[3]), -1)
	names := map[string]string{}
	for _, m := range mods {
		names[m[1]] = m[1] + "_baseline"
	}
	for _, p := range paths {
		s := read(p)
		for old, newName := range names {
			s = regexp.MustCompile(`\b` + regexp.QuoteMeta(old) + `\b`).ReplaceAllString(s, newName)
		}
		if err := os.WriteFile("baseline_"+base(p), []byte(s), 0644); err != nil { panic(err) }
	}
}

func read(path string) string {
	c := exec.Command("git", "show", baseline+":"+path)
	b, err := c.Output(); if err != nil { panic(err) }; return string(b)
}

func base(path string) string { for i:=len(path)-1; i>=0; i-- { if path[i]=='/' { return path[i+1:] } }; return path }
