package main

import (
	"fmt"
	"os"
	"os/exec"
)

func main() {
	cmd := exec.Command("jtframe", "ucode", "jt680x", "6802_seicro", "-o", "6801")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(fmt.Sprintf("generate Seicro MC6802 ucode profile: %v", err))
	}
}
