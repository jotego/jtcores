/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jtgrad3_game(
    `include "jtframe_game_ports.inc"
);

wire [19:1] s_addr;
wire [ 7:0] tile_dout, obj_dout, snd_latch;
wire [ 7:0] video_din, st_snd;
reg  [ 4:0] cen_num=5'd5;
wire        m_cpu_we,   s_cpu_we,  snd_irq,   sub_rst, sub_irq, main_irq;
wire        m_tile_cs,  s_tile_cs, s_obj_cs,  pal_cs;
wire        m_tile_dtack, s_tile_dtack;
wire        tile_irqn, tile_nmin;
wire        rmrd, prio;
wire        m_video_req_n, s_video_req_n, m_video_gnt_n, s_video_gnt_n;
wire        turbo;

assign debug_view = st_snd;
assign dip_flip   = 1'b0;
`ifdef JTFRAME_IOCTL_RD
assign ioctl_din  = video_din;
`endif
assign s_shram_addr = s_addr[13:1];
assign sram_addr    = s_addr[13:1];
assign s_gchar_addr = s_addr[16:1];
assign pal_we       = {2{m_cpu_we & pal_cs}} & ~m_dsn;
assign turbo        = ~dipsw[20];

always @(posedge clk) begin
    cen_num <= turbo ? 5'd8 : 5'd5;
end

jtgrad3_main u_main(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .LVBL       ( LVBL         ),
    .irq_trig   ( main_irq     ),
    .cen_num    ( cen_num      ),

    .main_addr  ( main_addr    ),
    .cpu_dout   ( m_dout       ),
    .cpu_we     ( m_cpu_we     ),
    .bus_dsn    ( m_dsn        ),
    .rom_cs     ( main_cs      ),
    .rom_dout   ( main_data    ),
    .rom_ok     ( main_ok      ),
    .ram_dout   ( mram_dout    ),
    .ram_we     ( mram_we      ),

    .sh_we      ( m_shram_we   ),
    .sh_dout    ( m_shram_dout ),

    .tile_cs    ( m_tile_cs    ),
    .tile_dout  ( tile_dout    ),
    .tile_dtack ( m_tile_dtack ),
    .video_req_n( m_video_req_n),
    .video_grant_n(m_video_gnt_n),

    .gchar_cs   ( m_gchar_cs   ),
    .gchar_we   ( m_gchar_we   ),
    .gchar_dout ( m_gchar_data ),
    .gchar_ok   ( m_gchar_ok   ),

    .pal_cs     ( pal_cs       ),
    .pal_dout   ( pal_dout     ),
    .rmrd       ( rmrd         ),
    .prio       ( prio         ),
    .sub_rst    ( sub_rst      ),
    .sub_irq    ( sub_irq      ),

    .snd_latch  ( snd_latch    ),
    .snd_irq    ( snd_irq      ),

    .cab_1p     ( cab_1p[2:0]  ),
    .coin       ( coin[2:0]    ),
    .joystick1  ( joystick1    ),
    .joystick2  ( joystick2    ),
    .service    ( service      ),
    .dip_pause  ( dip_pause    ),
    .dipsw      ( dipsw[19:0]  ),

    .st_dout    (              ),
    .debug_bus  ( debug_bus    )
);

jtgrad3_sub u_sub(
    .rst        ( rst          ),
    .sub_rst    ( sub_rst      ),
    .clk        ( clk          ),
    .LVBL       ( LVBL         ),
    .cpu_trig   ( sub_irq      ),
    .cen_num    ( cen_num      ),

    .cpu_addr   ( s_addr       ),
    .cpu_dout   ( s_dout       ),
    .cpu_we     ( s_cpu_we     ),
    .bus_dsn    ( s_dsn        ),
    .rom_cs     ( sub_cs       ),
    .rom_addr   ( sub_addr     ),
    .rom_dout   ( sub_data     ),
    .rom_ok     ( sub_ok       ),
    .ram_dout   ( sram_dout    ),
    .ram_we     ( sram_we      ),

    .sh_we      ( s_shram_we   ),
    .sh_dout    ( s_shram_dout ),

    .tile_cs    ( s_tile_cs    ),
    .tile_dout  ( tile_dout    ),
    .tile_dtack ( s_tile_dtack ),
    .video_req_n( s_video_req_n),
    .video_grant_n(s_video_gnt_n),

    .obj_cs     ( s_obj_cs     ),
    .obj_dout   ( obj_dout     ),

    .gchar_cs   ( s_gchar_cs   ),
    .gchar_we   ( s_gchar_we   ),
    .gchar_dout ( s_gchar_data ),
    .gchar_ok   ( s_gchar_ok   ),

    .gfx_addr   ( gfx_addr     ),
    .gfx_cs     ( gfx_cs       ),
    .gfx_data   ( gfx_data     ),
    .gfx_ok     ( gfx_ok       ),

    .irq_trig   ( main_irq     ),
    .dip_pause  ( dip_pause    ),
    .st_dout    (              )
);

jtgrad3_video u_video(
    .rst          ( rst             ),
    .clk          ( clk             ),
    .pxl_cen      ( pxl_cen         ),
    .pxl2_cen     ( pxl2_cen        ),
    .cen24        ( cen24           ),
    .prio         ( prio            ),

    .lhbl         ( LHBL            ),
    .lvbl         ( LVBL            ),
    .hs           ( HS              ),
    .vs           ( VS              ),
    .tile_irqn    (                 ),
    .tile_nmin    (                 ),

    .m_cpu_addr   ( main_addr[16:1] ),
    .m_cpu_dsn    ( m_dsn           ),
    .m_cpu_dout   ( m_dout          ),
    .m_cpu_we     ( m_cpu_we        ),
    .s_cpu_addr   ( s_addr[16:1]    ),
    .s_cpu_dsn    ( s_dsn           ),
    .s_cpu_dout   ( s_dout          ),
    .s_cpu_we     ( s_cpu_we        ),
    .m_tilesys_cs ( m_tile_cs       ),
    .m_video_req_n( m_video_req_n   ),
    .s_video_req_n( s_video_req_n   ),
    .m_video_grant_n(m_video_gnt_n  ),
    .s_video_grant_n(s_video_gnt_n  ),
    .s_tilesys_cs ( s_tile_cs       ),
    .objsys_cs    ( s_obj_cs        ),
    .m_vdtack     ( m_tile_dtack    ),
    .s_vdtack     ( s_tile_dtack    ),
    .tilesys_dout ( tile_dout       ),
    .objsys_dout  ( obj_dout        ),
    .pal_rd_addr  ( palrd_addr      ),
    .palrd_dout   ( palrd_dout      ),

    .ioctl_addr   ( ioctl_addr      ),
    .ioctl_ram    ( ioctl_ram       ),
    .ioctl_din    ( video_din       ),
    .rmrd         ( rmrd            ),

    .prog_addr    ( prog_addr[10:0] ),
    .prog_data    ( prog_data       ),
    .prom_pal_we  ( prom_we         ),

    .lyrf_addr    ( lyrf_addr       ),
    .lyra_addr    ( lyra_addr       ),
    .lyrb_addr    ( lyrb_addr       ),
    .lyro_addr    ( lyro_addr       ),
    .lyrf_data    ( lyrf_data       ),
    .lyra_data    ( lyra_data       ),
    .lyrb_data    ( lyrb_data       ),
    .lyro_data    ( lyro_data       ),
    .lyrf_cs      ( lyrf_cs         ),
    .lyra_cs      ( lyra_cs         ),
    .lyrb_cs      ( lyrb_cs         ),
    .lyro_cs      ( lyro_cs         ),
    .lyra_ok      ( lyra_ok         ),
    .lyro_ok      ( lyro_ok         ),

    .red          ( red             ),
    .green        ( green           ),
    .blue         ( blue            ),

    .gfx_en       ( gfx_en          ),
    .debug_bus    ( debug_bus       ),
    .st_dout      (                 )
);

jtgrad3_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),
    .cen_pcm    ( cen_pcm   ),

    .snd_irq    ( snd_irq   ),
    .snd_latch  ( snd_latch ),

    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),

    .pcma_addr  ( pcma_addr ),
    .pcma_data  ( pcma_data ),
    .pcma_cs    ( pcma_cs   ),
    .pcma_ok    ( pcma_ok   ),
    .pcmb_addr  ( pcmb_addr ),
    .pcmb_data  ( pcmb_data ),
    .pcmb_cs    ( pcmb_cs   ),
    .pcmb_ok    ( pcmb_ok   ),

    .fm_l       ( fm_l      ),
    .fm_r       ( fm_r      ),
    .pcm        ( pcm       ),

    .debug_bus  ( debug_bus ),
    .st_dout    ( st_snd    )
);

endmodule
