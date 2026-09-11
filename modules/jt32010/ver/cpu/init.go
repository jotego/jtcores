// SPDX-FileCopyrightText: 2026 Marc Emmerson
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Build the C reference model and generate one program image and one
// reference trace per case in the matrix that test.v walks. The cases mirror
// regress.sh: plain execution, three interrupt rates, and two of those
// repeated with the core held for part of every clock.
package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
)

// seed, interrupt period in instructions. HALT duty is a property of the RTL
// only - the reference model never sees it - so it does not appear here.
var cases = []struct{ seed, irq int }{
	{1, 0},
	{2, 97},
	{3, 23},
	{4, 7},
	{5, 97},
	{6, 0},
}

const steps = 4000

func run(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Fatalf("%s: %v", name, err)
	}
}

func trace(prog, out string, irq int) {
	f, err := os.Create(out)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	cmd := exec.Command("./ref32010", prog, fmt.Sprint(steps), fmt.Sprint(irq))
	cmd.Stdout = f
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Fatalf("ref32010: %v", err)
	}
}

func main() {
	run("gcc", "-O2", "-o", "ref32010", "ref32010.c")
	for i, c := range cases {
		prog := fmt.Sprintf("prog%d.hex", i)
		run("python3", "gen_prog.py", fmt.Sprint(c.seed), prog)
		trace(prog, fmt.Sprintf("ref%d.trace", i), c.irq)
	}
}
