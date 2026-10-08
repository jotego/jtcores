// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-or-later

package main

import (
	"bufio"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"gopkg.in/yaml.v2"
)

func TestParseValue(t *testing.T) {
	for _, test := range []struct {
		text  string
		value uint64
		width int
	}{
		{"0", 0, 1},
		{"1", 1, 1},
		{"$AA", 0xaa, 8},
		{"$1234", 0x1234, 16},
	} {
		value, width, err := parseValue(test.text)
		if err != nil || value != test.value || width != test.width {
			t.Fatalf("parseValue(%q) = %#x, %d, %v", test.text, value, width, err)
		}
	}
}

func TestWriteChecksRejectsMalformedCheck(t *testing.T) {
	out := t.TempDir()
	err := writeChecks(asmTest{Test: []asmLine{{Asm: "NOP", Check: "not an assertion"}}}, out)
	if err == nil || !strings.Contains(err.Error(), "NAME=VALUE") {
		t.Fatalf("writeChecks accepted malformed check: %v", err)
	}
	if _, statErr := os.Stat(filepath.Join(out, "test_checks.vh")); statErr != nil {
		t.Fatalf("writeChecks did not create output: %v", statErr)
	}
}

func TestSignalExpr(t *testing.T) {
	for name, expected := range map[string]string{
		"A":           "uut.a",
		"R0":          "iram[0]",
		"IRAM[$31]":   "iram[7'h31]",
		"XRAM[$1234]": "xram[16'h1234]",
		"DPTR":        "uut.dptr",
		"P":           "uut.psw[0]",
		"OV":          "uut.psw[2]",
	} {
		actual, err := signalExpr(name)
		if err != nil || actual != expected {
			t.Fatalf("signalExpr(%q) = %q, %v; want %q", name, actual, err, expected)
		}
	}
	if _, err := signalExpr("UNKNOWN"); err == nil {
		t.Fatal("signalExpr accepted an unknown name")
	}
}

func TestWriteChecksCycles(t *testing.T) {
	out := t.TempDir()
	cycles := 2
	if err := writeChecks(asmTest{Test: []asmLine{{Asm: "MOVX A,@DPTR", Cycles: &cycles}}}, out); err != nil {
		t.Fatalf("writeChecks returned %v", err)
	}
	data, err := os.ReadFile(filepath.Join(out, "test_checks.vh"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "machine-cycle count expected 2") || !strings.Contains(string(data), "actual !== 24") {
		t.Fatalf("cycle check was not emitted:\n%s", data)
	}
}

func TestWriteChecksRejectsZeroCycles(t *testing.T) {
	out := t.TempDir()
	cycles := 0
	err := writeChecks(asmTest{Test: []asmLine{{Asm: "NOP", Cycles: &cycles}}}, out)
	if err == nil || !strings.Contains(err.Error(), "cycles must be positive") {
		t.Fatalf("writeChecks accepted zero cycles: %v", err)
	}
}

func TestVectorMnemonicCoverage(t *testing.T) {
	ucode, err := os.ReadFile(filepath.Join("..", "ucode", "8051.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	var definition struct {
		Ops []struct {
			Name string `yaml:"name"`
		} `yaml:"ops"`
	}
	if err := yaml.Unmarshal(ucode, &definition); err != nil {
		t.Fatal(err)
	}
	vectors, err := os.ReadFile(filepath.Join("..", "ver", "vectors", "tests.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	all := map[string]asmTest{}
	if err := yaml.Unmarshal(vectors, &all); err != nil {
		t.Fatal(err)
	}
	covered := map[string]bool{"RESERVED": false}
	for _, vector := range all {
		for _, line := range vector.Test {
			asm := strings.TrimSpace(line.Asm)
			if colon := strings.IndexByte(asm, ':'); colon >= 0 {
				asm = strings.TrimSpace(asm[colon+1:])
			}
			fields := strings.Fields(asm)
			if len(fields) != 0 {
				if strings.EqualFold(fields[0], ".DB") {
					covered["RESERVED"] = true
				} else {
					covered[strings.ToUpper(fields[0])] = true
				}
			}
		}
	}
	for _, op := range definition.Ops {
		if !covered[strings.ToUpper(op.Name)] {
			t.Errorf("no readable vector exercises %s", op.Name)
		}
	}
}

func TestAbsolutePageOpcodeMap(t *testing.T) {
	ucode, err := os.ReadFile(filepath.Join("..", "ucode", "8051.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	var definition struct {
		Ops []struct {
			Name string `yaml:"name"`
			Op   int    `yaml:"op"`
		} `yaml:"ops"`
	}
	if err := yaml.Unmarshal(ucode, &definition); err != nil {
		t.Fatal(err)
	}
	got := map[int]string{}
	for _, op := range definition.Ops {
		if _, duplicate := got[op.Op]; duplicate {
			t.Errorf("microcode defines opcode %02X more than once", op.Op)
		}
		got[op.Op] = op.Name
	}
	for opcode := 0; opcode < 256; opcode++ {
		if _, present := got[opcode]; !present {
			t.Errorf("microcode has no definition for opcode %02X", opcode)
		}
	}
	for _, opcode := range []int{0x01, 0x21, 0x41, 0x61, 0x81, 0xa1, 0xc1, 0xe1} {
		if got[opcode] != "AJMP" {
			t.Errorf("opcode %02X is %q; want AJMP", opcode, got[opcode])
		}
	}
	for _, opcode := range []int{0x11, 0x31, 0x51, 0x71, 0x91, 0xb1, 0xd1, 0xf1} {
		if got[opcode] != "ACALL" {
			t.Errorf("opcode %02X is %q; want ACALL", opcode, got[opcode])
		}
	}
}

func TestVectorOpcodeCoverage(t *testing.T) {
	vectors, err := os.ReadFile(filepath.Join("..", "ver", "vectors", "tests.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	all := map[string]asmTest{}
	if err := yaml.Unmarshal(vectors, &all); err != nil {
		t.Fatal(err)
	}
	covered := map[uint8]bool{}
	root := t.TempDir()
	for name, vector := range all {
		out := filepath.Join(root, name)
		if err := os.Mkdir(out, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := writeAsm(vector, out); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if err := assemble(vector, out); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		listing, err := os.Open(filepath.Join(out, "test.lst"))
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		scanner := bufio.NewScanner(listing)
		for scanner.Scan() {
			line := scanner.Text()
			colon := strings.IndexByte(line, ':')
			if colon < 0 || len(line) < 5 {
				continue
			}
			fields := strings.Fields(line[colon+1:])
			if len(fields) == 0 || len(fields[0]) != 2 {
				continue
			}
			value, err := strconv.ParseUint(fields[0], 16, 8)
			if err == nil {
				covered[uint8(value)] = true
			}
		}
		if err := scanner.Err(); err != nil {
			listing.Close()
			t.Fatalf("%s: %v", name, err)
		}
		listing.Close()
	}
	for opcode := 0; opcode < 256; opcode++ {
		if !covered[uint8(opcode)] {
			t.Errorf("no readable vector assembles opcode %02X", opcode)
		}
	}
}
