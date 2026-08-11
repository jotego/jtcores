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

wire [31:0] gfxbank;
wire [ 2:0] charbank;
wire        turbofrc, pspikes, aerofgt;
wire [ 8:0] scrx1, scry1;
wire [ 1:0] objbank;
wire        flip;
wire [ 8:0] scry;
wire [ 7:0] snd_latch;
wire        snd_wr, snd_pending;
wire        main_rnw;
wire        gga_cs, gga_we, gga_addr;
wire [ 1:0] main_dsn;

assign dip_flip   = flip;
assign debug_view = 0;
assign st_dout    = 0;

assign ram_addr   = main_addr[15:1];
assign vram_addr  = main_addr[12:1];
assign rascr_addr = main_addr[11:1];
assign oram_addr  = main_addr[10:1];
assign lut_addr   = main_addr[13:1];
assign pal_addr   = main_addr[11:1];
assign ram2_addr  = main_addr[13:1];
assign vram1_addr = main_addr[12:1];
assign oram1_addr = main_addr[10:1];
assign lut1_addr  = main_addr[13:1];

jtpspike_header u_header(
    .clk        ( clk           ),
    .header     ( header        ),
    .prog_we    ( prog_we       ),
    .prog_addr  ( prog_addr[2:0]),
    .prog_data  ( prog_data     ),
    .pspikes    ( pspikes       ),
    .turbofrc   ( turbofrc      ),
    .aerofgt    ( aerofgt       )
);

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

    .turbofrc   ( turbofrc      ),
    .aerofgt    ( aerofgt       ),
    .gfxbank    ( gfxbank       ),
    .charbank   ( charbank      ),
    .objbank    ( objbank       ),
    .flip       ( flip          ),
    .scry       ( scry          ),
    .scrx1      ( scrx1         ),
    .scry1      ( scry1         ),
    .ram2_we    ( ram2_we       ),
    .vram1_we   ( vram1_we      ),
    .oram1_we   ( oram1_we      ),
    .lut1_we    ( lut1_we       ),
    .ram2_dout  ( ram2_dout     ),
    .vram1_dout ( vram1_dout    ),
    .lut1_dout  ( lut1_dout     ),

    .gga_cs     ( gga_cs        ),
    .gga_we     ( gga_we        ),
    .gga_addr   ( gga_addr      ),

    .snd_latch  ( snd_latch     ),
    .snd_wr     ( snd_wr        ),
    .snd_pending( snd_pending   ),

    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .joystick3  ( joystick3     ),
    .service    ( service       ),
    .tilt       ( tilt          ),
    .dip_test   ( dip_test      ),
    .dipsw      ( dipsw[15:0]   )
);

jtpspike_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .turbofrc   ( turbofrc      ),
    .aerofgt    ( aerofgt       ),
    .gga_cs     ( gga_cs        ),
    .gga_we     ( gga_we        ),
    .gga_addr   ( gga_addr      ),
    .gga_din    ( main_dout[7:0]),
    .gfxbank    ( gfxbank       ),
    .charbank   ( charbank      ),
    .objbank    ( objbank       ),
    .flip       ( flip          ),
    .scry       ( scry          ),
    .scrx1      ( scrx1         ),
    .scry1      ( scry1         ),

    .scr_addr   ( scr_addr      ),
    .scr_vram   ( scr_vram      ),
    .scr1v_addr ( scr1v_addr    ),
    .scr1_vram  ( scr1_vram     ),
    .ras_addr   ( ras_addr      ),
    .ras_dout   ( ras_dout      ),
    .objr_addr  ( objr_addr     ),
    .objr_dout  ( objr_dout     ),
    .objr1_addr ( objr1_addr    ),
    .objr1_dout ( objr1_dout    ),
    .objl_addr  ( objl_addr     ),
    .objl_dout  ( objl_dout     ),
    .objl1_addr ( objl1_addr    ),
    .objl1_dout ( objl1_dout    ),
    .mix_addr   ( mix_addr      ),
    .mix_pal    ( mix_pal       ),

    .scr0_addr  ( scr0_addr     ),
    .scr0_cs    ( scr0_cs       ),
    .scr0_data  ( scr0_data     ),
    .scr0_ok    ( scr0_ok       ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_cs    ( scr1_cs       ),
    .scr1_data  ( scr1_data     ),
    .scr1_ok    ( scr1_ok       ),

    .obj0_addr  ( obj0_addr     ),
    .obj0_cs    ( obj0_cs       ),
    .obj0_data  ( obj0_data     ),
    .obj0_ok    ( obj0_ok       ),
    .obj1_addr  ( obj1_addr     ),
    .obj1_cs    ( obj1_cs       ),
    .obj1_data  ( obj1_data     ),
    .obj1_ok    ( obj1_ok       ),

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
    .aerofgt    ( aerofgt       ),
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
