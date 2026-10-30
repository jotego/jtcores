/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-10-2026 */

module jt88game_game(
    `include "jtframe_game_ports.inc"
);

wire        cpu_cen, cpu_we, snd_irq, rmrd, prio, rot_readroms;
wire        pal_we, tilesys_cs, objsys_cs;
wire        psac_vr_cs, psac_io_cs, rst8, cpu_irq_n;
wire        tilesys_rom_dtack, psac_cpu_ok;
wire [15:0] cpu_addr;
wire [ 7:0] cpu_dout, snd_latch;
wire [ 7:0] tilesys_dout, objsys_dout, pal_dout, psac_dout;
wire [ 7:0] st_main, st_video, st_sound;
reg  [ 7:0] debug_mux;

assign ram_din    = cpu_dout;
assign debug_view = debug_mux;

always @(posedge clk) begin
    case (debug_bus[7:6])
        2'd0: debug_mux <= st_main;
        2'd1: debug_mux <= st_video;
        2'd2: debug_mux <= st_sound;
        2'd3: debug_mux <= {prio,rmrd,rot_readroms,5'd0};
    endcase
end

jt88game_main u_main(
    .rst               ( rst               ),
    .clk               ( clk               ),
    .cen24             ( cen24             ),
    .cpu_cen           ( cpu_cen           ),
    .cpu_addr          ( cpu_addr          ),
    .cpu_dout          ( cpu_dout          ),
    .cpu_we            ( cpu_we            ),
    .rom_addr          ( main_addr         ),
    .rom_cs            ( main_cs           ),
    .rom_data          ( main_data         ),
    .rom_ok            ( main_ok           ),
    .ram_we            ( ram_we            ),
    .ram_dout          ( ram_dout          ),
    .nvram_we          ( nvram_we          ),
    .nvram_dout        ( nvram_dout        ),
    .cab_1p            ( cab_1p            ),
    .coin              ( coin              ),
    .joystick1         ( joystick1         ),
    .joystick2         ( joystick2         ),
    .joystick3         ( joystick3         ),
    .joystick4         ( joystick4         ),
    .service           ( service           ),
    .dipsw             ( dipsw[23:0]       ),
    .dip_pause         ( dip_pause         ),
    .rst8              ( rst8              ),
    .irq_n             ( cpu_irq_n         ),
    .tilesys_dout      ( tilesys_dout      ),
    .objsys_dout       ( objsys_dout       ),
    .pal_dout          ( pal_dout          ),
    .psac_dout         ( psac_dout         ),
    .psac_rom_data     ( psac_data         ),
    .tilesys_rom_dtack ( tilesys_rom_dtack ),
    .psac_ok           ( psac_cpu_ok       ),
    .tilesys_cs        ( tilesys_cs        ),
    .objsys_cs         ( objsys_cs         ),
    .pal_we            ( pal_we            ),
    .psac_vr_cs        ( psac_vr_cs        ),
    .psac_io_cs        ( psac_io_cs        ),
    .rmrd              ( rmrd              ),
    .prio              ( prio              ),
    .rot_readroms      ( rot_readroms      ),
    .snd_irq           ( snd_irq           ),
    .snd_latch         ( snd_latch         ),
    .st_dout           ( st_main           )
);

jt88game_sound u_sound(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .cen_fm    ( cen_fm    ),
    .cen_fm2   ( cen_fm2   ),
    .cen_640   ( cen_640   ),
    .snd_irq   ( snd_irq   ),
    .snd_latch ( snd_latch ),
    .rom_addr  ( snd_addr  ),
    .rom_cs    ( snd_cs    ),
    .rom_data  ( snd_data  ),
    .rom_ok    ( snd_ok    ),
    .pcm_addr  ( pcm_addr  ),
    .pcm_cs    ( pcm_cs    ),
    .pcm_data  ( pcm_data  ),
    .pcm_ok    ( pcm_ok    ),
    .fm_l      ( fm_l      ),
    .fm_r      ( fm_r      ),
    .pcm       ( pcm       ),
    .st_dout   ( st_sound  )
);

jt88game_video u_video(
    .rst               ( rst               ),
    .clk               ( clk               ),
    .pxl_cen           ( pxl_cen           ),
    .pxl2_cen          ( pxl2_cen          ),
    .cen24             ( cen24             ),
    .cpu_prio          ( prio              ),
    .lhbl              ( LHBL              ),
    .lvbl              ( LVBL              ),
    .hs                ( HS                ),
    .vs                ( VS                ),
    .cpu_addr          ( cpu_addr          ),
    .cpu_dout          ( cpu_dout          ),
    .cpu_we            ( cpu_we            ),
    .rio_cs            ( psac_io_cs        ),
    .vr_cs             ( psac_vr_cs        ),
    .pal_dout          ( pal_dout          ),
    .tilesys_dout      ( tilesys_dout      ),
    .tilesys_rom_dtack ( tilesys_rom_dtack ),
    .psacck_ok         ( psac_cpu_ok       ),
    .objsys_dout       ( objsys_dout       ),
    .psac_dout         ( psac_dout         ),
    .pal_we            ( pal_we            ),
    .tilesys_cs        ( tilesys_cs        ),
    .objsys_cs         ( objsys_cs         ),
    .rst8              ( rst8              ),
    .rmrd              ( rmrd              ),
    .rvo               ( 1'b0              ),
    .tile_irqn         ( cpu_irq_n         ),
    .obj_irqn          (                   ),
    .flip              ( dip_flip          ),
    .prog_addr         ( prog_addr[7:0]    ),
    .prog_data         ( prog_data[3:0]    ),
    .prom_we           ( prom_we           ),
    .lyrf_addr         ( lyrf_addr         ),
    .lyra_addr         ( lyra_addr         ),
    .lyrb_addr         ( lyrb_addr         ),
    .lyro_addr         ( lyro_addr         ),
    .lyrf_cs           ( lyrf_cs           ),
    .lyra_cs           ( lyra_cs           ),
    .lyrb_cs           ( lyrb_cs           ),
    .lyro_cs           ( lyro_cs           ),
    .lyra_ok           ( lyra_ok           ),
    .lyro_ok           ( lyro_ok           ),
    .lyrf_data         ( lyrf_data         ),
    .lyra_data         ( lyra_data         ),
    .lyrb_data         ( lyrb_data         ),
    .lyro_data         ( lyro_data         ),
    .psac_addr         ( psac_addr         ),
    .psac_cs           ( psac_cs           ),
    .psac_ok           ( psac_ok           ),
    .psac_data         ( psac_data         ),
    .red               ( red               ),
    .green             ( green             ),
    .blue              ( blue              ),
    .ioctl_addr        ( ioctl_addr[14:0]  ),
    .ioctl_ram         ( ioctl_ram         ),
    .ioctl_din         ( ioctl_din         ),
    .gfx_en            ( gfx_en            ),
    .debug_bus         ( debug_bus         ),
    .st_dout           ( st_video          )
);

endmodule
