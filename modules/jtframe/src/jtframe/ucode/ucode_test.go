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
	if err := dump_ucrom_vh(output, true, false, 16, 32, params, chunks); err != nil {
		t.Fatal(err)
	}
	generated, err := os.ReadFile(output + ".vh")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(generated), "ucode_data = ucode_rom[uaddr]") ||
		!strings.Contains(string(generated), "assign done") || strings.Contains(string(generated), "jsr_ua") {
		t.Fatalf("expected ROM controls without subroutine logic:\n%s", generated)
	}
}

func Test_compile_constants_from_nested_includes(t *testing.T) {
	jtframe, err := filepath.Abs("../../..")
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("JTFRAME", jtframe)
	modules := t.TempDir()
	t.Setenv("MODULES", modules)
	folder := filepath.Join(modules, "graphics", "ucode")
	if err := os.MkdirAll(folder, 0755); err != nil {
		t.Fatal(err)
	}
	files := map[string]string{
		"root.yaml": `config:
  entries: 4
  entry_len: 1
  latch_ucode: true
  latch_nonblocking: true
  ignore_cycles: true
include: [middle.yaml]
constants: {SELECTED: parent}
ucode:
  - {name: first, start: 0, seq: ["${SELECTED}"]}
`,
		"middle.yaml": "include: [leaf.yaml]\nconstants: {SELECTED: middle}\n",
		"leaf.yaml": `constants: {INHERITED: inherited, SELECTED: child}
ucode:
  - {name: second, start: 1, seq: ["${INHERITED}, ${SELECTED}"]}
`,
	}
	for name, contents := range files {
		if err := os.WriteFile(filepath.Join(folder, name), []byte(contents), 0644); err != nil {
			t.Fatal(err)
		}
	}
	previous := Args
	t.Cleanup(func() { Args = previous })
	Args.Output = filepath.Join(t.TempDir(), "graphics")
	if err := Make("graphics", "root.yaml"); err != nil {
		t.Fatal(err)
	}
	image, err := os.ReadFile(Args.Output + ".uc")
	if err != nil {
		t.Fatal(err)
	}
	words := strings.Fields(string(image))
	if len(words) != 4 || (words[0] != "01" && words[0] != "10") ||
		words[1] != "11" || words[2] != "00" || words[3] != "00" {
		t.Fatalf("expected inherited control and parent override in compiled ROM, got %q", image)
	}
	header, err := os.ReadFile(Args.Output + ".vh")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(header), "ucode_data <= ucode_rom[uaddr]") ||
		!strings.Contains(string(header), "assign inherited") ||
		!strings.Contains(string(header), "assign parent") ||
		strings.Contains(string(header), "assign child") || strings.Contains(string(header), "assign middle") {
		t.Fatalf("included constants did not preserve the parent override:\n%s", header)
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
