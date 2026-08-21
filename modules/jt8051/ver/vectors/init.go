// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

func run(dir, command string, args ...string) {
	cmd := exec.Command(command, args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Fatal(err)
	}
}

func main() {
	root := os.Getenv("JTROOT")
	if root == "" {
		log.Fatal("JTROOT is not set")
	}
	wd, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}
	name := os.Getenv("JT8051_VECTOR")
	if name == "" {
		name = "register_indirect_direct"
	}
	run(filepath.Join(root, "modules/jt8051/hdl"), "jtframe", "ucode", "--output", "jt8051", "jt8051", "8051")
	run(wd, "jtframe", "ucode", "--output", "jt8051", "jt8051", "8051")
	run(filepath.Join(root, "modules/jt8051/testgen"), "go", "run", ".", "-input", filepath.Join(wd, "tests.yaml"), "-out", wd, name)
}
