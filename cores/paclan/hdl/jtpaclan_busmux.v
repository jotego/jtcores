/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-5-2025 */

module jtpaclan_busmux(
    input         clk, rom_ok,
    output reg    ok_dly,
    input         scr0_cs, scr1_cs, oram_cs, c30_cs, rom_cs, addr0,
    input  [15:0] scr0_dout, scr1_dout, oram_dout,
    input  [ 7:0] c30_dout, rom_data,
    output [ 7:0] muxed
);

reg [7:0] pre;
reg       c30_csl;

assign muxed = c30_csl ? c30_dout : // c30_dout comes too late to register it
               pre;

always @(posedge clk) begin
    ok_dly  <= rom_ok;
    c30_csl <= c30_cs;
    pre <= scr0_cs ? w2b(scr0_dout) :
           scr1_cs ? w2b(scr1_dout) :
           rom_cs  ? rom_data       :
           oram_cs ? w2b(oram_dout) : 8'd0;
end

function [7:0] w2b(input [15:0] w); begin
    w2b = addr0 ? w[15:8] : w[7:0];
end endfunction

endmodule
