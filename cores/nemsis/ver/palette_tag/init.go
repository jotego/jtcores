package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	root := os.Getenv("JTROOT")
	if root == "" {
		panic("JTROOT is not set")
	}
	localCores, err := filepath.Abs("../generated/palette_tag/cores")
	if err != nil {
		panic(err)
	}
	cfgDir := filepath.Join(localCores, "nemsis", "cfg")
	if err := os.MkdirAll(cfgDir, 0o755); err != nil {
		panic(err)
	}
	if err := os.MkdirAll(filepath.Join(localCores, "nemsis", "hdl"), 0o755); err != nil {
		panic(err)
	}
	config, err := os.ReadFile(filepath.Join(root, "cores", "nemsis", "cfg", "mmr.yaml"))
	if err != nil {
		panic(err)
	}
	if err := os.WriteFile(filepath.Join(cfgDir, "mmr.yaml"), config, 0o644); err != nil {
		panic(err)
	}
	if err := os.WriteFile("rest.bin", make([]byte, 16), 0o644); err != nil {
		panic(err)
	}
	// Let the jtframe wrapper bootstrap its binary with the normal project
	// CORES root. The local MMR generation below intentionally narrows CORES to
	// the fixture tree, which is unsuitable for the wrapper's Go test suite.
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
