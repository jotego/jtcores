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
    Date: 6-7-2025 */

module jtrungun_colmix(
    input             rst, clk, pxl_cen,

    // Base Video
    input             lhbl, lvbl, lrsw,

    output     [11:1] pal_addr,
    input      [15:0] pal_dout,
    // Final pixels
    input      [ 1:0] shadow,
    input      [ 8:0] obj_pxl,
    input      [ 7:0] fix_pxl,

    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    // Debug
    // input      [11:0] ioctl_addr,
    // input             ioctl_ram,
    // output     [ 7:0] ioctl_din,
    // output     [ 7:0] dump_mmr,

    input      [ 7:0] debug_bus
);

reg  [23:0] bgr;
reg  [ 7:0] r8, b8, g8;
wire        shad, fix_op;

assign {blue,green,red} = (lvbl & lhbl ) ? bgr : 24'd0;
assign fix_op   = fix_pxl[3:0]!=0;
assign pal_addr =  fix_op ? {lrsw,2'd0,fix_pxl} : {lrsw,1'b0,obj_pxl};

assign shad      = 0; // to do

function [7:0] conv58(input [4:0] cin );
begin
    conv58 = {cin, cin[4-:3]};
end
endfunction

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bgr   <= 0;
    end else begin
        { b8, g8, r8 } <= {conv58(pal_dout[10+:5]),conv58(pal_dout[5+:5]),conv58(pal_dout[0+:5])};
        if( pxl_cen ) bgr <= ~shad ? { b8, g8, r8 } : { b8>>1, g8>>1, r8>>1 };
    end
end

endmodule