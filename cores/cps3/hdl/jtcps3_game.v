/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-2-2026 */

module jtcps3_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [26:0] main_addr;
wire [31:0] cpu_dout;
wire [31:0] cram_data;
wire [31:0] snd_data;
wire [31:0] cps3_key1, cps3_key2;
wire [ 2:0] cps3_crypt_mode;
wire        cps3_region_redearth;
`ifdef CPS3_CPU_TEST
wire [ 2:0] cputest_crypt_mode;
`endif
wire [ 3:0] we_n;
wire        rd_wr_n, bs_n, rd_n;
wire        ram_wait_ok, fram_cs;
wire        cram_cs, ppu_cs, snd_cs, charram_cs, gfxflash_cs;
wire        input_cs, dipsw_cs, eeprom_cs, ssram_cs, ssreg_cs, scsi_cs;
wire        flash2_cs;
wire [17:1] paldma_addr;
wire [15:0] paldma_din;
wire [ 1:0] cpu_pal_we,   paldma_we;
reg  [17:1] cpu_pal_addr_l;
reg  [15:0] cpu_pal_din_l;
reg  [ 1:0] cpu_pal_we_l;
wire        paldma_busy,  paldma_done;
wire        chardma_dma_busy, chardma_dma_done;
wire        chardma_busy, chardma_done, sprdma_busy;
wire [ 2:0] video_dma_busy = { paldma_busy, chardma_busy, sprdma_busy };
wire [ 1:0] video_dma_done = { paldma_done, chardma_done };
wire [ 7:0] st_video;
wire [ 3:0] cram_bank;
wire [15:0] gfxflash_bank;
wire        main_charram_rd, main_charram_we, main_charram_ok;
wire [19:2] main_charram_addr;
wire [31:0] main_charram_din, main_charram_data;
wire [ 3:0] main_charram_dsn;
wire        main_gfxflash_rd, main_gfxflash_ok;
wire [25:2] main_gfxflash_addr;
wire        video_gfxdma_rd, video_gfxdma_ok;
wire [25:2] video_gfxdma_addr;
wire        dma_tiles_rd, dma_tiles_we, dma_tiles_ok;
wire [22:2] dma_tiles_addr;
wire [31:0] dma_tiles_din, dma_tiles_data;
wire [ 3:0] dma_tiles_dsn;
reg         chardma_flush_pending;

localparam [1:0] GFXDMA_NONE  = 2'd0,
                 GFXDMA_CPU   = 2'd1,
                 GFXDMA_VIDEO = 2'd2;

reg  [1:0] gfxdma_owner;
wire       main_gfxflash_req = main_gfxflash_rd;
wire       video_gfxdma_req  = video_gfxdma_rd;
wire       gfxdma_idle       = gfxdma_owner == GFXDMA_NONE && !gfxdma_ok;
wire [1:0] gfxdma_idle_owner = main_gfxflash_req ? GFXDMA_CPU :
                               video_gfxdma_req  ? GFXDMA_VIDEO : GFXDMA_NONE;
wire [1:0] gfxdma_active_owner = gfxdma_owner != GFXDMA_NONE ? gfxdma_owner :
                                 gfxdma_idle ? gfxdma_idle_owner : GFXDMA_NONE;
wire [25:2] gfxdma_user5_addr = gfxdma_active_owner == GFXDMA_CPU   ? main_gfxflash_addr :
                               gfxdma_active_owner == GFXDMA_VIDEO ? video_gfxdma_addr : 24'd0;

assign ioctl_din  = 8'd0;
assign mute       = ~dip_pause;
assign debug_view = st_video;
assign dip_flip   = 1'b0;
`ifdef JTFRAME_LF_BUFFER
assign fb_keep    = 1'b0;
`endif

