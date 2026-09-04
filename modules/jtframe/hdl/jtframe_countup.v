/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-02-2025 */

module jtframe_countup #(
    parameter W=10
)(
    input  rst, clk, cen,  // keep port order
    output reg v=0
);

reg [W-1:0] cnt=0;

always @(posedge clk) begin
    if( rst ) begin
        cnt <= 0;
        v   <= 0;
    end else if(cen) begin
        if(!v) {v,cnt} <= {v,cnt}+1'd1;
    end
end

endmodule
