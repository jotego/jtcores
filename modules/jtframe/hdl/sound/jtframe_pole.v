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

// Single pole IIR filter
// y[k] = a * y[k-1] + (1-a) * x[k]
//
// where a = exp(-wc ), a<1
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
    output reg signed [WS-1:0] sout
);

localparam [WS-1:0] ONE={ {WS-WA-1{1'b0}}, 1'b1, {WA{1'b0}}};
reg signed [WS-1:0] factor, last_prod, fmux;

wire signed [   WS-1:0] aext = { {WS-WA{1'b0}}, a };
reg  signed [ 2*WS-1:0] prod;

always @(*) begin
    factor = sample ? (ONE-aext) : aext;
    fmux   = sample ? sin : sout;
    prod   = factor * fmux;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sout      <= 0;
        last_prod <= 0;
    end else begin
        if(sample)
            // a==0 comparison added for logic simplification in jtframe_rcmix
            // when the filter is not used and a is constant
            sout <= a==0 ? sin : last_prod + prod[WS+WA-1:WA];
        else
            last_prod <= prod[WS+WA-1:WA];
    end
end

endmodule