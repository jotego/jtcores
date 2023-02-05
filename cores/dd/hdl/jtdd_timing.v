/*  This file is part of JTDD.
    JTDD program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTDD program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTDD.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-12-2017 */


module jtdd_timing(
    input              clk,
    input              rst,
    (*direct_enable*) input pxl_cen,
    input              flip,
    output reg [7:0]   VPOS=8'd0, // VPOS in schematics
    output     [7:0]   HPOS, // HPOS in schematics
    output reg         VBL=1'b0,
    output reg         HBL=1'b0,
    output reg         VS=1'b0,
    output reg         HS=1'b0,
    output     [5:0]   M       // *M in schematics, *M represents ~M
);

localparam VBDLY=5;

reg [8:0] hn=9'd0;
reg [7:0] vn=8'he0;
reg [7:0]  m;
wire hover = hn==9'd383;
wire [8:0] nextn = hover ? 9'd0 : hn+9'd1;
reg aux=1'b0;
reg [VBDLY-1:0] preVBL;

`ifdef SIMULATION
initial begin
    preVBL = {VBDLY{1'b0}};
end
`endif

always @(posedge clk) begin
    VPOS <= vn ^ {8{flip}};
end

assign M = m[5:0];
assign HPOS = hn[7:0] ^ {8{flip}};

wire [8:0] HS1 = 9'd302;
wire [8:0] HS0 = HS1+9'd27; // 4.5us
wire [8:0] VS1 = 9'hed;
wire [8:0] VS0 = VS1+8'h3;

always @(posedge clk) if(pxl_cen) begin
    // bus phases
    m  <= 8'd0;
    if( nextn[0] ) m[nextn[3:1]] <= 1'b1;
    // counters
    hn <= nextn;
    //HS <= hn==9'd255+((9'd383-9'd255)>>1); // middle of blanking
    if( hn==HS1 ) begin
        HS <= 1'b1;
        //VS <= vn==8'hef && VBL;
        if( vn==VS1[7:0] && VBL ) VS <= 1'b1;
        if( vn==VS0[7:0] && VBL ) VS <= 1'b0;
    end
    if( hn==HS0 ) HS <= 1'b0;
    if( hn == 9'd255 ) begin
        HBL <= 1'b1;
    end else if( hover )begin
        HBL <= 1'b0;
        { VBL, preVBL[VBDLY-1:1] } <= preVBL;
        if( &vn ) begin
            vn <= (VBL&&!aux) ? 8'he8 : 8'h8;
        end else begin
            vn <= vn + 8'd1;
            if( vn == 8'hEF ) begin
                preVBL[0] <= 1'b1;
                aux <= VBL;
            end
        end
        if( vn == 8'hff && aux ) preVBL[0] <= 1'b0;
        //if( vn == 8'h08 ) VBL <= 1'b0;
    end
end


endmodule
