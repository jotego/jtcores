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

// Second order IIR filter
module jtframe_iir2 #(parameter
    WS=14,
    G = 4   // Gain = 2^G, G>0 needed for unity gain depending on
            // coefficient scaling
)(
    input                      rst,
    input                      clk,
    input                      sample,
    input      signed [WS-1:0] sin,
    input      signed [WS-1:0] b0,b1,b2,a1,a2,    // coefficients (a0=1)
    output     signed [WS-1:0] sout
);

reg  signed [WS-1:0] x1, x2, y0, y1, y2; // previous signals
wire signed [WS-1:0] x0;
reg  signed [WS*2-1:0] xb0,xb1,xb2,ya1,ya2;
wire signed [WS*2-1:0] sum;

assign x0  = sin;
assign sout= sum[(WS*2-1-G)-:WS];
assign sum = xb0+xb1+xb2-ya1-ya2;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
    end else begin
        if(sample) begin
            x2 <= x1;
            x1 <= x0;
            y2 <= y1;
            y1 <= y0;
            // y0 <= ^sum[WC*2+3:WC*2-1] ? { sum[WC*2+3], {WC-1{~sum[WC*2+3]}}} : sum[(WC*2-1)-:WC];
            y0 <= sum[WS+:WS];
        end else begin
            xb0 <= x0*b0;
            xb1 <= x1*b1;
            xb2 <= x2*b2;
            ya1 <= y1*a1;
            ya2 <= y2*a2;
        end
    end
end

endmodule