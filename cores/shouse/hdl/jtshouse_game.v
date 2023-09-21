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
    Date: 21-9-2023 */

module jtshouse_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [21:0] baddr;
wire        brnw, key_cs;
wire [ 7:0] bdout, key_dout;

// bit 16 of ROM T10 in sch. is inverted:
assign main_addr = (&baddr[21:18] ? 22'h10000 : 22'h0) ^ baddr;
assign sub_addr  = main_addr;

jtshouse_key u_key(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cs         ( key_cs    ),
    .rnw        ( brnw      ),
    .addr       ( baddr[7:0]),
    .din        ( bdout     ),
    .dout       ( key_dout  )

    .prog_en    ( header    ),
    .prog_wr    ( prog_wr   ),
    .prog_addr  ( prog_addr[2:0] ),
    .prog_data  ( prog_data )

);

endmodule