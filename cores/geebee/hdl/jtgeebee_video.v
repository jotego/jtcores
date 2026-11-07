/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 06-11-2026 */

module jtgeebee_video(
    input             clk,
    input             pxl_cen,
    input             flip,
    input             ball_on,
    input      [7:0]  ball_x,
    input      [7:0]  ball_y,
    output     [9:0]  vram_addr,
    input      [7:0]  vram_data,
    output     [10:0] gfx_addr,
    input      [7:0]  gfx_data,
    output     [8:0]  h,
    output     [8:0]  v,
    output            char_pxl,
    output            ball_pxl,
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs
);

wire [8:0] scan_x = flip ? ~h : h;
wire [8:0] scan_y = flip ? ~v : v;
wire side_sel = h[8] && lhbl && lvbl;

jtframe_vtimer #(
    .HCNT_START( 9'd0   ),
    .HCNT_END  ( 9'd383 ),
    .HB_START ( 9'd271 ),
    .HB_END   ( 9'd383 ),
    .HS_START ( 9'd304 ),
    .HS_END   ( 9'd335 ),
    .H_VB     ( 9'd383 ),
    .H_VNEXT  ( 9'd383 ),
    .V_START  ( 9'd0   ),
    .VB_START ( 9'd223 ),
    .VB_END   ( 9'd263 ),
    .VS_START ( 9'd256 ),
    .VS_END   ( 9'd260 ),
    .VCNT_END ( 9'd263 )
) u_timing(
    .clk        ( clk     ),
    .pxl_cen    ( pxl_cen ),
    .vdump      ( v       ),
    .vrender    (         ),
    .vrender1   (         ),
    .H          ( h       ),
    .Hinit      (         ),
    .Vinit      (         ),
    .LHBL       ( lhbl    ),
    .LVBL       ( lvbl    ),
    .HS         ( hs      ),
    .VS         ( vs      )
);

assign vram_addr = side_sel ? {scan_y[7:4], scan_x[3], scan_y[7:3]} :
                              {scan_y[7:3], scan_x[7:3]};
assign gfx_addr  = {1'b0, vram_data, scan_y[1:0]};
assign char_pxl  = gfx_data[~scan_x[2:0]];
assign ball_pxl  = ball_on && scan_x[7:2] == ball_x[7:2] &&
                   scan_y[7:2] == ball_y[7:2];
endmodule
