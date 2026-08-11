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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 10-8-2026 */

module jtpspike_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [ 3:0] gfxbank0, gfxbank1;
wire [ 2:0] charbank;
wire [ 1:0] objbank;
wire        flip;
wire [ 8:0] scry;
wire [ 7:0] snd_latch;
wire        snd_wr, snd_pending;
wire        main_rnw;
wire [ 1:0] main_dsn;

assign dip_flip   = flip;
assign debug_view = 0;
assign st_dout    = 0;

assign ram_addr   = main_addr[15:1];
assign vram_addr  = main_addr[11:1];
assign rascr_addr = main_addr[11:1];
assign oram_addr  = main_addr[ 9:1];
assign lut_addr   = main_addr[13:1];
assign pal_addr   = main_addr[11:1];

jtpspike_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LVBL       ( LVBL          ),
    .dip_pause  ( dip_pause     ),

    .main_addr  ( main_addr     ),
    .main_dout  ( main_dout     ),
    .main_rnw   ( main_rnw      ),
    .main_dsn   ( main_dsn      ),
    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),

    .ram_we     ( ram_we        ),
    .vram_we    ( vram_we       ),
    .rascr_we   ( rascr_we      ),
    .oram_we    ( oram_we       ),
    .lut_we     ( lut_we        ),
    .pal_we     ( pal_we        ),
    .ram_dout   ( ram_dout      ),
    .vram_dout  ( vram_dout     ),
    .rascr_dout ( rascr_dout    ),
    .oram_dout  ( oram_dout     ),
    .lut_dout   ( lut_dout      ),
    .pal_dout   ( pal_dout      ),

    .gfxbank0   ( gfxbank0      ),
    .gfxbank1   ( gfxbank1      ),
    .charbank   ( charbank      ),
    .objbank    ( objbank       ),
    .flip       ( flip          ),
    .scry       ( scry          ),

    .snd_latch  ( snd_latch     ),
    .snd_wr     ( snd_wr        ),
    .snd_pending( snd_pending   ),

    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .service    ( service       ),
    .dipsw      ( dipsw[15:0]   )
);

jtpspike_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .gfxbank0   ( gfxbank0      ),
    .gfxbank1   ( gfxbank1      ),
    .charbank   ( charbank      ),
    .objbank    ( objbank       ),
    .flip       ( flip          ),
    .scry       ( scry          ),

    .scr_addr   ( scr_addr      ),
    .scr_vram   ( scr_vram      ),
    .ras_addr   ( ras_addr      ),
    .ras_dout   ( ras_dout      ),
    .objr_addr  ( objr_addr     ),
    .objr_dout  ( objr_dout     ),
    .objl_addr  ( objl_addr     ),
    .objl_dout  ( objl_dout     ),
    .mix_addr   ( mix_addr      ),
    .mix_pal    ( mix_pal       ),

    .scr0_addr  ( scr0_addr     ),
    .scr0_cs    ( scr0_cs       ),
    .scr0_data  ( scr0_data     ),
    .scr0_ok    ( scr0_ok       ),

    .obj0_addr  ( obj0_addr     ),
    .obj0_cs    ( obj0_cs       ),
    .obj0_data  ( obj0_data     ),
    .obj0_ok    ( obj0_ok       ),

    .gfx_en     ( gfx_en        ),

    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

jtpspike_snd u_snd(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .snd_cen    ( snd_cen       ),
    .fm_cen     ( fm_cen        ),

    .snd_latch  ( snd_latch     ),
    .snd_wr     ( snd_wr        ),
    .snd_pending( snd_pending   ),
    .debug_bus  ( debug_bus     ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),

    .pcma_addr  ( pcma_addr     ),
    .pcma_cs    ( pcma_cs       ),
    .pcma_data  ( pcma_data     ),
    .pcma_ok    ( pcma_ok       ),

    .pcmb_addr  ( pcmb_addr     ),
    .pcmb_cs    ( pcmb_cs       ),
    .pcmb_data  ( pcmb_data     ),
    .pcmb_ok    ( pcmb_ok       ),

    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          )
);

endmodule
