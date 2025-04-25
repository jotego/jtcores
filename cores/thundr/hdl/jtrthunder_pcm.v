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
    Date: 23-3-2025 */

module jtthundr_pcm(
    input               rst,
                        clk, cen,
    input        [ 1:0] addr,
    input        [ 7:0] din,
    input               wr,

    output       [18:0] rom0_addr,
    input        [ 7:0] rom0_data,
    output              rom0_cs,
    input               rom0_ok,

    output       [18:0] rom1_addr,
    input        [ 7:0] rom1_data,
    output              rom1_cs,
    input               rom1_ok,

    output       [11:0] pcm0, pcm1
);

wire wr0, wr1;

assign wr0 = ~addr[1] & wr;
assign wr1 =  addr[1] & wr;

jtthundr_pcm_single u_ch0(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .addr       ( addr[0]   ),
    .din        ( din       ),
    .wr         ( wr0       ),
    .rom_addr   ( rom0_addr ),
    .rom_data   ( rom0_data ),
    .rom_cs     ( rom0_cs   ),
    .rom_ok     ( rom0_ok   ),
    .snd        ( pcm0      )
);

jtthundr_pcm_single u_ch1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .addr       ( addr[0]   ),
    .din        ( din       ),
    .wr         ( wr1       ),
    .rom_addr   ( rom1_addr ),
    .rom_data   ( rom1_data ),
    .rom_cs     ( rom1_cs   ),
    .rom_ok     ( rom1_ok   ),
    .snd        ( pcm1      )
);

endmodule
