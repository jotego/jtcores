// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"log"
	"os"
	"os/exec"
)

func main() {
	if os.Getenv("JTROOT") == "" {
		log.Fatal("JTROOT is not set")
	}
	cmd := exec.Command("jtframe", "ucode", "--output", "jt8051", "jt8051", "8051")
	if err := cmd.Run(); err != nil {
		log.Fatal(err)
	}
}
