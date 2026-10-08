/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-1-2025 */

module jtgaiden_scroll_adder(
    input             clk,
    input      [15:0] din,
    input      [ 1:0] dsn,
    input             wr_n,
    input             cs,
    input             short_en,
    input             long_en,
    output reg [15:0] scroll
);

reg  [ 7:0] short;
reg  [15:0] long;

always @(posedge clk) begin
    scroll <= long - {8'd0,short};
   if( cs && short_en && !wr_n && !dsn[0] ) short      <= din[7:0];
   if( cs && long_en  && !wr_n && !dsn[0] ) long[ 7:0] <= din[7:0];
   if( cs && long_en  && !wr_n && !dsn[0] ) long[15:8] <= din[15:8];
end

endmodule