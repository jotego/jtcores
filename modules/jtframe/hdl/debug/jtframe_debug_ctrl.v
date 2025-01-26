/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 8-5-2021 */

// ctrl+shift selects sys info
// alt+shift selects target info

module jtframe_debug_ctrl(
    input            clk,
    input            pxl_cen,
    
    input [7:0]      debug_bus, view_bin, view_hex,
    input [8:0]      v, h,
    input [1:0]      view_mode,

    input            split_binhex,

    output reg       hex_en,
    output reg       bin_en,
    output reg [2:0] color=0,
    output reg [7:0] msg
);

`include "jtframe_debug.vh"

// Video overlay
localparam [8:0] JTFRAME_DEBUG_VPOS=`JTFRAME_DEBUG_VPOS;

wire [8:0] HBIN=((`JTFRAME_WIDTH&9'h1f8)>>1)-9'h10,
                 HHEX=HBIN+9'h44,
                 VOSD=(`JTFRAME_HEIGHT & 9'h1f8)-9'd8*JTFRAME_DEBUG_VPOS, // 4 rows above bottom
                 VVIEW=VOSD+9'd8*9'd2;

reg  view_sel, bus_sel, hex_col, bin_col;
wire osd_on           = view_sel | bus_sel;
wire show_bin         = split_binhex & bin_en;
wire dbg_nonz         = debug_bus!=0;
wire msg_nonz         = msg !=0;

always @(posedge clk) begin
    msg <= bus_sel  ? debug_bus :
           show_bin ? view_bin  : view_hex;
end

always @(posedge clk) begin
    // display of debug_bus
    bus_sel  <= dbg_nonz             && v[8:3]==VOSD[8:3];
    view_sel <=(msg_nonz || dbg_nonz)&& v[8:3]==VVIEW[8:3];
end

always @(posedge clk) begin
    hex_col <= h[8:4] == HHEX[8:4];
    bin_col <= h[8:6] == HBIN[8:6];
    if(pxl_cen) begin
        hex_en <= osd_on & hex_col;
        bin_en <= osd_on & bin_col;
    end
end

reg [2:0] color_x;
reg       in_splitview_bin;

always @(posedge clk) begin
    color_x = 7;
    if( view_mode==SYS_INFO    ) color_x = 3'b100; // system info is shown reddish
    if( view_mode==TARGET_INFO ) color_x = 3'b001; // system info is shown blueish

    in_splitview_bin = split_binhex & bin_col & view_sel;
    if( in_splitview_bin ) color_x[1] = ~color_x[1]; // binary in different color
end

always @(posedge clk) begin
    color <= color_x;
end

endmodule