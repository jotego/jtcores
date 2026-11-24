/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-11-2026 */

module jtwrpwrp_game(
    `include "jtframe_game_ports.inc"
);

wire [8:0] h, v;
wire [10:0] gfx_cpu_addr, gfx_video_addr;
wire gfx_cpu_rd, cmpblk_n, wrq_n;
wire [7:0] outputs, ball_h, ball_v;
wire effects_wr, music1_wr, music2_wr;
wire [5:0] snd_din;
wire [7:0] pixel_color;
wire pixel, ball, irq;
wire [7:0] switches, vol;
wire paddle_board;

assign gfx1_addr  = gfx_cpu_rd && !cmpblk_n ? gfx_cpu_addr : gfx_video_addr;
assign debug_view = 8'd0;

jtwrpwrp_header u_header(
    .clk          ( clk            ),
    .header       ( header         ),
    .prog_we      ( prog_we        ),
    .paddle_board ( paddle_board   ),
    .prog_addr    ( prog_addr[2:0] ),
    .prog_data    ( prog_data      )
);

jtwrpwrp_cab u_cab(
    .clk          ( clk                 ),
    .rst          ( rst                 ),
    .pxl_cen      ( pxl_cen             ),
    .h            ( h[3:0]              ),
    .v            ( v                   ),
    .paddle_board ( paddle_board        ),
    .joyana_l1    ( joyana_l1[7:0]      ),
    .joyana_l2    ( joyana_l2[7:0]      ),
    .dial_x       ( dial_x              ),
    .dial_y       ( dial_y              ),
    .joystick1    ( joystick1[4:0]      ),
    .joystick2    ( joystick2[4:0]      ),
    .cab_1p       ( cab_1p[1:0]         ),
    .coin         ( coin[1:0]           ),
    .credit       ( service             ),
    .upright      ( dipsw[14]           ),
    .service_n    ( dip_test & dipsw[13] ),
    .flip         ( outputs[7]          ),
    .switches     ( switches            ),
    .vol          ( vol                 )
);

jtwrpwrp_main u_main(
    .clk          ( clk           ),
    .rst          ( rst           ),
    .cen_cpu      ( cpu_cen       ),
    .paddle_board ( paddle_board  ),
    .irq          ( irq           ),
    .wrq_n        ( wrq_n         ),
    .vs           ( v[8]          ),
    .dip1         ( dipsw[7:0]    ),
    .dip2         ( 8'hff         ),
    .switches     ( switches      ),
    .vol          ( vol           ),
    .maincpu_addr ( maincpu_addr  ),
    .maincpu_data ( maincpu_data  ),
    .gfx_cpu_addr ( gfx_cpu_addr  ),
    .gfx_cpu_rd   ( gfx_cpu_rd    ),
    .gfx1_data    ( gfx1_data     ),
    .vram1_addr   ( vram1_addr    ),
    .vram1_we     ( vram1_we      ),
    .vram1_din    ( vram1_din     ),
    .vram1_dout   ( vram1_dout    ),
    .vram2_addr   ( vram2_addr    ),
    .vram2_we     ( vram2_we      ),
    .vram2_din    ( vram2_din     ),
    .vram2_dout   ( vram2_dout    ),
    .workram_addr ( workram_addr  ),
    .workram_we   ( workram_we    ),
    .workram_din  ( workram_din   ),
    .workram_dout ( workram_dout  ),
    .ball_h       ( ball_h        ),
    .ball_v       ( ball_v        ),
    .outputs      ( outputs       ),
    .effects_wr   ( effects_wr    ),
    .music1_wr    ( music1_wr     ),
    .music2_wr    ( music2_wr     ),
    .snd_din      ( snd_din       )
);

jtwrpwrp_snd u_sound(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .pxl_cen    ( pxl_cen     ),
    .audio_cen  ( audio_cen   ),
    .effects_wr ( effects_wr  ),
    .music1_wr  ( music1_wr   ),
    .music2_wr  ( music2_wr   ),
    .din        ( snd_din     ),
    .h          ( h[4:0]      ),
    .v          ( v[6:0]      ),
    .effects    ( effects     ),
    .music      ( music       )
);

jtwrpwrp_video u_video(
    .clk      ( clk                  ),
    .pxl_cen  ( pxl_cen              ),
    .flip     ( outputs[7] ^ dip_flip ),
    .code     ( vram1_video_data     ),
    .color    ( vram2_video_data     ),
    .gfx_data ( gfx1_data            ),
    .vram_addr( vram1_video_addr     ),
    .gfx_addr ( gfx_video_addr       ),
    .color_out( pixel_color          ),
    .pixel    ( pixel                ),
    .cmpblk_n ( cmpblk_n             ),
    .wrq_n    ( wrq_n                ),
    .h        ( h                    ),
    .v        ( v                    ),
    .lhbl     ( LHBL                 ),
    .lvbl     ( LVBL                 ),
    .hs       ( HS                   ),
    .vs       ( VS                   )
);

assign vram2_video_addr = vram1_video_addr;

jtwrpwrp_ball u_ball(
    .clk     ( clk        ),
    .rst     ( rst        ),
    .pxl_cen ( pxl_cen    ),
    .hs      ( HS         ),
    .vs      ( v[8]       ),
    .h       ( h          ),
    .v       ( v[7:0]     ),
    .ball_h  ( ball_h     ),
    .ball_v  ( ball_v     ),
    .ball_on ( outputs[6] ),
    .osd_flip( dip_flip   ),
    .ball    ( ball       ),
    .irq     ( irq        )
);

jtwrpwrp_colmix u_colmix(
    .color ( pixel_color ),
    .pixel ( pixel       ),
    .ball  ( ball        ),
    .lhbl  ( LHBL        ),
    .lvbl  ( LVBL        ),
    .red   ( red         ),
    .green ( green       ),
    .blue  ( blue        )
);

endmodule
