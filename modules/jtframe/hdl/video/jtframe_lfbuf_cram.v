/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2022 */

// Frame buffer built on top of two line buffers
// the frame is stored in two PSRAM chips

// clk and clk96 must be related PLL clocks; clk is clk48 or clk96.
module jtframe_lfbuf_cram #(parameter
    DW      =  16,
    VW      =   8,
    HW      =   9,
    FW      =   8
)(
    input               rst,     // hold in reset for >150 us
    input               clk,
    input               clk96,
    input               pxl_cen,

    // video status
    input      [VW-1:0] vrender,
    input      [HW-1:0] hdump,
    input               hs,
    input               vs,
    input               lhbl,
    input               lvbl,

    // zoom step in 1.FW fixed-point
    input      [FW:0]   h_step,
    input      [FW:0]   v_step,

    // core interface
    input      [HW-1:0] ln_addr,
    input      [DW-1:0] ln_data,
    input               ln_done,
    input               fb_keep,
    output              ln_hs, ln_vs, ln_lvbl,
    output     [DW-1:0] ln_dout,
    output     [DW-1:0] ln_pxl,
    output     [VW-1:0] ln_v,
    input               ln_we,

    // PSRAM chip
    output     [ 21:16] cr_addr,
    inout      [  15:0] cr_adq,
    output              cr_advn,
    output     [   1:0] cr_cen,
    output              cr_clk,
    output              cr_cre,
    output     [   1:0] cr_dsn,
    output              cr_oen,
    input               cr_wait,
    output              cr_wen
);

wire          frame, fb_clr, fb_done, line, scr_we, fb_blank, pxl96_cen;
wire          fb_done96;
reg           pxl_toggle, pxl_l, done_toggle, done_l;
wire [HW-1:0] fb_addr, rd_addr;
wire [  15:0] fb_din, fb_dout;
wire [VW-1:0] vread;

// Preserve events across both supported PLL ratios. In particular, a single
// clk96 completion pulse may fall entirely between two clk48 rising edges.
// These related-clock paths remain timed by STA.
assign pxl96_cen = pxl_toggle ^ pxl_l;
assign fb_done   = done_toggle ^ done_l;

always @(posedge clk) begin
    if( rst ) begin
        pxl_toggle <= 0;
        done_l     <= 0;
    end else begin
        if( pxl_cen ) pxl_toggle <= ~pxl_toggle;
        done_l <= done_toggle;
    end
end

always @(posedge clk96) begin
    if( rst ) begin
        pxl_l       <= 0;
        done_toggle <= 0;
    end else begin
        pxl_l <= pxl_toggle;
        if( fb_done96 ) done_toggle <= ~done_toggle;
    end
end

jtframe_lfbuf_ctrl #(.CLK96(1),.HW(HW),.VW(VW)) u_ctrl (
    .rst        ( rst       ),
    .clk        ( clk96     ),
    .pxl_cen    ( pxl96_cen ),

    .lhbl       ( lhbl      ),
    .vs         ( vs        ),
    .ln_done    ( ln_done   ),
    .fb_keep    ( fb_keep   ),
    .vrender    ( vrender   ),
    .ln_v       ( ln_v      ),
    // data written to external memory
    .frame      ( frame     ),
    .fb_blank   ( fb_blank  ),
    .fb_addr    ( fb_addr   ),
    .rd_addr    ( rd_addr   ),
    .fb_din     ( fb_din    ),
    .fb_dout    ( fb_dout   ),
    .fb_clr     ( fb_clr    ),
    .fb_done    ( fb_done96 ),

    // data read from external memory to screen buffer
    // during h blank
    .line       ( line      ),
    .scr_we     ( scr_we    ),

    // cell RAM (PSRAM) signals
    .cr_addr    ( cr_addr   ),
    .cr_adq     ( cr_adq    ),
    .cr_wait    ( cr_wait   ),
    .cr_clk     ( cr_clk    ),
    .cr_advn    ( cr_advn   ),
    .cr_cre     ( cr_cre    ),
    .cr_cen     ( cr_cen    ),
    .cr_oen     ( cr_oen    ),
    .cr_wen     ( cr_wen    ),
    .cr_dsn     ( cr_dsn    )
);

jtframe_lfbuf_line #(.DW(DW),.HW(HW),.VW(VW)) u_line(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_ctrl   ( clk96     ),
    .pxl_cen    ( pxl_cen   ),
    // video status
    .vrender    ( vrender   ),
    .vread      ( vread     ),
    .hdump      ( hdump     ),
    .hs         ( hs        ),
    .lhbl       ( lhbl      ),
    .vs         ( vs        ),   // vertical sync, the buffer is swapped here
    .lvbl       ( lvbl      ),   // vertical blank, active low

    // zoom step
    .h_step     ( h_step    ),
    .v_step     ( v_step    ),

    // core interface
    .ln_hs      ( ln_hs     ),
    .ln_v       ( ln_v      ),
    .ln_vs      ( ln_vs     ),
    .ln_lvbl    ( ln_lvbl   ),
    .ln_addr    ( ln_addr   ),
    .ln_data    ( ln_data   ),
    .ln_we      ( ln_we     ),
    .ln_dout    ( ln_dout   ),
    .ln_pxl     ( ln_pxl    ),

    // data written to external memory
    .frame      ( frame     ),
    .fb_blank   ( fb_blank  ),
    .fb_addr    ( fb_addr   ),
    .rd_addr    ( rd_addr   ),
    .fb_din     ( fb_din    ),
    .fb_dout    ( fb_dout   ),
    .fb_clr     ( fb_clr    ),
    .fb_done    ( fb_done   ),
    .fb_busy    ( 1'b0      ),

    // data read from external memory to screen buffer
    // during h blank
    .line       ( line      ),
    .scr_we     ( scr_we    )
);

endmodule
