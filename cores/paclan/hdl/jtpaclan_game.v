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

module jtpaclan_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] fave, maddr;
wire [ 1:0] busy;
reg  [ 7:0] dbg_mux;
wire [ 7:0] st_main, mdout, c30_dout, st_video;
wire [ 8:0] scr0_pos, scr1_pos;
wire [ 1:0] palbank;
wire        cen_E, cen_Q, cen_mcu, flip, mmr0_cs, mmr1_cs,
            mrnw, srst, mc30_cs, mcu_seln, cpu_rnw;
reg         lvbl_ps;

assign debug_view   = dbg_mux;
assign dip_flip     = flip;

always @(posedge clk) lvbl_ps <= LVBL & dip_pause;

always @* begin
    case( debug_bus[7:6] )
        0: dbg_mux = st_video;
        2: dbg_mux = st_main;
        3: dbg_mux = debug_bus[0] ? fave[7:0] : fave[15:8]; // average CPU frequency (BCD format)
        default: dbg_mux = 0;
    endcase
end

jtthundr_cenloop u_cen(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .busy       ( busy      ),

    .cen_main   ( cen_E     ),
    .cen_sub    ( cen_Q     ),
    .cen_mcu    ( cen_mcu   ),
    .mcu_seln   ( mcu_seln  ),

    .fave       ( fave      ),
    .fworst     (           )
);

jtpaclan_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_E      ( cen_E     ),
    .cen_Q      ( cen_Q     ),
    .srst       ( srst      ),

    .lvbl       ( lvbl_ps   ),
    .scr0_pos   ( scr0_pos  ),
    .scr1_pos   ( scr1_pos  ),
    .palbank    ( palbank   ),
    .flip       ( flip      ),

    .cpu_dout   ( cpu_dout  ),
    .rnw        ( cpu_rnw   ),
    // ROM
    .rom_cs     ( main_cs   ),
    .rom_ok     ( main_ok   ),
    .rom_addr   ( main_addr ),
    .rom_data   ( main_data ),

    .bus_busy   ( busy[0]   ),

    // VRAM
    .scr0_dout  ( fg_dout   ),
    .scr1_dout  ( bg_dout   ),
    .oram_dout  ( olut_dout ),
    .scr0_we    ( bg_we     ),
    .scr1_we    ( fg_we     ),
    .oram_we    ( olut_we   ),

    // CUS30
    .c30_dout   ( c30_dout  ),
    .c30_cs     ( mc30_cs   ),

    .ioctl_din  ( ioctl_din ),
    .ioctl_addr ( ioctl_addr[1:0]),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_main   )
);

jtpaclan_sound u_sound(
    .rst        ( srst      ),
    .clk        ( clk       ),
    .cen_mcu    ( cen_mcu   ),
    .cen_c30    ( cen_c30   ),
    .pxl_cen    ( pxl_cen   ),

    .vs         ( VS        ),
    .lvbl       ( lvbl_ps   ),

    .dipsw      (dipsw[15:0]),
    .joystick1  (joystick1[6:0]),
    .joystick2  (joystick2[6:0]),
    .joyana_r1  ( joyana_r1 ),
    .cab_1p     (cab_1p[1:0]),
    .coin       ( coin[1:0] ),
    .service    ( service   ),

    // sub 6809 connection to CUS30/PCM MCU
    .mcu_seln   ( mcu_seln  ),
    .c30_dout   ( c30_dout  ),
    .mc30_cs    ( mc30_cs   ),
    .mrnw       ( cpu_rnw   ),
    .maddr      (main_addr[9:0]),
    .mdout      ( cpu_dout  ),

    .ram_addr   (sndram_addr),
    .ram_dout   (sndram_dout),
    .ram_we     (sndram_we  ),
    .ram_din    (sndram_din ),

    .embd_addr  ( mcu_addr  ),
    .embd_data  ( mcu_data  ),

    .rom_cs     (mcusub_cs  ),
    .rom_ok     (mcusub_ok  ),
    .rom_addr   (mcusub_addr),
    .rom_data   (mcusub_data),
    .bus_busy   ( busy[1]   ),

    .cus30_l    ( cus30_l   ),
    .cus30_r    ( cus30_r   ),
    .debug_bus  ( debug_bus )
);

jtpaclan_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .flip       ( flip      ),
    .scr0_pos   ( scr0_pos  ),
    .scr1_pos   ( scr1_pos  ),
    .palbank    ( palbank   ),

    .lvbl       ( LVBL      ),
    .lhbl       ( LHBL      ),
    .hs         ( HS        ),
    .vs         ( VS        ),

    // Objects
    .oram_addr  ( oram_addr ),
    .oram_dout  ( oram_dout ),

    // Tile ROM decoder PROM
    .vram0_addr ( vram0_addr),
    .vram1_addr ( vram1_addr),
    .vram0_dout  (vram0_dout),
    .vram1_dout  (vram1_dout),

    // ROMs
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),
    .obj_ok     ( obj_ok    ),

    .scr0_cs    ( scr0_cs   ),
    .scr0_addr  ( scr0_addr ),
    .scr0_data  ( scr0_data ),
    .scr0_ok    ( scr0_ok   ),

    .scr1_cs    ( scr1_cs   ),
    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),
    .scr1_ok    ( scr1_ok   ),

    // Palette PROMs
    .objpal_addr ( objpal_addr  ),
    .objpal_data ( objpal_data  ),

    .scr0pal_addr( scr0pal_addr ),
    .scr1pal_addr( scr1pal_addr ),
    .scr0pal_data( scr0pal_data ),
    .scr1pal_data( scr1pal_data ),

    .rgb_addr    ( rgb_addr     ),
    .rg_data     ( rgpal_data   ),
    .b_data      ( bpal_data[3:0] ),
    .red         ( red          ),
    .green       ( green        ),
    .blue        ( blue         ),
    // Debug
    .gfx_en      ( gfx_en       ),
    .debug_bus   ( debug_bus    ),
    .st_dout     ( st_video     )
);

endmodule
