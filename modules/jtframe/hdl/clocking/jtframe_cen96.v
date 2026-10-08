/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 6-12-2019 */

// Input clock must be 96 MHz
// Generates various clock enable signals

module jtframe_cen96(
    input   clk,    // 96 MHz
    output  reg cen16,
    output  reg cen8,
    output  reg cen12,
    output  reg cen6,
    output  reg cen6b
);

reg [3:0] cencnt12 = 4'd0;
reg [3:0] cencnt16 = 4'd0;

always @(posedge clk) begin
    cencnt12 <= cencnt12==4'd11 ? 4'd0 : cencnt12+4'd1;
    cencnt16 <= cencnt16 + 1'd1;
end

always @(posedge clk) begin
    cen16  <= cencnt12 == 4'd0 || cencnt12 == 4'd6;
    cen8   <= cencnt12 == 4'd0;
    cen12  <= cencnt16 == 4'd0 || cencnt16 == 4'd8;
    cen6   <= cencnt16 == 4'd0;
    cen6b  <= cencnt16 == 4'd8;
end
endmodule
