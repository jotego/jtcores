/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-1-2021 */

// Single pole IIR filter
// y[k] = a * y[k-1] + (1-a) * x[k]
//
// where a = 1/(1+wc), a<1
// wc = radian normalized frequency = 2*pi*fc/fs
// fc = cut-off frequency, fs = sampling frequency
// There is no overflow check

module jtframe_pole #(parameter
    WS=16,      // Assuming that the signal is fixed point
    WA=WS/2     // WA is only the decimal part
)(
    input                      rst,
    input                      clk,
    input                      sample,
    input      signed [WS-1:0] sin,
    input             [WA-1:0] a,    // coefficient, unsigned
    output     signed [WS-1:0] sout
);

localparam [WS-1:0] ONE={ {WS-WA-1{1'b0}}, 1'b1, {WA{1'b0}}};
reg signed [WS  :0] insum, full_out, fmux;
reg signed [WS-1:0] sin_l, factor;

wire signed [   WS-1:0] aext = { {WS-WA{1'b0}}, a };
reg  signed [ 2*WS-1:0] prod, last_prod, sum;

assign sout = full_out[WS:1]; // drop LSB

always @(*) begin
    insum  = {sin[WS-1],sin}+{sin_l[WS-1],sin_l};
    factor = sample ? (ONE-aext) : aext;
    fmux   = sample ? insum : full_out;
    prod   = factor * fmux;
    sum    = last_prod + prod;  // using 2*WS for less rounding error
end

always @(posedge clk) begin
    if( rst ) begin
        sin_l     <= 0;
        full_out  <= 0;
        last_prod <= 0;
    end else begin
        if(sample) begin
            sin_l <= sin;
            // a==0 comparison added for logic simplification in jtframe_rcmix
            // when the filter is not used and a is constant
            full_out <= a==0 ? {sin,1'b0} : sum[WS+WA:WA];
        end else begin
            last_prod <= prod;
        end
    end
end

endmodule