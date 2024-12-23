/*
	This file is derived from JTFRAME.
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
	Author: LMN-san.           Twitter: @Lmn_Sama
	Author: Olivier Scherler.  Twitter: @oscherler
	Version: 1.0
    Date: 24-08-2022
*/

//================================================================================
//  Generic Unsigned Mixer
//  
//  Based on jtframe_mixer.
//================================================================================

// Like jtframe_mixer, but works on unsigned signals.

// Usage:
// Specify width of input signals and desired outputs
// Select gain for each signal

module unsigned_mixer #(parameter W0=16,W1=16,W2=16,W3=16,WOUT=16)(
    input             rst,
    input             clk,
    input             cen,
    // input signals
    input  [W0-1:0]   ch0,
    input  [W1-1:0]   ch1,
    input  [W2-1:0]   ch2,
    input  [W3-1:0]   ch3,
    // gain for each channel in 4.4 fixed point format
    input  [7:0]      gain0,
    input  [7:0]      gain1,
    input  [7:0]      gain2,
    input  [7:0]      gain3,
    output [WOUT-1:0] mixed,
    output            peak   // overflow signal (time enlarged)
);

localparam WM = 16,
           WD =  4,    // decimal part
           WA = WM+8,  // width for the amplification
           WS = WA+2,  // width for the sum
           WI = WS-WD; // width of the integer part of the sum
localparam [WM+3:0] MAXPOS = { 5'b0, {WM-1{1'b1}}};
localparam [WM+3:0] MAXNEG = { 5'b0, {WM-1{1'b0}}};


`ifdef SIMULATION
initial begin
    if( WOUT<W0 || WOUT<W1 || WOUT<W2 || WOUT<W3 ) begin
        $display("ERROR: %m parameter WOUT must be larger or equal than any other w parameter");
        $finish;
    end
    if( W0>WM || W1 > WM || W2>WM || W3>WM || WOUT>WM ) begin
        $display("ERROR: %m parameters cannot be larger than %d bits",WM);
        $finish;
    end
end
`endif

wire [WA-1:0] ch0_pre, ch1_pre, ch2_pre, ch3_pre;
reg  [WS-1:0] pre_sum; // 4 extra bits for overflow guard
reg  [WM-1:0] sum;
reg  [WI-1:0] pre_int; // no fractional part
wire          ov_pos, ov_neg;

// rescale to WM
wire [WM-1:0] scaled0 = { ch0, {WM-W0{1'b0}} };
wire [WM-1:0] scaled1 = { ch1, {WM-W1{1'b0}} };
wire [WM-1:0] scaled2 = { ch2, {WM-W2{1'b0}} };
wire [WM-1:0] scaled3 = { ch3, {WM-W3{1'b0}} };

assign ch0_pre = gain0 * scaled0;
assign ch1_pre = gain1 * scaled1;
assign ch2_pre = gain2 * scaled2;
assign ch3_pre = gain3 * scaled3;
assign mixed   = sum[WM-1:WM-WOUT];

assign peak    = pre_int[WI-1:WM] != {WI-WM{pre_int[WM-1]}};
assign ov_pos  = peak && !pre_int[WI-1];
assign ov_neg  = peak &&  pre_int[WI-1];

function [WS-1:0] ext;
    input [WA-1:0] a;
    ext = { {WS-WA{1'b0}}, a };
endfunction

always @(*) begin
    pre_sum = ext(ch0_pre) + ext(ch1_pre) + ext(ch2_pre) + ext(ch3_pre);
    pre_int = pre_sum[WS-1:WD];
end

// Apply gain
always @(posedge clk) if(cen) begin
    if( rst ) begin // synchronous
        sum <= sum>>>1;
    end else begin
        sum <= ov_pos ? MAXPOS[WM-1:0] : (
               ov_neg ? MAXNEG[WM-1:0] : pre_int[WM-1:0] );
    end
end

endmodule // unsigned_mixer
