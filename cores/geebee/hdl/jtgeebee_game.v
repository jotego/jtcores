/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 06-11-2026 */

module jtgeebee_game(
    `include "jtframe_game_ports.inc"
);

wire [8:0] h, v;
wire [9:0] gfx_cpu_addr;
wire [10:0] gfx_video_addr;
wire gfx_cpu_rd;
wire cmpblk_n;
wire char_pxl, char_gate, ball_pxl, bgw, ball_on, flip;
wire snd_wr;
wire [7:0] snd_din, ball_x, ball_y;
wire [7:0] sw0, sw1, dsw, paddle;
`ifdef SIMSCENE
reg [7:0] scene_regs [0:5];
initial $readmemh("scene_mmr.hex", scene_regs);
wire cpu_rst = 1'b1;
wire bgw_eff = scene_regs[0][0];
wire ball_on_eff = scene_regs[1][0];
wire [7:0] ball_x_eff = scene_regs[2];
wire [7:0] ball_y_eff = scene_regs[3];
wire flip_eff = scene_regs[4][0];
`else
wire cpu_rst = rst;
wire bgw_eff = bgw;
wire ball_on_eff = ball_on;
wire [7:0] ball_x_eff = ball_x;
wire [7:0] ball_y_eff = ball_y;
wire flip_eff = flip ^ dip_flip;
`endif

// Sheet 9: 74157s 2D/2E switch 2708 addressing between CPU and video.
assign gfx1_addr  = gfx_cpu_rd && !cmpblk_n ? {1'b0, gfx_cpu_addr} : gfx_video_addr;
assign debug_view = 8'd0;

jtgeebee_cab u_cab(
    .clk      ( clk          ),
    .rst      ( rst          ),
    .joystick1( joystick1    ),
    .joyana_l1( joyana_l1    ),
    .joyana_l2( joyana_l2    ),
    .dial_x   ( dial_x       ),
    .dial_y   ( dial_y       ),
    .flip     ( flip         ),
    .cab_1p   ( cab_1p[1:0]  ),
    .coin     ( coin[1:0]    ),
    .service  ( service      ),
    .dipsw    ( dipsw[23:16] ),
    .v        ( v[7:0]       ),
    .sw0      ( sw0          ),
    .sw1      ( sw1          ),
    .dsw      ( dsw          ),
    .paddle   ( paddle       )
);

jtgeebee_main u_main(
    .clk          ( clk          ),
    .rst          ( cpu_rst      ),
    .cen_cpu      ( cpu_cen      ),
    .pxl_cen      ( pxl_cen      ),
    .h            ( h            ),
    .v            ( v            ),
    .vblank       ( ~LVBL        ),
    .sw0          ( sw0          ),
    .sw1          ( sw1          ),
    .dsw          ( dsw          ),
    .paddle       ( paddle       ),
    .maincpu_addr ( maincpu_addr ),
    .maincpu_data ( maincpu_data ),
    .gfx_cpu_addr ( gfx_cpu_addr ),
    .gfx_cpu_rd   ( gfx_cpu_rd   ),
    .gfx1_data    ( gfx1_data    ),
    .vram_addr    ( vram_addr    ),
    .vram_we      ( vram_we      ),
    .vram_din     ( vram_din     ),
    .vram_dout    ( vram_dout    ),
    .workram_addr ( workram_addr ),
    .workram_we   ( workram_we   ),
    .workram_din  ( workram_din  ),
    .workram_dout ( workram_dout ),
    .snd_wr       ( snd_wr       ),
    .snd_din      ( snd_din      ),
    .bgw          ( bgw          ),
    .ball_on      ( ball_on      ),
    .flip         ( flip         ),
    .ball_x       ( ball_x       ),
    .ball_y       ( ball_y       )
);

jtgeebee_video u_video(
    .clk        ( clk             ),
    .rst        ( rst             ),
    .pxl_cen    ( pxl_cen         ),
    .flip       ( flip_eff        ),
    .ball_on    ( ball_on_eff     ),
    .ball_x     ( ball_x_eff      ),
    .ball_y     ( ball_y_eff      ),
    .vram_addr  ( vram_video_addr ),
    .vram_data  ( vram_video_data ),
    .gfx_addr   ( gfx_video_addr  ),
    .gfx_data   ( gfx1_data       ),
    .h          ( h               ),
    .v          ( v               ),
    .cmpblk_n   ( cmpblk_n        ),
    .char_pxl   ( char_pxl        ),
    .char_gate  ( char_gate       ),
    .ball_pxl   ( ball_pxl        ),
    .lhbl       ( LHBL            ),
    .lvbl       ( LVBL            ),
    .hs         ( HS              ),
    .vs         ( VS              )
);

jtgeebee_colmix u_colmix(
    .h         ( h             ),
    .v         ( v             ),
    .overlay   ( status[14:13] ),
    .char_pxl  ( char_pxl      ),
    .char_gate ( char_gate     ),
    .ball_pxl  ( ball_pxl      ),
    .bgw       ( bgw_eff       ),
    .lhbl      ( LHBL          ),
    .lvbl      ( LVBL          ),
    .red       ( red           ),
    .green     ( green         ),
    .blue      ( blue          )
);

jtgeebee_snd u_sound(
    .clk       ( clk       ),
    .rst       ( rst       ),
    .pxl_cen   ( pxl_cen   ),
    .audio_cen ( audio_cen ),
    .wr        ( snd_wr    ),
    .din       ( snd_din   ),
    .v         ( v[7:0]    ),
    .snd       ( sound     )
);

endmodule
