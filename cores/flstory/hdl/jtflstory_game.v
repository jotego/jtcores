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

wire       ghflip, gvflip, cen_mcu;
wire [1:0] pal_bank;

jtframe_cendiv u_cendiv(
    .clk        ( clk       ),
    .cen_in     ( pxl_cen   ),
    .cen_div    ( cen_mcu   ),
    .cen_da     (           )
);

jtflstory_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_5p3   ),
    .lvbl       ( lvbl      ),       // video interrupt

    .bus_addr   ( bus_addr  ),
    .bus_din    ( bus_din   ),
    .bus_rnw    ( bus_rnw   ),

    // Cabinet inputs
    .cab_1p     ( cab_1p    ),
    .coin       ( coin      ),
    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .dipsw      (dipsw[23:0]),
    .service    ( service   ),
    .tilt       ( tilt      ),
    // ROM access
    .rom_cs     ( main_cs   ),
    .rom_addr   ( main_addr ),
    .rom_data   ( main_data ),
    .rom_ok     ( main_ok   ),

    .debug_bus  ( debug_bus )
);

jtflstory_mcu u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .cpu_dout   ( cpu_dout  ),
    .dout       ( dout      ),
    .stn        ( stn       ),
    .irqn       ( irqn      ),
    // bus sharing
    .baddr      ( baddr     ),
    // ROM
    .rom_addr   ( mcu_addr  ),
    .rom_data   ( mcu_data  )
);

jtflstory_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen4       ( cen4      ),
    .cen2       ( cen2      ),

    // communication with the other CPUs
    .bus_dout   ( bus_dout  ),
    .bus_wr     ( bus_wr    ),
    .bus_rd     ( bus_rd    ),
    .bus_cs     ( bus_cs    ),
    .bus_a0     ( bus_a0    ),
    .bus_din    ( bus_din   ),

    .rom_addr   ( snd_addr  ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),
    .rom_cs     ( snd_cs    ),

    // sound output
    .psg        ( psg       ),
    .debug_bus  ( debug_bus )
);

jtflstory_video u_video(
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