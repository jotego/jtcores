/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-1-2025 */

module jtframe_counter #(
    parameter W=10, RST_VAL=0
)(
    input  rst, clk, cen,  // keep port order
    output reg [W-1:0] cnt=0
);

always @(posedge clk) begin
    if( rst ) begin
        cnt <= RST_VAL[0+:W];
    end else if(cen) begin
        cnt <= cnt+1'd1;
    end
end

endmodule