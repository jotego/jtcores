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
    Date: 29-3-2025 */

module jtcus115(
    input         rst,
    input         clk,
    input         cs,
    input  [15:0] addr,
    input  [ 7:0] din,
    output [ 4:0] banksel
);

wire banksel_cs;

assign banksel_cs = addr[12:9]==4 && cs;

jtframe_mmr_reg #(.W(5)) u_mbank(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( 1'b0      ),
    .din        ( din[4:0]  ),
    .cs         ( banksel_cs),
    .dout       ( banksel   )
);

endmodule    