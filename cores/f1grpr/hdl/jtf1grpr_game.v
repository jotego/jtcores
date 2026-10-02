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
    Date: 27-8-2026 */

module jtf1grpr_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        f1gp;
wire        flip;
wire [ 7:0] gfxctrl;
wire [ 8:0] fg_scrx, fg_scry;
wire        roz_we;
wire [ 4:1] roz_addr;
wire        gga_cs, gga_we, gga_addr;
wire [ 7:0] snd_latch;
wire        snd_wr, snd_pending;
wire        main_rnw, sub_rnw;
wire [ 1:0] main_dsn, sub_dsn;

assign dip_flip   = flip;
assign debug_view = { 7'd0, f1gp };
assign st_dout    = 0;

// Both CPUs address their own work RAM and the shared block
assign ram_addr    = main_addr[13:1];
assign shared_addr = main_addr[11:1];
assign fgvram_addr = main_addr[11:1];
assign pal_addr    = main_addr[11:1];
assign rozgfx_addr = main_addr[17:1];
assign rozvram_addr= main_addr[12:1];
assign lut0_addr   = main_addr[13:1];
assign lut1_addr   = main_addr[13:1];
assign oram0_addr  = main_addr[ 9:1];
assign oram1_addr  = main_addr[ 9:1];
assign subram_addr = sub_addr[13:1];
assign shsub_addr  = sub_addr[11:1];

jtf1grpr_header u_header(
    .clk        ( clk           ),
    .header     ( header        ),
    .prog_we    ( prog_we       ),
    .prog_addr  ( prog_addr[2:0]),
    .prog_data  ( prog_data     ),
    .f1gp       ( f1gp          )
);

jtf1grpr_main u_main(
    .rst        ( rst48         ),
    .clk        ( clk48         ),
    .LVBL       ( LVBL          ),
    .dip_pause  ( dip_pause     ),

    .main_addr  ( main_addr     ),
    .main_dout  ( main_dout     ),
    .main_rnw   ( main_rnw      ),
    .main_dsn   ( main_dsn      ),
    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    .user2_addr ( user2_addr    ),
    .user2_cs   ( user2_cs      ),
    .user2_data ( user2_data    ),
    .user2_ok   ( user2_ok      ),

    .ram_we     ( ram_we        ),
    .shared_we  ( shared_we     ),
    .fgvram_we  ( fgvram_we     ),
    .pal_we     ( pal_we        ),
    .rozgfx_we  ( rozgfx_we     ),
    .rozvram_we ( rozvram_we    ),
    .lut0_we    ( lut0_we       ),
    .lut1_we    ( lut1_we       ),
    .oram0_we   ( oram0_we      ),
    .oram1_we   ( oram1_we      ),
    .ram_dout   ( ram_dout      ),
    .shared_dout( shared_dout   ),
    .fgvram_dout( fgvram_dout   ),
    .pal_dout   ( pal_dout      ),
    .rozgfx_dout( rozgfx_dout   ),
    .rozvram_dout(rozvram_dout  ),
    .lut0_dout  ( lut0_dout     ),
    .lut1_dout  ( lut1_dout     ),
    .oram0_dout ( oram0_dout    ),
    .oram1_dout ( oram1_dout    ),

    .gga_cs     ( gga_cs        ),
    .gga_we     ( gga_we        ),
    .gga_addr   ( gga_addr      ),
    .gfxctrl    ( gfxctrl       ),
    .flip       ( flip          ),
    .fg_scrx    ( fg_scrx       ),
    .fg_scry    ( fg_scry       ),
    .roz_we     ( roz_we        ),
    .roz_addr   ( roz_addr      ),

    .snd_latch  ( snd_latch     ),
    .snd_wr     ( snd_wr        ),
    .snd_pending( snd_pending   ),

    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    // AD_STICK_X: jtframe gives 2's complement, MAME's port is 0..ff at 0x80
    .wheel      ( {~joyana_l1[7], joyana_l1[6:0]} ),
    .service    ( service       ),
    .tilt       ( tilt          ),
    .dip_test   ( dip_test      ),
    .dipsw      ( dipsw         )
);

jtf1grpr_sub u_sub(
    .rst        ( rst48         ),
    .clk        ( clk48         ),
    .LVBL       ( LVBL          ),
    .dip_pause  ( dip_pause     ),

    .sub_addr   ( sub_addr      ),
    .sub_dout   ( sub_dout      ),
    .sub_rnw    ( sub_rnw       ),
    .sub_dsn    ( sub_dsn       ),
    .rom_cs     ( sub_cs        ),
    .rom_data   ( sub_data      ),
    .rom_ok     ( sub_ok        ),

    .ram_we     ( subram_we     ),
    .shared_we  ( shsub_we      ),
    .ram_dout   ( subram_dout   ),
    .shared_dout( shsub_dout    )
);

jtf1grpr_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .gga_cs     ( gga_cs        ),
    .gga_we     ( gga_we        ),
    .gga_addr   ( gga_addr      ),
    .gga_din    ( main_dout[7:0]),

    .gfxctrl    ( gfxctrl       ),
    .flip       ( flip          ),
    .fg_scrx    ( fg_scrx       ),
    .fg_scry    ( fg_scry       ),
    .roz_we     ( roz_we        ),
    .roz_addr   ( roz_addr      ),
    .roz_din    ( main_dout     ),

    .fgv_addr   ( fgv_addr      ),
    .fgv_dout   ( fgv_dout      ),
    .rozv_addr  ( rozv_addr     ),
    .rozv_dout  ( rozv_dout     ),
    .rozg_addr  ( rozg_addr     ),
    .rozg_dout  ( rozg_dout     ),
    .objr0_addr ( objr0_addr    ),
    .objr0_dout ( objr0_dout    ),
    .objr1_addr ( objr1_addr    ),
    .objr1_dout ( objr1_dout    ),
    .objl0_addr ( objl0_addr    ),
    .objl0_dout ( objl0_dout    ),
    .objl1_addr ( objl1_addr    ),
    .objl1_dout ( objl1_dout    ),
    .mix_addr   ( mix_addr      ),
    .mix_pal    ( mix_pal       ),

    .fg_addr    ( fg_addr       ),
    .fg_cs      ( fg_cs         ),
    .fg_data    ( fg_data       ),
    .fg_ok      ( fg_ok         ),
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

// Z80 + YM2610, shared with pspike: same port map (00 bank, 14 latch/ack,
// 18-1b YM). f1gp banks two 32kB entries from 0x8000, hence BANK_OFF
jtpspike_snd #(.BANK_OFF(2'd1),.PCMBW(20)) u_snd(
    .rst        ( rst48         ),
    .clk        ( clk48         ),
    .snd_cen    ( snd_cen       ),
    .fm_cen     ( fm_cen        ),

    .snd_latch  ( snd_latch     ),
    .snd_wr     ( snd_wr        ),
    .snd_pending( snd_pending   ),
    .LVBL_snd   ( LVBL          ),
    .aerofgt    ( 1'b0          ),   // spinlbrk port map, what f1gp uses
    .debug_bus  ( debug_bus     ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),

    .pcma_addr  ( pcma_addr     ),
    .pcma_cs    ( pcma_cs       ),
    .pcma_data  ( pcma_data     ),

    .pcmb_addr  ( pcmb_addr     ),
    .pcmb_cs    ( pcmb_cs       ),
    .pcmb_data  ( pcmb_data     ),

    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          ),
    .psg        ( psg           )
);

endmodule
