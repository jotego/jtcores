// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

func generate(dir string) {
	cmd := exec.Command("jtframe", "ucode", "--output", "jt8051", "jt8051", "8051")
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
	generate(filepath.Join(root, "modules", "jt8051", "hdl"))
	generate(wd)
}
