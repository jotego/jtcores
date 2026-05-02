/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtgrad3_game(
    `include "jtframe_game_ports.inc"
);

wire [19:1] s_addr;
wire [17:1] m_addr;
wire [16:1] m_gchar_addr, s_gchar_addr;
wire [15:0] m_dout, s_dout, m_sh_dout, s_sh_dout;
wire [15:0] pal_dout;
wire [ 7:0] tile_dout, obj_dout, snd_latch;
wire [ 7:0] st_main, st_sub, st_video, st_snd;
wire [ 1:0] m_dsn, s_dsn, m_gchar_dsn, s_gchar_dsn;
wire [ 1:0] m_sh_we, s_sh_we;
wire        m_cpu_we, s_cpu_we, snd_irq, sub_rst, sub_irq;
wire        m_tile_cs, s_tile_cs, s_obj_cs, pal_cs;
wire        m_gchar_cs, s_gchar_cs, m_gchar_we, s_gchar_we;
wire        m_gchar_ok, s_gchar_ok;
wire        tile_dtack, tile_irqn, tile_nmin, sub_irq2;
    wire        rmrd, prio;
wire [ 7:0] video_ioctl_din;
wire        game_rst;
reg  [ 7:0] debug_mux;
reg  [16:1] gchar_addr_r;
reg  [15:0] gchar_din_r;
reg  [ 1:0] gchar_dsn_r;
reg         gchar_we_r, gchar_cs_r, gchar_sel;
reg         m_gchar_done, s_gchar_done;

assign debug_view = debug_mux;
assign dip_flip   = 1'b0;
`ifdef JTFRAME_IOCTL_RD
assign ioctl_din  = video_ioctl_din;
`endif
`ifdef JTGRAD3_SIM_RESET_DELAY
reg  [ 7:0] sim_rst_cnt;
reg         sim_lvbl_l;
wire        sim_frame = sim_lvbl_l & ~LVBL;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sim_rst_cnt <= 0;
        sim_lvbl_l  <= 0;
    end else begin
        sim_lvbl_l <= LVBL;
        if( sim_frame && sim_rst_cnt != `JTGRAD3_SIM_RESET_DELAY )
            sim_rst_cnt <= sim_rst_cnt + 1'd1;
    end
end

assign game_rst = rst | (sim_rst_cnt != `JTGRAD3_SIM_RESET_DELAY);
`else
assign game_rst = rst;
`endif

assign main_addr = m_addr;
assign mram_din = m_dout;
assign sram_din = s_dout;

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

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: debug_mux <= st_main;
        1: debug_mux <= st_sub;
        2: debug_mux <= st_video;
        3: debug_mux <= st_snd;
    endcase
end

`ifdef JTGRAD3_TRACE_BOOT
reg        trace_lvbl_l, trace_sub_rst_l;
reg [15:0] trace_frame;
reg [15:0] trace_mtile, trace_stile, trace_mchar, trace_schar;
reg [15:0] trace_pal, trace_obj, trace_gfx;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        trace_lvbl_l   <= 0;
        trace_sub_rst_l<= 1;
        trace_frame    <= 0;
        trace_mtile    <= 0;
        trace_stile    <= 0;
        trace_mchar    <= 0;
        trace_schar    <= 0;
        trace_pal      <= 0;
        trace_obj      <= 0;
        trace_gfx      <= 0;
    end else begin
        trace_lvbl_l    <= LVBL;
        trace_sub_rst_l <= sub_rst;
        if( trace_lvbl_l & ~LVBL )
            trace_frame <= trace_frame + 1'd1;

        if( sub_rst != trace_sub_rst_l )
            $display("G3BOOT frame=%0d sub_rst=%b", trace_frame, sub_rst);

        if( m_tile_cs && m_cpu_we && m_dsn != 2'b11 ) begin
            trace_mtile <= trace_mtile + 1'd1;
            if( trace_mtile[8:0] == 9'd0 )
                $display("G3BOOT frame=%0d main tile write #%0d addr=%06x dsn=%b data=%04x",
                    trace_frame, trace_mtile, {m_addr,1'b0}, m_dsn, m_dout);
        end
        if( s_tile_cs && s_cpu_we && s_dsn != 2'b11 ) begin
            trace_stile <= trace_stile + 1'd1;
            if( trace_stile[8:0] == 9'd0 )
                $display("G3BOOT frame=%0d sub tile write #%0d addr=%06x dsn=%b data=%04x",
                    trace_frame, trace_stile, {s_addr,1'b0}, s_dsn, s_dout);
        end
        if( m_gchar_cs && m_gchar_we && m_gchar_dsn != 2'b11 ) begin
            trace_mchar <= trace_mchar + 1'd1;
            if( trace_mchar[8:0] == 9'd0 )
                $display("G3BOOT frame=%0d main char write #%0d addr=%06x dsn=%b data=%04x",
                    trace_frame, trace_mchar, {m_gchar_addr,1'b0}, m_gchar_dsn, m_dout);
        end
        if( s_gchar_cs && s_gchar_we && s_gchar_dsn != 2'b11 ) begin
            trace_schar <= trace_schar + 1'd1;
            if( trace_schar[8:0] == 9'd0 )
                $display("G3BOOT frame=%0d sub char write #%0d addr=%06x dsn=%b data=%04x",
                    trace_frame, trace_schar, {s_gchar_addr,1'b0}, s_gchar_dsn, s_dout);
        end
        if( pal_cs && m_cpu_we && m_dsn != 2'b11 ) begin
            trace_pal <= trace_pal + 1'd1;
            if( trace_pal[7:0] == 8'd0 )
                $display("G3BOOT frame=%0d pal write #%0d addr=%06x dsn=%b data=%04x",
                    trace_frame, trace_pal, {m_addr,1'b0}, m_dsn, m_dout);
        end
        if( s_obj_cs && s_cpu_we && s_dsn != 2'b11 ) begin
            trace_obj <= trace_obj + 1'd1;
            if( trace_obj[7:0] == 8'd0 )
                $display("G3BOOT frame=%0d obj write #%0d addr=%06x dsn=%b data=%04x",
                    trace_frame, trace_obj, {s_addr,1'b0}, s_dsn, s_dout);
        end
        if( gfx_cs && !s_cpu_we && gfx_ok ) begin
            trace_gfx <= trace_gfx + 1'd1;
            if( trace_gfx[7:0] == 8'd0 )
                $display("G3BOOT frame=%0d gfx read #%0d addr=%06x data=%04x",
                    trace_frame, trace_gfx, {gfx_addr,1'b0}, gfx_data);
        end
    end
end
`endif

`ifdef JTGRAD3_TRACE_GCHAR_SAMPLE
always @(posedge clk) begin
    if( s_gchar_cs && s_gchar_we && s_gchar_dsn != 2'b11 &&
        s_gchar_addr >= 16'h0220 && s_gchar_addr <= 16'h023f )
        $display("G3CHAR sub addr=%05x dsn=%b data=%04x gfx_addr=%06x gfx_data=%04x gfx_cs=%b gfx_ok=%b",
            {s_gchar_addr,1'b0}, s_gchar_dsn, s_dout, {gfx_addr,1'b0}, gfx_data, gfx_cs, gfx_ok);
end
`endif

`ifdef JTGRAD3_TRACE_GCHAR_ALL
reg        trace_gchar_lvbl_l;
reg [15:0] trace_gchar_frame;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        trace_gchar_lvbl_l <= 0;
        trace_gchar_frame  <= 0;
    end else begin
        trace_gchar_lvbl_l <= LVBL;
        if( trace_gchar_lvbl_l & ~LVBL )
            trace_gchar_frame <= trace_gchar_frame + 1'd1;
        if( gchar_cs_r && gchar_ok && gchar_we_r )
            $display("G3GW frame=%0d sel=%b addr=%05x data=%04x mask=%b",
                trace_gchar_frame, gchar_sel, {gchar_addr_r,1'b0}, gchar_din_r, gchar_dsn_r);
    end
end
`endif

`ifdef JTGRAD3_DUMP_GCHAR
`ifndef JTGRAD3_DUMP_GCHAR_FRAME
`define JTGRAD3_DUMP_GCHAR_FRAME 1779
`endif
reg        dump_gchar_lvbl_l, dump_gchar_done;
reg [15:0] dump_gchar_frame;
reg [15:0] dump_gchar_ram[0:65535];
integer    dump_gchar_i, dump_gchar_fd;

initial begin
    for( dump_gchar_i=0; dump_gchar_i<65536; dump_gchar_i=dump_gchar_i+1 )
        dump_gchar_ram[dump_gchar_i] = 16'd0;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dump_gchar_lvbl_l <= 0;
        dump_gchar_frame  <= 0;
        dump_gchar_done   <= 0;
    end else begin
        dump_gchar_lvbl_l <= LVBL;
        if( gchar_cs_r && gchar_ok && gchar_we_r ) begin
            if( !gchar_dsn_r[0] ) dump_gchar_ram[gchar_addr_r][ 7:0] <= gchar_din_r[ 7:0];
            if( !gchar_dsn_r[1] ) dump_gchar_ram[gchar_addr_r][15:8] <= gchar_din_r[15:8];
        end
        if( dump_gchar_lvbl_l & ~LVBL ) begin
            dump_gchar_frame <= dump_gchar_frame + 1'd1;
            if( dump_gchar_frame == `JTGRAD3_DUMP_GCHAR_FRAME && !dump_gchar_done ) begin
                dump_gchar_done = 1;
                dump_gchar_fd = $fopen("hdl_gchar.bin", "wb");
                for( dump_gchar_i=0; dump_gchar_i<65536; dump_gchar_i=dump_gchar_i+1 ) begin
                    $fwrite(dump_gchar_fd, "%c", dump_gchar_ram[dump_gchar_i][ 7:0]);
                    $fwrite(dump_gchar_fd, "%c", dump_gchar_ram[dump_gchar_i][15:8]);
                end
                $fclose(dump_gchar_fd);
                $display("G3DUMP gchar frame=%0d", dump_gchar_frame);
            end
        end
    end
end
`endif

`ifdef JTGRAD3_TRACE_GCHAR_PC
reg        trace_gpc_lvbl_l;
reg [15:0] trace_gpc_frame;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        trace_gpc_lvbl_l <= 0;
        trace_gpc_frame  <= 0;
    end else begin
        trace_gpc_lvbl_l <= LVBL;
        if( trace_gpc_lvbl_l & ~LVBL )
            trace_gpc_frame <= trace_gpc_frame + 1'd1;
        if( gchar_cs_r && gchar_ok && gchar_we_r &&
            ((trace_gpc_frame >= 16'd430 && trace_gpc_frame <= 16'd470) ||
             (trace_gpc_frame >= 16'd760 && trace_gpc_frame <= 16'd790)) )
            $display("G3GPC frame=%0d sel=%b pc=%06x addr=%05x data=%04x mask=%b s_irqmask=%b s_addr=%06x",
                trace_gpc_frame, gchar_sel,
                gchar_sel ? u_sub.u_cpu.u_cpu.PC[23:0] : u_main.u_cpu.u_cpu.PC[23:0],
                {gchar_addr_r,1'b0}, gchar_din_r, gchar_dsn_r,
                u_sub.irq_mask, {s_addr,1'b0});
    end
end
`endif

jtgrad3_share u_share(
    .clk        ( clk       ),
    .m_dout     ( m_dout    ),
    .s_dout     ( s_dout    ),
    .m_addr     ( m_addr[13:1] ),
    .s_addr     ( s_addr[13:1] ),
    .m_we       ( m_sh_we   ),
    .s_we       ( s_sh_we   ),
    .m_din      ( m_sh_dout ),
    .s_din      ( s_sh_dout )
);

jtgrad3_main u_main(
    .rst        ( game_rst  ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),

    .main_addr  ( m_addr    ),
    .cpu_dout   ( m_dout    ),
    .cpu_we     ( m_cpu_we  ),
    .bus_dsn    ( m_dsn     ),
    .ram_dsn    ( mram_dsn  ),
    .ram_addr   ( mram_addr ),
    .ram_cs     ( mram_cs   ),
    .ram_we     ( mram_we   ),
    .ram_dout   ( mram_data ),
    .ram_ok     ( mram_ok   ),
    .rom_cs     ( main_cs   ),
    .rom_dout   ( main_data ),
    .rom_ok     ( main_ok   ),

    .sh_we      ( m_sh_we   ),
    .sh_dout    ( m_sh_dout ),

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

    .st_dout    ( st_main  ),
    .debug_bus  ( debug_bus )
);

jtgrad3_sub u_sub(
    .rst        ( game_rst | sub_rst ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),
    .irq2       ( sub_irq2  ),

    .cpu_addr   ( s_addr    ),
    .cpu_dout   ( s_dout    ),
    .cpu_we     ( s_cpu_we  ),
    .bus_dsn    ( s_dsn     ),
    .ram_dsn    ( sram_dsn  ),
    .ram_addr   ( sram_addr ),
    .ram_cs     ( sram_cs   ),
    .ram_we     ( sram_we   ),
    .ram_dout   ( sram_data ),
    .ram_ok     ( sram_ok   ),
    .rom_cs     ( sub_cs    ),
    .rom_addr   ( sub_addr  ),
    .rom_dout   ( sub_data  ),
    .rom_ok     ( sub_ok    ),

    .sh_we      ( s_sh_we   ),
    .sh_dout    ( s_sh_dout ),

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
    .st_dout    ( st_sub    )
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

    .m_cpu_addr ( m_addr[16:1] ),
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

    .ioctl_addr ( ioctl_addr[15:0] ),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( video_ioctl_din ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_video  )
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
    .st_dout    ( st_snd    )
);

endmodule
