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
    Date: 1-1-2025 */

module jtgaiden_colmix(
    input               clk,
    input               lvbl,
    input               pxl_cen,

    output reg   [12:1] pal_addr,
    input        [15:0] pal_dout,

    input        [ 7:0] txt_pxl, scr2_pxl,
    input        [ 8:0] scr1_pxl,
    input        [10:0] obj_pxl,
    // Colours
    output       [ 3:0] red,
    output       [ 3:0] green,
    output       [ 3:0] blue,
    // Test
    input        [ 3:0] gfx_en,
    input        [ 7:0] debug_bus
);

localparam [3:0] OBJ=0, TEXT=1, SCR1=2, SCR2=3;
localparam SEL_TXT=1,SEL_SCR1=2,SEL_SCR2=4,SEL_OBJ=8,SEL_NONE=16;
localparam [12:1] FILL={SCR1,8'd0};

reg [4:0] sel;
wire      video, blink;

wire txt_bn  = !( txt_pxl[3:0]==0 || !gfx_en[0]);
wire scr1_bn = !(scr1_pxl[3:0]==0 || !gfx_en[1]);
wire scr2_bn = !(scr2_pxl[3:0]==0 || !gfx_en[2]);
wire  obj_bn = !( obj_pxl[3:0]==0 || !gfx_en[3]);

wire [1:0] oprio  = obj_pxl[10:9];
wire       oblend = obj_pxl[8];
wire       sblend = scr1_pxl[8];

always @* begin
    casez({obj_bn,~oprio})
        3'b1_00: casez({txt_bn,scr1_bn,scr2_bn})
             3'b1??: sel = SEL_TXT;
             3'b01?: sel = SEL_SCR1;
             3'b001: sel = SEL_SCR2;
            default: sel = SEL_OBJ;
        endcase
        3'b1_01: casez({txt_bn,scr1_bn,scr2_bn})
             3'b1??: sel = SEL_TXT;
             3'b01?: sel = sblend && blink ? SEL_OBJ  : SEL_SCR1;
             3'b001: sel = oblend && blink ? SEL_SCR2 : SEL_OBJ;
            default: sel = SEL_OBJ;
        endcase
        3'b1_10: casez({txt_bn,scr1_bn,scr2_bn})
             3'b1??: sel = SEL_TXT;
             3'b01?: sel = oblend && blink ? SEL_SCR1 : SEL_OBJ;
            default: sel = SEL_OBJ;
        endcase
        3'b1_11: sel = SEL_OBJ;
        3'b0_??: casez({txt_bn,scr1_bn,scr2_bn})
             3'b1??: sel = SEL_TXT;
             3'b01?: sel = SEL_SCR1;
             3'b001: sel = SEL_SCR2;
            default: sel = SEL_NONE;
        endcase
    endcase
    case(sel)
        SEL_TXT:  pal_addr = {TEXT, txt_pxl};
        SEL_SCR1: pal_addr = {SCR1, scr1_pxl[7:0]};
        SEL_SCR2: pal_addr = {SCR2, scr2_pxl};
        SEL_OBJ:  pal_addr = {OBJ,  obj_pxl[7:0]};
        SEL_NONE: pal_addr = FILL;
    endcase
end

assign {blue,green,red} = pal_dout[11:0];

jtframe_blink u_blink(
    .clk        ( clk       ),
    .vs         ( lvbl      ),
    .en         ( 1'b1      ),
    .blink      ( blink     )
);

endmodule
