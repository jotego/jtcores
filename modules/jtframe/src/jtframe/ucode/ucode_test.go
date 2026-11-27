/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package ucode

import (
	"os"
	"path/filepath"
	"testing"
)

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

func Test_read_yaml_partial_inherited_mnemonics(t *testing.T) {
	dir := t.TempDir()
	common := `ucode:
  - mnemo: [KEEP, SHADOW, EXTRA]
    seq: [ni]
`
	profile := `config:
  partial_mnemonics: true
include: [common.yaml]
ops:
  - { name: KEEP, op: 0x01, cycles: 1 }
  - { name: SHADOW, op: 0x02, cycles: 1 }
ucode:
  - mnemo: [SHADOW]
    seq: [halt]
`
	write_ucode_test_file(t, dir, "common.yaml", common)
	write_ucode_test_file(t, dir, "profile.yaml", profile)
	desc := read_yaml(filepath.Join(dir, "profile.yaml"))
	if len(desc.Chunks) != 2 {
		t.Fatalf("expected local override and partial inherited group, got %d chunks", len(desc.Chunks))
	}
	if got := desc.Chunks[0].Mnemo; len(got) != 1 || got[0] != "SHADOW" {
		t.Fatalf("unexpected local mnemonic chunk: %v", got)
	}
	if got := desc.Chunks[1].Mnemo; len(got) != 1 || got[0] != "KEEP" {
		t.Fatalf("expected only the unshadowed declared mnemonic, got %v", got)
	}
}

func Test_read_yaml_partial_mnemonics_omits_empty_group(t *testing.T) {
	dir := t.TempDir()
	common := `ucode:
  - mnemo: [UNUSED]
    seq: [ni]
`
	profile := `config:
  partial_mnemonics: true
include: [common.yaml]
ops:
  - { name: OWN, op: 0x01, cycles: 1 }
`
	write_ucode_test_file(t, dir, "common.yaml", common)
	write_ucode_test_file(t, dir, "profile.yaml", profile)
	desc := read_yaml(filepath.Join(dir, "profile.yaml"))
	if len(desc.Chunks) != 0 {
		t.Fatalf("expected filtered empty inherited group to be omitted, got %d chunks", len(desc.Chunks))
	}
}

func Test_read_yaml_nested_partial_mnemonics(t *testing.T) {
	dir := t.TempDir()
	common := `ucode:
  - mnemo: [NATIVE, MCU_ONLY]
    seq: [ni]
`
	native := `config:
  partial_mnemonics: true
include: [common.yaml]
ops:
  - { name: NATIVE, op: 0x01, cycles: 1 }
`
	derivative := `include: [native.yaml]
ops:
  - { name: EXTENSION, op: 0x02, cycles: 1 }
ucode:
  - mnemo: [EXTENSION]
    seq: [halt]
`
	write_ucode_test_file(t, dir, "common.yaml", common)
	write_ucode_test_file(t, dir, "native.yaml", native)
	write_ucode_test_file(t, dir, "derivative.yaml", derivative)
	desc := read_yaml(filepath.Join(dir, "derivative.yaml"))
	if len(desc.Ops) != 2 || len(desc.Chunks) != 2 {
		t.Fatalf("unexpected nested include content: %d ops, %d chunks", len(desc.Ops), len(desc.Chunks))
	}
	if index := find_chunk("NATIVE", &desc); index < 0 {
		t.Fatal("native include lost its filtered mnemonic")
	} else if got := desc.Chunks[index].Mnemo; len(got) != 1 || got[0] != "NATIVE" {
		t.Fatalf("native include changed its filtered mnemonic: %v", got)
	}
	if index := find_chunk("EXTENSION", &desc); index < 0 {
		t.Fatal("derivative mnemonic was lost during nested include")
	} else if got := desc.Chunks[index].Mnemo; len(got) != 1 || got[0] != "EXTENSION" {
		t.Fatalf("derivative mnemonic changed during nested include: %v", got)
	}
}

func Test_read_yaml_default_inherited_mnemonics_unchanged(t *testing.T) {
	dir := t.TempDir()
	common := `ucode:
  - mnemo: [KEEP, SHADOW]
    seq: [ni]
`
	profile := `include: [common.yaml]
ops:
  - { name: KEEP, op: 0x01, cycles: 1 }
  - { name: SHADOW, op: 0x02, cycles: 1 }
ucode:
  - mnemo: [SHADOW]
    seq: [halt]
`
	write_ucode_test_file(t, dir, "common.yaml", common)
	write_ucode_test_file(t, dir, "profile.yaml", profile)
	desc := read_yaml(filepath.Join(dir, "profile.yaml"))
	if len(desc.Chunks) != 1 || len(desc.Chunks[0].Mnemo) != 1 || desc.Chunks[0].Mnemo[0] != "SHADOW" {
		t.Fatalf("default whole-group shadow behavior changed: %#v", desc.Chunks)
	}
}

func Test_check_op_chunks_requires_one_template_per_mnemonic(t *testing.T) {
	desc := UcDesc{
		Ops: []UcOp{{Name: "A"}, {Name: "B"}},
		Chunks: []UcChunk{{Mnemo: []string{"A"}}, {Mnemo: []string{"B"}}},
	}
	if err := check_op_chunks(&desc); err != nil {
		t.Fatalf("expected a unique template for each operation, got %v", err)
	}
	desc.Chunks = desc.Chunks[:1]
	if err := check_op_chunks(&desc); err == nil {
		t.Fatal("expected a declared operation without a template to fail")
	}
	desc.Chunks = append(desc.Chunks, UcChunk{Mnemo: []string{"A"}})
	if err := check_op_chunks(&desc); err == nil {
		t.Fatal("expected duplicate mnemonic templates to fail")
	}
}

func write_ucode_test_file(t *testing.T, dir, name, contents string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, name), []byte(contents), 0644); err != nil {
		t.Fatal(err)
	}
}
