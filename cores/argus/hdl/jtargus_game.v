/*  Argus hardware implementation for JTFRAME.

    This file intentionally wires together existing JTFRAME/JTCORES building
    blocks. The game-specific logic lives in the address decoder, palette
    mapper, VROM lookup, and object scanner described by MAME.
*/

module jtargus_game(
    `include "jtframe_game_ports.inc"
);

wire        irq8, irq10, flip, bg1_en, grey_en;
wire [ 7:0] snd_latch;
wire [ 9:0] bg0_scrx;
wire [ 8:0] bg0_scry, bg1_scrx, bg1_scry;
wire [ 7:0] bg0_vrom;
wire [ 7:0] st_snd;

wire [11:0] pal_addr;
wire [ 7:0] pal_din;
wire        pal_we;

wire [ 9:0] pal_pxl;
wire [11:0] pal_rgb;
wire [ 9:0] blend_bg_pxl, blend_obj_pxl;
wire [11:0] blend_bg_rgb, blend_obj_rgb;
wire [ 3:0] blend_alpha;

assign debug_view = debug_bus[7] ? st_snd : { grey_en, bg1_en, flip, snd_latch[4:0] };
assign dip_flip   = flip;
`ifdef JTFRAME_IOCTL_RD
assign ioctl_din  = 8'd0;
`endif

jtargus_main u_main(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .cen5       ( cen5         ),
    .irq8       ( irq8         ),
    .irq10      ( irq10        ),

    .cpu_dout   ( cpu_dout     ),

    .snd_latch  ( snd_latch    ),
    .flip       ( flip         ),
    .bg1_en     ( bg1_en       ),
    .grey_en    ( grey_en      ),
    .bg0_scrx   ( bg0_scrx     ),
    .bg0_scry   ( bg0_scry     ),
    .bg0_vrom   ( bg0_vrom     ),
    .bg1_scrx   ( bg1_scrx     ),
    .bg1_scry   ( bg1_scry     ),

    .ram_dout   ( ram_dout     ),
    .ram_we     ( ram_we       ),
    .tx_dout    ( tx_dout      ),
    .tx_we      ( tx_we        ),
    .bg1_dout   ( bg1_dout     ),
    .bg1_we     ( bg1_we       ),

    .pal_addr   ( pal_addr     ),
    .pal_din    ( pal_din      ),
    .pal_we     ( pal_we       ),

    .main_addr  ( main_addr    ),
    .main_data  ( main_data    ),
    .main_cs    ( main_cs      ),
    .main_ok    ( main_ok      ),

    .cab_1p     ( cab_1p[1:0]  ),
    .coin       ( coin[1:0]    ),
    .joystick1  ( joystick1    ),
    .joystick2  ( joystick2    ),
    .dipsw_a    ( dipsw[ 7:0]  ),
    .dipsw_b    ( dipsw[15:8]  ),
    .dip_pause  ( dip_pause    )
);

jtargus_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen5       ( cen5      ),
    .cen1p5     ( cen1p5    ),

    .snd_latch  ( snd_latch ),

    .snd_addr   ( snd_addr  ),
    .snd_data   ( snd_data  ),
    .snd_cs     ( snd_cs    ),
    .snd_ok     ( snd_ok    ),

    .fm         ( fm        ),
    .psg        ( psg       ),
    .st_dout    ( st_snd    )
);

jtargus_palette u_palette(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .addr       ( pal_addr  ),
    .din        ( pal_din   ),
    .we         ( pal_we    ),
    .grey_en    ( grey_en   ),

    .pxl        ( pal_pxl   ),
    .blend_bg_pxl ( blend_bg_pxl ),
    .blend_obj_pxl( blend_obj_pxl ),
    .rgb        ( pal_rgb   ),
    .blend_bg_rgb ( blend_bg_rgb ),
    .blend_obj_rgb( blend_obj_rgb ),
    .blend_alpha  ( blend_alpha )
);

jtargus_video u_video(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),

    .flip       ( flip         ),
    .bg1_en     ( bg1_en       ),

    .bg0_scrx   ( bg0_scrx     ),
    .bg0_scry   ( bg0_scry     ),
    .bg0_vrom   ( bg0_vrom     ),
    .bg1_scrx   ( bg1_scrx     ),
    .bg1_scry   ( bg1_scry     ),

    .tx_addr    ( tx_vid_addr  ),
    .tx_data    ( tx_vid_dout  ),
    .bg1_addr   ( bg1_vid_addr ),
    .bg1_data   ( bg1_vid_dout ),

    .objram_addr( ram_obj_addr ),
    .objram_data( ram_obj_dout ),

    .bg0_addr   ( bg0_addr     ),
    .bg0_data   ( bg0_data     ),
    .bg0_cs     ( bg0_cs       ),
    .bg0_ok     ( bg0_ok       ),

    .bg1rom_addr( bg1_addr     ),
    .bg1rom_data( bg1_data     ),
    .bg1rom_cs  ( bg1_cs       ),
    .bg1rom_ok  ( bg1_ok       ),

    .txt_addr   ( txt_addr     ),
    .txt_data   ( txt_data     ),
    .txt_cs     ( txt_cs       ),
    .txt_ok     ( txt_ok       ),

    .obj_addr   ( obj_addr     ),
    .obj_data   ( obj_data     ),
    .obj_cs     ( obj_cs       ),
    .obj_ok     ( obj_ok       ),

    .vrom1_addr ( vrom1_addr   ),
    .vrom1_data ( vrom1_data   ),
    .vrom1_cs   ( vrom1_cs     ),
    .vrom1_ok   ( vrom1_ok     ),
    .vrom2_addr ( vrom2_addr   ),
    .vrom2_data ( vrom2_data   ),
    .vrom2_cs   ( vrom2_cs     ),
    .vrom2_ok   ( vrom2_ok     ),

    .pal_pxl    ( pal_pxl      ),
    .pal_rgb    ( pal_rgb      ),
    .blend_bg_pxl ( blend_bg_pxl ),
    .blend_obj_pxl( blend_obj_pxl ),
    .blend_bg_rgb ( blend_bg_rgb ),
    .blend_obj_rgb( blend_obj_rgb ),
    .blend_alpha  ( blend_alpha ),

    .red        ( red          ),
    .green      ( green        ),
    .blue       ( blue         ),
    .LHBL       ( LHBL         ),
    .LVBL       ( LVBL         ),
    .HS         ( HS           ),
    .VS         ( VS           ),
    .irq8       ( irq8         ),
    .irq10      ( irq10        ),

    .gfx_en     ( gfx_en       ),
    .debug_bus  ( debug_bus    )
);

endmodule
