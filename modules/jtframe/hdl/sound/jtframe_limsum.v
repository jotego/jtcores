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
    Date: 8-3-2024

*/

// Limiter summer of signed inputs of equal bit width
// the output will be clipped (limited) if the sum does not fit in W bits
// peak is set when the output is clipped
module jtframe_limsum #(parameter
    W = 16,
    K = 5
)(
    input             rst,
    input             clk,
    input             cen,
    input   [W*K-1:0] parts,
    input   [K-1:0]   en,
    output reg signed [W-1:0] sum,
    output reg        peak
);

localparam WS = W+$clog2(K)+1;
reg signed [WS-1:0] full;
wire       [WS-W:0] signs = full[WS-1:W-1];
wire v = |signs & ~&signs; // overflow

function [WS-1:0] ext(input en, input [W-1:0] a);
    ext = en ? { {WS-W{a[W-1]}}, a } : {WS{1'b0}};
endfunction

integer k;
always @* begin
    for(k=0;k<K;k=k+1) full = k==0? ext(en[k],parts[W-1:0]) : full+ext(en[k],parts[W*k+:W]);
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sum <= 0;
    end else begin
        peak <= v;
        sum  <= v ? {full[WS-1],{W-1{~full[WS-1]}}} : full[W-1:0];
    end
end

endmodule