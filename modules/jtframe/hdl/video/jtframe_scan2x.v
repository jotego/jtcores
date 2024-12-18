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
    input       rst,
    input       clk,
    input       pxl_cen,
    input       pxl2_cen,

    // configuration
    input       enb,      // enable bar
    input [1:0] sl_mode,  // scanline modes
    input       blend_en, // horizontal blending modes

    // rotating
    input [1:0] rotation, // 0 - no rotation, 1 - clockwise, 2 - anticlockwise
    input       hfilter,
    input       vfilter,

    input [COLORW*3-1:0] x1_pxl,
    input       x1_hs,
    input       x1_vs,
    input       x1_hb,
    input       x1_vb,

    output  reg [COLORW*3-1:0] x2_pxl,
    output  reg x2_hs,
    output  reg x2_vs,
    output      x2_de,
    output  reg x2_HB,
    output  reg x2_VB,

    // SDRAM interface for rotation
    input         init,
    inout  [15:0] sd_data,
    output [12:0] sd_addr,
    output  [1:0] sd_dqm,
    output  [1:0] sd_ba,
    output        sd_cs,
    output        sd_we,
    output        sd_ras,
    output        sd_cas,
    output        sd_cke
);

localparam AW=HLEN<=512 ? 9:10;
localparam DW=COLORW*3;

reg  [DW-1:0] preout=0;
reg  [AW-1:0] wraddr, rdaddr, hlen, hswidth, hb_rise, hb_fall, vb_rise, vb_fall, vs_rise, vs_fall;
reg           scanline;
reg           last_HS, last_VS, last_HB, last_VB;
reg           vb_rising, vb_falling, vs_rising, vs_falling;
reg           line=0;
reg           vchng=0, vwait=0;
//reg           x2_HB, x2_VB;

wire          HS_posedge     =  x1_hs && !last_HS;
wire          HS_negedge     = !x1_hs &&  last_HS;
wire [DW-1:0] next;
wire [DW-1:0] linebuf_q;
wire [DW-1:0] dim2, dim4;
reg [COLORW:0] ab;
wire [COLORW*3-1:0] gated_pxl;

wire          HB_posedge     =  x1_hb && !last_HB;
wire          HB_negedge     = !x1_hb &&  last_HB;
wire          VB_posedge     =  x1_vb && !last_VB;
wire          VB_negedge     = !x1_vb &&  last_VB;
wire          VS_posedge     =  x1_vs && !last_VS;
wire          VS_negedge     = !x1_vs &&  last_VS;

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
reg alt_pxl=0; // this is needed in case pxl2_cen and pxl_cen are not aligned.
reg [CLKSTEPS-1:0] mixst;

