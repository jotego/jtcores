/* SPDX-License-Identifier: GPL-3.0-or-later */
/* verilator lint_off UNUSEDSIGNAL */

module jtmoomsa_main_decode(
    input  [23:1] addr,
    input         as_n,
    input         pale_n,
    input         uds_n,
    input         lds_n,
    input         rw,
    output        m6_rom,
    output        m6_reg,
    output        m6_cr,
    output        m6_regcs,
    output        m6_pcu,
    output        m6_objcs,
    output        m6_objreg,
    output        g7_cc0,
    output        g7_col,
    output        g7_sdon,
    output        g7_pair,
    output        g7_bnk_scr,
    output        g7_io,
    output        g7_iocsb,
    output        g7_reg_write
);

// M6B/L6B 74LS138 hits are normalized to active-high selects. G7 is the
// direct 74LS08 BDS stage; the normalized g7_reg_write name is retained for
// interface stability, but its producer is L6B O7.
// Direct KiCad marks M6B O3/O4 no-connect.  P6 owns every high-address
// resource select; this block only represents the PALE-qualified TTL decoders.
wire m6_en = !as_n && !pale_n && !addr[16];
wire bds_n = uds_n & lds_n;
wire g7_en = !as_n && !bds_n && !pale_n && addr[16];

wire [7:0] m6_hit = m6_en ? (8'b1 << addr[15:13]) : 8'b0;
wire [7:0] g7_hit = g7_en ? (8'b1 << addr[15:13]) : 8'b0;

assign m6_rom    = m6_hit[0];
assign m6_reg    = m6_hit[1];
assign m6_cr     = m6_hit[2];
assign m6_regcs  = m6_hit[5];
assign m6_pcu    = m6_hit[6];
assign m6_objcs  = 1'b0;
assign m6_objreg = m6_hit[7];

assign g7_cc0      = g7_hit[0];
assign g7_col      = g7_hit[1];
assign g7_sdon     = g7_hit[2];
assign g7_pair     = g7_hit[3];
assign g7_bnk_scr  = g7_hit[4];
assign g7_io       = g7_hit[5];
assign g7_iocsb    = g7_hit[6];
assign g7_reg_write= g7_hit[7] && !rw;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
