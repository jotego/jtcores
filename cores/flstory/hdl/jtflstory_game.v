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
    Date: 23-11-2024 */

module jtflstory_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire       ghflip, gvflip;
wire [1:0] pal_bank;

jtflstory_video u_game(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .ghflip     ( ghflip    ),
    .gvflip     ( gvflip    ),
    .lhbl       ( LHBL      ),
    .lvbl       ( LVBL      ),
    .vs         ( VS        ),
    .hs         ( HS        ),

    // Scroll
    .vram_addr  ( vram_addr ),
    .vram_data  ( vram_data ),
    .scr_addr   ( scr_addr  ),
    .scr_data   ( scr_data  ),
    .scr_cs     ( scr_cs    ),
    .scr_ok     ( scr_ok    ),

    // Objects
    //      RAM shared with CPU
    .oram_addr  ( oram_addr ),
    .oram_dout  ( oram_dout ),
    //      ROM
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),
    .obj_cs     ( obj_cs    ),
    .obj_ok     ( obj_ok    ),

    // palette - color mixer
    .pal_bank   ( pal_bank  ),
    .prio_addr  ( prio_addr ),
    .prio_dout  ( prio_dout ),
    .pal_addr   ( pal_addr  ),
    .pal_dout   ( pal_dout  ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule