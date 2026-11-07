package main

import (
	"fmt"
	"os"
	"os/exec"
)

func main() {
	cmd := exec.Command("jtframe", "mmr", "rungun")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "init: failed to generate MMR files: %v\n", err)
		os.Exit(1)
	}

	// Mirror rungun's synthesized INIT while the download-reset test holds the
	// CPU reset active. The MMR file is ordered from register 0 to register 15.
	ccu := []byte{0x01, 0xff, 0x00, 0x21, 0x00, 0x37, 0x01, 0x00,
		0x01, 0x07, 0x0c, 0x0e, 0x54, 0x00, 0x00, 0x00}
	if err := os.WriteFile("ccu.bin", ccu, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "init: failed to write ccu.bin: %v\n", err)
		os.Exit(1)
	}
}
