/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtapach3_game(
    `include "jtframe_game_ports.inc"
);

wire [7:0] download_data;
wire [15:0] control, rotate_data;
wire [14:0] host_addr;
wire [7:0] host_din, host_dout, road_z;
wire host_sel, host_rd, host_wr, host_ok;
wire sub_reset_n, z80_halt, rotate_we;
wire [15:1] ground_cpu_addr;
wire [15:0] ground_cpu_din, ground_cpu_data;
wire [15:1] ground_video_addr;
wire [15:0] ground_video_data;
wire [ 1:0] ground_cpu_dsn;
wire ground_cpu_cs, ground_cpu_we, ground_cpu_ok;
wire ground_video_cs, ground_video_ok;
wire ground_initialized;
`ifdef SIMSCENE
wire cpu_rst = 1'b1;
localparam GROUND_INIT = 0;
`else
wire cpu_rst = rst | !ground_initialized;
localparam GROUND_INIT = 1;
`endif
wire [7:0] in0, stick_x, stick_y, throttle;

jtapach3_cab u_cab (
    .rst        ( rst                  ),
    .clk        ( clk                  ),
    .LVBL       ( LVBL                 ),
    .joystick   ( joystick1            ),
    .joyana_l   ( joyana_l1            ),
    .joyana_r   ( joyana_r1            ),
    .digital    ( status[13]           ),
    .invert_y   ( status[14]           ),
    .throttle_y ( status[15]           ),
    .test_n     ( dip_test & dipsw[16] ),
    .service_n  ( service              ),
    .coin_n     ( coin[1:0]            ),
    .start_n    ( cab_1p[0]            ),
    .in0        ( in0                  ),
    .stick_x    ( stick_x              ),
    .stick_y    ( stick_y              ),
    .throttle   ( throttle             )
);

always @* post_data = download_data;
assign dip_flip = 1'b0;
assign debug_view = control[7:0];
`ifdef JTFRAME_IOCTL_RD
assign ioctl_din = 0;
`endif
jtapach3_download u_download (
    .prog_addr ( prog_addr     ),
    .prog_data ( prog_data     ),
    .prog_ba   ( prog_ba       ),
    .post_data ( download_data )
);

jtapach3_main u_main (
    .rst                ( cpu_rst                ),
    .clk                ( clk                ),
    .cen                ( v30_8m_cen         ),
    .vblank             ( ~LVBL              ),
    .dsw                ( dipsw[15:0]        ),
    .control            ( control            ),
    .host_addr          ( host_addr          ),
    .host_sel           ( host_sel           ),
    .host_rd            ( host_rd            ),
    .host_wr            ( host_wr            ),
    .host_din           ( host_din           ),
    .host_dout          ( host_dout          ),
    .host_ok            ( host_ok            ),
    .workram_addr       ( workram_addr       ),
    .workram_din        ( workram_din        ),
    .workram_dout       ( workram_dout       ),
    .workram_we         ( workram_we         ),
    .backup_addr        ( backup_addr        ),
    .backup_din         ( backup_din         ),
    .backup_dout        ( backup_dout        ),
    .backup_we          ( backup_we          ),
    .videoram_addr      ( videoram_addr      ),
    .videoram_din       ( videoram_din       ),
    .videoram_dout      ( videoram_dout      ),
    .videoram_we        ( videoram_we        ),
    .palette_addr       ( palette_addr       ),
    .palette_din        ( palette_din        ),
    .palette_dout       ( palette_dout       ),
    .palette_we         ( palette_we         ),
    .v30_shared_addr    ( v30_shared_addr    ),
    .v30_shared_din     ( v30_shared_din     ),
    .v30_shared_dout    ( v30_shared_dout    ),
    .v30_shared_we      ( v30_shared_we      ),
    .master_rom_addr    ( master_rom_addr    ),
    .master_rom_cs      ( master_rom_cs      ),
    .master_rom_data    ( master_rom_data    ),
    .master_rom_ok      ( master_rom_ok      ),
    .v30_slave_rom_addr ( v30_slave_rom_addr ),
    .v30_slave_rom_cs   ( v30_slave_rom_cs   ),
    .v30_slave_rom_data ( v30_slave_rom_data ),
    .v30_slave_rom_ok   ( v30_slave_rom_ok   )
);

jtapach3_sub u_sub (
    .rst               ( cpu_rst               ),
    .clk               ( clk               ),
    .halt              ( control[4]        ),
    .vblank            ( ~LVBL             ),
    .reset_n           ( sub_reset_n       ),
    .z80_halt          ( z80_halt          ),
    .rotate_data       ( rotate_data       ),
    .rotate_we         ( rotate_we         ),
    .road_z            ( road_z            ),
    .slave_rom_addr    ( slave_rom_addr    ),
    .slave_rom_cs      ( slave_rom_cs      ),
    .slave_rom_data    ( slave_rom_data    ),
    .slave_rom_ok      ( slave_rom_ok      ),
    .sharedram_addr    ( sharedram_addr    ),
    .sharedram_din     ( sharedram_din     ),
    .sharedram_dout    ( sharedram_dout    ),
    .sharedram_we      ( sharedram_we      ),
    .spriteram_addr    ( spriteram_addr    ),
    .spriteram_din     ( spriteram_din     ),
    .spriteram_dout    ( spriteram_dout    ),
    .spriteram_we      ( spriteram_we      ),
    .obj_ctrl_ram_addr ( obj_ctrl_ram_addr ),
    .obj_ctrl_ram_din  ( obj_ctrl_ram_din  ),
    .obj_ctrl_ram_dout ( obj_ctrl_ram_dout ),
    .obj_ctrl_ram_we   ( obj_ctrl_ram_we   ),
    .ground_ram_addr   ( ground_cpu_addr   ),
    .ground_ram_cs     ( ground_cpu_cs     ),
    .ground_ram_we     ( ground_cpu_we     ),
    .ground_ram_din    ( ground_cpu_din    ),
    .ground_ram_dsn    ( ground_cpu_dsn    ),
    .ground_ram_data   ( ground_cpu_data   ),
    .ground_ram_ok     ( ground_cpu_ok     ),
    .m68k_z80ram_addr  ( m68k_z80ram_addr  ),
    .m68k_z80ram_din   ( m68k_z80ram_din   ),
    .m68k_z80ram_dout  ( m68k_z80ram_dout  ),
    .m68k_z80ram_we    ( m68k_z80ram_we    )
);

jtapach3_groundbus #(
    .INIT        ( GROUND_INIT        )
) u_groundbus (
    .rst         ( rst                ),
    .clk         ( clk                ),
    .initialized ( ground_initialized ),
    .cpu_addr    ( ground_cpu_addr    ),
    .cpu_din     ( ground_cpu_din     ),
    .cpu_dsn     ( ground_cpu_dsn     ),
    .cpu_cs      ( ground_cpu_cs      ),
    .cpu_we      ( ground_cpu_we      ),
    .cpu_dout    ( ground_cpu_data    ),
    .cpu_ok      ( ground_cpu_ok      ),
    .video_addr  ( ground_video_addr  ),
    .video_cs    ( ground_video_cs    ),
    .video_dout  ( ground_video_data  ),
    .video_ok    ( ground_video_ok    ),
    .ram_addr    ( ground_ram_addr    ),
    .ram_din     ( ground_ram_din     ),
    .ram_dsn     ( ground_ram_dsn     ),
    .ram_cs      ( ground_ram_cs      ),
    .ram_we      ( ground_ram_we      ),
    .ram_dout    ( ground_ram_data    ),
    .ram_ok      ( ground_ram_ok      )
);

