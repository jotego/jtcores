/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 11-1-2019 */

module jtgng_objdraw(
    input              rst,
    input              clk,     // 24 MHz
    input              cen6,    //  6 MHz
    // screen
    input       [7:0]  VF,
    input       [3:0]  pxlcnt,
    output reg  [8:0]  posx,
    input              flip,
    // per-line sprite data
    input       [4:0]  objcnt,
    input       [7:0]  objbuf_data,
    // SDRAM interface
    output  reg [15:0] obj_addr,
    input       [15:0] objrom_data,
    // pixel data
    output      [1:0]  pospal,
    output reg  [3:0]  new_pxl
);

reg [7:0] ADlow;
reg [1:0] objpal;
reg [1:0] ADhigh;
reg [7:0] objy, objx;
// reg [7:0] VB;
wire [7:0] posy;
wire [8:0] objx2;
reg obj_vflip, obj_hflip, hover;
wire posvflip, poshflip;
reg vinzone;
wire vinzone2;

jtgng_sh #(.width(8), .stages(3)) sh_objy (.clk(clk), .clk_en(cen6), .din(objy), .drop(posy));
jtgng_sh #(.width(9), .stages(3)) sh_objx (.clk(clk), .clk_en(cen6), .din({hover,objx}), .drop(objx2));
//jtgng_sh #(.width(1), .stages(4)) sh_objv (.clk(clk), .clk_en(cen6), .din(obj_vflip), .drop(posvflip));
jtgng_sh #(.width(1), .stages(5)) sh_objh (.clk(clk), .clk_en(cen6), .din(obj_hflip), .drop(poshflip));

reg poshflip2;
always @(posedge clk) if(cen6) begin
    poshflip2 <= poshflip;
end

jtgng_sh #(.width(2), .stages(7)) sh_objp (.clk(clk), .clk_en(cen6), .din(objpal), .drop(pospal));
jtgng_sh #(.width(1), .stages(4)) sh_objz (.clk(clk), .clk_en(cen6), .din(vinzone), .drop(vinzone2));

reg [7:0] Vsum;

always @(*) begin
    Vsum = (~VF + { {7{~flip}}, 1'b1})+objy; // this is equivalent to
    // 2's complement of VF plus object's Y, i.e. a subtraction
    // but flip is used to make it work with flipped screens
    // This is the same formula used on the schematics
    // VB = VF-objy;
    //vinzone = (VF>=objy) && (VF<(objy+8'd16));
    vinzone = &Vsum[7:4];
end

always @(posedge clk) if(cen6) begin
    case( pxlcnt[3:0] )
        4'd0: ADlow   <= objbuf_data;
        4'd1: begin
            ADhigh    <= objbuf_data[7:6];
            objpal    <= objbuf_data[5:4];
            obj_vflip <= objbuf_data[3];
            obj_hflip <= objbuf_data[2];
            hover     <= objbuf_data[0];
        end
        4'd2: begin
            objy <= objbuf_data;
        end
        4'd3: begin
            objx <= objbuf_data;
        end
        default:;
    endcase
    if( pxlcnt[1:0]==2'd3 ) begin
        obj_addr <= (!vinzone || objcnt==5'd0) ? 16'd0 :
            { ADhigh, ADlow, pxlcnt[3]^obj_hflip, Vsum[3:0]^{4{~obj_vflip}}, pxlcnt[2]^obj_hflip };
    end
end


// ROM data depacking

reg [3:0] z,y,x,w;

always @(posedge clk) if(cen6) begin
    new_pxl <= poshflip2 ? {w[0],x[0],y[0],z[0]} : {w[3],x[3],y[3],z[3]};
    posx    <= pxlcnt[3:0]==4'h8 ? objx2 : posx + 1'b1;
    case( pxlcnt[3:0] )
        4'd3,4'd7,4'd11,4'd15:  // new data
                {z,y,x,w} <= vinzone2 ? objrom_data[15:0] : 16'hffff;
        default:
            if( poshflip ) begin
                z <= z >> 1;
                y <= y >> 1;
                x <= x >> 1;
                w <= w >> 1;
            end else begin
                z <= z << 1;
                y <= y << 1;
                x <= x << 1;
                w <= w << 1;
            end
    endcase
end

endmodule // jtgng_objdraw