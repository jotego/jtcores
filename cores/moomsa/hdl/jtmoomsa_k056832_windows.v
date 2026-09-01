/* SPDX-License-Identifier: GPL-3.0-or-later */

// CPU-visible K056832 windows for the Moo Mesa address map.
//
// The low M6/G7 selects are board-level decoded signals.  This module keeps
// their physical ownership separate from the high-address windows proven by
// the software map, so an unresolved P6 equation is not silently replaced by
// a guessed PAL implementation.
module jtmoomsa_k056832_windows(
    input             bus_active,
    input             cpu_rnw,
    input             uds_n,
    input             lds_n,
    input             pale_n,
    input             lyr_prio_n,
    input             pre_dtack_n,
    input      [23:1] addr,
    output            reg_cs,
    output            b_cs,
    output            vram_cs,
    output            rom_cs,
    output            any_cs,
    output     [4:0]  reg_addr,
    output     [1:0]  b_addr,
    output     [13:1] vram_addr,
    output     [12:1] rom_addr
);

wire byte_cycle = !uds_n || !lds_n;
wire active = bus_active && byte_cycle;

// The 68000 address bus is presented without A0.  Constants below are the
// corresponding word-address values of the byte-addressed MAME map.
wire reg_window = (addr[23:6] == 18'h03000); // 0x0c0000..0x0c003f
wire b_window   = (addr[23:3] == 21'h01b000); // 0x0d8000..0x0d8007

assign reg_cs   = active && !pale_n && reg_window;
assign b_cs     = active && !pale_n && b_window;
assign vram_cs  = active && !lyr_prio_n;
assign rom_cs   = active && cpu_rnw && !pre_dtack_n;
assign any_cs   = reg_cs || b_cs || vram_cs || rom_cs;

assign reg_addr  = addr[5:1];
assign b_addr    = addr[2:1];
assign vram_addr = addr[13:1];
assign rom_addr  = addr[12:1];

endmodule
