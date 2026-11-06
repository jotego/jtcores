// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func must(err error) {
	if err != nil {
		panic(err)
	}
}
func read(path string) []byte        { data, err := os.ReadFile(path); must(err); return data }
func write(path string, data []byte) { must(os.WriteFile(path, data, 0644)) }
func run(env []string, command string, args ...string) {
	cmd := exec.Command(command, args...)
	cmd.Env, cmd.Stdout, cmd.Stderr = env, os.Stdout, os.Stderr
	must(cmd.Run())
}

func main() {
	root := os.Getenv("JTROOT")
	if root == "" {
		panic("source setprj.sh before running simunit")
	}
	core := filepath.Join(root, "cores", "mzone")
	tool := os.Getenv("JTFRAME_BIN")
	if tool == "" {
		tool = "jtframe"
	}
	// Generate the MMR in isolation so concurrent simunits never rewrite RTL
	// that another test may be compiling.
	tmp, err := os.MkdirTemp("", "mzone-mmr-")
	must(err)
	defer os.RemoveAll(tmp)
	cfg := filepath.Join(tmp, "mzone", "cfg")
	must(os.MkdirAll(cfg, 0755))
	must(os.MkdirAll(filepath.Join(tmp, "mzone", "hdl"), 0755))
	// mem inspects the game port include before generating mem_ports.inc.
	// Keep that inspection local to the fixture tree as well.
	write(filepath.Join(tmp, "mzone", "hdl", "jtmzone_game.v"), read(filepath.Join(core, "hdl", "jtmzone_game.v")))
	entries, err := os.ReadDir(filepath.Join(core, "cfg"))
	must(err)
	for _, entry := range entries {
		if !entry.IsDir() {
			write(filepath.Join(cfg, entry.Name()), read(filepath.Join(core, "cfg", entry.Name())))
		}
	}
	must(os.MkdirAll(filepath.Join(tmp, "mzone", "ver", "game"), 0755))
	must(os.Symlink(filepath.Join(root, "cores", "kicker"), filepath.Join(tmp, "kicker")))
	env := []string{}
	for _, entry := range os.Environ() {
		if len(entry) < 6 || entry[:6] != "CORES=" {
			env = append(env, entry)
		}
	}
	env = append(env, "CORES="+tmp)
	run(env, tool, "mmr", "mzone")
	write("jtmzone_video_mmr.vh", read(filepath.Join(tmp, "mzone", "hdl", "jtmzone_video_mmr.v")))
	run(env, tool, "mem", "mzone", "--target", "mist", "--local")
	// .vh prevents simunit's automatic *.v discovery from adding these
	// explicit gather.f sources a second time.
	must(os.Rename("jtmzone_game_sdram.v", "jtmzone_game_sdram.vh"))
	data := make([]byte, 7172)
	for i := 0; i < 7168; i++ {
		data[i] = byte((i * 37) ^ (i >> 8))
	}
	copy(data[7168:], []byte{0xa6, 0x59, 1, 0})
	label := "synthetic"
	// Real captures are optional local inputs, never repository fixtures.
	if capture := os.Getenv("MZONE_SCENE_DUMP"); capture != "" {
		label = capture
		data = read(capture)
	}
	if len(data) != 7172 {
		panic("invalid scene dump length")
	}
	write("dump.bin", data)
	splitter := filepath.Join(tmp, "mzone", "ver", "game", "dump2bin.sh")
	run(os.Environ(), "bash", splitter, "dump.bin")
	offset := 0
	for _, part := range []struct {
		name string
		size int
	}{
		{"vram0", 1024}, {"vram1", 1024}, {"cram0", 1024}, {"cram1", 1024},
		{"objram", 1024}, {"shared", 2048}, {"rest", 4},
	} {
		if !bytes.Equal(read(part.name+".bin"), data[offset:offset+part.size]) {
			panic("dump split mismatch: " + part.name)
		}
		offset += part.size
	}
	fmt.Println("Prepared scene restoration fixture:", label)
}
