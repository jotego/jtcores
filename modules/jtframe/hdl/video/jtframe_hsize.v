/*  This file is part of JT_FRAME.
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
    Date: 1-8-2021 */

// Applies horizontal scaling to an analogue signal

module jtframe_hsize #( parameter
    COLORW     =4     // bits per colour
    //VIDEO_WIDTH=256   // screen pixel width (excluding blanking)
) (
    input              clk,
    input              pxl_cen,
    input              pxl2_cen,

    input        [3:0] scale,
    input        [4:0] offset,
    input              enable,

    input [COLORW-1:0] r_in,
    input [COLORW-1:0] g_in,
    input [COLORW-1:0] b_in,
    input              HS_in,
    input              VS_in,
    input              HB_in,
    input              VB_in,
    // filtered video
    output reg            HS_out,
    output reg            VS_out,
    output reg            HB_out,
    output reg            VB_out,
    output reg [COLORW-1:0] r_out,
    output reg [COLORW-1:0] g_out,
    output reg [COLORW-1:0] b_out
);

//localparam VW = VIDEO_WIDTH <= 256 ? 9 : (VIDEO_WIDTH <= 512 ? 9 : 10);
localparam VW = 9; // Max 512 pixels including blanking
localparam SW = 8;

wire [COLORW*3-1:0] rgb_out, rgb_in;
reg  [    VW-1:0] rdcnt, wrcnt;
wire [    SW-2:0] summand;
reg  [    SW-1:0] sum;
reg  [    VW-1:0] hmax, hb0, hb1;

reg  line=0, over, passz, overl;
reg  VSl, HSl, HBl, HBll, VBl, VBll;
wire [SW-1:0] next_sum;

assign rgb_in   = {r_in, g_in, b_in};
assign next_sum = sum + {1'b0, summand};
assign summand  = { ~scale[3], {SW-5{scale[3]}}, scale[2:0] };

always @(posedge clk) if(pxl_cen) begin
    HSl   <= HS_in;
    HBl   <= HB_in;
    HBll  <= HBl;
    overl <= over;

    // VB must be adjusted to prevent the bottom line from being washed out
    if( HB_in & ~HBl ) begin
        { VBll, VBl } <= { VBl, VB_in };
    end

    if( HS_in & ~HSl ) begin
        line  <= ~line;
        wrcnt <= 0;
        hmax  <= wrcnt;
        VSl   <= VS_in;
        if( enable ) VS_out <= VSl;
    end else begin
        wrcnt <= wrcnt + 1'd1;
    end
    // Register when HB toggles
    if(  HBl & ~HBll ) hb1 <= wrcnt;
    if( ~HBl &  HBll ) hb0 <= wrcnt;

    HS_out <= HS_in;
    if( enable ) begin
        if(  HB_out && rdcnt==hb0 ) HB_out <= 0;
        if( !HB_out && (rdcnt==hb1 || (HS_in && !HSl) ) ) begin
            HB_out <= 1;
            if( enable ) VB_out <= VBll;
        end
    end else begin
        HB_out <= HB_in;
        VB_out <= VB_in;
        VS_out <= VS_in;
    end

    // colour output
    {r_out,g_out,b_out} <= enable ? (overl || !passz ? {3*COLORW{1'b0}} : rgb_out) : rgb_in;
end

always @(posedge clk) if(pxl2_cen) begin
    if( HS_in & ~HSl ) begin
        rdcnt <= { {VW-5{offset[4]}}, offset };
        sum   <= 0;
        over  <= 0;
        passz <= 0; // passed zero, used to avoid setting "over" wrong
                    // when using negative offsets
    end else begin
        sum  <= next_sum;
        if( sum[SW-1] != next_sum[SW-1] && !over ) begin
            if( rdcnt==0 ) passz <= 1;
            if( rdcnt == hmax && passz ) begin
                over <= 1;
            end else begin
                rdcnt <= rdcnt + 1'd1;
            end
        end
    end
end

jtframe_rpwp_ram #(.DW(COLORW*3), .AW(VW+1)) u_line(
    .clk    ( clk       ),
    // Port 0: writes
    .din    ( rgb_in    ),
    .wr_addr({line, wrcnt}),
    .we     ( pxl_cen   ),
    // Port 1
    .rd_addr({line,rdcnt}),
    .dout   ( rgb_out   )
);

endmodule