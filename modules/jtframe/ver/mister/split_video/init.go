// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func must(err error) {
	if err != nil {
		panic(err)
	}
}
func between(s, a, b string) string {
	i := strings.Index(s, a)
	if i < 0 {
		panic("missing routing anchor: " + a)
	}
	j := strings.Index(s[i+len(a):], b)
	if j < 0 {
		panic("missing routing anchor: " + b)
	}
	return s[i : i+len(a)+j]
}
func main() {
	root := os.Getenv("JTFRAME")
	read := func(p string) string { b, e := os.ReadFile(filepath.Join(root, p)); must(e); return string(b) }
	write := func(p, s string) { must(os.WriteFile(p, []byte(s), 0644)) }
	emu := read("target/mister/hdl/jtframe_emu.sv")
	sys := read("target/mister/hdl/sys/sys_top.v")
	// Compile production routing, not a second copy of its equations.
	write("emu_route.vh", between(emu, "`ifndef JTFRAME_SPLIT_VIDEO\n`ifndef JTFRAME_INTERLACED", "// unused features"))
	write("scan_ports.vh", between(emu, "`ifdef JTFRAME_SPLIT_VIDEO\n    .scan2x_r", "    // status"))
	write("sys_route.vh", between(sys, "`ifdef JTFRAME_SPLIT_VIDEO\nwire  [7:0] sc_r", "wire uart_dtr;"))
	write("cfg_route.vh", between(sys, "`ifdef MISTER_DEBUG_NOHDMI\n\twire    vga_fb", "wire       audio_96k")+between(sys, "\t`ifdef MISTER_DEBUG_NOHDMI\n\t\twire vga_scaler", "\n`endif\n\nreg        cfg_custom_t"))
	// Guard paths outside the isolated combinational harness: both OSDs stay
	// downstream, RGB/component conversion consumes the analog OSD result, and
	// scandoubler controls remain in the standard framework path.
	for _, want := range []string{
		".din(vga_data_sl)", ".din(vga_data_osd)", ".ypbpr_en(ypbpr_en)",
		".dout(vga_data_osd)", ".VGA_F1(f1)", ".SCALER_F1(sc_f1)",
		"wire forced_scandoubler = cfg[4]", "wire ypbpr_en           = cfg[5]",
		".i_fl     (hf1)", ".HPS_BUS({fb_en, sl, hf1, HDMI_TX_VS,",
	} {
		if !strings.Contains(sys, want) {
			panic("changed downstream wiring: " + want)
		}
	}
	if !strings.Contains(emu, "assign VGA_SL    = 2'd0;") {
		panic("split scanlines must be disabled")
	}
	fmt.Println("Production split/legacy routing extracted; OSD, format, field and scandoubler connections checked")
}
