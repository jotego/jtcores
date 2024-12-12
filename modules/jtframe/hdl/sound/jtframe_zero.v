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

// Single zero IIR filter
// y[k] = a * (x[k]-x[k-1]) + (1-a) * y[k-1]
//
// where a = wc/(1+wc)
// wc = radian normalized frequency = 2*pi*fc/fs
// fc = cut-off frequency, fs = sampling frequency
// There is no overflow check

module jtframe_zero #(parameter
    WS=16,      // Assuming that the signal is fixed point
    WA=WS/2     // WA is only the decimal part
)(
    input                      rst,
    input                      clk,
    input                      sample,  // cannot be a fixed 1
    input      signed [WS-1:0] sin,
    input             [WA-1:0] a,       // coefficient, unsigned
    output reg signed [WS-1:0] sout
);

localparam [WS-1:0] ONE={ {WS-WA-1{1'b0}}, 1'b1, {WA{1'b0}}};
reg signed [WS-1:0] factor, prod_l, fmux, sin_l, delta;
reg signed [WS  :0] diff;

wire signed [   WS-1:0] aext = { {WS-WA{1'b0}}, a };
reg  signed [ 2*WS-1:0] prod;

always @(*) begin
    diff   = {sin[WS-1],sin}-{sin_l[WS-1],sin_l};
    delta  = diff[WS]!=diff[WS-1] ? {diff[WS],{WS-1{~diff[WS-1]}}} : diff[WS-1:0]; // prevent overflow
    factor = sample ? aext  : (ONE-aext);
    fmux   = sample ? delta : sout;
    prod   = factor * fmux;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sout   <= 0;
        prod_l <= 0;
    end else begin
        if(sample) begin
            sin_l <= sin;
            sout  <= prod[WS+WA-1:WA]+prod_l;
        end else begin // calculate (1-a)*y[k-1]
            prod_l <= prod[WS+WA-1:WA];
        end
    end
end

endmodule