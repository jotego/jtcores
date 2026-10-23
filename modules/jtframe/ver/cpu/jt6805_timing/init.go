package main

import (
	"os"
	"os/exec"
)

func main() {
	cmd := exec.Command("jtframe", "ucode", "jt680x", "6805", "--output", "6805")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(err)
	}
	cmd = exec.Command("python3", "manual_inventory.py")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(err)
	}
	check := exec.Command("python3", "check_inventory.py")
	check.Stdout = os.Stdout
	check.Stderr = os.Stderr
	if err := check.Run(); err != nil {
		panic(err)
	}
}
