/* This file is part of JTFRAME.


    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-1-2021

*/

// First order high-pass IIR filter
// y[k] = b * (x[k]-x[k-1]) - a * y[k-1]
//
// Ωc=tan(pi*fc/fs)
// b=1/(1+Ωc), a=abs((Ωc-1)/(Ωc+1))
// fc = cut-off frequency, fs = sampling frequency

module jtframe_hipass #(parameter
    WS=16,      // Assuming that the signal is fixed point
    WA=WS/2     // WA is only the decimal part
)(
    input                      rst,
    input                      clk,
    input                      sample,  // cannot be a fixed 1
    input      signed [WS-1:0] sin,
    input             [WA-1:0] a,       // denominator coefficient, unsigned
    input             [WA-1:0] b,       // numerator coefficient, unsigned
    output reg signed [WS-1:0] sout
);

reg signed [WS-1:0] factor, prod_l, fmux, sin_l, delta;
reg signed [WS  :0] diff, sum;

wire signed [   WS-1:0] aext = { {WS-WA{1'b0}}, a };
wire signed [   WS-1:0] bext = { {WS-WA{1'b0}}, b };
reg  signed [ 2*WS-1:0] prod;
reg v, v2;

always @(*) begin
    diff   = {sin[WS-1],sin}-{sin_l[WS-1],sin_l};
    v      = diff[WS]!=diff[WS-1];
    delta  = v ? {diff[WS],{WS-1{~diff[WS]}}} : diff[WS-1:0]; // prevent overflow
    factor = sample ? bext  : aext;
    fmux   = sample ? delta : sout;
    prod   = factor * fmux;
    sum    = {prod[WS+WA-1],prod[WS+WA-1:WA]}+{prod_l[WS-1],prod_l};
    v2     = sum[WS]!=sum[WS-1];
end

always @(posedge clk) begin
    if( rst ) begin
        sout   <= 0;
        prod_l <= 0;
    end else begin
        if(sample) begin
            sin_l <= sin;
            sout  <= v2 ? {sum[WS],{WS-1{~sum[WS]}}} : sum[WS-1:0];
        end else begin // calculate (1-a)*y[k-1]
            prod_l <= prod[WS+WA-1:WA];
        end
    end
end

endmodule