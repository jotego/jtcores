/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-1-2025 */

module jtframe_mmr_reg #(parameter W=8)(
    // do not change port order
    // as this module is intended for direct instantiation
    input rst,
    input clk,
    input wr_n,
    input [W-1:0] din,
    input cs,
    output reg [W-1:0] dout
);

always @(posedge clk) begin
    if(rst) begin
        dout <= 0;
    end else begin
        if( cs && !wr_n ) dout <= din;
    end
end

endmodule
