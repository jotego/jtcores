/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-4-2026 */

module jtcps3_pixel(
    input       [31:0]  w0,
    input       [31:0]  w1,
    input       [31:0]  w2,
    input       [31:0]  w3,
    input       [ 3:0]  px,

    output reg  [ 7:0]  pxl
);

wire [31:0] word_sel;

assign word_sel = px[3:2] == 2'd0 ? w0 :
                  px[3:2] == 2'd1 ? w1 :
                  px[3:2] == 2'd2 ? w2 : w3;

always @(*) begin
    case( px[1:0] )
        2'd1: pxl = word_sel[7:0];
        2'd0: pxl = word_sel[15:8];
        2'd3: pxl = word_sel[23:16];
        default: pxl = word_sel[31:24];
    endcase
end

endmodule