jtapach3_snd u_snd (
    .rst                ( cpu_rst                     ),
    .clk                ( clk                     ),
    .cen                ( v20_8m_cen              ),
    .ym_cen             ( ym_cen                  ),
    .oki_cen            ( oki_cen                 ),
    .control            ( control                 ),
    .in0                ( in0                     ),
    .stick_x            ( stick_x                 ),
    .stick_y            ( stick_y                 ),
    .throttle           ( throttle                ),
    .host_addr          ( host_addr               ),
    .host_sel           ( host_sel                ),
    .host_rd            ( host_rd                 ),
    .host_wr            ( host_wr                 ),
    .host_din           ( host_din                ),
    .host_dout          ( host_dout               ),
    .host_ok            ( host_ok                 ),
    .fm_l               ( fm_l                    ),
    .fm_r               ( fm_r                    ),
    .pcm                ( pcm                     ),
    .sound_rom_addr     ( sound_rom_addr          ),
    .sound_rom_cs       ( sound_rom_cs            ),
    .sound_rom_data     ( sound_rom_data          ),
    .sound_rom_ok       ( sound_rom_ok            ),
    .v30_sound_rom_addr ( v30_sound_rom_addr      ),
    .v30_sound_rom_cs   ( v30_sound_rom_cs        ),
    .v30_sound_rom_data ( v30_sound_rom_data      ),
    .v30_sound_rom_ok   ( v30_sound_rom_ok        ),
    .oki_addr           ( oki_addr                ),
    .oki_cs             ( oki_cs                  ),
    .oki_data           ( oki_data                ),
    .oki_ok             ( oki_ok                  ),
    .soundram_addr      ( soundram_addr           ),
    .soundram_din       ( soundram_din            ),
    .soundram_dout      ( soundram_dout           ),
    .soundram_we        ( soundram_we             ),
    .v30_soundram_addr  ( v30_soundram_addr       ),
    .v30_soundram_din   ( v30_soundram_din        ),
    .v30_soundram_dout  ( v30_soundram_dout       ),
    .v30_soundram_we    ( v30_soundram_we         )
);

