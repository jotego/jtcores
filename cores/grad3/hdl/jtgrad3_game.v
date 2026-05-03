/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtgrad3_game(
    `include "jtframe_game_ports.inc"
);

wire [19:1] s_addr;
wire [16:1] m_gchar_addr, s_gchar_addr;
wire [15:0] m_dout, s_dout;
wire [15:0] pal_dout;
wire [ 7:0] tile_dout, obj_dout, snd_latch;
wire [ 1:0] m_dsn, s_dsn, m_gchar_dsn, s_gchar_dsn;
wire [ 1:0] m_sh_we, s_sh_we;
wire        m_cpu_we, s_cpu_we, snd_irq, sub_rst, sub_irq;
wire        m_tile_cs, s_tile_cs, s_obj_cs, pal_cs;
wire        m_gchar_cs, s_gchar_cs, m_gchar_we, s_gchar_we;
wire        m_gchar_ok, s_gchar_ok;
wire        tile_dtack, tile_irqn, tile_nmin, sub_irq2;
    wire        rmrd, prio;
wire        game_rst;
reg  [16:1] gchar_addr_r;
reg  [15:0] gchar_din_r;
reg  [ 1:0] gchar_dsn_r;
reg         gchar_we_r, gchar_cs_r, gchar_sel;
reg         m_gchar_done, s_gchar_done;

assign debug_view = 8'd0;
assign dip_flip   = 1'b0;
`ifdef JTFRAME_IOCTL_RD
assign ioctl_din  = 8'hff;
`endif
assign game_rst = rst;
assign m_shram_addr = main_addr[13:1];
assign s_shram_addr = s_addr[13:1];
assign m_shram_din  = m_dout;
assign s_shram_din  = s_dout;
assign m_shram_we   = m_sh_we;
assign s_shram_we   = s_sh_we;

assign m_gchar_ok = (!gchar_sel && gchar_cs_r && gchar_ok) ||
                    (m_gchar_done && m_gchar_cs);
assign s_gchar_ok = ( gchar_sel && gchar_cs_r && gchar_ok) ||
                    (s_gchar_done && s_gchar_cs);
assign gchar_cs   = gchar_cs_r;
assign gchar_addr = gchar_addr_r;
assign gchar_din  = gchar_din_r;
assign gchar_dsn  = gchar_dsn_r;
assign gchar_we   = gchar_we_r;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        gchar_cs_r    <= 0;
        gchar_sel     <= 0;
        gchar_we_r    <= 0;
        gchar_addr_r  <= 0;
        gchar_din_r   <= 0;
        gchar_dsn_r   <= 2'b11;
        m_gchar_done  <= 0;
        s_gchar_done  <= 0;
    end else begin
        if( game_rst ) begin
            gchar_cs_r    <= 0;
            gchar_sel     <= 0;
            gchar_we_r    <= 0;
            gchar_addr_r  <= 0;
            gchar_din_r   <= 0;
            gchar_dsn_r   <= 2'b11;
            m_gchar_done  <= 0;
            s_gchar_done  <= 0;
        end else begin
            if( !m_gchar_cs ) m_gchar_done <= 0;
            if( !s_gchar_cs ) s_gchar_done <= 0;

            if( gchar_cs_r ) begin
                if( gchar_ok ) begin
                    gchar_cs_r <= 0;
                    if( gchar_sel )
                        s_gchar_done <= 1;
                    else
                        m_gchar_done <= 1;
                end
            end else if( s_gchar_cs && s_gchar_dsn != 2'b11 && !s_gchar_done ) begin
                gchar_cs_r   <= 1;
                gchar_sel    <= 1;
                gchar_we_r   <= s_gchar_we;
                gchar_addr_r <= s_gchar_addr;
                gchar_din_r  <= s_dout;
                gchar_dsn_r  <= s_gchar_dsn;
            end else if( m_gchar_cs && m_gchar_dsn != 2'b11 && !m_gchar_done ) begin
                gchar_cs_r   <= 1;
                gchar_sel    <= 0;
                gchar_we_r   <= m_gchar_we;
                gchar_addr_r <= m_gchar_addr;
                gchar_din_r  <= m_dout;
                gchar_dsn_r  <= m_gchar_dsn;
            end
        end
    end
end

jtgrad3_main u_main(
    .rst        ( game_rst  ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),

    .main_addr  ( main_addr ),
    .cpu_dout   ( m_dout    ),
    .cpu_we     ( m_cpu_we  ),
    .bus_dsn    ( m_dsn     ),
    .rom_cs     ( main_cs   ),
    .rom_dout   ( main_data ),
    .rom_ok     ( main_ok   ),

    .sh_we      ( m_sh_we   ),
    .sh_dout    ( m_shram_dout ),

    .tile_cs    ( m_tile_cs ),
    .tile_dout  ( tile_dout ),
    .tile_dtack ( tile_dtack),
    .tile_irqn  ( tile_irqn ),
    .tile_nmin  ( tile_nmin ),

    .gchar_addr ( m_gchar_addr ),
    .gchar_dsn  ( m_gchar_dsn  ),
    .gchar_cs   ( m_gchar_cs   ),
    .gchar_we   ( m_gchar_we   ),
    .gchar_dout ( gchar_data   ),
    .gchar_ok   ( m_gchar_ok   ),

    .pal_cs     ( pal_cs    ),
    .pal_dout   ( pal_dout  ),
    .rmrd       ( rmrd      ),
    .prio       ( prio      ),
    .sub_rst    ( sub_rst   ),
    .sub_irq    ( sub_irq   ),

    .snd_latch  ( snd_latch ),
    .snd_irq    ( snd_irq   ),

    .cab_1p     ( cab_1p[2:0] ),
    .coin       ( coin[2:0]   ),
    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .service    ( service   ),
    .dip_pause  ( dip_pause ),
    .dipsw      ( dipsw[19:0] ),

    .st_dout    (          ),
    .debug_bus  ( debug_bus )
);

jtgrad3_sub u_sub(
    .rst        ( game_rst  ),
    .sub_rst    ( sub_rst   ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),
    .irq2       ( sub_irq2  ),

    .cpu_addr   ( s_addr    ),
    .cpu_dout   ( s_dout    ),
    .cpu_we     ( s_cpu_we  ),
    .bus_dsn    ( s_dsn     ),
    .rom_cs     ( sub_cs    ),
    .rom_addr   ( sub_addr  ),
    .rom_dout   ( sub_data  ),
    .rom_ok     ( sub_ok    ),

    .sh_we      ( s_sh_we   ),
    .sh_dout    ( s_shram_dout ),

    .tile_cs    ( s_tile_cs ),
    .tile_dout  ( tile_dout ),
    .tile_dtack ( tile_dtack),

    .obj_cs     ( s_obj_cs  ),
    .obj_dout   ( obj_dout  ),

    .gchar_addr ( s_gchar_addr ),
    .gchar_dsn  ( s_gchar_dsn  ),
    .gchar_cs   ( s_gchar_cs   ),
    .gchar_we   ( s_gchar_we   ),
    .gchar_dout ( gchar_data   ),
    .gchar_ok   ( s_gchar_ok   ),

    .gfx_addr   ( gfx_addr  ),
    .gfx_cs     ( gfx_cs    ),
    .gfx_data   ( gfx_data  ),
    .gfx_ok     ( gfx_ok    ),

    .irq_trig   ( sub_irq   ),
    .dip_pause  ( dip_pause ),
    .st_dout    (          )
);

jtgrad3_video u_video(
    .rst        ( game_rst  ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .prio       ( prio      ),

    .lhbl       ( LHBL      ),
    .lvbl       ( LVBL      ),
    .hs         ( HS        ),
    .vs         ( VS        ),
    .tile_irqn  ( tile_irqn ),
    .tile_nmin  ( tile_nmin ),
    .sub_irq2   ( sub_irq2  ),

    .m_cpu_addr ( main_addr[16:1] ),
    .m_cpu_dsn  ( m_dsn        ),
    .m_cpu_dout ( m_dout       ),
    .m_cpu_we   ( m_cpu_we     ),
    .s_cpu_addr ( s_addr[16:1] ),
    .s_cpu_dsn  ( s_dsn        ),
    .s_cpu_dout ( s_dout       ),
    .s_cpu_we   ( s_cpu_we     ),
    .m_tilesys_cs( m_tile_cs   ),
    .s_tilesys_cs( s_tile_cs   ),
    .objsys_cs  ( s_obj_cs  ),
    .pal_cs     ( pal_cs    ),
    .vdtack     ( tile_dtack),
    .tilesys_dout( tile_dout),
    .objsys_dout( obj_dout  ),
    .pal_dout   ( pal_dout  ),
    .pal_rd_addr( pal_rd_addr ),
    .palrd_dout ( palrd_dout ),
    .pal_cpu_addr( pal_cpu_addr ),
    .pal_cpu_din( pal_cpu_din ),
    .pal_cpu_we ( pal_cpu_we ),
    .pal_cpu_dout( pal_cpu_dout ),
    .rmrd       ( rmrd      ),

    .lyrf_addr  ( lyrf_addr ),
    .lyra_addr  ( lyra_addr ),
    .lyrb_addr  ( lyrb_addr ),
    .lyro_addr  ( lyro_addr ),
    .lyrf_data  ( lyrf_data ),
    .lyra_data  ( lyra_data ),
    .lyrb_data  ( lyrb_data ),
    .lyro_data  ( lyro_data ),
    .lyrf_cs    ( lyrf_cs   ),
    .lyra_cs    ( lyra_cs   ),
    .lyrb_cs    ( lyrb_cs   ),
    .lyro_cs    ( lyro_cs   ),
    .lyra_ok    ( lyra_ok   ),
    .lyro_ok    ( lyro_ok   ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    (          )
);

jtgrad3_sound u_sound(
    .rst        ( game_rst  ),
    .clk        ( clk       ),
    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),

    .snd_irq    ( snd_irq   ),
    .snd_latch  ( snd_latch ),

    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),

    .pcma_addr  ( pcma_addr ),
    .pcma_dout  ( pcma_data ),
    .pcma_cs    ( pcma_cs   ),
    .pcma_ok    ( pcma_ok   ),
    .pcmb_addr  ( pcmb_addr ),
    .pcmb_dout  ( pcmb_data ),
    .pcmb_cs    ( pcmb_cs   ),
    .pcmb_ok    ( pcmb_ok   ),

    .fm_l       ( fm_l      ),
    .fm_r       ( fm_r      ),
    .pcm        ( pcm       ),

    .debug_bus  ( debug_bus ),
    .st_dout    (          )
);

endmodule
