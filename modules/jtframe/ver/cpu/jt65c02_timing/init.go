package main

import (
	"os"
	"os/exec"
)

func main() {
	check := exec.Command("python3", "check_manifest.py")
	check.Stdout = os.Stdout
	check.Stderr = os.Stderr
	if err := check.Run(); err != nil {
		panic(err)
	}
	check = exec.Command("python3", "rockwell_oracle.py")
	check.Stdout = os.Stdout
	check.Stderr = os.Stderr
	if err := check.Run(); err != nil {
		panic(err)
	}
	cmd := exec.Command("jtframe", "ucode", "jt680x", "65c02", "--output", "65c02")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(err)
	}
}
