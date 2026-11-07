/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-10-2026 */

module jtnarc_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             gsp_hs,
    input             gsp_vs,
    input             gsp_hb,
    input             gsp_vb,
    input             line_load,
    input      [18:0] line_start,
    output reg [19:4] scan_addr,
    output reg        scan_rd,
    output            scan_fetch,
    output     [19:4] scan_lstart,
    input     [127:0] scan_data,
    input             scan_ok,
    output     [12:0] pxl,
    output            blank,
    output reg        HS,
    output reg        VS,
    output reg        LHBL,
    output reg        LVBL
);

reg  [1:0] hs_s, vs_s, hb_s, vb_s;
reg        wbuf, rbuf, fetching, hb_l;
reg  [6:0] wcnt;
reg  [8:0] rcnt;
reg  [2:0] loff, roff;
reg        hs_d, vs_d, hb_d, vb_d;
reg        gsp_on, vcen_n=0;
wire       t_hs, t_vs, t_lhbl, t_lvbl;
wire [127:0] lb_w;
wire [  9:0] rpx  = { 1'b0, rcnt } + { 7'd0, roff };
wire [ 15:0] lb_q = lb_w[ {rpx[2:0],4'd0} +: 16 ];

assign pxl         = lb_q[12:0];
assign blank       = !gsp_on || hb_d || vb_d;

assign scan_fetch  = fetching | line_load;
assign scan_lstart = line_start[18:3];

always @(posedge clk) begin
    hs_s <= { hs_s[0], gsp_hs };
    vs_s <= { vs_s[0], gsp_vs };
    hb_s <= { hb_s[0], gsp_hb };
    vb_s <= { vb_s[0], gsp_vb };
end

always @(posedge clk) begin
    if( rst ) begin
        wbuf      <= 0;
        fetching  <= 0;
        wcnt      <= 0;
        loff      <= 0;
        scan_rd   <= 0;
        scan_addr <= 0;
    end else begin
        if( line_load ) begin
            wbuf      <= ~wbuf;
            fetching  <= 1;
            wcnt      <= 0;
            loff      <= line_start[2:0];
            scan_addr <= line_start[18:3];
            scan_rd   <= 1;
        end else if( fetching ) begin
            if( scan_rd && scan_ok ) begin
                scan_rd   <= 0;
                wcnt      <= wcnt+7'd1;
                scan_addr <= scan_addr+16'd1;
                if( wcnt==( loff==0 ? 7'd63 : 7'd64 ) ) fetching <= 0;
            end else begin
                scan_rd <= 1;
            end
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        rbuf <= 0;
        roff <= 0;
        rcnt <= 0;
        hb_l <= 1;
        { hs_d, vs_d, hb_d, vb_d } <= 0;
        { HS, VS, LHBL, LVBL } <= { t_hs, t_vs, t_lhbl, t_lvbl };
        gsp_on <= 0;
    end else if( pxl_cen ) begin
        if( vs_s[1] && !vs_d ) gsp_on <= 1;
        hb_l <= hb_s[1];
        if( hb_l && !hb_s[1] ) begin
            rbuf <= wbuf;
            roff <= loff;
            rcnt <= 0;
        end else if( !hb_s[1] ) begin
            rcnt <= rcnt+9'd1;
        end
        hs_d <= hs_s[1];
        vs_d <= vs_s[1];
        hb_d <= hb_s[1];
        vb_d <= vb_s[1];
        HS   <= gsp_on ? hs_d : t_hs;
        VS   <= gsp_on ? vs_d : t_vs;
        LHBL <= gsp_on ? ~hb_d : t_lhbl;
        LVBL <= gsp_on ? ~vb_d : t_lvbl;
    end
end

always @(posedge clk) if( pxl_cen ) vcen_n <= ~vcen_n;

wire        vt_cen = pxl_cen & vcen_n;

jtframe_vtimer #(
    .VCNT_END ( 9'h1B0 ),
    .VB_START ( 9'h1AB ),
    .VB_END   ( 9'h01B ),
    .VS_START ( 9'h000 ),
    .VS_END   ( 9'h003 ),
    .HCNT_END ( 9'h150 ),
    .HB_START ( 9'h13D ),
    .HB_END   ( 9'h03D ),
    .HS_START ( 9'h000 ),
    .HS_END   ( 9'h01C )
) u_vtimer(
    .clk      ( clk    ),
    .pxl_cen  ( vt_cen ),
    .vdump    (        ),
    .vrender  (        ),
    .vrender1 (        ),
    .H        (        ),
    .Hinit    (        ),
    .Vinit    (        ),
    .LHBL     ( t_lhbl ),
    .LVBL     ( t_lvbl ),
    .HS       ( t_hs   ),
    .VS       ( t_vs   )
);

wire [ 7:0] lb_wa = { wbuf, wcnt };
wire [ 7:0] lb_ra = { rbuf, rpx[9:3] };
wire        lb_we = scan_rd & scan_ok;

jtframe_dual_ram #(.DW(128),.AW(8)) u_linebuf(
    .clk0  ( clk       ),
    .data0 ( scan_data ),
    .addr0 ( lb_wa     ),
    .we0   ( lb_we     ),
    .q0    (           ),
    .clk1  ( clk       ),
    .data1 ( 128'd0    ),
    .addr1 ( lb_ra     ),
    .we1   ( 1'b0      ),
    .q1    ( lb_w      )
);

endmodule
