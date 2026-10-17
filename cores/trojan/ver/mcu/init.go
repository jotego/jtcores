// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	trace, rom := os.Getenv("MCU_TRACE"), os.Getenv("MCU_ROM")
	if trace == "" || rom == "" {
		log.Fatal("set MCU_TRACE to capture.lua's trace.log and MCU_ROM to av.13k or avengers.rom")
	}
	wd, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}
	for _, dir := range []string{filepath.Join(os.Getenv("JTROOT"), "modules/jt8051/hdl"), wd} {
		cmd := exec.Command("jtframe", "ucode", "--output", "jt8051", "jt8051", "8051")
		cmd.Dir, cmd.Stdout, cmd.Stderr = dir, os.Stdout, os.Stderr
		if err := cmd.Run(); err != nil {
			log.Fatal(err)
		}
	}
	cmd := exec.Command("python3", "prepare.py", trace, rom)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		log.Fatal(err)
	}
}
