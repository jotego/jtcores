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

wire [7:0] snd_latch;

jtwwfss_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),
    .cen_oki    ( cen_oki   ),

    // Interface with main CPU
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
