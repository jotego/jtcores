/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package ucode

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func Test_dump_ucrom_without_subroutines(t *testing.T) {
	jtframe, err := filepath.Abs("../../..")
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("JTFRAME", jtframe)
	output := filepath.Join(t.TempDir(), "graphics")
	params := []UcParam{{Name: "DONE", Pos: 0, Bw: 1}}
	chunks := []UcChunk{{Name: "finish", Start: 0, Seq: []string{"DONE"}}}
	if err := dump_ucrom_vh(output, true, 16, 32, params, chunks); err != nil {
		t.Fatal(err)
	}
	generated, err := os.ReadFile(output + ".vh")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(generated), "assign done") || strings.Contains(string(generated), "jsr_ua") {
		t.Fatalf("expected ROM controls without subroutine logic:\n%s", generated)
	}
}

func Test_fix_cycles_adds_leading_idle_cycles(t *testing.T) {
	desc := UcDesc{}
	desc.Cfg.EntryLen = 16
	desc.Cfg.Entries = 1
	desc.Cfg.CycleK = 4
	desc.Ops = []UcOp{{Name: "EXEC", Op: 0, Cycles: 2}}
	code := make([]string, 16)
	code[0] = "DO NI"
	fix_cycles(code, &desc, false)
	if code[0] != "" || code[7] != "DO NI" {
		t.Fatalf("expected the instruction to be delayed by seven microcycles: %#v", code[:8])
	}
	if actual := calc_cycles(0, code, true, &desc, nil); actual != 8 {
		t.Fatalf("expected 8 microcycles after padding, got %d", actual)
	}
}
