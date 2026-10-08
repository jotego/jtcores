/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-1-2025 */

// makes consequitive requests and 
// converts 16 bit data to 32 bits
module jtframe_bram_burst(
    input             clk,

    output reg        sel,
    input      [15:0] din16,
    output reg [31:0] dout32
);

reg [15:0] hihalf;

always @(posedge clk) begin
    sel <= ~sel;
    if(!sel)
        hihalf <= din16;
    else
        dout32 <= {hihalf,din16};
end

endmodule    