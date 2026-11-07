/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-02-2025 */

module jtframe_int_cen#(parameter CKW=3)(
    input      clk,
    output reg cen
);

reg  [CKW-1:0] cnt=0;

always @(posedge clk) begin
    cnt <=  cnt + 1'b1;
    cen <= &cnt;
end

endmodule
