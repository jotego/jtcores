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
    Date: 23-8-2024 */

module jtcircus_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// SDRAM offsets
localparam [21:0] SCR_START  = `JTFRAME_BA2_START,
                  OBJ_START  = `JTFRAME_BA3_START;
localparam [24:0] PROM_START = `JTFRAME_PROM_START;

wire        cpu_rnw, cpu_irqn, cpu_nmin, cpu_cen, obj_frame,
            snd_on, main_pause, mute;
wire        vram_cs, vgap_cs, objram_cs, flip;
wire [ 7:0] vram_dout, obj_dout, cpu_dout, st_snd, snd_latch;

assign dip_flip   = flip^dipsw[16]; // extra DIPSW, not in the original
assign main_pause = dip_pause & ~ioctl_ram;
assign debug_view = { mute, st_snd[4], 1'd0, dip_flip, st_snd[3:0] };

jtcircus_main u_main(
    .rst            ( rst24         ),
    .clk            ( clk24         ),        // 24 MHz
    .cpudiv_cen     ( cpudiv_cen    ),
    .cpu_cen        ( cpu_cen       ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),
    // GFX
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),
    .vgap_cs        ( vgap_cs       ),
    .vram_cs        ( vram_cs       ),
    .vram_dout      ( vram_dout     ),

    .objram_cs      ( objram_cs     ),
    .obj_dout       ( obj_dout      ),
    // Sound control
    .snd_latch      ( snd_latch     ),
    .snd_irq        ( snd_on        ),
    .mute           ( mute          ),
    // GFX configuration
    .flip           ( flip          ),
    .obj_frame      ( obj_frame     ),
    // interrupt triggers
    .LVBL           ( LVBL          ),
    // DIP switches
    .dip_pause      ( main_pause    ),
    .dipsw_a        ( dipsw[ 7:0]   ),
    .dipsw_b        ( dipsw[15:8]   ),
    .dipsw_c        ( 7'h7f         )//unpopulated. None seems to have an effect
);

jtcircus_snd u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .psg1_cen   ( psg1_cen  ),    // 3.5MHz
    .psg2_cen   ( psg2_cen  ),    // 1.7MHz
    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),
    // From main CPU
    .main_latch ( snd_latch ),
    .snd_on     ( snd_on    ),
    // sound output
    .psg1       ( psg1      ),
    .psg2       ( psg2      ),
    .rdac       ( rdac      ),
    .psg1_rcen  ( psg1_rcen ),
    .psg2_rcen  ( psg2_rcen ),
    .rdac_rcen  ( rdac_rcen ),
    // debug
    .st_dout    ( st_snd    )
);

jtcircus_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    // configuration
    .flip       ( dip_flip  ),
    .obj_frame  ( obj_frame ),

    // CPU interface
    .cpu_addr   ( main_addr[10:0] ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    // Scroll
    .vram_cs    ( vram_cs   ),
    .vram_dout  ( vram_dout ),
    .vscr_cs    ( vgap_cs   ),
    // Objects
    .objram_cs  ( objram_cs ),
    .obj_dout   ( obj_dout  ),

    // PROMs
    .prog_data  ( prog_data ),
    .prog_addr  ( prog_addr[9:0] ),
    .prom_en    ( prom_we   ),

    // Scroll
    .scr_addr   ( scr_addr  ),
    .scr_data   ( scr_data  ),
    .scr_ok     ( scr_ok    ),
    .scr_cs     ( scr_cs    ),

    // Objects
    .obj_addr   ( objrom_addr ),
    .obj_data   ( objrom_data ),
    .obj_cs     ( objrom_cs ),
    .obj_ok     ( objrom_ok ),

    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

endmodule
