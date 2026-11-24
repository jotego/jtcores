package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func generateMMR() {
	root := os.Getenv("JTROOT")
	if root == "" {
		panic("JTROOT is not set")
	}
	localCores, err := filepath.Abs("../generated/bram_iface/cores")
	if err != nil {
		panic(err)
	}
	cfgDir := filepath.Join(localCores, "nemsis", "cfg")
	hdlDir := filepath.Join(localCores, "nemsis", "hdl")
	if err := os.MkdirAll(cfgDir, 0o755); err != nil {
		panic(err)
	}
	if err := os.MkdirAll(hdlDir, 0o755); err != nil {
		panic(err)
	}
	config, err := os.ReadFile(filepath.Join(root, "cores", "nemsis", "cfg", "mmr.yaml"))
	if err != nil {
		panic(err)
	}
	if err := os.WriteFile(filepath.Join(cfgDir, "mmr.yaml"), config, 0o644); err != nil {
		panic(err)
	}
	// Bootstrap jtframe before overriding CORES for the isolated MMR output.
	// The wrapper's Go test suite expects the normal full-project CORES root.
	bootstrap := exec.Command("jtframe", "--help")
	bootstrap.Dir = root
	if out, err := bootstrap.CombinedOutput(); err != nil {
		panic(fmt.Sprintf("jtframe bootstrap failed: %v\n%s", err, out))
	}
	cmd := exec.Command("jtframe", "mmr", "nemsis")
	cmd.Dir = root
	for _, entry := range os.Environ() {
		if !strings.HasPrefix(entry, "CORES=") {
			cmd.Env = append(cmd.Env, entry)
		}
	}
	cmd.Env = append(cmd.Env, "CORES="+localCores)
	if out, err := cmd.CombinedOutput(); err != nil {
		panic(fmt.Sprintf("jtframe mmr failed: %v\n%s", err, out))
	}
}

func main() {
	generateMMR()
	seed := []byte{
		0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
		0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88,
	}
	if err := os.WriteFile("mmr_seed.bin", seed, 0o644); err != nil {
		panic(err)
	}
}
