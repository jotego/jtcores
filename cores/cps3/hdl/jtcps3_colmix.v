/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-3-2026 */

module jtcps3_colmix(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               lhbl,
    input               lvbl,
    input       [ 3:0]  gfx_en,

    input       [16:0]  ss_pxl,
    input       [15:0]  sfb_pxl,
    input       [16:0]  scene_pxl,

    output reg  [17:1]  pal_addr,
    input       [15:0]  pal_data,
    output      [14:0]  scene_rgb,

    output      [ 4:0]  red,
    output      [ 4:0]  green,
    output      [ 4:0]  blue
);

`ifndef NOVIDEO
wire        blanking  = ~lhbl | ~lvbl;
wire        ss_opaque = gfx_en[0] & |ss_pxl[3:0];
reg  [14:0] rgb, ss_rgb;
reg  [ 2:0] ss_sh;
reg         ss_sel;

assign {blue,green,red} = rgb;
assign scene_rgb = pal_data[14:0];

always @(posedge clk) begin
    if( rst ) begin
        pal_addr <= 17'd0;
        rgb      <= 15'd0;
        ss_rgb   <= 15'd0;
        ss_sh    <= 3'b0;
        ss_sel   <= 1'b0;
    end else begin
        ss_sh <= {ss_sh[1:0],ss_opaque & pxl_cen};
        if( ss_sh[2] ) begin
            ss_rgb <= pal_data[14:0];
            ss_sel <= 1;
        end

        if( pxl_cen ) begin
            rgb    <= blanking ? 15'd0 : ss_sel ? ss_rgb : sfb_pxl[14:0];
            ss_sel <= 0;
        end

        pal_addr <= pxl_cen ? ss_pxl : scene_pxl;
    end
end

`else
assign {blue,green,red} = 15'd0;
assign scene_rgb        = 15'd0;
initial pal_addr = 17'd0;
`endif

endmodule
