/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2022 */

// Frame buffer built on top of two line buffers
/* verilator lint_off MODDUP */
// This module is not fully tested yet
module jtframe_lfbuf_ddr #(parameter
    DW      =  16,
    VW      =   8,
    HW      =   9,
    FW      =   8
)(
    input               rst,     // hold in reset for >150 us
    input               clk,
    input               pxl_cen,

    // video status
    input      [VW-1:0] vrender,
    input      [HW-1:0] hdump,
    input               hs, vs,
    input               lhbl,
    input               lvbl,

    // zoom step in 1.FW fixed-point
    input      [FW:0]   h_step,
    input      [FW:0]   v_step,

    // core interface
    input      [HW-1:0] ln_addr,
    input      [DW-1:0] ln_data,
    input               ln_done,
    input               ln_we,
    input               fb_keep,
    output              ln_hs, ln_vs, ln_lvbl,
    output     [DW-1:0] ln_dout,
    output     [DW-1:0] ln_pxl,
    output     [VW-1:0] ln_v,

    // DDR3 RAM
    output              ddram_clk,
    input               ddram_busy,
    output      [7:0]   ddram_burstcnt,
    output     [28:0]   ddram_addr,
    input      [63:0]   ddram_dout,
    input               ddram_dout_ready,
    output              ddram_rd,
    output     [63:0]   ddram_din,
    output      [7:0]   ddram_be,
    output              ddram_we,
    // Status
    input       [7:0]   st_addr,
    output      [7:0]   st_dout
);

wire          frame, fb_clr, fb_done, line, scr_we, fb_blank;
wire [HW-1:0] fb_addr, rd_addr;
wire [  15:0] fb_din, fb_dout;
wire [VW-1:0] vread;

jtframe_lfbuf_ddr_ctrl #(.HW(HW),.VW(VW)) u_ctrl (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .lhbl       ( lhbl      ),
    .vs         ( vs        ),
    .ln_done    ( ln_done   ),
    .fb_keep    ( fb_keep   ),
    .vrender    ( vread     ),
    .ln_v       ( ln_v      ),
    // data written to external memory
    .frame      ( frame     ),
    .fb_blank   ( fb_blank  ),
    .fb_addr    ( fb_addr   ),
    .rd_addr    ( rd_addr   ),
    .fb_din     ( fb_din    ),
    .fb_dout    ( fb_dout   ),
    .fb_clr     ( fb_clr    ),
    .fb_done    ( fb_done   ),

    // data read from external memory to screen buffer
    // during h blank
    .line       ( line      ),
    .scr_we     ( scr_we    ),

    .ddram_clk  ( ddram_clk     ),
    .ddram_busy ( ddram_busy    ),
    .ddram_addr ( ddram_addr    ),
    .ddram_dout ( ddram_dout    ),
    .ddram_rd   ( ddram_rd      ),
    .ddram_din  ( ddram_din     ),
    .ddram_be   ( ddram_be      ),
    .ddram_we   ( ddram_we      ),
    .ddram_burstcnt  ( ddram_burstcnt    ),
    .ddram_dout_ready( ddram_dout_ready  ),
    .st_addr    ( st_addr       ),
    .st_dout    ( st_dout       )
);

jtframe_lfbuf_line #(.DW(DW),.HW(HW),.VW(VW)) u_line(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_ctrl   ( clk       ),
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
    .ln_vs      ( ln_vs     ),
    .ln_lvbl    ( ln_lvbl   ),
    .ln_v       ( ln_v      ),
    .ln_addr    ( ln_addr   ),
    .ln_data    ( ln_data   ),
    .ln_we      ( ln_we     ),
    .ln_dout    ( ln_dout   ),
    .ln_pxl     ( ln_pxl    ),

    // data written to external memory
    .frame      ( frame     ),
    .fb_addr    ( fb_addr   ),
    .rd_addr    ( rd_addr   ),
    .fb_din     ( fb_din    ),
    .fb_dout    ( fb_dout   ),
    .fb_clr     ( fb_clr    ),
    .fb_done    ( fb_done   ),
    .fb_blank   ( fb_blank  ),

    // data read from external memory to screen buffer
    // during h blank
    .line       ( line      ),
    .scr_we     ( scr_we    )
);

endmodule
