/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 11-5-2021 */


// Based on Furrtek's finding
// https://github.com/furrtek/VGChips/tree/master/Konami/007452

module jtcontra_007452(
    input            rst,
    input            clk,
    input            cs,
    input            wrn,
    input      [2:0] addr,
    input      [7:0] din,
    output reg [7:0] dout
);

reg [6:0] factor_A;
reg [7:0] factor_B;
reg [15:0] dividend, divaux, divisor, rmnd, quo;
wire [31:0] divfull = {divaux, dividend};
wire [16:0] divstep = {1'b0,divfull[31:16]}-divisor;

reg [15:0] mul;
reg [ 4:0] cnt;
reg        start_mul;

always @(*) begin
    case( addr )
        0: dout = mul[7:0];
        1: dout = mul[15:8];
        2: dout = rmnd[7:0];
        3: dout = rmnd[15:8];
        4: dout = quo[7:0];
        5: dout = quo[15:8];
        default: dout = 0;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        factor_A  <= 0;
        factor_B  <= 0;
        divisor   <= 0;
        dividend  <= 0;
        divaux    <= 0;
        start_mul <= 0;
        cnt       <= 0;
    end else begin
        start_mul <= 0;
        if( start_mul ) mul <= factor_B * {1'b0, factor_A };
        // division
        if( { cnt[4], cnt[0] } != 2'b11 ) begin
            quo <= { quo[14:0],~divstep[16] };
            if( !divstep[16] )
                { divaux, dividend } <= { divstep[14:0], dividend,1'b0 };
            else
                { divaux, dividend } <= divfull<<1;
            if( cnt[4] ) rmnd <= divstep[16] ? divaux : divstep[15:0];
            cnt <= cnt+1'd1;
        end
        // Bus access
        if( cs && !wrn ) begin
            case( addr )
                0: factor_A <= din[6:0];
                1: begin
                    factor_B  <= din;
                    start_mul <= 1;
                end
                2: divisor[15:8] <= din;
                3: divisor[ 7:0] <= din;
                4: dividend[15:8] <= din;
                5: begin
                    dividend[ 7:0] <= din;
                    rmnd   <= { dividend[15:8], din };
                    divaux <= 0;
                    cnt <= 0;
                    quo <= 0;
                end
            endcase
        end
    end
end

endmodule