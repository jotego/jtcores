/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-3-2025 */

module jtcus115(
    input         rst,
    input         clk,
    input         cs,
    input  [15:0] addr,
    input  [ 7:0] din,
    output [ 4:0] banksel,

    output [ 1:0] pcm_addr,
    output        pcm_wr
);

wire banksel_cs;
wire [3:0] asel;

assign asel       = addr[12:9];
assign banksel_cs = asel==4 && cs;
assign pcm_addr   = asel[1:0];
assign pcm_wr     = asel[3:2]==0 && cs;

jtframe_mmr_reg #(.W(5)) u_mbank(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( 1'b0      ),
    .din        ( din[4:0]  ),
    .cs         ( banksel_cs),
    .dout       ( banksel   )
);

endmodule    