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
    Date: 9-8-2026 */

// Tecfri Tricky Doc. MAME covers it in tecfri/sauro.cpp, but Sauro
// itself is a different board and is not handled here

module jttrcdoc_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// cpu_addr and cpu_dout are declared in mem.yaml, they feed the BRAMs
wire [ 7:0] scrx;
wire        cpu_rnw, flip, fm_cs;
wire        wram_cs, oram_cs, vram_cs, cram_cs;

assign dip_flip   = flip;
assign debug_view = 0;

assign wram_we = wram_cs & ~cpu_rnw;
assign oram_we = oram_cs & ~cpu_rnw;
assign vram_we = vram_cs & ~cpu_rnw;
assign cram_we = cram_cs & ~cpu_rnw;

jttrcdoc_main u_main(
    .rst            ( rst24         ),
    .clk            ( clk24         ),
    .cen            ( cpu_cen       ),

    .cpu_addr       ( cpu_addr      ),
    .cpu_rnw        ( cpu_rnw       ),
    .cpu_dout       ( cpu_dout      ),

    .wram_cs        ( wram_cs       ),
    .oram_cs        ( oram_cs       ),
    .vram_cs        ( vram_cs       ),
    .cram_cs        ( cram_cs       ),
    .wram_dout      ( wram_dout     ),
    .oram_dout      ( oram_dout     ),
    .vram_dout      ( vram_dout     ),
    .cram_dout      ( cram_dout     ),

    .fm_cs          ( fm_cs         ),

    .scrx           ( scrx          ),
    .flip           ( flip          ),

    .LVBL           ( LVBL          ),
    // cabinet I/O
    .cab_1p         ( cab_1p[1:0]   ),
    .coin           ( coin[1:0]     ),
    .joystick1      ( joystick1[5:0]),
    .joystick2      ( joystick2[5:0]),
    .service        ( service       ),
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw[ 7:0]   ),
    .dipsw_b        ( dipsw[15:8]   ),

    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       )
);

jttrcdoc_snd u_snd(
    .rst        ( rst24         ),
    .clk        ( clk24         ),
    .cen        ( fm_cen        ),

    .cs         ( fm_cs         ),
    .addr       ( cpu_addr[0]   ),
    .wr_n       ( cpu_rnw       ),
    .din        ( cpu_dout      ),
    .dout       (               ),

    .fm         ( fm            )
);

jttrcdoc_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .flip       ( flip          ),
    .scrx       ( scrx          ),

    .vscan_addr ( vscan_addr    ),
    .vscan_dout ( vscan_dout    ),
    .cscan_dout ( cscan_dout    ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_cs     ( scr_cs        ),
    .scr_ok     ( scr_ok        ),

    .oscan_addr ( oscan_addr    ),
    .oscan_dout ( oscan_dout    ),
    .objrom_addr( objrom_addr   ),
    .objrom_data( objrom_data   ),
    .objrom_cs  ( objrom_cs     ),
    .objrom_ok  ( objrom_ok     ),

    .prog_data  ( prog_data     ),
    .prog_addr  ( prog_addr[9:0]),
    .prom_we    ( prom_we       ),

    .HS         ( HS            ),
    .VS         ( VS            ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .gfx_en     ( gfx_en        )
);

endmodule
