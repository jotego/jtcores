/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-10-2026 */

module jtnarc_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        gsp_hs, gsp_vs, gsp_hb, gsp_vb, line_load;
wire [18:0] line_pstart;
wire [12:0] pxl;
wire        blank;
wire [31:0] gsp_pc;
wire [19:4] vcpu_addr, scan_addr, vrow_addr;
wire[127:0] vcpu_din, vcpu_data, scan_data, vrow_data;
wire [15:0] vcpu_dsn;
wire        vcpu_rd, vcpu_we, vcpu_ok, vcpu_flush, vcpu_flush_done;
wire        scan_rd, scan_ok, vrow_rd, vrow_ok, scan_fetch;
wire [19:4] scan_lstart;
wire [15:0] snd_latch;
wire [ 7:0] tb_data;
wire        tb_ack_n;
wire signed [15:0] cvsd;

assign pxl2_cen    = cen32;
assign pxl_cen     = cen16;
assign ioctl_din   = 0;
assign ex          = fm_r;
assign cv          = cvsd;
assign debug_view  = gsp_pc[11:4];
assign dip_flip    = 0;

jtnarc_main u_main(
    .rst             ( rst             ),
    .clk             ( clk             ),
    .rst48           ( rst48           ),
    .clk48           ( clk48           ),
    .pgm_addr        ( pgm_addr        ),
    .pgm_rd          ( pgm_rd          ),
    .pgm_data        ( pgm_data        ),
    .pgm_ok          ( pgm_ok          ),
    .gfx_addr        ( gfx_addr        ),
    .gfx_rd          ( gfx_rd          ),
    .gfx_data        ( gfx_data        ),
    .gfx_ok          ( gfx_ok          ),
    .vcpu_addr       ( vcpu_addr       ),
    .vcpu_rd         ( vcpu_rd         ),
    .vcpu_we         ( vcpu_we         ),
    .vcpu_din        ( vcpu_din        ),
    .vcpu_dsn        ( vcpu_dsn        ),
    .vcpu_data       ( vcpu_data       ),
    .vcpu_ok         ( vcpu_ok         ),
    .vcpu_flush      ( vcpu_flush      ),
    .vcpu_flush_done ( vcpu_flush_done ),
    .vrow_addr       ( vrow_addr       ),
    .vrow_rd         ( vrow_rd         ),
    .vrow_data       ( vrow_data       ),
    .vrow_ok         ( vrow_ok         ),
    .scratch_addr    ( scratch_addr    ),
    .scratch_din     ( scratch_din     ),
    .scratch_we      ( scratch_we      ),
    .scratch_dout    ( scratch_dout    ),
    .colram_addr     ( colram_addr     ),
    .colram_din      ( colram_din      ),
    .colram_we       ( colram_we       ),
    .colram_dout     ( colram_dout     ),
    .cmos_addr       ( cmos_addr       ),
    .cmos_din        ( cmos_din        ),
    .cmos_we         ( cmos_we         ),
    .cmos_dout       ( cmos_dout       ),
    .joystick1       ( joystick1       ),
    .joystick2       ( joystick2       ),
    .coin            ( coin            ),
    .cab_1p          ( cab_1p          ),
    .dip_test        ( dip_test        ),
    .tilt            ( tilt            ),
    .snd_latch       ( snd_latch       ),
    .tb_data         ( tb_data         ),
    .tb_ack_n        ( tb_ack_n        ),
    .line_load       ( line_load       ),
    .line_pstart     ( line_pstart     ),
    .hs              ( gsp_hs          ),
    .vs              ( gsp_vs          ),
    .hblank          ( gsp_hb          ),
    .vblank          ( gsp_vb          ),
    .pc              ( gsp_pc          )
);

