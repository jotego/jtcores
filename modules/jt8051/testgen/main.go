// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-or-later

// jt8051-testgen assembles one human-readable JT8051 YAML vector group and
// emits the program image and boundary-check include used by the vector bench.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"gopkg.in/yaml.v2"
)

type asmLine struct {
	Asm    string `yaml:"asm"`
	Check  string `yaml:"check"`
	Cycles *int   `yaml:"cycles"`
}

type asmTest struct {
	Code []memCfg  `yaml:"code"`
	Test []asmLine `yaml:"test"`
}

type memCfg struct {
	From int    `yaml:"from"`
	Data string `yaml:"data"`
}

var iramCheck = regexp.MustCompile(`^IRAM\[\$(?i:([0-9a-f]+))\]$`)
var xramCheck = regexp.MustCompile(`^XRAM\[\$(?i:([0-9a-f]+))\]$`)

func main() {
	input := flag.String("input", "tests.yaml", "input test YAML")
	out := flag.String("out", ".", "output directory")
	flag.Parse()
	if flag.NArg() != 1 {
		fmt.Fprintln(os.Stderr, "Usage: jt8051-testgen <test-name>")
		os.Exit(2)
	}
	name := flag.Arg(0)
	data, err := os.ReadFile(*input)
	must(err)
	all := map[string]asmTest{}
	must(yaml.Unmarshal(data, &all))
	test, ok := all[name]
	if !ok {
		must(fmt.Errorf("cannot find test %q in tests.yaml", name))
	}
	must(os.MkdirAll(*out, 0o755))
	must(writeAsm(test, *out))
	must(assemble(test, *out))
	must(writeChecks(test, *out))
}

func writeAsm(test asmTest, out string) error {
	f, err := os.Create(filepath.Join(out, "test.asm"))
	if err != nil {
		return err
	}
	defer f.Close()
	if _, err = fmt.Fprintln(f, ".ORG 0000H"); err != nil {
		return err
	}
	for _, line := range test.Test {
		if strings.TrimSpace(line.Asm) == "" {
			return fmt.Errorf("every test entry needs an asm field")
		}
		if _, err = fmt.Fprintln(f, line.Asm); err != nil {
			return err
		}
	}
	// The bench terminates at the final expected instruction.  Padding keeps
	// a program-counter overrun from turning the verification into an X-state.
	_, err = fmt.Fprintln(f, "NOP\nNOP\nNOP\nNOP")
	return err
}

func assemble(test asmTest, out string) error {
	cmd := exec.Command("as31", "-l", "-Fbin", "-Oprogram.bin", "test.asm")
	cmd.Dir = out
	log, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("as31 failed:\n%s%w", log, err)
	}
	binname := filepath.Join(out, "program.bin")
	bin, err := os.ReadFile(binname)
	if err != nil {
		return err
	}
	for _, cfg := range test.Code {
		if cfg.From < 0 || cfg.From > 0xffff {
			return fmt.Errorf("code address %#x is out of range", cfg.From)
		}
		for _, field := range strings.Fields(cfg.Data) {
			value, err := strconv.ParseUint(field, 16, 8)
			if err != nil {
				return fmt.Errorf("invalid code byte %q: %w", field, err)
			}
			for len(bin) <= cfg.From {
				bin = append(bin, 0)
			}
			bin[cfg.From] = byte(value)
			cfg.From++
		}
	}
	return os.WriteFile(binname, bin, 0o666)
}

