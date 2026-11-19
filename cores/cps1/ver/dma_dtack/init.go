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

	// Icarus resolves declarations in source order while Verilator allows
	// last_LVBL to be declared after its first use in jtcps1_main.v. Move only
	// that declaration in a temporary copy; no functional RTL is changed.
	mainPath := filepath.Join(os.Getenv("JTROOT"), "cores/cps1/hdl/jtcps1_main.v")
	main, err := os.ReadFile(mainPath)
	if err != nil {
		panic(err)
	}
	mainText := string(main)
	late := "reg        last_LVBL;"
	early := "reg         dsn_dly;"
	if strings.Count(mainText, late) != 1 || strings.Count(mainText, early) != 1 {
		panic("jtcps1_main declaration workaround no longer matches")
	}
	mainText = strings.Replace(mainText, late, "", 1)
	mainText = strings.Replace(mainText, early, "reg         dsn_dly, last_LVBL;", 1)
	if err := os.WriteFile("jtcps1_main_iverilog.v", []byte(mainText), 0600); err != nil {
		panic(err)
	}
}
