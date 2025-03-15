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
    Date: 15-3-2025 */

module jtrthunder_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] fave;
wire [ 2:0] busy;
reg  [ 7:0] dbg_mux;

assign debug_view= dbg_mux;

always @* begin
    case( debug_bus[7:6] )
        // 0: dbg_mux = { 3'd0, mcu_halt, 3'd0, ~srst_n };
        // 1: dbg_mux = st_video;
        // 2: dbg_mux = st_main;
        3: dbg_mux = debug_bus[0] ? fave[7:0] : fave[15:8]; // average CPU frequency (BCD format)
        default: dbg_mux = 0;
    endcase
end

jtrthunder_cenloop u_cen(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .busy       ( busy      ),

    .cen_main   ( cen_main  ),
    .cen_sub    ( cen_sub   ),
    .cen_mcu    ( cen_mcu   ),

    .fave       ( fave      ),
    .fworst     (           )
);

endmodule