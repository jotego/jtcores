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
reg  [    VW-1:0] wrcnt, hwcnt,rd_z, rd_out, rgbcnt;
reg  [      VW:0] rdcnt_l, rdcnt, hrmax;
wire [    VW+5:0] summand;
reg  [    SW-1:0] sum;
reg  [    VW-1:0] hmax, hb0, hb1;
//reg  [    VW+1:0] hrmax;

reg  line=0, over, passz, overl;
reg  VSl, HSl, HBl, HBll, VBl, VBll, HB_chnl,HB_chn,repr;
wire [SW-1:0] next_sum;
reg [5:0] rdfrac=0,rgbfrac=0;

assign rgb_in   = {r_in, g_in, b_in};
//assign next_sum = sum + {1'b0, summand};
assign summand  = {{VW{1'b0}},~scale[3],scale[3],scale};//{ ~scale[3], {SW-5{scale[3]}}, scale[2:0] };
/*
always @(posedge clk) if(pxl_cen) begin
    HSl     <= HS_in;
    HBl     <= HB_in;
    HBll    <= HBl;
    overl   <= over;
    HB_outl <= HB_out;

    // VB must be adjusted to prevent the bottom line from being washed out
    if( HB_in & ~HBl ) begin
        { VBll, VBl } <= { VBl, VB_in };
    end
    if( ~HS_in &  HSl ) hscnt <= wrcnt/2;
    if(  HS_in & ~HSl ) begin
        line  <= ~line;
        wrcnt <= 0;
        hmax  <= wrcnt;
        VSl   <= VS_in;
        if( enable ) VS_out <= VSl;
    end else begin
        wrcnt <= wrcnt + 1'd1;
    end

    // Register when HB toggles
    if(  HBl & ~HBll  ) hb1 <= wrcnt;
    //if( ~HB_in &  HBl ) hb0 <= hmax-sumcnt;//-hscnt;
    //if( HB_out & ~HB_outl) hb0 <= hmax-rdcnt;//-hscnt;

    HS_out <= HS_in;
    if( enable ) begin
        if(  HB_out && (rdcnt== hb0 || rdcnt_l==hb0) ) HB_out <= 0;
        if( !HB_out && (rdcnt== hb1 || rdcnt_l==hb1)|| (HS_in && !HSl) ) ) begin
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
    rdcnt_l <= rdcnt;
    if( HS_in & ~HSl wrcnt==hscnt ) begin
        hrmax <= rdcnt_l; 
        rdcnt <= { {VW-5{offset[4]}}, offset };
        sum   <= 0;
        over  <= 0;
        passz <= 0; // passed zero, used to avoid setting "over" wrong
                    // when using negative offsets
    end else begin
        sum  <= next_sum;
        if( HB_out & ~HB_outl) hb0 <= hrmax-rdcnt;
        if( sum[SW-1] != next_sum[SW-1] && !over ) begin
            
            if( rdcnt==0 || rdcnt_l == 0) passz <= 1;
            if( (rdcnt == hmax || rdcnt_l == hmax) && passz ) begin
                over <= 1;
            end else begin
                rdcnt <= rdcnt + 1'd1;
            end
        end
    end
end
*/


always @(posedge clk) if(pxl_cen) begin
    HSl     <= HS_in;
    HBl     <= HB_in;
    HBll    <= HBl;
    //HB_out  <= HB_in;
    HB_chnl <= HB_chn;
    overl   <= over;
    hwcnt   <= (hb0-hb1)>>1;
    rd_z    <= hwcnt+hb1;
    hrmax   <= rdcnt_l-{1'b0,hwcnt};

    // VB must be adjusted to prevent the bottom line from being washed out
    if( HB_in & ~HBl ) {VBll, VBl} <= {VBl, VB_in};

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
    if(  HBl & ~HBll  ) hb1 <= wrcnt;
    if( ~HB_in &  HBl ) hb0 <= wrcnt;//-hscnt;
    //if( HB_out & ~HB_outl) hb0 <= hmax-rdcnt;//-hscnt;

    HS_out <= HS_in;
    if( enable ) begin
        if( wrcnt==rd_z) /*HB_chn*/HB_out <= 1;
        if( HB_chn && rdcnt >= {1'b0,hwcnt} && wrcnt > rd_z ) HB_out/*HB_chn*/ <= 0;
        if(!HB_chn && rdcnt >= hrmax) begin
            HB_out/*HB_chn*/ <= 1;
            VB_out <= VBll;            
        end
    end else begin
        HB_out/*HB_chn*/ <= HB_in;
        VB_out <= VB_in;
        VS_out <= VS_in;
    end

    HB_chn <= HB_out; //QUITAR!!!
    // colour output
    {r_out,g_out,b_out} <= enable ? (HB_out ? rgb_out : {3*COLORW{1'b0}}) : rgb_in;
end

always @(posedge clk) if(pxl2_cen) begin
    {rdcnt,rdfrac} <= {rdcnt,rdfrac} + {1'b0,summand};//{{VW+1{1'b0}},~scale[3],scale[3],scale};
    if( HB_chn && ~HB_chnl) {rgbcnt,rgbfrac} <= {hb1,6'b0};
    else if( HB_chn)        {rgbcnt,rgbfrac} <= {rgbcnt,rgbfrac} + summand;//{{VW{1'b0}},~scale[3],scale[3],scale};
    else rgbcnt <= 0;
        if( wrcnt==rd_z ) begin 
            {rdcnt,rdfrac}  <= 0; //{ {VW-5{offset[4]}}, offset };
            if( !repr) begin 
                rdcnt_l <= rdcnt;
                repr <= 1;
            end 
        end else repr <= 0;
end

jtframe_rpwp_ram #(.DW(COLORW*3), .AW(VW+1)) u_line(
    .clk    ( clk       ),
    // Port 0: writes
    .din    ( rgb_in    ),
    .wr_addr({line, wrcnt}),
    .we     ( pxl_cen   ),
    // Port 1
    .rd_addr({line,rgbcnt}),
    .dout   ( rgb_out   )
);

endmodule