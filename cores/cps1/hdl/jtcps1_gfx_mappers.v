/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR a PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-1-2020 */


// A[22:20]   Usage
// 000        OBJ
// 001        SCROLL 1
// 010        SCROLL 2
// 011        SCROLL 3
// 100        Star field

module jtcps1_gfx_mappers(
    input              clk,
    input              rst,

    input      [ 5:0]  game,
    input      [15:0]  bank_offset,
    input      [15:0]  bank_mask,

    input      [ 2:0]  layer,
    input      [ 9:0]  cin,    // pins 2-9, 11,13,15,17,18

    output reg [ 3:0]  offset,
    output reg [ 3:0]  mask,
    output reg         unmapped
);

localparam [2:0] OBJ=3'd0, SCR1=3'd1, SCR2=3'd2, SCR3=3'd3, STARS=3'd4;

reg  [ 3:0]  bank_a, bank_b;
reg          set_used;

wire [15:6] code = cin;

reg last_enable;
wire [3:0] eff_bank = set_used ? bank_b : bank_a;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        unmapped <= 1'b1;
        offset   <= 4'd0;
        mask     <= 4'd0;
    end else begin
        unmapped <= eff_bank==4'd0; // no bank was selected
        case ( eff_bank )
            4'b0001: { offset, mask } <= { bank_offset[ 3: 0], bank_mask[ 3: 0] };
            4'b0010: { offset, mask } <= { bank_offset[ 7: 4], bank_mask[ 7: 4] };
            4'b0100: { offset, mask } <= { bank_offset[11: 8], bank_mask[11: 8] };
            4'b1000: { offset, mask } <= { bank_offset[15:12], bank_mask[15:12] };
            default: { offset, mask } <= { 4'h0, 4'hf };
        endcase
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank_a   <= 4'd0;
        bank_b   <= 4'd0;
        set_used <= 1'b0;
    end else begin
        case( game )
            default: begin
                bank_a   <= 4'd1;
                bank_b   <= 4'd0;
                set_used <= 1'b0;
            end
            `ifndef CPS2
                `ifdef CPS15
                /* verilator lint_off CMPCONST */
                /* verilator lint_off WIDTH */
                `endif
                `include "mappers.inc"
                /* verilator lint_on CMPCONST */
                /* verilator lint_on WIDTH */
            `endif
        endcase
    end
end


endmodule