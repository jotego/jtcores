/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-7-2025 */

module jtframe_ff_jk #(parameter RST=0) (
    input rst, clk, cen,
          j, k,
    output reg q,q_n
);

always @(posedge clk) begin
    if(rst) begin
        q   <= RST[0];
        q_n <=~RST[0];
    end else if(cen) begin
        case({j,k})
            2'b01: {q,q_n}<=2'b01;
            2'b10: {q,q_n}<=2'b10;
            2'b11: {q,q_n}<=~{q,q_n};
            default:;
        endcase
    end
end

endmodule
