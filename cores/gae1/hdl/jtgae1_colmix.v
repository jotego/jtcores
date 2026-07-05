/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-7-2026 */

module jtgae1_colmix (
    input        clk,
    input        pxl_cen,
    input        squash,
    input        bigkarnk,
    input [3:0]  gfx_en,

    input [11:0] scr0_pxl,
    input [11:0] scr1_pxl,

    output reg  [9:0]  color_addr,
    input [15:0] color_data,

    input [12:0] obj_pxl,
    output [9:0]  spr_color_addr,
    input [15:0] spr_color_data,

    output [4:0]  red,
    output [4:0]  green,
    output [4:0]  blue
);

localparam integer SPN     = 12;
localparam integer SPR_DLY = SPN-2;

function [4:0] rank;
input        layer;
input        isback;
input [1:0]  cat;
case ({cat, layer, isback})
    {2'd3,1'b1,1'b1}: rank=5'd0;  {2'd3,1'b1,1'b0}: rank=5'd1;
    {2'd3,1'b0,1'b1}: rank=5'd2;  {2'd3,1'b0,1'b0}: rank=5'd3;
    {2'd2,1'b1,1'b1}: rank=5'd4;  {2'd2,1'b1,1'b0}: rank=5'd5;
    {2'd2,1'b0,1'b1}: rank=5'd6;  {2'd2,1'b0,1'b0}: rank=5'd7;
    {2'd1,1'b1,1'b1}: rank=5'd8;  {2'd1,1'b0,1'b1}: rank=5'd9;
    {2'd1,1'b1,1'b0}: rank=5'd10; {2'd1,1'b0,1'b0}: rank=5'd11;
    {2'd0,1'b1,1'b1}: rank=5'd12; {2'd0,1'b1,1'b0}: rank=5'd13;
    {2'd0,1'b0,1'b1}: rank=5'd14; default:              rank=5'd15;
endcase
endfunction

function [3:0] pri_code;
input       isback;
input [1:0] cat;
begin
    if (isback) begin
        pri_code = cat == 2'd3 ? 4'd0 :
                   cat == 2'd2 ? 4'd1 :
                   cat == 2'd1 ? 4'd2 : 4'd4;
    end else begin
        pri_code = cat == 2'd3 ? 4'd1 :
                   cat == 2'd2 ? 4'd2 :
                   cat == 2'd1 ? 4'd4 : 4'd8;
    end
end
endfunction

wire [ 5:0] pal0 = scr0_pxl[ 9: 4];
wire [ 5:0] pal1 = scr1_pxl[ 9: 4];
wire [ 3:0] pen0 = scr0_pxl[ 3: 0];
wire [ 3:0] pen1 = scr1_pxl[ 3: 0];
wire [ 1:0] cat0 = scr0_pxl[11:10];
wire [ 1:0] cat1 = scr1_pxl[11:10];
wire        opaque0 = gfx_en[1] & (pen0 != 4'd0);
wire        opaque1 = gfx_en[2] & (pen1 != 4'd0);

wire [ 4:0] rank0 = rank(1'b0, pen0[3], cat0);
wire [ 4:0] rank1 = rank(1'b1, pen1[3], cat1);
wire [ 3:0] pri0  = opaque0 ? pri_code(pen0[3], cat0) : 4'd0;
wire [ 3:0] pri1  = opaque1 ? pri_code(pen1[3], cat1) : 4'd0;
wire        l0_wins = opaque0 & (~opaque1 | (rank0 >= rank1));
reg  [ 4:0] win_rank;
reg  [ 3:0] win_prio;
reg        win_opaque;

always @(posedge clk) if (pxl_cen) begin
    win_prio <= pri0 | pri1;
    if (opaque0 & l0_wins) begin
        color_addr <= { pal0, pen0 };
        win_rank   <= rank0;
        win_opaque <= 1'b1;
    end else if (opaque1) begin
        color_addr <= { pal1, pen1 };
        win_rank   <= rank1;
        win_opaque <= 1'b1;
    end else begin
        color_addr <= 10'd0;
        win_rank   <= 5'd0;
        win_opaque <= 1'b0;
    end
end

reg [12:0] spr_sr [0:SPR_DLY];
integer ss;
always @(posedge clk) if (pxl_cen) begin
    spr_sr[0] <= obj_pxl;
    for (ss=1; ss<=SPR_DLY; ss=ss+1) spr_sr[ss] <= spr_sr[ss-1];
end

wire [5:0] spr_color = spr_sr[SPR_DLY][9:4];
wire [3:0] spr_pen_a = spr_sr[SPR_DLY][3:0];
assign spr_color_addr = { spr_color, spr_pen_a };

wire [3:0] spr_pen = spr_sr[SPR_DLY][3:0];
wire [2:0] spr_pri = spr_sr[SPR_DLY][12:10];

reg  [4:0] win_rank_d;
reg  [3:0] win_prio_d;
reg        win_opaque_d;
always @(posedge clk) if (pxl_cen) begin
    win_rank_d   <= win_rank;
    win_prio_d   <= win_prio;
    win_opaque_d <= win_opaque;
end

wire [4:0] spr_thresh = (spr_pri == 3'd0) ? 5'd12 :
                         (spr_pri == 3'd1) ? 5'd10 :
                         (spr_pri == 3'd2) ? 5'd8  :
                         (spr_pri == 3'd3) ? 5'd4  : 5'd31;
wire [15:0] spr_mask   = (spr_pri == 3'd0) ? 16'hff00 :
                          (spr_pri == 3'd1) ? 16'hfff0 :
                          (spr_pri == 3'd2) ? 16'hfffc :
                          (spr_pri == 3'd3) ? 16'hfffe : 16'h0000;
wire [4:0] spr_rank    = squash ? win_rank   : win_rank_d;
wire       spr_opaque  = squash ? win_opaque : win_opaque_d;
wire       bigkarnk_spr_blocked = win_opaque_d & (((16'd1 << win_prio_d) & spr_mask) != 16'd0);
wire       gae1_spr_blocked     = spr_opaque & (spr_rank >= spr_thresh);
wire       spr_occluded         = bigkarnk ? bigkarnk_spr_blocked : gae1_spr_blocked;
wire       spr_show     = gfx_en[3] & (spr_pen != 4'd0) & ~spr_occluded;

wire [4:0] red_scr   = color_data[4:0];
wire [4:0] green_scr = color_data[9:5];
wire [4:0] blue_scr  = color_data[14:10];
wire [4:0] red_spr   = spr_color_data[4:0];
wire [4:0] green_spr = spr_color_data[9:5];
wire [4:0] blue_spr  = spr_color_data[14:10];

wire [4:0] red_mix   = spr_show ? red_spr   : red_scr;
wire [4:0] green_mix = spr_show ? green_spr : green_scr;
wire [4:0] blue_mix  = spr_show ? blue_spr  : blue_scr;

assign red   = red_mix;
assign green = green_mix;
assign blue  = blue_mix;

endmodule
