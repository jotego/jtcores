// SPDX-FileCopyrightText: 2026 Andrea Bogazzi
// SPDX-License-Identifier: GPL-3.0-or-later
// Date: 29-10-2026

package main

import (
	"os"
	"os/exec"
)

func main() {
	cmd := exec.Command("bash", "../v20/run.sh", "--inside", "--cpu-only")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		os.Exit(1)
	}
}
