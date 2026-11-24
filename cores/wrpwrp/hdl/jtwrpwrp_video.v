/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-11-2026 */

module jtwrpwrp_video(
    input             clk,
    input             pxl_cen,
    input             flip,
    input      [7:0]  code,
    input      [7:0]  color,
    input      [7:0]  gfx_data,
    output     [9:0]  vram_addr,
    output     [10:0] gfx_addr,
    output reg [7:0]  color_out,
    output            pixel,
    output            cmpblk_n,
    output            wrq_n,
    output     [8:0]  h,
    output     [8:0]  v,
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs
);

wire [7:0] scan_h = h[7:0] ^ {8{flip}};
wire [7:0] scan_v = v[7:0] ^ {8{flip}};
wire side_column = h[8] && cmpblk_n;
wire shift_load = cmpblk_n && (&h[2:0]);
reg [7:0] pixels;

// Sheet 2: 5P opens the fetch window one character before the visible line.
assign cmpblk_n = lvbl && (h < 9'd264 || h >= 9'd376);
// Sheet 2: 5R and 5P feed the 3N /WRQ gate.
assign wrq_n = !lvbl || (h >= 9'd272 && h < 9'd368);
// Sheet 3: 3J/3K/3L/3M select a column address when 256H is high.
assign vram_addr = side_column ? {4'b0, scan_h[3], scan_v[7:3]} :
                                 {scan_v[7:3], scan_h[7:3]};
assign gfx_addr = {code, scan_v[2:0]};
assign pixel = flip ? pixels[0] : pixels[7];

// 5N supplies the 3A shifter load and the 6K clock gate for 6D/6E.
always @(posedge clk) if (pxl_cen) begin
    if (shift_load) begin
        pixels    <= gfx_data;
        color_out <= color;
    end else if (flip) begin
        pixels <= {1'b0, pixels[7:1]};
    end else begin
        pixels <= {pixels[6:0], 1'b0};
    end
end

jtframe_vtimer #(
    .HCNT_START( 9'd0   ),
    .HCNT_END  ( 9'd383 ),
    .HB_START ( 9'd271 ),
    .HB_END   ( 9'd383 ),
    .HS_START ( 9'd303 ),
    .HS_END   ( 9'd335 ),
    .H_VB     ( 9'd303 ),
    .H_VNEXT  ( 9'd303 ),
    .V_START  ( 9'd0   ),
    .VB_START ( 9'd239 ),
    .VB_END   ( 9'd15  ),
    .VS_START ( 9'd256 ),
    .VS_END   ( 9'd0   ),
    .VCNT_END ( 9'd263 )
) u_timing(
    .clk     ( clk     ),
    .pxl_cen ( pxl_cen ),
    .vdump   ( v       ),
    .vrender (         ),
    .vrender1(         ),
    .H       ( h       ),
    .Hinit   (         ),
    .Vinit   (         ),
    .LHBL    ( lhbl    ),
    .LVBL    ( lvbl    ),
    .HS      ( hs      ),
    .VS      ( vs      )
);

endmodule
