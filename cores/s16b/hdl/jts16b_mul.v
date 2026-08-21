/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 31-10-2021 */

// SEGA 315-5248 model based on MAME driver

module jts16b_mul(
    input              rst,
    input              clk,

    input      [23:1]  A,
    input      [ 1:0]  dsn,
    input              rnw,
    input              cs,
    input      [15:0]  din,

    output reg [15:0]  dout
);

reg signed [15:0] factors[0:1];
reg signed [31:0] mul;

always @(posedge clk or posedge rst) begin 
    if(rst) begin
        factors[0] <= 0;
        factors[1] <= 0;
    end else if(cs) begin
        mul <= factors[0] * factors[1];
        if( !rnw ) begin
            if( !dsn[0] ) factors[A[1]][ 7:0] <=  din[ 7:0];
            if( !dsn[1] ) factors[A[1]][15:8] <=  din[15:8];
        end
        case(A[2:1])
            0: dout <= factors[0];
            1: dout <= factors[1];
            2: dout <= mul[31:16];
            3: dout <= mul[15: 0];
        endcase
    end
end

endmodule