func writeChecks(test asmTest, out string) error {
	f, err := os.Create(filepath.Join(out, "test_checks.vh"))
	if err != nil {
		return err
	}
	defer f.Close()
	if _, err = fmt.Fprintf(f, "localparam integer CHECK_COUNT=%d;\n", len(test.Test)); err != nil {
		return err
	}
	if _, err = fmt.Fprintln(f, "task check_state; input integer index; begin case(index)"); err != nil {
		return err
	}
	for index, line := range test.Test {
		if _, err = fmt.Fprintf(f, "%d: begin\n", index); err != nil {
			return err
		}
		for _, pair := range strings.Split(line.Check, ",") {
			pair = strings.TrimSpace(pair)
			if pair == "" {
				continue
			}
			if !strings.Contains(pair, "=") {
				return fmt.Errorf("test entry %d (%s): check %q must use NAME=VALUE", index, line.Asm, pair)
			}
			parts := strings.SplitN(pair, "=", 2)
			signal, err := signalExpr(strings.ToUpper(strings.TrimSpace(parts[0])))
			if err != nil {
				return fmt.Errorf("test entry %d (%s): %w", index, line.Asm, err)
			}
			value, width, err := parseValue(strings.TrimSpace(parts[1]))
			if err != nil {
				return fmt.Errorf("test entry %d (%s): %w", index, line.Asm, err)
			}
			if _, err = fmt.Fprintf(f, "if (%s !== %d'h%X) begin $display(\"Vector %d: %s expected %%0h got %%0h\", %d'h%X, %s); failed=1; end\n", signal, width, value, index, signal, width, value, signal); err != nil {
				return err
			}
		}
		if _, err = fmt.Fprintln(f, "end"); err != nil {
			return err
		}
	}
	if _, err = fmt.Fprintln(f, "default: ; endcase end endtask"); err != nil {
		return err
	}
	if _, err = fmt.Fprintln(f, "task check_cycles; input integer index; input integer actual; begin case(index)"); err != nil {
		return err
	}
	for index, line := range test.Test {
		if line.Cycles == nil {
			continue
		}
		if *line.Cycles < 1 {
			return fmt.Errorf("test entry %d (%s): cycles must be positive", index, line.Asm)
		}
		if _, err = fmt.Fprintf(f, "%d: if (actual !== %d) begin $display(\"Vector %d: machine-cycle count expected %d got %%0d\", actual); failed=1; end\n", index, *line.Cycles*12, index, *line.Cycles); err != nil {
			return err
		}
	}
	_, err = fmt.Fprintln(f, "default: ; endcase end endtask")
	return err
}

func signalExpr(name string) (string, error) {
	switch name {
	case "A":
		return "uut.a", nil
	case "B":
		return "uut.b", nil
	case "SP":
		return "uut.sp", nil
	case "DPTR":
		return "uut.dptr", nil
	case "PC":
		return "uut.pc", nil
	case "PSW":
		return "uut.psw", nil
	case "P":
		return "uut.psw[0]", nil
	case "C":
		return "uut.psw[7]", nil
	case "AC":
		return "uut.psw[6]", nil
	case "OV":
		return "uut.psw[2]", nil
	case "P0":
		return "p0_o", nil
	case "P1":
		return "p1_o", nil
	case "P2":
		return "p2_o", nil
	case "P3":
		return "p3_o", nil
	}
	if strings.HasPrefix(name, "R") && len(name) == 2 && name[1] >= '0' && name[1] <= '7' {
		return fmt.Sprintf("iram[%d]", name[1]-'0'), nil
	}
	if match := iramCheck.FindStringSubmatch(name); match != nil {
		addr, _ := strconv.ParseUint(match[1], 16, 8)
		return fmt.Sprintf("iram[7'h%02X]", addr), nil
	}
	if match := xramCheck.FindStringSubmatch(name); match != nil {
		addr, _ := strconv.ParseUint(match[1], 16, 16)
		return fmt.Sprintf("xram[16'h%04X]", addr), nil
	}
	return "", fmt.Errorf("unsupported check field %q", name)
}

func parseValue(text string) (uint64, int, error) {
	text = strings.TrimSpace(strings.ToUpper(text))
	base := 10
	if strings.HasPrefix(text, "$") {
		base, text = 16, text[1:]
	}
	value, err := strconv.ParseUint(text, base, 16)
	if err != nil {
		return 0, 0, err
	}
	if value <= 1 {
		return value, 1, nil
	}
	if value <= 0xff {
		return value, 8, nil
	}
	return value, 16, nil
}

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
