/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-1-2021 */

module jtframe_enlarger(
    input      rst,
    input      clk,
    input      cen,
    input      pulse_in,
    output reg pulse_out
);

parameter W=14;

localparam [W-1:0] ZERO={W{1'b0}};

reg  [W-1:0] cnt;
reg  [1:0] pin_s;
wire       psync;

assign psync = pin_s[1];

// synchronizer as pulse_in may come from
// a different domain
always @(posedge clk) begin
    pin_s <= { pin_s[0], pulse_in };
end

always @(posedge clk, posedge rst) begin
    if(rst) begin
        cnt       <= ~ZERO;
        pulse_out <= 0;
    end else begin
        pulse_out <= cnt != ZERO || psync;
        if( psync )
            cnt <= ~ZERO;
        else if( cnt!=ZERO && cen )
            cnt <= cnt - 1'd1;
    end
end


endmodule