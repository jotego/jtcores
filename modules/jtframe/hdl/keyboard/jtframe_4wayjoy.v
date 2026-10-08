/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 10-5-2020 */

module jtframe_4wayjoy(
    input            clk,
    input            enable,
    input      [3:0] joy8way,
    output reg [3:0] joy4way
);

always @(posedge clk) begin
    if( !enable ) begin
        joy4way <= joy8way;
    end else begin
        if( joy8way==4'b0001 || joy8way==4'b0010 ||
            joy8way==4'b0100 || joy8way==4'b1000 || joy8way==4'b0000 )
            joy4way <= joy8way;
    end
end

endmodule