package main

import (
	"os"
	"os/exec"
)

func main() {
	cmd := exec.Command("jtframe", "ucode", "jt680x", "6802", "--output", "6801")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(err)
	}
}
