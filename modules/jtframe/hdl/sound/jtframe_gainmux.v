/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 10-1-2025 */

module jtframe_gainmux(
    input            clk,
    input      [2:0] sel,
    output reg [7:0] g0,g1,g2,g3,g4,g5
);

parameter CH=6; // do not change when instantiating
// gains for each sel code, all channels appear concatenated
parameter [CH*8-1:0] GAME0=0,GAME1=0,GAME2=0,GAME3=0,
                     GAME4=0,GAME5=0,GAME6=0,GAME7=0;

always @(posedge clk) begin
    case(sel)
        0: {g5,g4,g3,g2,g1,g0} <= GAME0;
        1: {g5,g4,g3,g2,g1,g0} <= GAME1;
        2: {g5,g4,g3,g2,g1,g0} <= GAME2;
        3: {g5,g4,g3,g2,g1,g0} <= GAME3;
        4: {g5,g4,g3,g2,g1,g0} <= GAME4;
        5: {g5,g4,g3,g2,g1,g0} <= GAME5;
        6: {g5,g4,g3,g2,g1,g0} <= GAME6;
        7: {g5,g4,g3,g2,g1,g0} <= GAME7;
    endcase
end

endmodule