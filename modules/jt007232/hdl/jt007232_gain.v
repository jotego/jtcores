/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-8-2021 */

module jt007232_gain(
    input                    clk,
    input                    swap_gains,   // makes ^ with REG12A below
    input             [ 7:0] reg12,
    input      signed [ 6:0] rawa, rawb,
    output reg signed [10:0] snda, sndb
);

parameter REG12A=1, NOGAIN=0;

wire signed [ 4:0] cha_gain = {1'b0,  (REG12A[0]^swap_gains) ? reg12[7:4] : reg12[3:0] };
wire signed [ 4:0] chb_gain = {1'b0, ~(REG12A[0]^swap_gains) ? reg12[7:4] : reg12[3:0] };
reg  signed [11:0] mula, mulb;

always @(posedge clk) begin
    if(NOGAIN==1) begin
        snda <= {{4{rawa[6]}},rawa};
        sndb <= {{4{rawb[6]}},rawb};
    end else begin
        snda <= rawa * cha_gain;
        sndb <= rawb * chb_gain;
    end
end

endmodule