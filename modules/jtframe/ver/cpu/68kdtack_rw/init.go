package main

import (
	"os"
	"path/filepath"
	"strings"
)

// Icarus needs an if/else for this enum assignment. Generate a disposable
// CPU copy, preserving the logic and timing of the production fx68k.
func main() {
	for _, name := range []string{"microrom.mem", "nanorom.mem"} {
		data, err := os.ReadFile(filepath.Join(os.Getenv("JTROOT"), "modules/fx68k/hdl", name))
		if err != nil {
			panic(err)
		}
		if err := os.WriteFile(name, data, 0600); err != nil {
			panic(err)
		}
	}
	data, err := os.ReadFile(filepath.Join(os.Getenv("JTROOT"), "modules/fx68k/hdl/verilator/fx68k.sv"))
	if err != nil {
		panic(err)
	}
	old := "tState <= wClk ? T0 : T1;"
	if strings.Count(string(data), old) != 1 {
		panic("fx68k enum workaround no longer matches")
	}
	source := strings.Replace(string(data), old, "begin if(wClk) tState <= T0; else tState <= T1; end", 1)
	if err := os.WriteFile("fx68k_iverilog.sv", []byte(source), 0600); err != nil {
		panic(err)
	}
}
