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
    Date: 27-8-2024 */

module jtwwfss_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] char_dout;
wire [11:1] main_addr;
wire [ 8:0] scrx, scry;
wire [ 7:0] snd_latch;
wire [ 1:0] pal_wen;
wire        snd_on, v8;

assign char_dout = {8'd0, main_addr[1] ? char16_dout[7:0] : char16_dout[15:8]};
assign scr_dout  = {8'd0, main_addr[1] ? scr16_dout[7:0] : scr16_dout[15:8]};
assign obj_dout  = {8'd0, main_addr[1] ? scr16_dout[7:0] : scr16_dout[15:8]};

jtwwfss_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ), // 48 MHz
    .LVBL       ( LVBL      ),
    .v8         ( v8        ),

    .main_addr  ( main_addr ),
    .main_dsn   ( main_dsn  ),
    .main_dout  ( main_dout ),
    .main_rnw   ( main_rnw  ),

    .cram_we    ( cram_we   ),
    .scr_we     ( scr_we    ),
    .oram_we    ( oram_we   ),
    .pal_wen    ( pal_wen   ),

    .fix_dout   ( fix_dout  ),
    .scr_dout   ( scr_dout  ),
    .oram_dout  ( oram_dout ),
    .pal_dout   ( pal_dout  ),

    .scrx       ( scrx      ),
    .scry       ( scry      ),

    .ram_cs     ( ram_cs    ),
    .ram_ok     ( ram_ok    ),
    .ram_dout   ( ram_dout  ),

    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),

    // Sound interface
    .snd_on     ( snd_on        ),
    .snd_latch  ( snd_latch     ),

    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw[ 7:0]   ),
    .dipsw_b    ( dipsw[15:8]   )
);

jtwwfss_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .v8         ( v8            ),

    .cpu_dout   ( cpu_dout      ),
    .cpu_addr   ( cpu_addr[9:1] ),

    // Char
    .cram_addr  ( cram_addr     ),
    .cram_data  ( cram_data     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_cs    ( char_cs       ),
    .char_ok    ( char_ok       ),

    // Scroll
    .scrx       ( scrx          ),
    .scry       ( scry          ),
    .vram_addr  ( vram_addr     ),
    .vram_data  ( vram_data     ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_cs     ( scr_cs        ),
    .scr_ok     ( scr_ok        ),
    .scr_cs     ( scr_cs        ),

    // Object
    .oram_addr  ( oram_addr     ),
    .oram_data  ( oram_data     ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_cs     ( obj_cs        ),
    .obj_ok     ( obj_ok        ),
    .obj_cs     ( obj_cs        ),

    .pal_wen    ( pal_wen       ),
    .pal_dout   ( pal_dout      ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .gfx_en     ( gfx_en        )
);

jtwwfss_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),
    .cen_oki    ( cen_oki   ),

    // Interface with main CPU
    .snd_on     ( snd_on    ),
    .snd_latch  ( snd_latch ),

    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),

    // ADPCM ROM
    .pcm_addr   ( pcm_addr  ),
    .pcm_cs     ( pcm_cs    ),
    .pcm_data   ( pcm_data  ),
    .pcm_ok     ( pcm_ok    ),

    // Sound output
    .fm_l       ( fm_l      ),
    .fm_r       ( fm_r      ),
    .pcm        ( pcm       )
);

endmodule