always@(posedge clk or posedge rst) begin
    if( rst ) begin
        preout <= {DW{1'b0}};
    end else begin
        `ifndef JTFRAME_SCAN2X_NOBLEND
            // mixing can only be done if clk is at least 4x pxl2_cen
            mixst <= { mixst[0+:CLKSTEPS-1],pxl2_cen};
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
assign gated_pxl = (x1_vb|x1_hb) ? {3*COLORW{1'b0}} : x1_pxl;

// scan lines are black
always @(posedge clk) if(pxl2_cen) begin
    if( scanline ) begin
        case( sl_mode )
            2'd0: x2_pxl <= preout;
            2'd1: x2_pxl <= dim2;
            2'd2: x2_pxl <= dim4;
            2'd3: x2_pxl <= {DW{1'b0}};
        endcase
    end else x2_pxl <= preout;
    if( enb ) x2_pxl <= x1_pxl;
end

always @(posedge clk) if(pxl2_cen) begin
    alt_pxl <= ~alt_pxl;
    if( alt_pxl ) last_HS <= x1_hs;
    if( alt_pxl & HS_posedge ) begin
        wraddr   <= {AW{1'b0}};
        rdaddr   <= {AW{1'b0}};
        hlen     <= wraddr;
        line     <= ~line;
        scanline <= 0;
        x2_hs    <= 1;
    end else begin
        if(alt_pxl) wraddr <= wraddr + 1'd1;
        if( rdaddr == hlen ) begin
            rdaddr   <= {AW{1'b0}};
            x2_hs    <= 1;
            scanline <= 1;
        end else begin
            rdaddr <= rdaddr+1'd1;
            if( rdaddr == hswidth ) begin
                x2_hs <= 0;
            end
        end
    end
    if( alt_pxl & HS_negedge ) begin
        hswidth <= wraddr;
    end

    last_HB <= x1_hb;
    last_VB <= x1_vb;
    last_VS <= x1_vs;
    if (HB_posedge) begin
        hb_rise <= wraddr;
        if( vwait && vb_falling ) vchng <= 1;
        if( vchng && vb_rising  ) begin
            {vwait, vchng} <= 2'b0;
            vb_rise <= wraddr;
        end
    end
    if (HB_negedge) begin
        hb_fall <= wraddr;
        if( vwait && vb_rising  ) vchng <= 1;
        if( vchng && vb_falling ) begin
            {vwait, vchng} <= 2'b0;
            vb_fall <= wraddr;
        end
    end
    if (VB_posedge) begin
        vwait <= 1;
        // vb_rise <= wraddr;
        vb_rising <= 1;
        vb_falling <= 0;
    end
    if (VB_negedge) begin
        vwait <= 1;
        // vb_fall <= wraddr;
        vb_falling <= 1;
        vb_rising <= 0;
    end
    if (VS_posedge) begin
        vs_rise <= wraddr;
        vs_rising <= 1;
        vs_falling <= 0;
    end
    if (VS_negedge) begin
        vs_fall <= wraddr;
        vs_falling <= 1;
        vs_rising <= 0;
    end
    if (rdaddr == hb_rise) x2_HB <= 1;
    if (rdaddr == hb_fall) x2_HB <= 0;
    if (vb_rising && rdaddr == vb_rise) x2_VB <= 1;
    if (vb_falling && rdaddr == vb_fall) x2_VB <= 0;
    if (vs_rising && rdaddr == vs_rise) x2_vs <= 1;
    if (vs_falling && rdaddr == vs_fall) x2_vs <= 0;

    if( enb ) {x2_hs,x2_HB,x2_vs,x2_VB} <= {x1_hs,x1_hb,x1_vs,x1_vb};
end

assign x2_de = ~(x2_VB | x2_HB);

`ifdef JTFRAME_VERTICAL
`ifdef JTFRAME_SDRAM_ROTATION
`define JTFRAME_SCAN2X_ROTATE
`endif
`endif

`ifdef JTFRAME_SCAN2X_ROTATE
wire [COLORW-1:0] rotate_r, rotate_g, rotate_b;
wire        vidin_req;
wire  [1:0] vidin_frame;
wire [10:0] vidin_row;
wire [10:0] vidin_col;
wire [15:0] vidin_d;
wire        vidin_ack;

wire        vidout_req;
wire  [1:0] vidout_frame;
wire [10:0] vidout_row;
wire [10:0] vidout_col;
wire [15:0] vidout_d;
wire        vidout_ack;

scandoubler_rotate #(.COLOR_DEPTH(COLORW), .OUT_COLOR_DEPTH(COLORW)) u_rotate(
    .clk_sys    ( clk      ),
    .rotation   ( rotation ),
    .rotateonly ( 1'b0     ),
    .hfilter    ( hfilter  ),
    .vfilter    ( vfilter  ),
    .pe_in      ( pxl_cen  ),
    .ppe_out    ( pxl2_cen ),
    .hb_in      ( x1_hb    ),
    .vb_in      ( x1_vb    ),
    .hs_in      ( x1_hs    ),
    .vs_in      ( x1_vs    ),
    .r_in       ( x1_pxl[COLORW*3-1:COLORW*2] ),
    .g_in       ( x1_pxl[COLORW*2-1:COLORW] ),
    .b_in       ( x1_pxl[COLORW-1:0] ),
    .hb_sd      ( x2_HB    ),
    .vb_sd      ( x2_VB    ),
    .vs_sd      ( x2_vs    ),
    .r_out      ( rotate_r ),
    .g_out      ( rotate_g ),
    .b_out      ( rotate_b ),

    // Memory interface
    .vidin_req  ( vidin_req   ),
    .vidin_frame( vidin_frame ),
    .vidin_row  ( vidin_row   ),
    .vidin_col  ( vidin_col   ),
    .vidin_d    ( vidin_d     ),
    .vidin_ack  ( vidin_ack   ),

    .vidout_req ( vidout_req  ),
    .vidout_frame ( vidout_frame ),
    .vidout_row ( vidout_row  ),
    .vidout_col ( vidout_col  ),
    .vidout_d   ( vidout_d    ),
    .vidout_ack ( vidout_ack  )
);

scandoubler_sdram u_sdram (
    .init       ( init ),
    .clk        ( clk ),
    .ready      ( ),
    .sd_data    ( sd_data ),
    .sd_addr    ( sd_addr ),
    .sd_dqm     ( sd_dqm ),
    .sd_ba      ( sd_ba ),
    .sd_cs      ( sd_cs ),
    .sd_we      ( sd_we ),
    .sd_ras     ( sd_ras ),
    .sd_cas     ( sd_cas ),

    .ram_din    ( ),
    .ram_dout   ( ),
    .ram_addr   ( ),
    .ram_ds     ( ),
    .ram_req    ( ),
    .ram_we     ( ),
    .ram_ack    ( ),

    .rom_oe     ( ),
    .rom_addr   ( ),
    .rom_dout   ( ),

    .vidin_req  ( vidin_req  ),
    .vidin_frame ( vidin_frame ),
    .vidin_row  ( vidin_row  ),
    .vidin_col  ( vidin_col  ),
    .vidin_d    ( vidin_d    ),
    .vidin_ack  ( vidin_ack  ),

    .vidout_req ( vidout_req ),
    .vidout_frame ( vidout_frame ),
    .vidout_row ( vidout_row ),
    .vidout_col ( vidout_col ),
    .vidout_q   ( vidout_d   ),
    .vidout_ack ( vidout_ack )
);
assign sd_cke = 1;
assign next = |rotation ? {rotate_r, rotate_g, rotate_b} : linebuf_q;
`else
assign next = linebuf_q;
assign sd_data = 16'hZZZZ;
assign sd_addr = 0;
assign sd_dqm = 0;
assign sd_ba = 0;
assign sd_cs = 1;
assign sd_we = 1;
assign sd_ras = 1;
assign sd_cas = 1;
assign sd_cke = 0;
`endif

jtframe_dual_ram #(.DW(DW),.AW(AW+1)) u_buffer(
    .clk0   ( clk            ),
    .clk1   ( clk            ),
    // Port 0: read
    .data0  ( {DW{1'b0}}     ),
    .addr0  ( {line, rdaddr} ),
    .we0    ( 1'b0           ),
    .q0     ( linebuf_q      ),
    // Port 1: write
    .data1  ( gated_pxl      ),
    .addr1  ( {~line, wraddr}),
    .we1    ( pxl_cen        ),
    .q1     (                )
);

endmodule // jtframe_scan2x
