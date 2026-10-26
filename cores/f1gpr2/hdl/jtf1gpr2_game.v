/*  SPDX-FileCopyrightText: © 2026 Andrea Bogazzi
    SPDX-License-Identifier: GPL-3.0-or-later
    Date: 25-10-2026 */

module jtf1gpr2_game(
    `include "jtframe_game_ports.inc"
);

wire        flip;
wire [ 7:0] gfxctrl;
wire [ 8:0] fg_scrx, fg_scry;
wire        roz_we;
wire [ 4:1] roz_mmr;
wire [ 7:0] roz_bank;
wire [ 7:0] snd_latch;
wire        snd_wr, snd_pending;
wire        main_rnw, sub_rnw;
wire [ 1:0] main_dsn, sub_dsn;
assign dip_flip   = flip;
assign debug_view = 0;
assign st_dout    = 0;

assign ram_addr     = main_addr[13:1];
assign shared_addr  = main_addr[11:1];
assign fgvram_addr  = main_addr[11:1];
assign pal_addr     = main_addr[11:1];
assign rozvram_addr = main_addr[12:1];
assign sprcg_addr   = main_addr[14:1];
assign sprvram_addr = main_addr[11:1];
assign subram_addr  = sub_addr[13:1];
assign shsub_addr   = sub_addr[11:1];

jtf1gpr2_main u_main(
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

    .ram_we     ( ram_we        ),
    .shared_we  ( shared_we     ),
    .fgvram_we  ( fgvram_we     ),
    .pal_we     ( pal_we        ),
    .rozvram_we ( rozvram_we    ),
    .sprcg_we   ( sprcg_we      ),
    .sprvram_we ( sprvram_we    ),
    .ram_dout   ( ram_dout      ),
    .shared_dout( shared_dout   ),
    .fgvram_dout( fgvram_dout   ),
    .pal_dout   ( pal_dout      ),
    .rozvram_dout(rozvram_dout  ),
    .sprcg_dout ( sprcg_dout    ),
    .sprvram_dout(sprvram_dout  ),

    .gfxctrl    ( gfxctrl       ),
    .flip       ( flip          ),
    .fg_scrx    ( fg_scrx       ),
    .fg_scry    ( fg_scry       ),
    .roz_we     ( roz_we        ),
    .roz_addr   ( roz_mmr       ),
    .roz_bank   ( roz_bank      ),

    .snd_latch  ( snd_latch     ),
    .snd_wr     ( snd_wr        ),
    .snd_pending( snd_pending   ),

    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .joystick1  ( joystick1     ),
    .service    ( service       ),
    .tilt       ( tilt          ),
    .dip_test   ( dip_test      ),
    .wheel      ( {~joyana_l1[7], joyana_l1[6:0]} ),
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

jtf1gpr2_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .gfxctrl    ( gfxctrl       ),
    .flip       ( flip          ),
    .fg_scrx    ( fg_scrx       ),
    .fg_scry    ( fg_scry       ),
    .roz_we     ( roz_we        ),
    .roz_mmr_addr( roz_mmr      ),
    .roz_din    ( main_dout     ),
    .roz_dsn    ( main_dsn      ),
    .roz_bank   ( roz_bank      ),

    .fgv_addr   ( fgv_addr      ),
    .fgv_dout   ( fgv_dout      ),
    .rozv_addr  ( rozv_addr     ),
    .rozv_dout  ( rozv_dout     ),
    .objr_addr  ( objr_addr     ),
    .objr_dout  ( objr_dout     ),
    .objl_addr  ( objl_addr     ),
    .objl_dout  ( objl_dout     ),
    .mix_addr   ( mix_addr      ),
    .mix_pal    ( mix_pal       ),

    .fg_addr    ( fg_addr       ),
    .fg_cs      ( fg_cs         ),
    .fg_data    ( fg_data       ),
    .fg_ok      ( fg_ok         ),
    .obj_addr   ( obj_addr      ),
    .obj_cs     ( obj_cs        ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .rozrom_addr( roz_addr      ),
    .rozrom_cs  ( roz_cs        ),
    .rozrom_data( roz_data      ),
    .rozrom_ok  ( roz_ok        ),

    .gfx_en     ( gfx_en        ),

    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

jtpspike_snd #(
    .BANK_OFF   ( 2'd1          ),
    .BANK_PORT  ( 8'h0c         ),
    .BANK_MASK  ( 2'd1          ),
    .PCMBW      ( 19            )
) u_snd(
    .rst        ( rst48         ),
    .clk        ( clk48         ),
    .snd_cen    ( snd_cen       ),
    .fm_cen     ( fm_cen        ),

    .snd_latch  ( snd_latch     ),
    .snd_wr     ( snd_wr        ),
    .snd_pending( snd_pending   ),
    .LVBL_snd   ( LVBL          ),
    .aerofgt    ( 1'b0          ),
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
