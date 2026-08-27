/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-2-2026 */

module jtcps3_video(
    input               rst,
    input               clk,
    input               std_cen, std2_cen,
    output              pxl2_cen,
    output              pxl_cen,
    output              lhbl,
    output              lvbl,
    output              hs,
    output              vs,
    // frame buffer
    output      [ 8:0]  game_vrender,
    output      [ 9:0]  game_hdump,
    output      [ 9:0]  ln_addr,
    output      [15:0]  ln_data,
    output              ln_done,
    output              ln_we,
    input               ln_hs,
    input               ln_vs,
    input               ln_lvbl,
    input       [15:0]  ln_pxl,
    input       [ 8:0]  ln_v,
    // Scene DMA
    output              scndma_rd,
    output      [18:2]  scndma_addr,
    input       [31:0]  scndma_data,
    input               scndma_ok,
    output              cpuba0_flush,
    input               cpuba0_flushing,
    input               cpuba0_flush_done,
    output reg          gfxdma_flush,
    input               gfxdma_flushing,
    input               gfxdma_flush_done,

    input       [31:0]  scene_dout,
    output      [31:0]  scene_din,
    output      [12:2]  scene_addr,
    output      [ 3:0]  scene_we,
    output              sprdma_busy,
    // CPU interface
    input               ppu_cs,
    input               ssreg_cs,
    input       [ 8:1]  cpu_addr,
    input       [31:0]  cpu_dout,
    input               cpu_rnw,
    input       [ 3:0]  cpu_we_n,
    output      [ 3:0]  cram_bank,
    output      [15:0]  gfxflash_bank,
    // scene memory
    output      [12:2]  scn_vaddr,
    input       [31:0]  scn_vdata,
    // tile cache line
    output              tiles_rd,
    output      [22:4]  tiles_addr,
    input       [127:0] tiles_data,
    input               tiles_ok,
    // graphics DMA source
    output              gfxdma_rd,
    output      [25:2]  gfxdma_addr,
    input       [31:0]  gfxdma_data,
    input               gfxdma_ok,
    // char DMA destination
    output              tiles_wr_rd,
    output      [22:2]  tiles_wr_addr,
    output              tiles_wr_we,
    output      [31:0]  tiles_wr_din,
    output      [ 3:0]  tiles_wr_dsn,
    input       [31:0]  tiles_wr_data,
    input               tiles_wr_ok,
    output              chardma_busy,
    output              chardma_done,
    // scr map cache line
    output              scrmap_rd,
    output      [18:2]  scrmap_addr,
    input       [31:0]  scrmap_data,
    input               scrmap_ok,
    // SS layer memory
    output      [13:1]  sschar_vaddr,
    input       [15:0]  sschar_vdata,
    output      [12:1]  ssmap_vaddr,
    input       [15:0]  ssmap_vdata,
    output      [12:1]  ssscr_vaddr,
    input       [15:0]  ssscr_vdata,
    // palette DMA destination
    output      [17:1]  paldma_addr,
    output      [15:0]  paldma_din,
    output      [ 1:0]  paldma_we,
    output              paldma_busy,
    output              paldma_done,
    // palette memory
    output      [17:1]  pal_vaddr,
    input       [15:0]  pal_vdata,
    // zoom step output to frame buffer
    output reg  [ 8:0]  h_step,
    output reg  [ 8:0]  v_step,
    // color output
    output      [ 4:0]  red,
    output      [ 4:0]  green,
    output      [ 4:0]  blue,
    // Debug
    input       [ 3:0]  gfx_en,
    input       [ 7:0]  debug_bus,
    output      [ 7:0]  st_dout,
    input       [ 5:0]  ioctl_addr,
    output      [ 7:0]  ioctl_din
);

localparam [ 9:0] H_SYNC_WIDTH_DFLT = 10'h02a;
localparam [ 9:0] H_BLANK_END_DFLT  = 10'h06f;
localparam [ 9:0] H_SCREEN_END_DFLT = 10'h1ef;
localparam [ 9:0] H_TOTAL_END_DFLT  = 10'h1c6;
localparam [ 9:0] V_SYNC_END_DFLT   = 10'h003;
localparam [ 9:0] V_BLANK_END_DFLT  = 10'h015;
localparam [ 9:0] V_SCREEN_END_DFLT = 10'h0f5;
localparam [ 9:0] V_TOTAL_END_DFLT  = 10'h106;
localparam [ 2:0] PXL_DIV_DFLT      = 3'd3;
localparam [ 9:0] CPS1_V_BLANK_END  = 10'd14;

