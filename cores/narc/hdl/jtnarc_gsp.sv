/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-10-2026 */

module jtnarc_gsp(
    input             rst,
    input             clk,
    input             lint1_n,
    input             lint2_n,
    output            cyc_req,
    output     [ 3:0] cyc_kind,
    output     [31:0] cyc_addr,
    output     [15:0] cyc_wdata,
    output     [15:0] cyc_io_rdata,
    output            cyc_iaq,
    output     [13:0] cyc_srfaddr,
    output     [15:0] cyc_dpytap,
    output            cyc_org,
    input      [15:0] cyc_rdata,
    input             cyc_ack,
    output            hs,
    output            vs,
    output            hblank,
    output            vblank,
    output     [31:0] pc
);

wire vclk_cen;

jtnarc_vclk u_vclk(
    .rst      ( rst      ),
    .clk      ( clk      ),
    .vclk_cen ( vclk_cen )
);

tms34010_system #(.CLKS_PER_STATE(8),.CYCLE_ACCURATE(1'b1),.VCLK_CEN(1'b1)) u_tms(
    .clk                ( clk          ),
    .vclk_i             ( vclk_cen     ),
    .rst                ( rst          ),
    .vclk_rst_i         ( rst          ),
    .video_hsync_n_i    ( 1'b1         ),
    .video_vsync_n_i    ( 1'b1         ),
    .run_emu_n_i        ( 1'b1         ),
    .emua_n_o           (              ),
    .hcs_n_i            ( 1'b0         ),
    .host_req_i         ( 1'b0         ),
    .host_we_i          ( 1'b0         ),
    .host_reg_i         (              ),
    .host_be_i          ( 2'b00        ),
    .host_wdata_i       ( 16'd0        ),
    .host_rdata_o       (              ),
    .host_ack_o         (              ),
    .host_busy_o        (              ),
    .hint_n_o           (              ),
    .lint1_n_i          ( lint1_n      ),
    .lint2_n_i          ( lint2_n      ),
    .dpyint_set_i       ( 1'b0         ),
    .hold_req_i         ( 1'b0         ),
    .hold_ack_o         (              ),
    .video_hsync_o      ( hs           ),
    .video_vsync_o      ( vs           ),
    .video_hblank_o     ( hblank       ),
    .video_vblank_o     ( vblank       ),
    .video_blank_o      (              ),
    .video_hsync_oe_o   (              ),
    .video_vsync_oe_o   (              ),
    .cycle_req_o        ( cyc_req      ),
    .cycle_kind_o       ( cyc_kind     ),
    .cycle_addr_o       ( cyc_addr     ),
    .cycle_wdata_o      ( cyc_wdata    ),
    .cycle_io_rdata_o   ( cyc_io_rdata ),
    .cycle_iaq_o        ( cyc_iaq      ),
    .cycle_srfaddr_o    ( cyc_srfaddr  ),
    .cycle_dpytap_o     ( cyc_dpytap   ),
    .cycle_screen_org_o ( cyc_org      ),
    .cycle_dram_row_o   (              ),
    .cycle_rdata_i      ( cyc_rdata    ),
    .cycle_ack_i        ( cyc_ack      ),
    .state_o            (              ),
    .pc_o               ( pc           ),
    .instr_word_o       (              ),
    .illegal_opcode_o   (              )
);

endmodule
