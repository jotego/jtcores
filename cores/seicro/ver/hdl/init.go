/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-10-2026 */

package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	root := os.Getenv("JTROOT")
	if root == "" {
		panic("JTROOT is required")
	}
	dir, err := filepath.Abs("scratch/unit")
	check(err)
	check(os.MkdirAll(dir, 0755))
	run(dir, "mem", "seicro", "-t", "mister", "--local", "--inc")
	run(dir, "files", "plain", "seicro", "-t", "mister", "-m", "SIMULATION,VERILATOR", "--local")
	cmd := exec.Command("jtframe", "cfgstr", "seicro", "-t", "mister", "-o", "verilator")
	cmd.Dir = dir
	cmd.Stderr = os.Stderr
	definitions, err := cmd.Output()
	check(err)
	write(filepath.Join(dir, "definitions.txt"), definitions)
	files, err := os.ReadFile(filepath.Join(dir, "files"))
	check(err)
	wrapper, err := os.ReadFile(filepath.Join(dir, "jtseicro_game_sdram.v"))
	check(err)
	start := strings.LastIndex(string(wrapper), "\n`ifndef NOSOUND\n")
	if start < 0 {
		panic("audio wrapper boundary missing")
	}
	mixer := "module seicro_mixer(\n" +
		"input rst, clk, input [15:0] psg_snd, dac_snd,\n" +
		"input psg_snd_rcen, dac_snd_rcen, input [5:0] snd_en,\n" +
		"input [7:0] snd_vol, output signed [15:0] snd,\n" +
		"output sample, snd_peak, output [5:0] snd_vu\n);\n" +
		"wire mute; wire clk48=clk, rst48=rst;\n" + string(wrapper[start:])
	write(filepath.Join(dir, "seicro_mixer.rtl"), []byte(mixer))
	generated, err := filepath.Glob(filepath.Join(dir, "*.v"))
	check(err)
	paths := strings.Fields(string(files))
	paths = append(paths, generated...)
	paths = append(paths, filepath.Join(dir, "seicro_mixer.rtl"))
	renamed := make(map[string]string)
	for _, path := range generated {
		replacement := strings.TrimSuffix(path, ".v") + ".rtl"
		check(os.Rename(path, replacement))
		renamed[path] = replacement
	}
	seen := make(map[string]bool)
	var rtl []string
	for _, path := range paths {
		ext := filepath.Ext(path)
		if ext != ".v" && ext != ".sv" && ext != ".rtl" {
			continue
		}
		if !filepath.IsAbs(path) {
			local := filepath.Join(dir, path)
			if _, err := os.Stat(local); err == nil || renamed[local] != "" {
				path = local
			} else {
				path = filepath.Join(root, path)
			}
		}
		path = filepath.Clean(path)
		if renamed[path] != "" {
			path = renamed[path]
		}
		if !seen[path] {
			rtl = append(rtl, path)
			seen[path] = true
		}
	}
	write(filepath.Join(dir, "rtl.f"), []byte(strings.Join(rtl, "\n")+"\n"))
	roms, err := filepath.Glob(filepath.Join(dir, "*.uc"))
	check(err)
	for _, path := range roms {
		data, err := os.ReadFile(path)
		check(err)
		write(filepath.Base(path), data)
	}
	write("seicro_portb.hex", []byte("a7\n"))
}

func run(dir string, args ...string) {
	cmd := exec.Command("jtframe", args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	check(cmd.Run())
}

func write(path string, data []byte) {
	check(os.WriteFile(path, data, 0644))
}

func check(err error) {
	if err != nil {
		panic(err)
	}
}
