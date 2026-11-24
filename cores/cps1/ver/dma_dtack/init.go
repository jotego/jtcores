package main

import (
	"os"
	"path/filepath"
	"strings"
)

// Icarus needs the ROMs in its working directory and an if/else for this
// enum assignment. This mirrors the narrow workaround used by CPS2's DTACK
// unit test while keeping the production fx68k source and behavior intact.
func main() {
	// simunit compiles local Verilog files, including copies left by older runs.
	if err := os.Remove("jtcps1_main_iverilog.v"); err != nil && !os.IsNotExist(err) {
		panic(err)
	}

	hdl := filepath.Join(os.Getenv("JTROOT"), "modules/fx68k/hdl")
	for _, name := range []string{"microrom.mem", "nanorom.mem"} {
		data, err := os.ReadFile(filepath.Join(hdl, name))
		if err != nil {
			panic(err)
		}
		if err := os.WriteFile(name, data, 0600); err != nil {
			panic(err)
		}
	}
	path := filepath.Join(hdl, "verilator/fx68k.sv")
	data, err := os.ReadFile(path)
	if err != nil {
		panic(err)
	}
	const old = "tState <= wClk ? T0 : T1;"
	if strings.Count(string(data), old) != 1 {
		panic("fx68k enum workaround no longer matches")
	}
	source := strings.Replace(string(data), old, "begin if(wClk) tState <= T0; else tState <= T1; end", 1)
	if err := os.WriteFile("fx68k_iverilog.sv", []byte(source), 0600); err != nil {
		panic(err)
	}
}
