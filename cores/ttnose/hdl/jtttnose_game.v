/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 01-11-2026 */

module jtttnose_game(
    `include "jtframe_game_ports.inc"
);
wire [23:1] cpu_addr;
wire [7:0] steering,accelerator,brake,snd_latch;
wire snd_wr,snd_pending,roz_map_cs,roz_map_we,roz_map_ok,roz_we;
wire gga_cs,gga_we,gfxbank_we;
wire [7:0] roz_map_dout;
wire [9:1] sprite_addr;
wire chars_request;
wire chars_hole=&chars_addr[19:18];
assign chars_cs=chars_request && !chars_hole;
assign rozgfx_addr=cpu_addr[16:1];
assign oram_addr=cpu_addr[11:1];
assign txram_addr=cpu_addr[11:1];
assign pal_addr=cpu_addr[11:1];
assign objr_addr={2'd0,sprite_addr};
assign pcm_cs=0;
assign pcm_addr=0;
assign dip_flip=dipsw[13];
assign st_dout=debug_view;
jtttnose_controls u_controls(
    .ctrl_type   ( status[22:20]  ),
    .directions  ( joystick1[1:0] ),
    .buttons     ( joystick1[5:4] ),
    .joyana_l    ( joyana_l1      ),
    .joyana_r    ( joyana_r1      ),
    .steering    ( steering       ),
    .accelerator ( accelerator    ),
    .brake       ( brake          )
);
jtttnose_main u_main(
    .rst          ( rst          ),
    .clk          ( clk          ),
    .dip_pause    ( dip_pause    ),
    .lvbl         ( LVBL         ),
    .acia_cen     ( acia_cen     ),
    .addr         ( cpu_addr     ),
    .dout         ( main_dout    ),
    .rom_addr     ( main_addr    ),
    .rom_cs       ( main_cs      ),
    .rom_data     ( main_data    ),
    .rom_ok       ( main_ok      ),
    .work_addr    ( work_addr    ),
    .work_cs      ( work_cs      ),
    .work_we      ( work_we      ),
    .work_dsn     ( work_dsn     ),
    .work_din     ( work_din     ),
    .work_data    ( work_data    ),
    .work_ok      ( work_ok      ),
    .rozgfx_we    ( rozgfx_we    ),
    .rozgfx_dout  ( rozgfx_dout  ),
    .oram_we      ( oram_we      ),
    .oram_dout    ( oram_dout    ),
    .txram_we     ( txram_we     ),
    .txram_dout   ( txram_dout   ),
    .pal_we       ( pal_we       ),
    .pal_dout     ( pal_dout     ),
    .roz_map_cs   ( roz_map_cs   ),
    .roz_map_we   ( roz_map_we   ),
    .roz_map_dout ( roz_map_dout ),
    .roz_map_ok   ( roz_map_ok   ),
    .roz_we       ( roz_we       ),
    .gga_cs       ( gga_cs       ),
    .gga_we       ( gga_we       ),
    .gfxbank_we   ( gfxbank_we   ),
    .snd_latch    ( snd_latch    ),
    .snd_wr       ( snd_wr       ),
    .snd_pending  ( snd_pending  ),
    .joystick     ( joystick1    ),
    .steering     ( steering     ),
    .accelerator  ( accelerator  ),
    .brake        ( brake        ),
    .coin         ( coin         ),
    .cab_1p       ( cab_1p       ),
    .service      ( service      ),
    .dip_test     ( dip_test     ),
    .dipsw        ( dipsw[15:0]  ),
    .debug_view   ( debug_view   )
);
jtttnose_video u_video(
    .rst            ( rst                             ),
    .clk            ( clk                             ),
    .pxl_cen        ( pxl_cen                         ),
    .pxl2_cen       ( pxl2_cen                        ),
    .gga_cs         ( gga_cs                          ),
    .gga_we         ( gga_we                          ),
    .gga_addr       ( cpu_addr[1]                     ),
    .gga_din        ( main_dout[7:0]                  ),
    .roz_we         ( roz_we                          ),
    .roz_ctrl_addr  ( cpu_addr[4:1]                   ),
    .roz_ctrl_din   ( main_dout[7:0]                  ),
    .gfxbank_we     ( gfxbank_we                      ),
    .gfxbank_din    ( main_dout[7:0]                  ),
    .gfx_en         ( gfx_en[2:0]                     ),
    .txv_addr       ( txv_addr                        ),
    .txv_data       ( txv_data                        ),
    .chars_addr     ( chars_addr                      ),
    .chars_cs       ( chars_request                   ),
    .chars_data     ( chars_hole ? 32'd0 : chars_data ),
    .chars_ok       ( chars_hole | chars_ok           ),
    .roz_map_cs     ( roz_map_cs                      ),
    .roz_map_we     ( roz_map_we                      ),
    .roz_map_addr   ( cpu_addr[11:1]                  ),
    .roz_map_din    ( main_dout[7:0]                  ),
    .roz_map_dout   ( roz_map_dout                    ),
    .roz_map_ok     ( roz_map_ok                      ),
    .roz_ioctl_addr ( 11'd0                           ),
    .roz_ioctl_ram  ( 1'b0                            ),
    .roz_ioctl_din  (                                 ),
    .roz_mmr_dump   (                                 ),
    .rozg_addr      ( rozg_addr                       ),
    .rozg_data      ( rozg_data                       ),
    .objr_addr      ( sprite_addr                     ),
    .objr_data      ( objr_data                       ),
    .obj_addr       ( obj_addr                        ),
    .obj_cs         ( obj_cs                          ),
    .obj_data       ( obj_data                        ),
    .obj_ok         ( obj_ok                          ),
    .mix_addr       ( mix_addr                        ),
    .mix_data       ( mix_data                        ),
    .hdump          (                                 ),
    .vdump          (                                 ),
    .vrender        (                                 ),
    .LHBL           ( LHBL                            ),
    .LVBL           ( LVBL                            ),
    .HS             ( HS                              ),
    .VS             ( VS                              ),
    .red            ( red                             ),
    .green          ( green                           ),
    .blue           ( blue                            ),
    .obj_overrun    (                                 )
);
jtttnose_snd u_snd(
    .rst         ( rst         ),
    .clk         ( clk         ),
    .snd_cen     ( snd_cen     ),
    .fm_cen      ( fm_cen      ),
    .snd_latch   ( snd_latch   ),
    .snd_wr      ( snd_wr      ),
    .snd_pending ( snd_pending ),
    .rom_addr    ( snd_addr    ),
    .rom_cs      ( snd_cs      ),
    .rom_data    ( snd_data    ),
    .rom_ok      ( snd_ok      ),
    .ram_addr    ( sram_addr   ),
    .ram_din     ( snd_dout    ),
    .ram_we      ( sram_we     ),
    .ram_data    ( sram_dout   ),
    .snd         ( snd         ),
    .sample      ( sample      )
);

endmodule