assign fram_addr   = main_addr[9:1];
assign cpu_dodd    = cpu_dout[7:0];
assign fram_we     = fram_cs & ~rd_wr_n & ~&we_n;
assign cpu_pal_we  = {2{cram_cs}} & ~we_n[1:0];
assign pal_addr    = paldma_busy ? paldma_addr : cpu_pal_addr_l;
assign pal_din     = paldma_busy ? paldma_din  : cpu_pal_din_l;
assign pal_we      = paldma_busy ? paldma_we   : cpu_pal_we_l;

assign cram_data   = { 16'd0, pal_dout };
assign gfxdma_rd   = gfxdma_active_owner == GFXDMA_CPU   ? main_gfxflash_rd  :
                     gfxdma_active_owner == GFXDMA_VIDEO ? video_gfxdma_rd   : 1'b0;
// Physical map: SIMM3–5 occupy 16–64 MiB, SIMM2 occupies 64–80 MiB,
// and SIMM6 follows at 80–96 MiB. All requesters use contiguous m_user5.
assign gfxdma_addr = 25'h0400000 + { 1'b0, gfxdma_user5_addr } +
                     (gfxdma_user5_addr[25:22] >= 4'd12 ? 25'h0400000 : 25'd0);
assign main_gfxflash_ok = gfxdma_owner == GFXDMA_CPU   && gfxdma_ok;
assign video_gfxdma_ok  = gfxdma_owner == GFXDMA_VIDEO && gfxdma_ok;
// gfxdma write port — read-only in practice, tied inactive
assign gfxdma_we      = 1'b0;
assign gfxdma_din     = 32'd0;
assign gfxdma_dsn     = 4'hf;
assign tiles_wr_flush = chardma_dma_done;
assign chardma_busy   = chardma_dma_busy | chardma_flush_pending | tiles_wr_flushing;
assign chardma_done   = (chardma_flush_pending | chardma_dma_done) & tiles_wr_flush_done;

always @(posedge clk) begin
    if (rst) begin
        cpu_pal_addr_l <= 17'd0;
        cpu_pal_din_l  <= 16'd0;
        cpu_pal_we_l   <= 2'd0;
    end else begin
        cpu_pal_addr_l <= main_addr[17:1];
        cpu_pal_din_l  <= cpu_dout[15:0];
        cpu_pal_we_l   <= cpu_pal_we;
    end
end

always @(posedge clk) begin
    if (rst) begin
        gfxdma_owner <= GFXDMA_NONE;
    end else begin
        if (gfxdma_owner == GFXDMA_NONE && !gfxdma_ok) begin
            gfxdma_owner <= gfxdma_idle_owner;
        end else if (gfxdma_ok) begin
            gfxdma_owner <= GFXDMA_NONE;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        chardma_flush_pending <= 1'b0;
    end else begin
        if (tiles_wr_flush_done) begin
            chardma_flush_pending <= 1'b0;
        end else if (chardma_dma_done) begin
            chardma_flush_pending <= 1'b1;
        end
    end
end

/* verilator tracing_on */
jtcps3_keyload u_keyload(
    .clk            ( clk               ),
    .header         ( header            ),
    .prog_we        ( prog_we           ),
    .prog_addr      ( prog_addr[4:0]    ),
    .prog_data      ( prog_data         ),
`ifdef CPS3_CPU_TEST
    .cputest_crypt_mode ( cputest_crypt_mode ),
`endif
    .cps3_key1             ( cps3_key1             ),
    .cps3_key2             ( cps3_key2             ),
    .cps3_crypt_mode       ( cps3_crypt_mode       ),
    .cps3_region_redearth  ( cps3_region_redearth  )
);

/* verilator tracing_on */
jtcps3_main u_main(
    .clk            ( clk               ),
    .clk48          ( clk48             ),
    .rst            ( rst               ),
    .rst48          ( rst48             ),
    .cen_r          ( cen_r             ),
    .cps3_key1            ( cps3_key1             ),
    .cps3_key2            ( cps3_key2             ),
    .cps3_crypt_mode      ( cps3_crypt_mode       ),
    .cps3_region          ( dipsw[2:0]            ),
    .cps3_region_redearth ( cps3_region_redearth  ),
    .A              ( main_addr         ),
    .cpu_dout       ( cpu_dout          ),
    .wr_n           ( rd_wr_n           ),
    .we_n           ( we_n              ),
    .bs_n           ( bs_n              ),
    .rd_n           ( rd_n              ),
    .fram_cs        ( fram_cs           ),
    .fram_dout      ( fram_dout         ),
    .cram_cs        ( cram_cs           ),
    .cram_data      ( cram_data         ),
    .ppu_cs         ( ppu_cs            ),
    .snd_cs         ( snd_cs            ),
    .snd_data       ( snd_data          ),
    .charram_cs     ( charram_cs        ),
    .charram_rd     ( main_charram_rd   ),
    .charram_we     ( main_charram_we   ),
    .charram_addr   ( main_charram_addr ),
    .charram_din    ( main_charram_din  ),
    .charram_dsn    ( main_charram_dsn  ),
    .charram_data   ( main_charram_data ),
    .charram_ok     ( main_charram_ok   ),
    .gfxflash_cs    ( gfxflash_cs       ),
    .gfxflash_bank  ( gfxflash_bank     ),
    .gfxflash_rd    ( main_gfxflash_rd  ),
    .gfxflash_addr  ( main_gfxflash_addr),
    .gfxflash_data  ( gfxdma_data       ),
    .gfxflash_ok    ( main_gfxflash_ok  ),
    .input_cs       ( input_cs          ),
    .cab_1p         ( cab_1p            ),
    .coin           ( coin              ),
    .joystick1      ( joystick1         ),
    .joystick2      ( joystick2         ),
    .service        ( service           ),
    .dip_pause      ( dip_pause         ),
    .dip_test       ( dip_test          ),
    .dipsw_cs       ( dipsw_cs          ),
    .eeprom_cs      ( eeprom_cs         ),
    .eeprom_addr    ( eeprom_addr       ),
    .eeprom_din     ( eeprom_din        ),
    .eeprom_we      ( eeprom_we         ),
    .eeprom_dout    ( eeprom_dout       ),
    .ssram_cs       ( ssram_cs          ),
    .ssreg_cs       ( ssreg_cs          ),
    .scsi_cs        ( scsi_cs           ),
    .flash2_cs      ( flash2_cs         ),
    .sschar_addr    ( sschar_addr       ),
    .sschar_din     ( sschar_din        ),
    .sschar_dout    ( sschar_dout       ),
    .sschar_we      ( sschar_we         ),
    .ssmap_addr     ( ssmap_addr        ),
    .ssmap_din      ( ssmap_din         ),
    .ssmap_dout     ( ssmap_dout        ),
    .ssmap_we       ( ssmap_we          ),
    .ssscr_addr     ( ssscr_addr        ),
    .ssscr_din      ( ssscr_din         ),
    .ssscr_dout     ( ssscr_dout        ),
    .ssscr_we       ( ssscr_we          ),
    .lvbl           ( LVBL              ),
    .dma_busy       ( video_dma_busy    ),
    .dma_done       ( video_dma_done    ),
    .cpuba0_addr    ( cpuba0_addr       ),
    .cpuba0_rd      ( cpuba0_rd         ),
    .cpuba0_data    ( cpuba0_data       ),
    .cpuba0_ok      ( cpuba0_ok         ),
    .cpuba0_we      ( cpuba0_we         ),
    .cpuba0_din     ( cpuba0_din        ),
    .cpuba0_dsn     ( cpuba0_dsn        ),
    .simm2_addr     ( simm2_addr        ),
    .simm2_rd       ( simm2_rd          ),
    .simm2_data     ( simm2_data        ),
    .simm2_ok       ( simm2_ok          ),
    .simm2_we       ( simm2_we          ),
    .simm2_din      ( simm2_din         ),
    .simm2_dsn      ( simm2_dsn         )
`ifdef CPS3_CPU_TEST
    , .cputest_crypt_mode ( cputest_crypt_mode )
`endif
);

/* verilator tracing_off */
jtcps3_sound u_sound(
    .rst        ( rst48         ),
    .clk        ( clk48         ),
    .cen        ( pcm_cen       ),
    .snd_cs     ( snd_cs        ),
    .cpu_addr   ( main_addr[9:1]),
    .cpu_dout   ( cpu_dout      ),
    .cpu_rnw    ( rd_wr_n       ),
    .cpu_we_n   ( we_n          ),
    .cpu_din    ( snd_data      ),
    .rom_cs     ( pcm_rd        ),
    .rom_addr   ( pcm_addr      ),
    .rom_data   ( pcm_data      ),
    .rom_ok     ( pcm_ok        ),
    .snd_left   ( snd_l         ),
    .snd_right  ( snd_r         )
);

/* verilator tracing_off */
jtcps3_video u_video(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .std_cen        ( std_cen       ),
    .std2_cen       ( std2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),
    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .game_vrender   ( game_vrender  ),
    .game_hdump     ( game_hdump    ),
    .ln_addr        ( ln_addr       ),
    .ln_data        ( ln_data       ),
    .ln_done        ( ln_done       ),
    .ln_we          ( ln_we         ),
    .ln_hs          ( ln_hs         ),
    .ln_vs          ( ln_vs         ),
    .ln_lvbl        ( ln_lvbl       ),
    .ln_pxl         ( ln_pxl        ),
    .ln_v           ( ln_v          ),
    // CPU interface
    .ppu_cs         ( ppu_cs        ),
    .ssreg_cs       ( ssreg_cs      ),
    .cpu_addr       ( main_addr[8:1]),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( rd_wr_n       ),
    .cpu_we_n       ( we_n          ),
    .cram_bank      ( cram_bank     ),
    .gfxflash_bank  ( gfxflash_bank ),
    // Scene DMA
    .scndma_rd      ( scndma_rd     ),
    .scndma_addr    ( scndma_addr   ),
    .scndma_data    ( scndma_data   ),
    .scndma_ok      ( scndma_ok     ),
    .cpuba0_flush   ( cpuba0_flush  ),
    .cpuba0_flushing( cpuba0_flushing ),
    .cpuba0_flush_done( cpuba0_flush_done ),
    .gfxdma_flush   ( gfxdma_flush   ),
    .gfxdma_flushing( gfxdma_flushing ),
    .gfxdma_flush_done( gfxdma_flush_done ),
    .scene_dout     ( scene_dout    ),
    .scene_din      ( scene_din     ),
    .scene_addr     ( scene_addr    ),
    .scene_we       ( scene_we      ),
    .sprdma_busy    ( sprdma_busy   ),
    // scene/tile memories
    .scn_vaddr      ( scn_vaddr     ),
    .scn_vdata      ( scn_vdata     ),
    .tiles_rd       ( tiles_rd      ),
    .tiles_addr     ( tiles_addr    ),
    .tiles_data     ( tiles_data    ),
    .tiles_ok       ( tiles_ok      ),
    .gfxdma_rd      ( video_gfxdma_rd   ),
    .gfxdma_addr    ( video_gfxdma_addr ),
    .gfxdma_data    ( gfxdma_data   ),
    .gfxdma_ok      ( video_gfxdma_ok   ),
    .tiles_wr_rd    ( dma_tiles_rd  ),
    .tiles_wr_addr  ( dma_tiles_addr),
    .tiles_wr_we    ( dma_tiles_we  ),
    .tiles_wr_din   ( dma_tiles_din ),
    .tiles_wr_dsn   ( dma_tiles_dsn ),
    .tiles_wr_data  ( dma_tiles_data),
    .tiles_wr_ok    ( dma_tiles_ok  ),
    .chardma_busy   ( chardma_dma_busy ),
    .chardma_done   ( chardma_dma_done ),
    .scrmap_rd      ( scrmap_rd     ),
    .scrmap_addr    ( scrmap_addr   ),
    .scrmap_data    ( scrmap_data   ),
    .scrmap_ok      ( scrmap_ok     ),
    // SS Layer
    .sschar_vaddr   ( sschar_vaddr  ),
    .sschar_vdata   ( sschar_vdata  ),
    .ssmap_vaddr    ( ssmap_vaddr   ),
    .ssmap_vdata    ( ssmap_vdata   ),
    .ssscr_vaddr    ( ssscr_vaddr   ),
    .ssscr_vdata    ( ssscr_vdata   ),
    .paldma_addr    ( paldma_addr   ),
    .paldma_din     ( paldma_din    ),
    .paldma_we      ( paldma_we     ),
    .paldma_busy    ( paldma_busy   ),
    .paldma_done    ( paldma_done   ),
    .pal_vaddr      ( pal_vaddr     ),
    .pal_vdata      ( pal_vdata     ),
    .h_step         ( h_step        ),
    .v_step         ( v_step        ),
    // color
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // debug
    .gfx_en         ( gfx_en        ),
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_video      ),
    .ioctl_addr     (ioctl_addr[5:0]),
    .ioctl_din      (               )
);