jtapach3_roadcpu u_roadcpu (
    .rst             ( cpu_rst             ),
    .clk             ( clk             ),
    .cen             ( z80_cen         ),
    .sub_reset_n     ( sub_reset_n     ),
    .halt            ( z80_halt        ),
    .vblank          ( ~LVBL           ),
    .z80ram_addr     ( z80ram_addr     ),
    .z80ram_din      ( z80ram_din      ),
    .z80ram_dout     ( z80ram_dout     ),
    .z80ram_we       ( z80ram_we       ),
    .road_x_ram_addr ( road_x_ram_addr ),
    .road_x_ram_din  ( road_x_ram_din  ),
    .road_x_ram_we   ( road_x_ram_we   )
);

jtapach3_video u_video (
    .rst                ( rst                            ),
    .clk                ( clk                            ),
    .pxl_cen            ( pxl_cen                        ),
    .rotate_data        ( rotate_data                    ),
    .rotate_we          ( rotate_we                      ),
    .road_z             ( road_z                         ),
    .ground_invalidate  ( ground_cpu_cs && ground_cpu_we ),
    .road_invalidate    ( |road_x_ram_we                 ),
    .road_x_addr        ( road_x_video_addr              ),
    .road_x_data        ( road_x_video_data              ),
    .prom_addr          ( road_prom_addr                 ),
    .prom_data          ( road_prom_data                 ),
    .ground_addr        ( ground_video_addr              ),
    .ground_cs          ( ground_video_cs                ),
    .ground_data        ( ground_video_data              ),
    .ground_ok          ( ground_video_ok                ),
    .objram_addr        ( objram_addr                    ),
    .objram_data        ( objram_data                    ),
    .obj_ctrl_addr      ( obj_ctrl_addr                  ),
    .obj_ctrl_data      ( obj_ctrl_data                  ),
    .sprites_addr       ( sprites_addr                   ),
    .sprites_cs         ( sprites_cs                     ),
    .sprites_data       ( sprites_data                   ),
    .sprites_ok         ( sprites_ok                     ),
    .txmap_addr         ( txmap_addr                     ),
    .txmap_data         ( txmap_data                     ),
    .text_rom_addr      ( text_rom_addr                  ),
    .text_rom_cs        ( text_rom_cs                    ),
    .text_rom_data      ( text_rom_data                  ),
    .text_rom_ok        ( text_rom_ok                    ),
    .palette_video_addr ( palette_video_addr             ),
    .palette_video_data ( palette_video_data             ),
    .red                ( red                            ),
    .green              ( green                          ),
    .blue               ( blue                           ),
    .LHBL               ( LHBL                           ),
    .LVBL               ( LVBL                           ),
    .HS                 ( HS                             ),
    .VS                 ( VS                             )
);

