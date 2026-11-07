package main

import (
	"os"
	"os/exec"
)

func main() {
	cmd := exec.Command("jtframe", "ucode", "jt680x", "deco222", "--output", "65c02")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(err)
	}
}
