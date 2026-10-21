/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtroundu_game(
    `include "jtframe_game_ports.inc"
);

reg [7:0] reset_count=0;
wire game_rst = rst || !(&reset_count);
wire [15:0] control;
wire sub_irq_set;
wire [9:0] text_scroll_y;
wire [15:0] bg_back_x, bg_scroll_x, bg_scroll_y;
wire obj_overflow;
wire road_enable;
wire [7:0] road_top;
wire [15:0] road_yclip, road_vregs;
wire [15:0] audio_addr;
wire audio_sel, audio_rd, audio_wr, audio_ok;
wire [7:0] audio_din, audio_dout;
wire [7:0] download_data;
wire shift_pulse;
reg shift;
wire [7:0] stick = !joystick1[0] ? 8'hff :
                   !joystick1[1] ? 8'h00 :
                   joyana_l1[7:0] == 8'h80 ? 8'h00 : 8'h7f+joyana_l1[7:0];

always @* post_data = download_data;

assign dip_flip = 1'b0;
assign debug_view = control[7:0];

jtframe_edge_pulse #(
    .NEGEDGE ( 1 )
) u_shift (
    .rst   ( game_rst     ),
    .clk   ( clk          ),
    .cen   ( 1'b1         ),
    .sigin ( joystick1[6] ),
    .pulse ( shift_pulse  )
);

always @(posedge clk) begin
    if (game_rst) shift <= 1;
    else if (shift_pulse) shift <= ~shift;
end

always @(posedge clk) begin
    if (rst) reset_count <= 0;
    else if (!(&reset_count)) reset_count <= reset_count+1'd1;
end

jtroundu_download u_download (
    .prog_addr ( prog_addr     ),
    .prog_data ( prog_data     ),
    .prog_ba   ( prog_ba       ),
    .post_data ( download_data )
);

jtroundu_main u_main (
    .rst                ( game_rst           ),
    .clk                ( clk                ),
    .cen                ( v30_8m_cen         ),
    .vblank             ( ~LVBL              ),
    .dsw                ( dipsw[15:0]        ),
    .control            ( control            ),
    .sub_irq_set        ( sub_irq_set        ),
    .text_scroll_y      ( text_scroll_y      ),
    .road_enable        ( road_enable        ),
    .road_top           ( road_top           ),
    .bg_back_x          ( bg_back_x          ),
    .bg_scroll_x        ( bg_scroll_x        ),
    .bg_scroll_y        ( bg_scroll_y        ),
    .audio_addr         ( audio_addr         ),
    .audio_sel          ( audio_sel          ),
    .audio_rd           ( audio_rd           ),
    .audio_wr           ( audio_wr           ),
    .audio_din          ( audio_din          ),
    .audio_dout         ( audio_dout         ),
    .audio_ok           ( audio_ok           ),
    .workram_addr       ( workram_addr       ),
    .workram_din        ( workram_din        ),
    .workram_dout       ( workram_dout       ),
    .workram_we         ( workram_we         ),
    .videoram_addr      ( videoram_addr      ),
    .videoram_din       ( videoram_din       ),
    .videoram_dout      ( videoram_dout      ),
    .videoram_we        ( videoram_we        ),
    .v30_shared_addr    ( v30_shared_addr    ),
    .v30_shared_din     ( v30_shared_din     ),
    .v30_shared_dout    ( v30_shared_dout    ),
    .v30_shared_we      ( v30_shared_we      ),
    .palette_addr       ( palette_addr       ),
    .palette_din        ( palette_din        ),
    .palette_dout       ( palette_dout       ),
    .palette_we         ( palette_we         ),
    .tx_gfxram_addr     ( tx_gfxram_addr     ),
    .tx_gfxram_din      ( tx_gfxram_din      ),
    .tx_gfxram_dout     ( tx_gfxram_dout     ),
    .tx_gfxram_we       ( tx_gfxram_we       ),
    .bg_gfxram_addr     ( bg_gfxram_addr     ),
    .bg_gfxram_din      ( bg_gfxram_din      ),
    .bg_gfxram_dout     ( bg_gfxram_dout     ),
    .bg_gfxram_we       ( bg_gfxram_we       ),
    .master_rom_addr    ( master_rom_addr    ),
    .master_rom_cs      ( master_rom_cs      ),
    .master_rom_data    ( master_rom_data    ),
    .master_rom_ok      ( master_rom_ok      ),
    .v30_slave_rom_addr ( v30_slave_rom_addr ),
    .v30_slave_rom_cs   ( v30_slave_rom_cs   ),
    .v30_slave_rom_data ( v30_slave_rom_data ),
    .v30_slave_rom_ok   ( v30_slave_rom_ok   )
);

jtroundu_sub u_sub (
    .rst                 ( game_rst            ),
    .clk                 ( clk                 ),
    .cen                 ( m68k_cen            ),
    .halt                ( control[4]          ),
    .irq_set             ( sub_irq_set         ),
    .road_yclip          ( road_yclip          ),
    .road_vregs          ( road_vregs          ),
    .slave_rom_addr      ( slave_rom_addr      ),
    .slave_rom_cs        ( slave_rom_cs        ),
    .slave_rom_data      ( slave_rom_data      ),
    .slave_rom_ok        ( slave_rom_ok        ),
    .sharedram_addr      ( sharedram_addr      ),
    .sharedram_din       ( sharedram_din       ),
    .sharedram_dout      ( sharedram_dout      ),
    .sharedram_we        ( sharedram_we        ),
    .spriteram_addr      ( spriteram_addr      ),
    .spriteram_din       ( spriteram_din       ),
    .spriteram_dout      ( spriteram_dout      ),
    .spriteram_we        ( spriteram_we        ),
    .obj_ctrl_ram_addr   ( obj_ctrl_ram_addr   ),
    .obj_ctrl_ram_din    ( obj_ctrl_ram_din    ),
    .obj_ctrl_ram_dout   ( obj_ctrl_ram_dout   ),
    .obj_ctrl_ram_we     ( obj_ctrl_ram_we     ),
    .road_ctrl_ram_addr  ( road_ctrl_ram_addr  ),
    .road_ctrl_ram_din   ( road_ctrl_ram_din   ),
    .road_ctrl_ram_dout  ( road_ctrl_ram_dout  ),
    .road_ctrl_ram_we    ( road_ctrl_ram_we    ),
    .road_pixel_ram_addr ( road_pixel_ram_addr ),
    .road_pixel_ram_din  ( road_pixel_ram_din  ),
    .road_pixel_ram_dout ( road_pixel_ram_dout ),
    .road_pixel_ram_we   ( road_pixel_ram_we   ),
    .road_color_ram_addr ( road_color_ram_addr ),
    .road_color_ram_din  ( road_color_ram_din  ),
    .road_color_ram_dout ( road_color_ram_dout ),
    .road_color_ram_we   ( road_color_ram_we   )
);

jtroundu_snd u_snd (
    .rst                ( game_rst                                                             ),
    .clk                ( clk                                                                  ),
    .cen                ( z80ym_4m_cen                                                         ),
    .fm_cen             ( z80ym_4m_cen                                                         ),
    .oki_cen            ( oki_2m_cen                                                           ),
    .halt               ( control[2]                                                           ),
    .in0                ( {2'b11,cab_1p[0],joystick1[7],shift,joystick1[5],1'b1,joystick1[4]}  ),
    .in1                ( {dipsw[23:20],service,coin[1:0],dip_test}                            ),
    .stick              ( stick                                                                ),
    .v30_addr           ( audio_addr                                                           ),
    .v30_sel            ( audio_sel                                                            ),
    .v30_rd             ( audio_rd                                                             ),
    .v30_wr             ( audio_wr                                                             ),
    .v30_din            ( audio_din                                                            ),
    .v30_dout           ( audio_dout                                                           ),
    .v30_ok             ( audio_ok                                                             ),
    .fm_l               ( fm_l                                                                 ),
    .fm_r               ( fm_r                                                                 ),
    .pcm                ( pcm                                                                  ),
    .audiocpu_addr      ( audiocpu_addr                                                        ),
    .audiocpu_cs        ( audiocpu_cs                                                          ),
    .audiocpu_data      ( audiocpu_data                                                        ),
    .audiocpu_ok        ( audiocpu_ok                                                          ),
    .v30_audio_rom_addr ( v30_audio_rom_addr                                                   ),
    .v30_audio_rom_cs   ( v30_audio_rom_cs                                                     ),
    .v30_audio_rom_data ( v30_audio_rom_data                                                   ),
    .v30_audio_rom_ok   ( v30_audio_rom_ok                                                     ),
    .oki_addr           ( oki_addr                                                             ),
    .oki_cs             ( oki_cs                                                               ),
    .oki_data           ( oki_data                                                             ),
    .oki_ok             ( oki_ok                                                               ),
    .soundram_addr      ( soundram_addr                                                        ),
    .soundram_din       ( soundram_din                                                         ),
    .soundram_dout      ( soundram_dout                                                        ),
    .soundram_we        ( soundram_we                                                          ),
    .v30_soundram_addr  ( v30_soundram_addr                                                    ),
    .v30_soundram_din   ( v30_soundram_din                                                     ),
    .v30_soundram_dout  ( v30_soundram_dout                                                    ),
    .v30_soundram_we    ( v30_soundram_we                                                      )
);

jtroundu_video u_video (
    .control            ( control            ),
    .obj_overflow       ( obj_overflow       ),
    .rst                ( game_rst           ),
    .clk                ( clk                ),
    .pxl_cen            ( pxl_cen            ),
    .text_scroll_y      ( text_scroll_y      ),
    .road_enable        ( road_enable        ),
    .road_top           ( road_top           ),
    .bg_back_x          ( bg_back_x          ),
    .bg_scroll_x        ( bg_scroll_x        ),
    .bg_scroll_y        ( bg_scroll_y        ),
    .road_yclip         ( road_yclip         ),
    .road_bank          ( road_vregs[4]      ),
    .road_ctrl_addr     ( road_ctrl_addr     ),
    .road_ctrl_data     ( road_ctrl_data     ),
    .road_pixel_addr    ( road_pixel_addr    ),
    .road_pixel_data    ( road_pixel_data    ),
    .road_color_addr    ( road_color_addr    ),
    .road_color_data    ( road_color_data    ),
    .bg_gfx_addr        ( bg_gfx_addr        ),
    .bg_gfx_data        ( bg_gfx_data        ),
    .objram_addr        ( objram_addr        ),
    .objram_data        ( objram_data        ),
    .obj_ctrl_addr      ( obj_ctrl_addr      ),
    .obj_ctrl_data      ( obj_ctrl_data      ),
    .sprites_l_addr     ( sprites_l_addr     ),
    .sprites_l_cs       ( sprites_l_cs       ),
    .sprites_l_data     ( sprites_l_data     ),
    .sprites_l_ok       ( sprites_l_ok       ),
    .sprites_h_addr     ( sprites_h_addr     ),
    .sprites_h_cs       ( sprites_h_cs       ),
    .sprites_h_data     ( sprites_h_data     ),
    .sprites_h_ok       ( sprites_h_ok       ),
    .txmap_addr         ( txmap_addr         ),
    .txmap_data         ( txmap_data         ),
    .tx_gfx_addr        ( tx_gfx_addr        ),
    .tx_gfx_data        ( tx_gfx_data        ),
    .palette_video_addr ( palette_video_addr ),
    .palette_video_data ( palette_video_data ),
    .red                ( red                ),
    .green              ( green              ),
    .blue               ( blue               ),
    .LHBL               ( LHBL               ),
    .LVBL               ( LVBL               ),
    .HS                 ( HS                 ),
    .VS                 ( VS                 )
);


`ifdef ROUNDU_TRACE
integer trace_frame=0, trace_text=0, trace_gfx=0, trace_fm=0, trace_pcm=0;
reg trace_fm_wr=0, trace_pcm_wr=0;
reg trace_lvbl=0;
always @(posedge clk) begin
    trace_lvbl <= LVBL;
    if (game_rst) begin
        trace_frame <= 0;
        trace_fm <= 0;
        trace_pcm <= 0;
        trace_text <= 0;
        trace_gfx <= 0;
    end else begin
        trace_fm_wr <= u_snd.fm_cs && u_snd.io_wr;
        trace_pcm_wr <= u_snd.pcm_cs && u_snd.io_wr;
        if (u_snd.fm_cs && u_snd.io_wr && !trace_fm_wr) trace_fm <= trace_fm+1;
        if (u_snd.pcm_cs && u_snd.io_wr && !trace_pcm_wr) trace_pcm <= trace_pcm+1;
        if (|videoram_we) trace_text <= trace_text+1;
        if (tx_gfxram_we) trace_gfx <= trace_gfx+1;
        if (trace_lvbl && !LVBL) begin
            trace_frame <= trace_frame+1;
            if (trace_frame % 30 == 29)
                $display("FRAME %0d FM=%0d PCM=%0d V30=%04x:%04x SUB=%06x Z80=%04x CTRL=%04x TEXT=%0d GFX=%0d OBJ_OV=%0d",trace_frame+1,trace_fm,trace_pcm,
                    u_main.u_cpu.u_cpu.u_eu.sreg[1],u_main.u_cpu.u_cpu.u_eu.pc,
                    u_sub.byte_addr,u_snd.cpu_addr,control,trace_text,trace_gfx,obj_overflow);
        end
    end
end
`endif

endmodule