jtnarc_ddr u_ddr(
    .rst             ( rst             ),
    .clk             ( clk             ),
    .vcpu_addr       ( vcpu_addr       ),
    .vcpu_rd         ( vcpu_rd         ),
    .vcpu_we         ( vcpu_we         ),
    .vcpu_din        ( vcpu_din        ),
    .vcpu_dsn        ( vcpu_dsn        ),
    .vcpu_data       ( vcpu_data       ),
    .vcpu_ok         ( vcpu_ok         ),
    .vcpu_flush      ( vcpu_flush      ),
    .vcpu_flush_done ( vcpu_flush_done ),
    .scan_addr       ( scan_addr       ),
    .scan_rd         ( scan_rd         ),
    .scan_fetch      ( scan_fetch      ),
    .scan_lstart     ( scan_lstart     ),
    .scan_data       ( scan_data       ),
    .scan_ok         ( scan_ok         ),
    .vrow_addr       ( vrow_addr       ),
    .vrow_rd         ( vrow_rd         ),
    .vrow_data       ( vrow_data       ),
    .vrow_ok         ( vrow_ok         ),
    .ddr_burstcnt    ( ddr_burstcnt    ),
    .ddr_addr        ( ddr_addr        ),
    .ddr_rd          ( ddr_rd          ),
    .ddr_we          ( ddr_we          ),
    .ddr_be          ( ddr_be          ),
    .ddr_din         ( ddr_din         ),
    .ddr_busy        ( ddr_busy        ),
    .ddr_dout        ( ddr_dout        ),
    .ddr_dout_ready  ( ddr_dout_ready  )
);

jtnarc_video u_video(
    .rst         ( rst         ),
    .clk         ( clk         ),
    .pxl_cen     ( pxl_cen     ),
    .gsp_hs      ( gsp_hs      ),
    .gsp_vs      ( gsp_vs      ),
    .gsp_hb      ( gsp_hb      ),
    .gsp_vb      ( gsp_vb      ),
    .line_load   ( line_load   ),
    .line_start  ( line_pstart ),
    .scan_addr   ( scan_addr   ),
    .scan_rd     ( scan_rd     ),
    .scan_fetch  ( scan_fetch  ),
    .scan_lstart ( scan_lstart ),
    .scan_data   ( scan_data   ),
    .scan_ok     ( scan_ok     ),
    .pxl         ( pxl         ),
    .blank       ( blank       ),
    .HS          ( HS          ),
    .VS          ( VS          ),
    .LHBL        ( LHBL        ),
    .LVBL        ( LVBL        )
);

jtnarc_colmix u_colmix(
    .rst         ( rst         ),
    .clk         ( clk         ),
    .pxl_cen     ( pxl_cen     ),
    .gfx_en      ( gfx_en      ),
    .pxl         ( pxl         ),
    .blank       ( blank       ),
    .colvid_addr ( colvid_addr ),
    .colvid_dout ( colvid_dout ),
    .red         ( red         ),
    .green       ( green       ),
    .blue        ( blue        )
);

jtnarc_sound u_sound(
    .rst       ( rst24     ),
    .clk       ( clk24     ),
    .cen8      ( cen8      ),
    .cen_fm    ( cen_fm    ),
    .cen_fm2   ( cen_fm2   ),
    .cen192    ( cen192    ),
    .rst_rom   ( rst       ),
    .clk_rom   ( clk       ),
    .snd_latch ( snd_latch ),
    .tb_data   ( tb_data   ),
    .tb_ack_n  ( tb_ack_n  ),
    .mrom_addr ( snd_addr  ),
    .mrom_rd   ( snd_rd    ),
    .mrom_data ( snd_data  ),
    .mrom_ok   ( snd_ok    ),
    .srom_addr ( snds_addr ),
    .srom_rd   ( snds_rd   ),
    .srom_data ( snds_data ),
    .srom_ok   ( snds_ok   ),
    .fm_l      ( fm_l      ),
    .fm_r      ( fm_r      ),
    .dac_m     ( dacm      ),
    .dac_s     ( dacs      ),
    .cvsd      ( cvsd      )
);

endmodule
