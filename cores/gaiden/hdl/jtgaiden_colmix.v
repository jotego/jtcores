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

reg [4:0] sel,sel2;
wire      video;

wire txt_bn  = !( txt_pxl[3:0]==0 || !gfx_en[0]);
wire scr1_bn = !(scr1_pxl[3:0]==0 || !gfx_en[1]);
wire scr2_bn = !(scr2_pxl[3:0]==0 || !gfx_en[2]);
wire  obj_bn = !( obj_pxl[3:0]==0 || !gfx_en[3]);

wire [1:0] oprio  = obj_pxl[10:9];
wire       oblend = obj_pxl[8];
wire       sblend = scr1_pxl[8];
wire [2:0] priomx = {obj_bn,~oprio};
wire [2:0] bgopac = {txt_bn,scr1_bn,scr2_bn};

always @* begin
    sel2 = SEL_NONE;
    casez(priomx)
        3'b1_00: casez(bgopac)
             3'b1??: sel = SEL_TXT;
             3'b01?: sel = SEL_SCR1;
             3'b001: sel = SEL_SCR2;
            default: sel = SEL_OBJ;
        endcase
        3'b1_01: casez(bgopac)
             3'b1??: sel = SEL_TXT;
             3'b01?: begin sel = SEL_SCR1; sel2 = sblend ? SEL_OBJ : SEL_NONE;  end
             3'b001: begin sel = SEL_OBJ;  sel2 = oblend ? SEL_SCR2 : SEL_NONE; end
            default: sel = SEL_OBJ;
        endcase
        3'b1_10: casez(bgopac)
             3'b1??: sel = SEL_TXT;
             3'b01?: begin sel = SEL_OBJ; sel2 = oblend ? SEL_SCR1 : SEL_NONE; end
             3'b001: begin sel = SEL_OBJ; sel2 = oblend ? SEL_SCR2 : SEL_NONE; end
            default: sel = SEL_OBJ;
        endcase
        3'b1_11: sel = SEL_OBJ;
        3'b0_??: casez(bgopac)
             3'b1??: sel = SEL_TXT;
             3'b01?: sel = SEL_SCR1;
             3'b001: sel = SEL_SCR2;
            default: sel = SEL_NONE;
        endcase
    endcase
end

reg [ 4:0] amuxsel=SEL_NONE;
reg [11:0] main, other, blended, bgr;
reg        blend;

function [3:0] avg(input [3:0]a,b); begin
    reg [4:0] sum;
    sum = {1'b0,a}+{1'b0,b};
    avg = sum[4:1];
end endfunction

always @* begin
    case(amuxsel)
        SEL_TXT:  pal_addr = {TEXT, txt_pxl};
        SEL_SCR1: pal_addr = {SCR1, scr1_pxl[7:0]};
        SEL_SCR2: pal_addr = {SCR2, scr2_pxl};
        SEL_OBJ:  pal_addr = {OBJ,  obj_pxl[7:0]};
        default:  pal_addr = FILL;
    endcase
    blended = {avg(main[8+:4],other[8+:4]),
               avg(main[4+:4],other[4+:4]),
               avg(main[0+:4],other[0+:4])};
end

reg [2:0] st;

always @(posedge clk) begin
    st <= pxl_cen ? 3'd0 : (st+3'd1);
    case(st)
        1: amuxsel <= sel;
        3: begin
            main    <= pal_dout[11:0];
            amuxsel <= sel2;
            blend   <= sel2!=SEL_NONE;
        end
        5: begin
            other <= pal_dout[11:0];
        end
        6: bgr <= blend ? blended : main;
    endcase
end

assign {blue,green,red} = bgr;

endmodule
