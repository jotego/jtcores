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
    Date: 25-9-2019 */

// Simple scan doubler
// CRT-like output:
//  -simple blending of neighbouring pixels
//  -50% scan lines

// sl_mode for scan lines
// 0 = no scan lines
// 1 = dimmed
// 2 = more dimmed
// 3 = blank scan lines

// hz_mode for horizontal pixel blending
// 0 = no blending
// 1 = linear interpolation
// 2 = blank (zero)

module jtframe_scan2x #(parameter COLORW=4, HLEN=512)(
    input       rst_n,
    input       clk,
    input       pxl_cen,
    input       pxl2_cen,
    input       [COLORW*3-1:0]    base_pxl,
    input       HS,
    input       HB,
    input       VB,
    input [1:0] sl_mode,  // scanline modes
    input       blend_en, // horizontal blending modes

    output  reg [COLORW*3-1:0]    x2_pxl,
    output  reg x2_HS,
    output      x2_DE
);

localparam AW=HLEN<=512 ? 9:10;
localparam DW=COLORW*3;

reg  [DW-1:0] preout;
reg  [AW-1:0] wraddr, rdaddr, hlen, hswidth, hb_rise, hb_fall, vb_rise, vb_fall;
reg           scanline;
reg           last_HS, last_HB, last_VB;
reg           vb_rising, vb_falling;
reg           line;
reg           x2_HB, x2_VB;

wire          HS_posedge     =  HS && !last_HS;
wire          HS_negedge     = !HS &&  last_HS;
wire [DW-1:0] next;
wire [DW-1:0] dim2, dim4;
reg [COLORW:0] ab;
wire [COLORW*3-1:0] gated_pxl;

wire          HB_posedge     =  HB && !last_HB;
wire          HB_negedge     = !HB &&  last_HB;
wire          VB_posedge     =  VB && !last_VB;
wire          VB_negedge     = !VB &&  last_VB;

function [COLORW-1:0] ave(
        input [COLORW-1:0] a,
        input [COLORW-1:0] b );
    begin
        ab  = {1'b0,a}+{1'b0,b};
        ave = ab[COLORW:1];
    end
endfunction

function [DW-1:0] blend(
    input [DW-1:0] a,
    input [DW-1:0] b );
    blend = {
        ave(a[COLORW*3-1:COLORW*2],b[COLORW*3-1:COLORW*2]),
        ave(a[COLORW*2-1:COLORW],b[COLORW*2-1:COLORW]),
        ave(a[COLORW-1:0],b[COLORW-1:0]) };
endfunction

`ifdef JTFRAME_CLK96
localparam CLKSTEPS=8;
localparam [CLKSTEPS-1:0] BLEND_ST = 8'b10;
`else
localparam CLKSTEPS=4;
localparam [CLKSTEPS-1:0] BLEND_ST = 2;
`endif

localparam [CLKSTEPS-1:0] PURE_ST  = 0;
reg alt_pxl; // this is needed in case pxl2_cen and pxl_cen are not aligned.
reg [CLKSTEPS-1:0] mixst;

always@(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        preout <= {DW{1'b0}};
    end else begin
        `ifndef JTFRAME_SCAN2X_NOBLEND
            // mixing can only be done if clk is at least 4x pxl2_cen
            mixst <= { mixst[1:0],pxl2_cen};
            if(mixst==BLEND_ST) begin
                preout <= blend_en ?
                    blend( rdaddr=={AW{1'b0}} ? {DW{1'b0}} : preout, next) :
                    next;
            end else if( mixst==PURE_ST )
                preout <= next;
        `else
            preout <= next;
        `endif
    end
end

assign dim2      = blend( {DW{1'b0}}, preout);
assign dim4      = blend( {DW{1'b0}}, dim2 );
assign gated_pxl = (VB|HB) ? {3*COLORW{1'b0}} : base_pxl;

// scan lines are black
always @(posedge clk) begin
    if( scanline ) begin
        case( sl_mode )
            2'd0: x2_pxl <= preout;
            2'd1: x2_pxl <= dim2;
            2'd2: x2_pxl <= dim4;
            2'd3: x2_pxl <= {DW{1'b0}};
        endcase
    end else x2_pxl <= preout;
end

always @(posedge clk) if(pxl2_cen) begin
    alt_pxl <= ~alt_pxl;
    if( alt_pxl ) last_HS <= HS;
    if( alt_pxl & HS_posedge ) begin
        wraddr   <= {AW{1'b0}};
        rdaddr   <= {AW{1'b0}};
        hlen     <= wraddr;
        line     <= ~line;
        scanline <= 0;
        x2_HS    <= 1;
    end else begin
        if(alt_pxl) wraddr <= wraddr + 1'd1;
        if( rdaddr == hlen ) begin
            rdaddr   <= {AW{1'b0}};
            x2_HS    <= 1;
            scanline <= 1;
        end else begin
            rdaddr <= rdaddr+1'd1;
            if( rdaddr == hswidth ) begin
                x2_HS <= 0;
            end
        end
    end
    if( alt_pxl & HS_negedge ) begin
        hswidth <= wraddr;
    end
end

always @(posedge clk) if(pxl2_cen) begin
    last_HB <= HB;
    last_VB <= VB;
    if (HB_posedge) hb_rise <= wraddr;
    if (HB_negedge) hb_fall <= wraddr;
    if (VB_posedge) begin
        vb_rise <= wraddr;
        vb_rising <= 1;
        vb_falling <= 0;
    end
    if (VB_negedge) begin
        vb_fall <= wraddr;
        vb_falling <= 1;
        vb_rising <= 0;
    end
    if (rdaddr == hb_rise) x2_HB <= 1;
    if (rdaddr == hb_fall) x2_HB <= 0;
    if (vb_rising && rdaddr == vb_rise) x2_VB <= 1;
    if (vb_falling && rdaddr == vb_fall) x2_VB <= 0;
end

assign x2_DE = ~(x2_VB | x2_HB);

jtframe_dual_ram #(.DW(DW),.AW(AW+1)) u_buffer(
    .clk0   ( clk            ),
    .clk1   ( clk            ),
    // Port 0: read
    .data0  ( {DW{1'b0}}     ),
    .addr0  ( {line, rdaddr} ),
    .we0    ( 1'b0           ),
    .q0     ( next           ),
    // Port 1: write
    .data1  ( gated_pxl      ),
    .addr1  ( {~line, wraddr}),
    .we1    ( pxl_cen        ),
    .q1     (                )
);

endmodule // jtframe_scan2x
