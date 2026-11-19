/* SPDX-FileCopyrightText: 2026 Ulf Skutnabba
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-10-2026 */

module jtmzone_game(
    `include "jtframe_game_ports.inc"
);

wire         main_cpu_rnw;
wire [ 8:0]  video_vdump;
wire [ 8:0]  video_hdump;
wire [ 8:0]  video_vrender;
wire         vram0_cs, vram1_cs, cram0_cs, cram1_cs;
wire         objram_cs;
wire [ 7:0]  video_scrolly, video_scrollx;
wire         video_flip, intsnd;
wire         video_reg_cs;
wire [ 1:0]  video_reg_addr;
// The generic simulation driver does not initialize the optional OSD status
// bits, so keep simulations on the declared 288-pixel default.
wire         dip_orig_hactive =
`ifdef SIMULATION
                                1'b0;
`else
                                status[14];
`endif
wire         intmain_n;

assign dip_flip   = 0;
`ifndef MZONE_FETCH_DIAG
assign debug_view = 0;
`endif

assign vram0_cpu_we = vram0_cs && !main_cpu_rnw;
assign vram1_cpu_we = vram1_cs && !main_cpu_rnw;
assign cram0_cpu_we = cram0_cs && !main_cpu_rnw;
assign cram1_cpu_we = cram1_cs && !main_cpu_rnw;
assign objram_cpu_we = objram_cs && !main_cpu_rnw;

`ifdef JTFRAME_LF_BUFFER
assign game_hdump   = video_hdump;
assign game_vrender = video_vrender[7:0];
`endif

jtmzone_main u_main(
    .rst             ( rst24                                ),
    .clk             ( clk24                                ),
    .cpu_clk_cen     ( cpu4_cen                             ),
    .main_addr       ( main_addr                            ),
    .main_cs         ( main_cs                              ),
    .main_data       ( main_data                            ),
    .main_ok         ( main_ok                              ),
    .cpu_rnw         ( main_cpu_rnw                         ),
    .vram0_cs        ( vram0_cs                             ),
    .vram1_cs        ( vram1_cs                             ),
    .cram0_cs        ( cram0_cs                             ),
    .cram1_cs        ( cram1_cs                             ),
    .shared_addr     ( main_shared_addr                     ),
    .shared_dout     ( main_shared_din                      ),
    .shared_we       ( main_shared_we                       ),
    .shared_din      ( shared_dout                          ),
    .vram_addr       ( vram_addr                            ),
    .vram_din        ( vram_din                             ),
    .vram0_dout      ( vram0_cpu_dout                       ),
    .vram1_dout      ( vram1_cpu_dout                       ),
    .cram0_dout      ( cram0_cpu_dout                       ),
    .cram1_dout      ( cram1_cpu_dout                       ),
    .objram_addr     ( objcpu_addr                          ),
    .objram_din      ( objram_din                           ),
    .objram_cs       ( objram_cs                            ),
    .objram_dout     ( objram_cpu_dout                      ),
    .video_reg_cs    ( video_reg_cs                         ),
    .video_reg_addr  ( video_reg_addr                       ),
    .intsnd          ( intsnd                               ),
    .LVBL            ( LVBL                                 ),
    .dip_pause       ( dip_pause                            ),
    .intmain_n       ( intmain_n                            )
);

jtmzone_snd u_snd(
    .rst             ( rst24                                ),
    .clk             ( clk24                                ),
    .rom_addr        ( snd_addr                             ),
    .rom_cs          ( snd_cs                               ),
    .rom_data        ( snd_data                             ),
    .rom_ok          ( snd_ok                               ),
    .mcu_rom_addr    ( mcu_rom_addr                         ),
    .mcu_rom_cs      ( mcu_rom_cs                           ),
    .mcu_rom_data    ( mcu_rom_data                         ),
    .mcu_rom_ok      ( mcu_rom_ok                           ),
    .cab_1p          ( cab_1p[1:0]                          ),
    .coin            ( coin[1:0]                            ),
    .joystick1       ( joystick1[5:0]                       ),
    .joystick2       ( joystick2[5:0]                       ),
    .service         ( service                              ),
    .dipsw_a         ( dipsw[ 7:0]                          ),
    .dipsw_b         ( dipsw[15:8]                          ),
    .LVBL            ( LVBL                                 ),
    .hdump           ( video_hdump                          ),
    .intsnd          ( intsnd                               ),
    .shared_addr     ( snd_shared_addr                      ),
    .shared_dout     ( snd_shared_dout                      ),
    .shared_we       ( snd_shared_we                        ),
    .shared_din      ( snd_shared_din                       ),
    .intmain_n       ( intmain_n                            ),
    .psg0a           ( psg0a                                ),
    .psg0b           ( psg0b                                ),
    .psg0c           ( psg0c                                ),
    .psg0a_rcen      ( psg0a_rcen                           ),
    .psg0b_rcen      ( psg0b_rcen                           ),
    .psg0c_rcen      ( psg0c_rcen                           ),
    .dac             ( dac                                  )
);

jtmzone_video_mmr u_video_mmr(
    .rst             ( rst24                                ),
    .clk             ( clk24                                ),
    .cs              ( video_reg_cs                         ),
    .addr            ( video_reg_addr                       ),
    .rnw             ( main_cpu_rnw                         ),
    .din             ( vram_din                             ),
    .scrolly         ( video_scrolly                        ),
    .scrollx         ( video_scrollx                        ),
    .flip            ( video_flip                           ),
    .ioctl_addr      ( ioctl_addr[1:0]                      ),
    .ioctl_din       ( ioctl_din                            ),
    .debug_bus       ( 8'd0                                 ),
    .st_dout         (                                      )
);

jtmzone_video u_video(
    .rst             ( rst                                  ),
    .clk             ( clk                                  ),
    .pxl_cen         ( pxl_cen                              ),
    .scrram_addr     ( scrram_addr                          ),
    .vram0_data      ( vram0_dout                           ),
    .cram0_data      ( cram0_dout                           ),
    .fixram_addr     ( fixram_addr                          ),
    .vram1_data      ( vram1_dout                           ),
    .cram1_data      ( cram1_dout                           ),
    .objram_addr     ( objram_addr                          ),
    .objram_data     ( objram_dout                          ),
    .scrolly         ( video_scrolly                        ),
    .scrollx         ( video_scrollx                        ),
    .flip            ( video_flip                           ),
    .dip_orig_hactive( dip_orig_hactive                     ),
    .gfx_en          ( gfx_en                               ),
    .prog_data       ( prog_data                            ),
    .prog_addr       ( prog_addr                            ),
    .prom_we         ( prom_we                              ),
    .fixrom_addr     ( fixrom_addr                          ),
    .fixrom_cs       ( fixrom_cs                            ),
    .fixrom_data     ( fixrom_data                          ),
    .fixrom_ok       ( fixrom_ok                            ),
    .scrrom_addr     ( scrrom_addr                          ),
    .scrrom_cs       ( scrrom_cs                            ),
    .scrrom_data     ( scrrom_data                          ),
    .scrrom_ok       ( scrrom_ok                            ),
    .obj_addr        ( objrom_addr                          ),
    .obj_cs          ( objrom_cs                            ),
    .obj_data        ( objrom_data                          ),
    .obj_ok          ( objrom_ok                            ),
    .HS              ( HS                                   ),
    .VS              ( VS                                   ),
    .LHBL            ( LHBL                                 ),
    .LVBL            ( LVBL                                 ),
    .red             ( red                                  ),
    .green           ( green                                ),
    .blue            ( blue                                 ),
    .hdump           ( video_hdump                          ),
    .vdump           ( video_vdump                          ),
    .vrender         ( video_vrender                        )
`ifdef MZONE_FETCH_DIAG
    ,.debug_bus      ( debug_bus                            )
    ,.fetch_debug    ( debug_view                           )
`endif
);

endmodule
