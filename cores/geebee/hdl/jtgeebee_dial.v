/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-11-2026 */

module jtgeebee_dial #(
    parameter [7:0] LOW    = 8'h10,
    parameter [7:0] CENTER = 8'h58,
    parameter [7:0] HIGH   = 8'ha0
)(
    input            clk,
    input            rst,
    input            recenter,
    input      [1:0] dial,
    output reg [7:0] pos
);

reg [1:0] last;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        last <= 2'b00;
        pos  <= CENTER;
    end else begin
        last <= dial;
        if (recenter) pos <= CENTER;
        else if (dial == {last[0], ~last[1]} && pos > LOW)
            pos <= pos - 1'b1;
        else if (dial == {~last[0], last[1]} && pos < HIGH)
            pos <= pos + 1'b1;
    end
end

endmodule
