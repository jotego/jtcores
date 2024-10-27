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
    Date: 26-10-2024 */

module jtwc_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire       m2s_set, hflip, vflip;
wire [8:0] scrx;
wire [7:0] m2s, s2m, scry;

jtwc_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_psg    ( cen_psg       ),
    .cen_psg2   ( cen_psg2      ),
    .cen_pcm    ( cen_pcm       ),
    .m2s_set    ( m2s_set       ),
    .m2s        ( m2s           ),
    .s2m        ( s2m           ),
    // ROM access
    .rom_cs     ( snd_cs        ),
    .rom_addr   ( snd_addr      ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),
    // PCM ROM
    .pcm_cs     ( pcm_cs        ),
    .pcm_addr   ( pcm_addr      ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),
    // Sound output
    .psg0       ( psg0          ),
    .psg1       ( psg1          ),
    .pcm        ( pcm           )
);

jtwc_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .hflip      ( hflip         ),
    .vflip      ( vflip         ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),
    .vs         ( vs            ),
    .hs         ( hs            ),
    // Character (fix) RAM
    .fix_addr   ( fix_addr      ),
    .fix_dout   ( fix_dout      ),
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
    // Palette RAM
    .pal_addr   ( pal_addr      ),
    .pal_dout   ( pal_dout      ),
    // Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    // Debug
    .gfx_en     ( gfx_en        )
);

endmodule