`ifdef APACH3_TRACE
reg trace_lvbl;
integer trace_frame, trace_main_writes, trace_sound_writes, trace_sub_writes;
integer trace_fm_writes, trace_pcm_writes;
reg trace_pcm_write;
always @(posedge clk) begin
    if (rst) begin
        trace_lvbl <= 0;
        trace_frame <= 0;
        trace_main_writes <= 0;
        trace_sound_writes <= 0;
        trace_sub_writes <= 0;
        trace_fm_writes <= 0;
        trace_pcm_writes <= 0;
        trace_pcm_write <= 0;
    end else begin
        trace_lvbl <= LVBL;
        if (|workram_we || |backup_we || |videoram_we || |palette_we)
            trace_main_writes <= trace_main_writes + 1;
        if (soundram_we) trace_sound_writes <= trace_sound_writes + 1;
        if (|sharedram_we || |spriteram_we || |obj_ctrl_ram_we)
            trace_sub_writes <= trace_sub_writes + 1;
        if (u_snd.fm_cs && u_snd.io_wr && u_snd.ym_cen && u_snd.fm_half)
            trace_fm_writes <= trace_fm_writes + 1;
        trace_pcm_write <= u_snd.pcm_cs && u_snd.io_wr;
        if (!trace_pcm_write && u_snd.pcm_cs && u_snd.io_wr)
            trace_pcm_writes <= trace_pcm_writes + 1;
        if (trace_lvbl && !LVBL) begin
            trace_frame <= trace_frame + 1;
            if (trace_frame < 12 || trace_frame % 30 == 0) begin
                $display("APACH3 frame=%0d main_pc=%04x:%04x sound_pc=%04x:%04x sub_addr=%06x ctrl=%04x writes=%0d/%0d/%0d fm=%0d pcm=%0d ground_overflow=%b obj_overflow=%b obj_count=%0d obj_ready=%b cpu_rst=%b ground_init=%b",
                    trace_frame, u_main.u_cpu.u_cpu.u_eu.sreg[1], u_main.u_cpu.u_cpu.u_eu.pc,
                    u_snd.u_cpu.u_cpu.u_cpu.u_eu.sreg[1], u_snd.u_cpu.u_cpu.u_cpu.u_eu.pc,
                    {u_sub.addr,1'b0}, control,
                    trace_main_writes, trace_sound_writes, trace_sub_writes,
                    trace_fm_writes, trace_pcm_writes, u_video.ground_overflow, u_video.obj_overflow, u_video.u_obj.object_count, u_video.u_obj.frame_ready,cpu_rst,ground_initialized);
                $display("APACH3_REGS frame=%0d aw=%04x cw=%04x dw=%04x bw=%04x bp=%04x ix=%04x iy=%04x es=%04x text=%04x palette=%04x",
                    trace_frame,u_main.u_cpu.u_cpu.u_eu.gpr[0],u_main.u_cpu.u_cpu.u_eu.gpr[1],u_main.u_cpu.u_cpu.u_eu.gpr[2],
                    u_main.u_cpu.u_cpu.u_eu.gpr[3],u_main.u_cpu.u_cpu.u_eu.gpr[5],u_main.u_cpu.u_cpu.u_eu.gpr[6],
                    u_main.u_cpu.u_cpu.u_eu.gpr[7],u_main.u_cpu.u_cpu.u_eu.sreg[0],txmap_data,palette_video_data);
                $fflush();
            end
        end
    end
end
`endif

endmodule
