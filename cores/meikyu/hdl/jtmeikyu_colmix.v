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
    Date: 1-5-2022 */

/* Meikyu Jima has no background layer: the char tilemap is the opaque bottom
   layer and sprites go on top (MAME screen_update_kikcubic). Both layers index
   palette pens 0-255, so the bank select stays low.
*/

module jtmeikyu_colmix(
    input            rst,
    input            clk,

    input            pxl_cen,
    input            LHBL,
    input            LVBL,

    input      [7:0] scr1_pxl,
    input      [7:0] obj_pxl,

    input      [7:0] debug_bus,
    // Palette RAM
    output    [10:0] pal_addr,
    input     [ 7:0] pal_dout,

    // Debug
    input      [3:0] gfx_en,

    output reg [4:0] red,
    output reg [4:0] green,
    output reg [4:0] blue
);

localparam OBJ=0;

wire        obj_blank;
reg  [ 2:0] sub;
reg  [ 7:0] pal_base;
reg  [ 4:0] pre_r, pre_g, pre_b;

assign obj_blank  = obj_pxl[3:0]==0 || !gfx_en[3];
// RGB channel = sub[1:0] (0=R,1=G,2=B). Reading one channel per clock finishes
// by sub==3, leaving margin before pxl_cen. Two clocks/channel would latch blue
// at sub==5, which coincides with pxl_cen at 6 clk/pxl -> blue lags one pixel.
assign pal_addr   = { OBJ[0], sub[1:0], pal_base };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sub   <= 0;
        red   <= 0;
        green <= 0;
        blue  <= 0;
    end else begin
        sub <= pxl_cen ? 3'd0 : sub + 3'd1;
        `ifndef GRAY
        case( sub )
            3'd1: pre_r <= pal_dout[4:0]; // dout of R addr @sub0
            3'd2: pre_g <= pal_dout[4:0]; // G @sub1
            3'd3: pre_b <= pal_dout[4:0]; // B @sub2
            default:;
        endcase
        `else
            pre_r <= { pal_addr[3:0], 1'b0 };
            pre_g <= { pal_addr[3:0], 1'b0 };
            pre_b <= { pal_addr[3:0], 1'b0 };
        `endif
        if( pxl_cen ) begin
            { red, green, blue } <= ( !LVBL || !LHBL ) ? 15'd0 : {pre_r, pre_g, pre_b};
            // char is opaque under the sprites
            pal_base <= obj_blank ? scr1_pxl : obj_pxl;
        end
    end
end

endmodule
