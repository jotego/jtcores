/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps

module jtmoomsa_054156_vram_data(
    input             clk,
    input             capture,
    input      [23:0] vd_in,
    output reg [23:0] vd_latch,
    input             cpu_vram_cs,
    input             cpu_active,
    input             cpu_we,
    input             cpu_a1,
    input      [1:0]  cpu_dsn,
    input      [15:0] cpu_din,
    output     [23:0] cpu_vd_out,
    output     [2:0]  cpu_rwe_n
);

wire cpu_write = cpu_vram_cs && cpu_active && cpu_we;

assign cpu_vd_out = {cpu_din[7:0],cpu_din[15:8],cpu_din[7:0]};
assign cpu_rwe_n = {
    !(cpu_write && !cpu_a1 && !cpu_dsn[0]),
    !(cpu_write &&  cpu_a1 && !cpu_dsn[1]),
    !(cpu_write &&  cpu_a1 && !cpu_dsn[0])
};

always @(posedge clk)
    if (capture)
        vd_latch <= vd_in;

endmodule
