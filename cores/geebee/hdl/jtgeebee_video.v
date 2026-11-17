/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 06-11-2026 */

module jtgeebee_video(
    input             clk,
    input             rst,
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
    output            cmpblk_n,
    output            char_pxl,
    output            char_gate,
    output            ball_pxl,
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs
);

wire [8:0] scan_x = flip ? ~h : h;
wire [8:0] scan_y = flip ? ~v : v;
// Sheet 8: 4F and 4E establish the /CMPBLK windows.
reg cmpblk_h_n, cmpblk_v_n;
assign cmpblk_n = cmpblk_h_n && cmpblk_v_n;
wire side_sel = h[8] && cmpblk_n;
wire shift_load = cmpblk_n && h[2:0] == 3'b111;
reg [3:0] sh_hi, sh_lo;
reg char_gate_latch;
reg [7:0] ball_hcnt;
reg ball_count_en;
// Sheet 9: 2R/3R adders and 3S/3T counters form the ball position pulse.
wire [7:0] ball_vsum = ball_y + (flip ? ~v[7:0] : v[7:0]);

// Sheet 8: 3L, 3K and 3J supply the H/V counter and sync chain.
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
    .VB_START ( 9'd239 ),
    .VB_END   ( 9'd15  ),
    .VS_START ( 9'd256 ),
    .VS_END   ( 9'd0   ),
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

// Sheet 9: 2J/2K/2L/2M form the video RAM address mux chain.
assign vram_addr = side_sel ? {4'b0, scan_x[3], scan_y[7:3]} :
                              {scan_y[7:3], scan_x[7:3]};
// Sheet 9: 2D/2E and 4J/4K/3D drive 2708 A9..A0.
assign gfx_addr  = {1'b0, vram_data[6:0], scan_y[2:0]};
// Sheet 9: 74194s 2C/2B shift the graphics byte; 74157 2A selects QA/QD.
assign char_pxl  = flip ? sh_lo[3] : sh_hi[0];
assign char_gate = char_gate_latch;
assign ball_pxl  = ball_on && !vs && ball_count_en &&
                   ball_vsum[7:2] == 6'h3f && ball_hcnt[7:2] == 6'h3f;

always @(posedge clk) if (pxl_cen && h[3:0] == 4'd8)
    ball_count_en <= !h[8];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cmpblk_h_n <= 1;
        cmpblk_v_n <= 0;
    end else if (pxl_cen) begin
        if (!h[8]) cmpblk_h_n <= 1;
        else if (h[7:0] == 8'd120) cmpblk_h_n <= 1;
        else if (h[3:0] == 4'd8) cmpblk_h_n <= 0;
        if (h == 0 && v[4] && v[3:0] == 4'd0)
            cmpblk_v_n <= !(v[7] && v[6] && v[5]);
    end
end

always @(posedge clk) if (pxl_cen) begin
    if (hs) ball_hcnt <= flip ? ball_x - 8'd3 : ball_x;
    else if (ball_count_en) ball_hcnt <= flip ? ball_hcnt - 1'b1 : ball_hcnt + 1'b1;
end

always @(posedge clk) if (pxl_cen) begin
    if (shift_load) begin
        sh_hi <= {gfx_data[4], gfx_data[5], gfx_data[6], gfx_data[7]};
        sh_lo <= {gfx_data[0], gfx_data[1], gfx_data[2], gfx_data[3]};
    end else if (flip) begin
        sh_hi <= {sh_hi[2:0], 1'b0};
        sh_lo <= {sh_lo[2:0], sh_hi[3]};
    end else begin
        sh_hi <= {sh_lo[0], sh_hi[3:1]};
        sh_lo <= {1'b0, sh_lo[3:1]};
    end
end

always @(posedge clk) if (pxl_cen && shift_load)
    char_gate_latch <= ~vram_data[7];
endmodule