wire [ 7:0] ppu_addr, ppu_din, ppu_dump;
wire [ 1:0] ppu_flip;
wire        ppu_reg_cs;
wire [15:0] ss_hscroll, ss_vscroll;
wire [ 7:0] ss_din, ss_pal_base, ss_dump, st_ppu;
wire [ 4:0] ss_addr;
wire [ 1:0] ss_flip;
wire        ss_cs;
wire [15:0] tmap0_scrx, tmap0_scry, tmap1_scrx, tmap1_scry,
            tmap2_scrx, tmap2_scry, tmap3_scrx, tmap3_scry;
wire [ 9:0] gscr0x, gscr0y, gscr1x, gscr1y, gscr2x, gscr2y, gscr3x, gscr3y,
            gscr4x, gscr4y, gscr5x, gscr5y, gscr6x, gscr6y, gscr7x, gscr7y,
            h_sync_width, h_blank_end, h_screen_end, h_total_end,
            v_sync_end, v_blank_end, v_screen_end, v_total_end,
            hdump, vdump;
wire [ 8:0] cps1_hdump, cps1_vdump;
wire [ 6:0] tmap0_lscr_base, tmap0_tile_base, tmap1_lscr_base, tmap1_tile_base,
            tmap2_lscr_base, tmap2_tile_base, tmap3_lscr_base, tmap3_tile_base;
wire [ 5:0] tmap0_ctrl, tmap1_ctrl, tmap2_ctrl, tmap3_ctrl;
wire [ 4:0] tmap0_width, tmap1_width, tmap2_width, tmap3_width;
wire [ 2:0] pxl_div;
wire [ 9:0] objlim_scan;
wire        scan_busy;
wire [16:0] ss_pxl, scene_pxl;
wire [14:0] scene_rgb;
wire [15:0] sprdma;
wire        cps1_hb, cps1_vb;
wire        cps1_lhbl_mix;
wire        sprdma_enable,
            sprdma_go,
            sprdma_go_dma,
            chardma_go,
            paldma_go;
wire        sprdma_dma_busy;
reg         sprdma_flush_req, sprdma_flush_pending;
reg         gfxdma_flush_pending;
reg         chardma_go_pending, paldma_go_pending;
wire        chardma_go_gated, paldma_go_gated;
wire [31:0] zipchar_data;
wire [25:2] zipchar_addr;
wire [25:1] palrd_addr;
wire [15:0] palrd_data;
wire        zipchar_rd, zipchar_ok,
            palrd_rd, palrd_ok;
wire [15:0] chardma_src_lo;
wire [ 5:0] chardma_src_hi;
wire [31:0] paldma_src, paldma_dst, paldma_fade;
wire [15:0] h_zoom_size, v_zoom_size, h_zoom_scl, v_zoom_scl;
wire [15:0] paldma_len;
wire        paldma_len_hi;
wire [ 9:0] gscr0x_buf, gscr0y_buf, gscr1x_buf, gscr1y_buf,
            gscr2x_buf, gscr2y_buf, gscr3x_buf, gscr3y_buf,
            gscr4x_buf, gscr4y_buf, gscr5x_buf, gscr5y_buf,
            gscr6x_buf, gscr6y_buf, gscr7x_buf, gscr7y_buf;

assign sprdma_enable = sprdma[3];
assign ss_addr    = cpu_addr[5:1];
assign ss_cs      = ssreg_cs & (cpu_rnw | ~cpu_we_n[0]);
assign ss_din     = cpu_dout[7:0];

assign gfxdma_rd    = paldma_busy ? palrd_rd         : zipchar_rd;
assign gfxdma_addr  = paldma_busy ? palrd_addr[25:2] : zipchar_addr;
assign palrd_ok     = paldma_busy & gfxdma_ok;
assign zipchar_ok   =~paldma_busy & gfxdma_ok;
assign zipchar_data = gfxdma_data;
assign palrd_data   = palrd_addr[1] ? gfxdma_data[15:0] : gfxdma_data[31:16];

