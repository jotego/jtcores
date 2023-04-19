/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-1-2021 */

module jtcps2_dec_ctrl(
    input             clk,
    input             rom_ok,
    output            rom_ok_out,

    input      [15:0] range,
    input      [23:1] addr,
    input      [ 2:0] fc,
    input             en,

    input      [15:0] din,
    input      [15:0] dec,
    output reg [15:0] dout
);

reg en_latch;
reg [1:0] ok_sh;

assign rom_ok_out = ok_sh[0];

wire op_fetch = fc[1:0]==2'b10;

always @(posedge clk) begin
    en_latch <= op_fetch && en && (addr[14+:10] <= range[9:0]);
    ok_sh    <= { ok_sh[0], rom_ok };
    dout     <= en_latch ? dec : din;
end

endmodule