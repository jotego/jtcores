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
    Date: 12-7-2026 */

module jtgals_sound(
    input              rst,
    input              clk,
    input              cen,
    input       [ 7:0] cpu_dout,
    input              cs,
    input              wr,
    input       [ 3:0] bank,
    output      [ 7:0] dout,

    output             rom_cs,
    output      [19:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,

    output signed [13:0] pcm
);

`ifndef NOSOUND

wire [17:0] raw_addr;
wire        wrn;

assign wrn      = ~(cs && wr);
assign rom_cs   = 1'b1;
assign rom_addr = raw_addr < 18'h30000 ? { 2'd0, raw_addr } :
                  { bank, raw_addr[15:0] };

jt6295 u_pcm(
    .rst      ( rst      ),
    .clk      ( clk      ),
    .cen      ( cen      ),
    .ss       ( 1'b0     ),
    .wrn      ( wrn      ),
    .din      ( cpu_dout ),
    .dout     ( dout     ),
    .rom_addr ( raw_addr ),
    .rom_data ( rom_data ),
    .rom_ok   ( rom_ok   ),
    .sound    ( pcm      ),
    .sample   (          )
);

`else

assign dout     = 8'hff;
assign rom_cs   = 1'b0;
assign rom_addr = 20'd0;
assign pcm      = 14'sd0;

`endif

endmodule
