/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-6-2025 */

module jtlgtnfght_com(
    input                clk,
    input                cs,
    input          [1:0] dsn,
    input                rnw,
    input         [15:0] din,
    output reg    [ 2:0] cl,        // brightness
    output reg           sndon, vromrd
);

always @(posedge clk) begin
    if(!dsn[0] && !rnw && cs) begin
        {cl,vromrd,sndon} <= din[6:2];
    end
end

endmodule
