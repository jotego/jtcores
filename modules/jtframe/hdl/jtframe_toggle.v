/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-1-2025 */

module jtframe_toggle #(parameter
    W            = 4,
    VALUE_AT_RST = 1'b0
)(
    input            rst,
    input            clk,

    input      [W-1:0] toggle,
    output reg [W-1:0] q
);

reg  [W-1:0] toggle_l;

integer cnt;

always @(posedge clk) begin
    if( rst ) begin
        q <= {W{VALUE_AT_RST[0]}};
        toggle_l  <= 0;
    end else begin
        toggle_l <= toggle;
        for(cnt=0; cnt<W; cnt=cnt+1)
            if( toggle[cnt] && !toggle_l[cnt] ) q[cnt] <= ~q[cnt];
    end
end

endmodule