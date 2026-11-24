package main

import (
	"os"
	"path/filepath"
	"strings"
)

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
	fxPath := filepath.Join(hdl, "verilator/fx68k.sv")
	fx, err := os.ReadFile(fxPath)
	if err != nil {
		panic(err)
	}
	const fxEnum = "tState <= wClk ? T0 : T1;"
	if strings.Count(string(fx), fxEnum) != 1 {
		panic("fx68k enum workaround no longer matches")
	}
	fxCopy := strings.Replace(string(fx), fxEnum, "begin if(wClk) tState <= T0; else tState <= T1; end", 1)
	if err := os.WriteFile("fx68k_iverilog.sv", []byte(fxCopy), 0600); err != nil {
		panic(err)
	}

	sdramPath := filepath.Join(os.Getenv("JTROOT"), "cores/cps1/hdl/jtcps1_sdram.v")
	sdram, err := os.ReadFile(sdramPath)
	if err != nil {
		panic(err)
	}
	sdramText := string(sdram)
	moduleDecl := "module jtcps1_sdram #( parameter"
	if strings.Count(sdramText, moduleDecl) != 1 {
		panic("jtcps1_sdram module declaration workaround no longer matches")
	}
	sdramText = strings.Replace(sdramText, moduleDecl, "module jtcps1_sdram_test #( parameter", 1)
	const eraseParam = ".SLOT0_ERASE (  1            ),"
	if strings.Count(sdramText, eraseParam) != 1 {
		panic("jtcps1_sdram work-RAM erase parameter workaround no longer matches")
	}
	sdramText = strings.Replace(sdramText, eraseParam, ".SLOT0_ERASE (  0            ),", 1)
	if err := os.WriteFile("jtcps1_sdram_test.v", []byte(sdramText), 0600); err != nil {
		panic(err)
	}
}
