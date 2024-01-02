///////////////////////////////////////////////////////////////////////////////
// ./src/scrambler_reset_inserter.v : 
//
// Author: Mike Field <hamster@snap.net.nz>
//
// Part of the DisplayPort_Verlog project - an open implementation of the 
// DisplayPort protocol for FPGA boards. 
//
// See https://github.com/hamsternz/DisplayPort_Verilog for latest versions.
//
///////////////////////////////////////////////////////////////////////////////
// Version |  Notes
// ----------------------------------------------------------------------------
//   1.0   | Initial Release
//
///////////////////////////////////////////////////////////////////////////////
//
// MIT License
// 
// Copyright (c) 2019 Mike Field
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
///////////////////////////////////////////////////////////////////////////////
//
// Want to say thanks?
//
// This design has taken many hours - 3 months of work for the initial VHDL
// design, and another month or so to convert it to Verilog for this release.
//
// I'm more than happy to share it if you can make use of it. It is released
// under the MIT license, so you are not under any onus to say thanks, but....
//
// If you what to say thanks for this design either drop me an email, or how about
// trying PayPal to my email (hamster@snap.net.nz)?
//
//  Educational use - Enough for a beer
//  Hobbyist use    - Enough for a pizza
//  Research use    - Enough to take the family out to dinner
//  Commercial use  - A weeks pay for an engineer (I wish!)
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

/////////////////////////////////////////////////////////////////////
// TODO - Needs to also work for BS in the high half of the in_data
/////////////////////////////////////////////////////////////////////
// Note - this assumes that all the BS sysbols will be aligned (which
// they should). This means we only need one counter and one flag
/////////////////////////////////////////////////////////////////////
module  scrambler_reset_inserter( 
            input         clk,
            input  [71:0] in_data,
            output reg [71:0] out_data
        );

reg [8:0] bs_count;
reg       substitue_next;

localparam [8:0] BS = 9'b110111100;  // K28.5 0x1BC
localparam [8:0] SR = 9'b100011100;  // K28.0 0x11C

initial begin
    bs_count       = 9'b0;
    substitue_next = 1'b0;
    out_data       = 72'b0;
end

always @(posedge clk) begin
    //----------------------------------------------
    // Subsitute every 512nd Blank start (BS) symbol
    // with a Scrambler Reset (SR) symbol. 
    //----------------------------------------------
    out_data  <= in_data;

    if(substitue_next == 1'b1) begin
        if(in_data[8:0]   == BS) begin
            out_data[8:0]   <= SR;
        end

        if(in_data[26:18] == BS) begin
            out_data[26:18] <= SR;
        end

        if(in_data[44:36] == BS) begin
            out_data[44:36] <= SR;
        end

        if(in_data[62:54] == BS) begin
            out_data[62:54] <= SR;
        end
    end

    if(in_data[8:0] == BS) begin
    	if(bs_count == 1'b0) begin
            substitue_next <= 1'b1;
    	end else begin
            substitue_next <= 1'b0;
    	end
    	bs_count <= bs_count + 1;
    end
end

endmodule
