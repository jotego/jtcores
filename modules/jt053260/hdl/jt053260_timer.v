/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-8-2025 */

// generates a fixed frequency output used as a timer by the Z80
module jt053260_timer(
    input                    rst,
    input                    clk,
    input                    cen,
    output reg               tim2 // 2ms period for a cen&clk of 3.57 MHz
);

reg [12:0] cnt;
wire       over = cnt==7167;

always @(posedge clk) begin
    if(rst) begin
        cnt <= 0;
    end else if(cen) begin
        tim2 <= over;
        cnt  <= over ? 13'd0 : cnt+13'd1;
    end
end

endmodule