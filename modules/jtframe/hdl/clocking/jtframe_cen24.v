/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 6-12-2019 */

// Input clock must be 24 MHz
// Generates various clock enable signals

module jtframe_cen24(
    input   clk,    // 24 MHz
    output  reg cen12,
    output      cen8,
    output  reg cen6,
    output  reg cen4,
    output  reg cen3,
    output  reg cen3q, // 1/4 advanced with respect to cen3
    output  reg cen1p5,
    // 180 shifted signals
    output  reg cen12b,
    output  reg cen6b,
    output  reg cen3b,
    output  reg cen3qb,
    output  reg cen1p5b
);

reg [3:0] cencnt =4'd0;
reg [2:0] cencnt3=3'd0;
reg [2:0] cencnt8=3'd1;

assign cen8 = cencnt8[2];

always @(posedge clk) begin
    cencnt  <= cencnt+4'd1;
    cencnt3 <= cencnt3==3'd5 ? 3'd0 : (cencnt3+3'd1);
    cencnt8 <= { cencnt8[1:0], cencnt8[2] };
end

always @(posedge clk) begin
    cen12  <= cencnt[0] == 1'd0;
    cen12b <= cencnt[0] == 1'd1;
    cen4   <= cencnt3     == 3'd0;
    cen6   <= cencnt[1:0] == 2'd0;
    cen6b  <= cencnt[1:0] == 2'd2;
    cen3   <= cencnt[2:0] == 3'd0;
    cen3b  <= cencnt[2:0] == 3'h4;
    cen3q  <= cencnt[2:0] == 3'b110;
    cen3qb <= cencnt[2:0] == 3'b010;
    cen1p5 <= cencnt[3:0] == 4'd0;
    cen1p5b<= cencnt[3:0] == 4'b1000;
end
endmodule
