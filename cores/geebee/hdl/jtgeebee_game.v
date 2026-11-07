/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 06-11-2026 */

module jtgeebee_game(
    `include "jtframe_game_ports.inc"
);

reg [4:0] cpu_div;
wire cen_cpu = cpu_div == 5'd23;
wire [8:0] h, v;
wire [9:0] gfx_cpu_addr;
wire [10:0] gfx_video_addr;
wire gfx_cpu_rd;
wire char_pxl, ball_pxl, bgw, ball_on, flip;
wire snd_wr;
wire [7:0] snd_din, ball_x, ball_y;
wire [7:0] sw0, sw1, dsw, paddle;
wire flip_eff = flip ^ ~dip_flip;

always @(posedge clk or posedge rst) begin
    if (rst) cpu_div <= 0;
    else cpu_div <= cen_cpu ? 0 : cpu_div + 1'b1;
end

assign gfx1_addr  = gfx_cpu_rd ? {1'b0, gfx_cpu_addr} : gfx_video_addr;
assign debug_view = 8'd0;

jtgeebee_cab u_cab(
    .clk      ( clk          ),
    .rst      ( rst          ),
    .joystick1( joystick1    ),
    .cab_1p   ( cab_1p       ),
    .coin     ( coin         ),
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
    .rst          ( rst          ),
    .cen_cpu      ( cen_cpu      ),
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
    .pxl_cen    ( pxl_cen         ),
    .flip       ( flip_eff        ),
    .ball_on    ( ball_on         ),
    .ball_x     ( ball_x          ),
    .ball_y     ( ball_y          ),
    .vram_addr  ( vram_video_addr ),
    .vram_data  ( vram_video_data ),
    .gfx_addr   ( gfx_video_addr  ),
    .gfx_data   ( gfx1_data       ),
    .h          ( h               ),
    .v          ( v               ),
    .char_pxl   ( char_pxl        ),
    .ball_pxl   ( ball_pxl        ),
    .lhbl       ( LHBL            ),
    .lvbl       ( LVBL            ),
    .hs         ( HS              ),
    .vs         ( VS              )
);

jtgeebee_colmix u_colmix(
    .char_pxl ( char_pxl ),
    .ball_pxl ( ball_pxl ),
    .bgw      ( bgw      ),
    .lhbl     ( LHBL     ),
    .lvbl     ( LVBL     ),
    .red      ( red      ),
    .green    ( green    ),
    .blue     ( blue     )
);

jtgeebee_snd u_sound(
    .clk    ( clk      ),
    .rst    ( rst      ),
    .cen    ( pxl_cen  ),
    .wr     ( snd_wr   ),
    .din    ( snd_din  ),
    .v      ( v[7:0]  ),
    .snd    ( snd      ),
    .sample ( sample   )
);

endmodule
