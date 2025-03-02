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
    Date: 2-3-2025 */

module jtgaiden_priority(
    input        [ 7:0] txt_pxl, scr2_pxl,
    input        [ 8:0] scr1_pxl,
    input        [10:0] obj_pxl,
    // palette address mux select signals
    output reg   [ 4:0] sel, sel2,
    // Test
    input        [ 3:0] gfx_en
);

`include "jtgaiden_colmix.vh"

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
             3'b01?: begin sel = SEL_SCR1; sel2 = sblend ? SEL_OBJ  : SEL_NONE; end
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

endmodule