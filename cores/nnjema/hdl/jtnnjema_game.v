/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-9-2026 */

module jtnnjema_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        m4_en, flip, dispen_n, latch_clr;
wire [ 2:0] layers;
wire [12:0] scrx;
wire [10:0] scry;
wire        blit_stb, vb_ack;
wire [ 7:0] snd_latch, cpu_dout;
wire        vram_we;
wire [10:0] vram_addr;
wire [ 8:0] vdump, hdump;

assign dip_flip   = flip;
assign ocpu_din   = cpu_dout;
assign ioctl_din  = 0;
assign debug_view = 0;

jtnnjema_header u_header(
    .clk      ( clk            ),
    .header   ( header         ),
    .prog_we  ( prog_we        ),
    .prog_addr( prog_addr[2:0] ),
    .prog_data( prog_data      ),
    .m4_en    ( m4_en          )
);

jtnnjema_main u_main(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cen6       ( cen6       ),
    .m4_en      ( m4_en      ),
    .LVBL       ( LVBL       ),

    .cab_1p     ( cab_1p[1:0]),
    .coin       ( coin[1:0]  ),
    .joystick1  ( joystick1  ),
    .joystick2  ( joystick2  ),
    .service    ( service    ),
    .dip_test   ( dip_test   ),
    .dip_pause  ( dip_pause  ),
    .dipsw      ( dipsw[23:0]),

    .vram_we    ( vram_we    ),
    .vram_addr  ( vram_addr  ),
    .ocpu_addr  ( ocpu_addr  ),
    .ocpu_we    ( ocpu_we    ),
    .ocpu_dout  ( ocpu_dout  ),
    .cpu_dout   ( cpu_dout   ),

    .flip       ( flip       ),
    .dispen_n   ( dispen_n   ),
    .layers     ( layers     ),
    .scrx       ( scrx       ),
    .scry       ( scry       ),

    .blit_stb   ( blit_stb   ),
    .vb_ack     ( vb_ack     ),

    .snd_latch  ( snd_latch  ),
    .latch_clr  ( latch_clr  ),

    .rom_cs     ( main_cs    ),
    .rom_addr   ( main_addr  ),
    .rom_data   ( main_data  ),
    .rom_ok     ( main_ok    )
);

jtnnjema_snd u_snd(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cen4       ( cen4       ),

    .snd_latch  ( snd_latch  ),
    .latch_clr  ( latch_clr  ),

    .rom_cs     ( snd_cs     ),
    .rom_addr   ( snd_addr   ),
    .rom_data   ( snd_data   ),
    .rom_ok     ( snd_ok     ),

    .fm         ( fm         ),
    .dac1       ( dac1       ),
    .dac2       ( dac2       )
);

jtnnjema_video u_video(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),

    .m4_en      ( m4_en      ),
    .flip       ( flip       ),
    .dispen_n   ( dispen_n   ),
    .layers     ( layers     ),

    .cpu_vram_we  ( vram_we   ),
    .cpu_vram_addr( vram_addr ),
    .cpu_dout   ( cpu_dout   ),

    .main_scrx  ( scrx       ),
    .main_scry  ( scry       ),
    .blit_stb   ( blit_stb   ),
    .vb_ack     ( vb_ack     ),

    .odma_addr  ( odma_addr  ),
    .oram_dout  ( oram_dout  ),

    .vcode_scan ( vcode_scan ),
    .vcode_dout ( vcode_dout ),
    .vattr_scan ( vattr_scan ),
    .vattr_dout ( vattr_dout ),
    .vcwr_addr  ( vcwr_addr  ),
    .vcwr_din   ( vcwr_din   ),
    .vcwr_we    ( vcwr_we    ),
    .vcwr_dout  ( vcwr_dout  ),
    .vawr_addr  ( vawr_addr  ),
    .vawr_din   ( vawr_din   ),
    .vawr_we    ( vawr_we    ),

    .char_addr  ( char_addr  ),
    .char_data  ( char_data  ),
    .char_cs    ( char_cs    ),
    .char_ok    ( char_ok    ),

    .bgmap_addr ( bgmap_addr ),
    .bgmap_data ( bgmap_data ),
    .bgmap_cs   ( bgmap_cs   ),
    .bgmap_ok   ( bgmap_ok   ),

    .scr_addr   ( scr_addr   ),
    .scr_data   ( scr_data   ),
    .scr_cs     ( scr_cs     ),
    .scr_ok     ( scr_ok     ),

    .obj_addr   ( obj_addr   ),
    .obj_data   ( obj_data   ),
    .obj_cs     ( obj_cs     ),
    .obj_ok     ( obj_ok     ),

    .m4rom_addr ( m4rom_addr ),
    .m4rom_data ( m4rom_data ),
    .objbank_addr( objbank_addr ),
    .objbank_data( objbank_data ),
    .objlut_addr( objlut_addr ),
    .objlut_data( objlut_data ),
    .red_addr   ( red_addr   ),
    .green_addr ( green_addr ),
    .blue_addr  ( blue_addr  ),
    .red_data   ( red_data   ),
    .green_data ( green_data ),
    .blue_data  ( blue_data  ),

    .LHBL       ( LHBL       ),
    .LVBL       ( LVBL       ),
    .HS         ( HS         ),
    .VS         ( VS         ),
    .vdump      ( vdump      ),
    .hdump      ( hdump      ),
    .red        ( red        ),
    .green      ( green      ),
    .blue       ( blue       )
);

endmodule
