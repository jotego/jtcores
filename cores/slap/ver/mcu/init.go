// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"log"
	"os"
	"os/exec"
	"strings"
)

func main() {
	command := exec.Command("jtframe", "ucode", "jt680x", "6805", "-o", "6805")
	command.Stdout, command.Stderr = os.Stdout, os.Stderr
	if e := command.Run(); e != nil {
		log.Fatal(e)
	}
	protocol, e := os.ReadFile("protocol.hex")
	if e != nil {
		log.Fatal(e)
	}
	// BRSET replaces BRCLR for Tiger-Heli's active-low host-full input.
	tiger := strings.Replace(string(protocol), "01 02 FD", "00 02 FD", 1)
	if e := os.WriteFile("tiger-protocol.hex", []byte(tiger), 0644); e != nil {
		log.Fatal(e)
	}
}
