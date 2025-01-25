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
    Date: 25-1-2025 */

module jtframe_binhex_overlay #(
    parameter COLORW=4
) (
    input            clk,
    input      [8:0] v, h,
    input            hex_en,
    input            bin_en,
    input      [2:0] color,
    input      [7:0] din,
    // overlay the value on video
    input [COLORW-1:0] rin,
    input [COLORW-1:0] gin,
    input [COLORW-1:0] bin,

    // combinational output
    output reg [COLORW-1:0] rout,
    output reg [COLORW-1:0] gout,
    output reg [COLORW-1:0] bout
);

localparam [7:0] ZERO="0"-8'h20,
                 ONE ="1"-8'h20;

wire        osd_en, single;
reg         pxl, neg;
wire [ 7:0] pxl_row;
wire [ 2:0] bit_sel;
wire [ 3:0] nibble;
reg  [ 7:0] ascii;

jtframe_font u_font(
    .clk    ( clk       ),
    .ascii  ( ascii[6:0]),
    .v      ( v[2:0]    ),
    .pxl    ( pxl_row   )
);

assign bit_sel = ~h[5:3];
assign osd_en  = bin_en | hex_en;
assign single  = din[ bit_sel ];
assign nibble  = h[3] ? din[3:0] : din[7:4];

function [7:0] make_ascii(input [3:0] v); begin
    make_ascii = v<4'ha ? {4'h1,v} : "A"-8'h2a+{4'd0,v};
end endfunction

always @(posedge clk) begin
    if(bin_en) begin
        ascii <= single ? ONE : ZERO;
    end else begin
        ascii <= make_ascii(nibble);
    end
    neg <= single & bin_en;
    pxl <= pxl_row[~h[2:0]]^neg;
end

always @* begin
    rout = rin;
    gout = gin;
    bout = bin;

    if( osd_en ) begin
        rout = {COLORW{ pxl }};
        gout = {COLORW{ pxl }};
        bout = {COLORW{ pxl }};
        // change the color accent
        if(!color[2]) rout[COLORW-1]=0;
        if(!color[1]) gout[COLORW-1]=0;
        if(!color[0]) bout[COLORW-1]=0;
    end
end

endmodule