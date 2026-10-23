/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

package ucode

import (
	"os"
	"path/filepath"
	"testing"
)

func Test_read_yaml_overrides_included_procedure(t *testing.T) {
	dir := t.TempDir()
	files := map[string]string{
		"base.yaml": "ucode:\n  - { name: shared, start: 1, seq: [original] }\n  - { name: inherited, start: 2, seq: [ret_jsr] }\n",
		"profile.yaml": "include: [base.yaml]\nucode:\n  - { name: shared, start: 1, seq: [replacement] }\n",
	}
	for name, data := range files {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(data), 0600); err != nil {
			t.Fatal(err)
		}
	}
	desc := read_yaml(filepath.Join(dir, "profile.yaml"))
	if len(desc.Chunks) != 2 || desc.Chunks[0].Seq[0] != "replacement" || desc.find_proc("inherited") < 0 {
		t.Fatalf("profile must replace one procedure and inherit the other: %#v", desc.Chunks)
	}
}

func Test_read_yaml_overrides_one_inherited_mnemonic(t *testing.T) {
	dir := t.TempDir()
	files := map[string]string{
		"base.yaml": "ucode:\n  - { mnemo: [A, B], seq: [original] }\n",
		"profile.yaml": "config: { partial_mnemonics: true }\ninclude: [base.yaml]\nucode:\n  - { mnemo: [A], seq: [replacement] }\n",
	}
	for name, data := range files {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(data), 0600); err != nil {
			t.Fatal(err)
		}
	}
	desc := read_yaml(filepath.Join(dir, "profile.yaml"))
	a, b := find_chunk("A", &desc), find_chunk("B", &desc)
	if len(desc.Chunks) != 2 || a < 0 || b < 0 || desc.Chunks[a].Seq[0] != "replacement" || desc.Chunks[b].Seq[0] != "original" {
		t.Fatalf("profile must replace A and inherit B: %#v", desc.Chunks)
	}
	if err := os.WriteFile(filepath.Join(dir, "profile.yaml"), []byte("include: [base.yaml]\nucode:\n  - { mnemo: [A], seq: [replacement] }\n"), 0600); err != nil {
		t.Fatal(err)
	}
	desc = read_yaml(filepath.Join(dir, "profile.yaml"))
	if len(desc.Chunks) != 1 || find_chunk("B", &desc) >= 0 {
		t.Fatalf("default include behavior must keep replacing the whole mnemonic group: %#v", desc.Chunks)
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
