/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-3-2024 */

// Limiting summer of signed inputs of equal bit width
// the output will be clipped (limited) if the sum does not fit in W bits
// peak is set when the output is clipped
module jtframe_limsum #(parameter
    WI = 16,
    WO = WI,
    K = 5   // number of input signals
)(
    input             rst,
    input             clk,
    input             cen,
    input   [WI*K-1:0] parts,
    input   [K-1:0]   en,
    output reg signed [WO-1:0] sum,
    output reg        peak
);

localparam WS = WI+$clog2(K)+1;
reg signed [WS-1:0] full;
wire       [WS-WO:0] signs = full[WS-1:WO-1];
wire v = |signs & ~&signs; // overflow

function [WS-1:0] ext(input en, input [WI-1:0] a);
    ext = en ? { {WS-WI{a[WI-1]}}, a } : {WS{1'b0}};
endfunction

integer k;
always @* begin
    for(k=0;k<K;k=k+1) full = k==0? ext(en[k],parts[WI-1:0]) : full+ext(en[k],parts[WI*k+:WI]);
end

always @(posedge clk) begin
    if( rst ) begin
        sum  <= 0;
        peak <= 0;
    end else begin
        peak <= v;
        sum  <= v ? {full[WS-1],{WO-1{~full[WS-1]}}} : full[WO-1:0];
    end
end

endmodule