assign ioctl_din     = ioctl_addr[5] ? ppu_dump : ss_dump;
assign st_dout       = st_ppu;
assign cpuba0_flush  = sprdma_flush_req;
assign sprdma_go_dma = sprdma_flush_pending & cpuba0_flush_done;
assign sprdma_busy   = sprdma_flush_pending | sprdma_dma_busy;
assign pxl_cen       = std_cen;
assign pxl2_cen      = std2_cen;
assign lhbl          = ~cps1_hb;
assign lvbl          = ~cps1_vb;
// temporary work around for colmix to prevent the first pixel after lhbl
// from being lost
assign cps1_lhbl_mix = cps1_hdump >= 9'd64 && cps1_hdump < 9'd448;
assign hdump         = { 1'b0, cps1_hdump };
assign vdump         = { 1'b0, cps1_vdump };

// frame buffer
assign game_hdump   = { 1'b0, hdump[8:0] };

function [8:0] zoom(input [7:0] scale); begin
    zoom = scale >= 8'h80 ? 9'h1ff : { scale[6:0], 2'b00 };
end endfunction

always @(posedge clk) begin
    h_step <= zoom( h_zoom_scl[7:0] );
    v_step <= zoom( v_zoom_scl[7:0] );
end

always @(posedge clk) begin
    if(rst) begin
        sprdma_flush_req     <= 1'b0;
        sprdma_flush_pending <= 1'b0;
    end else begin
        sprdma_flush_req <= 1'b0;
        if(sprdma_go & sprdma_enable & !sprdma_dma_busy & !sprdma_flush_pending) begin
            sprdma_flush_req     <= 1'b1;
            sprdma_flush_pending <= 1'b1;
        end else if(sprdma_flush_pending & cpuba0_flush_done) begin
            sprdma_flush_pending <= 1'b0;
        end
    end
end

// gfxdma pre-flush: invalidate the shared GFX read cache before
// either the character DMA or the palette DMA starts a new transfer.
assign chardma_go_gated = gfxdma_flush_done & chardma_go_pending;
assign paldma_go_gated  = gfxdma_flush_done & paldma_go_pending;

always @(posedge clk) begin
    if(rst) begin
        gfxdma_flush        <= 1'b0;
        gfxdma_flush_pending <= 1'b0;
        chardma_go_pending  <= 1'b0;
        paldma_go_pending   <= 1'b0;
    end else begin
        gfxdma_flush <= 1'b0;
        if(gfxdma_flush_pending) begin
            if(chardma_go) chardma_go_pending <= 1'b1;
            if(paldma_go)  paldma_go_pending  <= 1'b1;
            if(gfxdma_flush_done) begin
                gfxdma_flush_pending <= 1'b0;
                chardma_go_pending   <= 1'b0;
                paldma_go_pending    <= 1'b0;
            end
        end else begin
            if((chardma_go | paldma_go) & !gfxdma_flush_pending) begin
                gfxdma_flush        <= 1'b1;
                gfxdma_flush_pending <= 1'b1;
                chardma_go_pending  <= chardma_go;
                paldma_go_pending   <= paldma_go;
            end
        end
    end
end

/* verilator tracing_on */
jtcps3_sprdma u_dma(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .sprdma_enable( sprdma_enable ),
    .sprdma_go  ( sprdma_go_dma ),
    .gscr0x     ( gscr0x     ),
    .gscr0y     ( gscr0y     ),
    .gscr1x     ( gscr1x     ),
    .gscr1y     ( gscr1y     ),
    .gscr2x     ( gscr2x     ),
    .gscr2y     ( gscr2y     ),
    .gscr3x     ( gscr3x     ),
    .gscr3y     ( gscr3y     ),
    .gscr4x     ( gscr4x     ),
    .gscr4y     ( gscr4y     ),
    .gscr5x     ( gscr5x     ),
    .gscr5y     ( gscr5y     ),
    .gscr6x     ( gscr6x     ),
    .gscr6y     ( gscr6y     ),
    .gscr7x     ( gscr7x     ),
    .gscr7y     ( gscr7y     ),
    .gscr0x_buf ( gscr0x_buf ),
    .gscr0y_buf ( gscr0y_buf ),
    .gscr1x_buf ( gscr1x_buf ),
    .gscr1y_buf ( gscr1y_buf ),
    .gscr2x_buf ( gscr2x_buf ),
    .gscr2y_buf ( gscr2y_buf ),
    .gscr3x_buf ( gscr3x_buf ),
    .gscr3y_buf ( gscr3y_buf ),
    .gscr4x_buf ( gscr4x_buf ),
    .gscr4y_buf ( gscr4y_buf ),
    .gscr5x_buf ( gscr5x_buf ),
    .gscr5y_buf ( gscr5y_buf ),
    .gscr6x_buf ( gscr6x_buf ),
    .gscr6y_buf ( gscr6y_buf ),
    .gscr7x_buf ( gscr7x_buf ),
    .gscr7y_buf ( gscr7y_buf ),
    .scndma_rd  ( scndma_rd  ),
    .scndma_addr( scndma_addr ),
    .scndma_data( scndma_data ),
    .scndma_ok  ( scndma_ok  ),
    .scene_addr ( scene_addr ),
    .scene_din  ( scene_din  ),
    .scene_we   ( scene_we   ),
    .dma_busy   ( sprdma_dma_busy ),
`ifdef SCENE
    .objlim     (             )
`else
    .objlim     ( objlim_scan )
`endif
);

`ifdef SCENE
wire [5:0] nc;
jtframe_16bit_reg #(.SIMFILE("dmast.bin")) u_16reg(
    .rst    ( rst            ),
    .clk    ( clk            ),
    .wr_n   ( 1'b1           ),
    .dsn    ( 2'b11          ),
    .din    ( 16'd0          ),
    .cs     ( 1'd0           ),
    .dout   ({nc,objlim_scan})
);
`endif

`ifdef SPRDMA
assign sprdma = {12'b0, sdmae_init, 2'b0, sdmas_init};
assign sprdma_go = sdmago_init;
reg sdmae_init, sdmas_init, sdmago_init,
    trig_l, start_l, busy_l;
wire trig=scan_busy;
always @(posedge clk) begin
    trig_l  <= trig;
    busy_l  <= sprdma_busy;
    start_l <= sprdma[0];
end
always @(posedge clk) begin
    if(rst) begin
        sdmae_init  <= 0;
        sdmas_init  <= 0;
        sdmago_init <= 0;
    end else if(trig_l & !trig) begin
        sdmae_init  <= 1;
        sdmas_init  <= 1;
        sdmago_init <= 1;
    end else begin
        sdmas_init  <= 0;
        if(start_l) sdmago_init <= 0;
        if(!sprdma_busy & busy_l)
            sdmae_init  <= 0;
    end
end
`endif
/* verilator tracing_on */
jtcps3_paldma u_paldma(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .src        ( paldma_src      ),
    .dst        ( paldma_dst[16:0]),
    .fade       ( paldma_fade     ),
    .len        ( paldma_len      ),
    .len_hi     ( paldma_len_hi   ),
    .go         ( paldma_go_gated ),
    .src_rd     ( palrd_rd        ),
    .src_addr   ( palrd_addr      ),
    .src_dout   ( palrd_data      ),
    .src_ok     ( palrd_ok        ),
    .dst_addr   ( paldma_addr     ),
    .dst_din    ( paldma_din      ),
    .dst_we     ( paldma_we       ),
    .busy       ( paldma_busy     ),
    .done       ( paldma_done     )
);
/* verilator tracing_on */
jtcps3_chardma #(
    .DMA_XOR_K  ( 2'd0 )
) u_chardma(
    .rst            ( rst            ),
    .clk            ( clk            ),
    .chardma_src_lo ( chardma_src_lo ),
    .chardma_src_hi ( chardma_src_hi ),
    .chardma_go     ( chardma_go_gated ),
    .zipchar_ok     ( zipchar_ok     ),
    .zipchar_data   ( zipchar_data   ),
    .zipchar_addr   ( zipchar_addr   ),
    .zipchar_rd     ( zipchar_rd     ),
    .tiles_ok       ( tiles_wr_ok    ),
    .tiles_data     ( tiles_wr_data  ),
    .tiles_rd       ( tiles_wr_rd    ),
    .tiles_addr     ( tiles_wr_addr  ),
    .tiles_we       ( tiles_wr_we    ),
    .tiles_din      ( tiles_wr_din   ),
    .tiles_dsn      ( tiles_wr_dsn   ),
    .busy           ( chardma_busy   ),
    .done           ( chardma_done   )
);

wire [15:0] cpu_little_dout = {cpu_dout[7:0],cpu_dout[15:8]};
wire [ 1:0] cpu_little_we_n = {cpu_we_n[0],  cpu_we_n[1]   };
/* verilator tracing_on */
jtcps3_ppu_mmr #(.SIMFILE("ppureg.bin")) u_ppu_mmr(
    .rst         ( rst             ),
    .clk         ( clk             ),
    .cs          ( ppu_cs          ),
    .addr        ( cpu_addr[7:1]   ),
    .rnw         ( cpu_rnw         ),
    .din         ( cpu_little_dout ),
    .dout        (                 ),
    .dsn         ( cpu_little_we_n ),
    .gscr0x      ( gscr0x          ),
    .gscr0y      ( gscr0y          ),
    .gscr1x      ( gscr1x          ),
    .gscr1y      ( gscr1y          ),
    .gscr2x      ( gscr2x          ),
    .gscr2y      ( gscr2y          ),
    .gscr3x      ( gscr3x          ),
    .gscr3y      ( gscr3y          ),
    .gscr4x      ( gscr4x          ),
    .gscr4y      ( gscr4y          ),
    .gscr5x      ( gscr5x          ),
    .gscr5y      ( gscr5y          ),
    .gscr6x      ( gscr6x          ),
    .gscr6y      ( gscr6y          ),
    .gscr7x      ( gscr7x          ),
    .gscr7y      ( gscr7y          ),
    .tmap0_scrx  ( tmap0_scrx      ),
    .tmap0_scry  ( tmap0_scry      ),
    .tmap0_width ( tmap0_width     ),
    .tmap0_ctrl  ( tmap0_ctrl      ),
    .tmap0_lscr_base( tmap0_lscr_base ),
    .tmap0_tile_base( tmap0_tile_base ),
    .tmap1_scrx  ( tmap1_scrx      ),
    .tmap1_scry  ( tmap1_scry      ),
    .tmap1_width ( tmap1_width     ),
    .tmap1_ctrl  ( tmap1_ctrl      ),
    .tmap1_lscr_base( tmap1_lscr_base ),
    .tmap1_tile_base( tmap1_tile_base ),
    .tmap2_scrx  ( tmap2_scrx      ),
    .tmap2_scry  ( tmap2_scry      ),
    .tmap2_width ( tmap2_width     ),
    .tmap2_ctrl  ( tmap2_ctrl      ),
    .tmap2_lscr_base( tmap2_lscr_base ),
    .tmap2_tile_base( tmap2_tile_base ),
    .tmap3_scrx  ( tmap3_scrx      ),
    .tmap3_scry  ( tmap3_scry      ),
    .tmap3_width ( tmap3_width     ),
    .tmap3_ctrl  ( tmap3_ctrl      ),
    .tmap3_lscr_base( tmap3_lscr_base ),
    .tmap3_tile_base( tmap3_tile_base ),
    .h_sync_width( h_sync_width    ),
    .h_blank_end ( h_blank_end     ),
    .h_screen_end( h_screen_end    ),
    .h_total_end ( h_total_end     ),
    .h_zoom_mstr (                 ),
    .h_zoom_off  (                 ),
    .h_zoom_size ( h_zoom_size     ),
    .h_zoom_scl  ( h_zoom_scl      ),
    .v_sync_end  ( v_sync_end      ),
    .v_blank_end ( v_blank_end     ),
    .v_screen_end( v_screen_end    ),
    .v_total_end ( v_total_end     ),
    .v_zoom_mstr (                 ),
    .v_zoom_off  (                 ),
    .v_zoom_size ( v_zoom_size    ),
    .v_zoom_scl  ( v_zoom_scl      ),
    .pxl_div     ( pxl_div         ),
    .flip        ( ppu_flip        ),
    `ifndef SPRDMA
    .sprdma      ( sprdma          ),
    .sprdma_go   ( sprdma_go       ),
    `else
    .sprdma      (                 ),
    .sprdma_go   (                 ),
    `endif
    .cram_bank   ( cram_bank       ),
    .gfxflash_bank( gfxflash_bank  ),
    .chardma_src_lo( chardma_src_lo ),
    .chardma_src_hi( chardma_src_hi ),
    .chardma_go  ( chardma_go      ),
    .paldma_src  ( paldma_src      ),
    .paldma_dst  ( paldma_dst      ),
    .paldma_fade ( paldma_fade     ),
    .paldma_len  ( paldma_len      ),
    .paldma_len_hi( paldma_len_hi  ),
    .paldma_go   ( paldma_go       ),
    .ioctl_addr  ( {2'd0, ioctl_addr} ),
    .ioctl_din   ( ppu_dump        ),
    .debug_bus   ( debug_bus       ),
    .st_dout     ( st_ppu          )
);
/* verilator tracing_on */
jtcps3_ss_mmr #(
    .SIMFILE("ssreg.bin")
) u_ss_mmr(
    .rst         ( rst          ),
    .clk         ( clk          ),
    .cs          ( ss_cs        ),
    .addr        ( ss_addr      ),
    .rnw         ( cpu_rnw      ),
    .din         ( ss_din       ),
    .dout        (              ), // the CPU cannot read back from SS MMR
    .ss_hscroll  ( ss_hscroll   ),
    .ss_vscroll  ( ss_vscroll   ),
    .ss_pal_base ( ss_pal_base  ),
    .ss_flip     ( ss_flip      ),
    // secondary timing generator unused
    .ss_hsync    (              ),
    .ss_hstart   (              ),
    .ss_hblank   (              ),
    .ss_htotal   (              ),
    .ss_vsync    (              ),
    .ss_vstart   (              ),
    .ss_vblank   (              ),
    .ss_vtotal   (              ),
    .ss_pxl_div  (              ),
    .ioctl_addr  (ioctl_addr[4:0]),
    .ioctl_din   ( ss_dump      ),
    .debug_bus   ( 8'd0         ),
    .st_dout     (              )
);

/* verilator tracing_on */
reg mmr_ok=0;

always @(posedge vs,posedge rst) begin
    if(rst) begin
        mmr_ok <= 0;
    end else begin
        mmr_ok<= h_sync_width!= 0;
    end
end

wire [9:0] eff_vb_end   = mmr_ok  ? v_blank_end   : V_BLANK_END_DFLT,
           eff_vcnt_end = mmr_ok  ? v_screen_end  : V_SCREEN_END_DFLT;
jtcps1_timing u_timing(
    .clk            ( clk               ),
    .cen8           ( pxl_cen           ),

    .vdump          ( cps1_vdump        ),
    .hdump          ( cps1_hdump        ),
    .vrender1       (                   ),
    .vrender        ( game_vrender      ),
    .line_inc       (                   ),
    .line_start     (                   ),
    .frame_start    (                   ),
    .HS             ( hs                ),
    .VS             ( vs                ),
    .VB             ( cps1_vb           ),
    .preVB          (                   ),
    .HB             ( cps1_hb           ),
    .debug_bus      ( debug_bus         )
);

jtcps3_ss u_ss(
    .rst         ( rst          ),
    .clk         ( clk          ),
    .pxl_cen     ( pxl_cen      ),
    .hs          ( hs           ),
    .lhbl        ( lhbl         ),
    .lvbl        ( lvbl         ),
    .hdump       ( hdump        ),
    .vdump       ( vdump        ),
    .h_blank_end ( |h_blank_end ? h_blank_end : H_BLANK_END_DFLT ),
    .v_blank_end ( CPS1_V_BLANK_END ),
    .ss_vscroll  ( ss_vscroll   ),
    .ss_pal_base ( ss_pal_base  ),
    .ss_flip     ( ss_flip      ),
    .sschar_vaddr( sschar_vaddr ),
    .sschar_vdata( sschar_vdata ),
    .ssmap_vaddr ( ssmap_vaddr  ),
    .ssmap_vdata ( ssmap_vdata  ),
    .ssscr_vaddr ( ssscr_vaddr  ),
    .ssscr_vdata ( ssscr_vdata  ),
    .pxl         ( ss_pxl       ),
    .debug_bus   ( debug_bus    )
);

jtcps3_scene u_scene(
    .rst         ( rst            ),
    .clk         ( clk            ),
    .pxl_cen     ( pxl_cen        ),

    .ln_hs       ( ln_hs          ),
    .ln_vs       ( ln_vs          ),
    .ln_lvbl     ( ln_lvbl        ),
    .ln_v        ( ln_v           ),
    .vb_end      ( eff_vb_end     ),
    .vcnt_end    ( eff_vcnt_end   ),
    .objlim      ( objlim_scan    ),
    .v_step      ( v_step         ),
    .scn_vaddr   ( scn_vaddr      ),
    .scn_vdata   ( scn_vdata      ),
    .tiles_rd    ( tiles_rd       ),
    .tiles_addr  ( tiles_addr     ),
    .tiles_data  ( tiles_data     ),
    .tiles_ok    ( tiles_ok       ),
    .scrmap_rd   ( scrmap_rd      ),
    .scrmap_addr ( scrmap_addr    ),
    .scrmap_data ( scrmap_data    ),
    .scrmap_ok   ( scrmap_ok      ),
    .scene_rgb   ( scene_rgb      ),
    .scene_pxl   ( scene_pxl      ),
    .gscr0x      ( gscr0x_buf     ),
    .gscr0y      ( gscr0y_buf     ),
    .gscr1x      ( gscr1x_buf     ),
    .gscr1y      ( gscr1y_buf     ),
    .gscr2x      ( gscr2x_buf     ),
    .gscr2y      ( gscr2y_buf     ),
    .gscr3x      ( gscr3x_buf     ),
    .gscr3y      ( gscr3y_buf     ),
    .gscr4x      ( gscr4x_buf     ),
    .gscr4y      ( gscr4y_buf     ),
    .gscr5x      ( gscr5x_buf     ),
    .gscr5y      ( gscr5y_buf     ),
    .gscr6x      ( gscr6x_buf     ),
    .gscr6y      ( gscr6y_buf     ),
    .gscr7x      ( gscr7x_buf     ),
    .gscr7y      ( gscr7y_buf     ),
    .tmap0_scrx  ( tmap0_scrx     ),
    .tmap0_scry  ( tmap0_scry     ),
    .tmap0_width ( tmap0_width    ),
    .tmap0_ctrl  ( tmap0_ctrl     ),
    .tmap0_lscr_base( tmap0_lscr_base ),
    .tmap0_tile_base( tmap0_tile_base ),
    .tmap1_scrx  ( tmap1_scrx     ),
    .tmap1_scry  ( tmap1_scry     ),
    .tmap1_width ( tmap1_width    ),
    .tmap1_ctrl  ( tmap1_ctrl     ),
    .tmap1_lscr_base( tmap1_lscr_base ),
    .tmap1_tile_base( tmap1_tile_base ),
    .tmap2_scrx  ( tmap2_scrx     ),
    .tmap2_scry  ( tmap2_scry     ),
    .tmap2_width ( tmap2_width    ),
    .tmap2_ctrl  ( tmap2_ctrl     ),
    .tmap2_lscr_base( tmap2_lscr_base ),
    .tmap2_tile_base( tmap2_tile_base ),
    .tmap3_scrx  ( tmap3_scrx     ),
    .tmap3_scry  ( tmap3_scry     ),
    .tmap3_width ( tmap3_width    ),
    .tmap3_ctrl  ( tmap3_ctrl     ),
    .tmap3_lscr_base( tmap3_lscr_base ),
    .tmap3_tile_base( tmap3_tile_base ),
    .flip        ( ppu_flip       ),
    .ln_addr     ( ln_addr        ),
    .ln_data     ( ln_data        ),
    .ln_we       ( ln_we          ),
    .ln_done     ( ln_done        ),
    .scan_busy   ( scan_busy      ),
    .gfx_en      ( gfx_en         )
);

jtcps3_colmix u_colmix(
    .rst         ( rst          ),
    .clk         ( clk          ),
    .pxl_cen     ( pxl_cen      ),
    .lhbl        ( cps1_lhbl_mix ),
    .lvbl        ( lvbl         ),

    .ss_pxl      ( ss_pxl       ),
    .sfb_pxl     ( ln_pxl       ),
    .scene_pxl   ( scene_pxl    ),

    .pal_addr    ( pal_vaddr    ),
    .pal_data    ( pal_vdata    ),
    .scene_rgb   ( scene_rgb    ),

    .red         ( red          ),
    .green       ( green        ),
    .blue        ( blue         ),
    // debug
    .gfx_en      ( gfx_en       )
);

endmodule
