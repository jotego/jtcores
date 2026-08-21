/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-2-2024 */

module jtframe_rsthold(
    input      rst,
    input      clk,
    input      hold,
    output reg rst_h,
    input      rst24,
    input      clk24,
    output reg rst24_h
`ifdef JTFRAME_CLK48 ,
    input      rst48,
    input      clk48,
    output reg rst48_h
`endif    
);

always @(posedge clk) begin
    rst_h <= rst || hold;
end

reg hold24;
always @(posedge clk24) begin
    hold24  <= hold;
    rst24_h <= rst24 || hold24;
end
`ifdef JTFRAME_CLK48
reg hold48;
always @(posedge clk48) begin
    hold48  <= hold;
    rst48_h <= rst48 || hold48;
end
`endif

endmodule