`ifdef SIMULATION
always @(posedge clk) begin
    if(!rst && sprdma_busy && cpuba0_addr[23:19] == 5'h11 && (cpuba0_rd || cpuba0_we)) begin
        $display("ERROR: CPU %s bank-0 sprite RAM during scene DMA addr=%h cpuba0_addr=%h sprdma_busy=%b cpuba0_flush=%b cpuba0_flushing=%b cpuba0_flush_done=%b",
            cpuba0_we ? "write" : "read",
            main_addr, cpuba0_addr, sprdma_busy, cpuba0_flush, cpuba0_flushing, cpuba0_flush_done);
        $finish;
    end
end
`ifdef CPS3_CPU_TEST_SPRDMA_OBSERVER
    `include "cpu_test_sprdma_observer.vh"
`endif
`endif

jtcps3_busmux u_busmux(
    .rst                ( rst               ),
    .clk                ( clk               ),
    .cram_bank          ( cram_bank[2:0]    ),
    .main_charram_rd    ( main_charram_rd   ),
    .main_charram_we    ( main_charram_we   ),
    .main_charram_addr  ( main_charram_addr ),
    .main_charram_din   ( main_charram_din  ),
    .main_charram_dsn   ( main_charram_dsn  ),
    .main_charram_data  ( main_charram_data ),
    .main_charram_ok    ( main_charram_ok   ),
    .main_grant         (                   ),
    .dma_tiles_rd       ( dma_tiles_rd      ),
    .dma_tiles_we       ( dma_tiles_we      ),
    .dma_tiles_addr     ( dma_tiles_addr    ),
    .dma_tiles_din      ( dma_tiles_din     ),
    .dma_tiles_dsn      ( dma_tiles_dsn     ),
    .dma_tiles_data     ( dma_tiles_data    ),
    .dma_tiles_ok       ( dma_tiles_ok      ),
    .dma_grant          (                   ),
    .tiles_wr_rd        ( tiles_wr_rd       ),
    .tiles_wr_addr      ( tiles_wr_addr     ),
    .tiles_wr_we        ( tiles_wr_we       ),
    .tiles_wr_din       ( tiles_wr_din      ),
    .tiles_wr_dsn       ( tiles_wr_dsn      ),
    .tiles_wr_data      ( tiles_wr_data     ),
    .tiles_wr_ok        ( tiles_wr_ok       )
);

endmodule
