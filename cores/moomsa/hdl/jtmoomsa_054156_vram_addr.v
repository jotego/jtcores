/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps

module jtmoomsa_054156_vram_addr(
    input       [10:0] cpu_ab_ram,
    input       [10:0] cpu_ab_mux_ram,
    input       [10:0] scan_low,
    input        [5:0] scan_page,
    input        [5:0] cpu_bank,
    input        [5:0] scan_bank,
    input              cpu_addr_mode,
    input              scan_bank_mode,
    output      [16:0] cpu_va,
    output      [16:0] scan_va,
    output      [12:0] cpu_scrama,
    output      [12:0] scan_scrama
);

wire [10:0] cpu_low = cpu_addr_mode ? cpu_ab_mux_ram : cpu_ab_ram;
wire  [5:0] scan_hi = scan_bank_mode ? scan_bank : scan_page;

assign cpu_va  = {cpu_bank, cpu_low};
assign scan_va = {scan_hi, scan_low};
assign cpu_scrama  = {cpu_va[14], cpu_va[11:0]};
assign scan_scrama = {scan_va[14], scan_va[11:0]};

endmodule
