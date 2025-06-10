/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-5-2025 */

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
