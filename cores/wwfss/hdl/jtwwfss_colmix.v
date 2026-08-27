/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 31-8-2024 */

module jtwwfss_colmix(
    input           clk,
    input           LHBL,
    input           LVBL,

    input    [ 6:0] char_pxl,
    input    [ 6:0] scr_pxl,
    input    [ 6:0] obj_pxl,

    output reg [9:1] pal_addr,
    input    [15:0] pal_dout,
    output   [ 3:0] red, green, blue,

    input    [ 3:0] gfx_en
);

wire        char_blank, obj_blank;

assign {blue,green,red} = LVBL && LHBL ? pal_dout[11:0] : 12'd0;
assign char_blank = !gfx_en[0] || char_pxl[3:0]==0;
assign obj_blank  = !gfx_en[3] ||  obj_pxl[3:0]==0;
// assign scr_blank  = gfx_en[1] || char_pxl[3:0]==0;

always @* begin
    casez( {char_blank, obj_blank} )
        2'b0?: pal_addr = { 2'b00, gfx_en[0] ? char_pxl: 7'd0 };
        2'b10: pal_addr = { 2'b01, gfx_en[3] ? obj_pxl : 7'd0 };
        2'b11: pal_addr = { 2'b10, gfx_en[1] ? scr_pxl : 7'd0 };
    endcase
end

endmodule