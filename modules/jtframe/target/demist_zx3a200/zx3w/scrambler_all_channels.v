///////////////////////////////////////////////////////////////////////////////
// ./src/scrambler_all_channels.v : 
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

module  scrambler_all_channels(
    input         clk,
    input         bypass0,
    input         bypass1,
    
    input  [71:0] in_data,
    output reg [71:0] out_data
);

    //--------------------------------------------------------------------------------
    // Should be verified against the table in Appendix C of the "PCI Express Base 
    // Specification 2.1" which uses the same polynomial.
    //
    // Here are the first 32 output words when data values of "00" are scrambled: 
    //
    //    | 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
    // ---+------------------------------------------------
    // 00 | FF 17 C0 14 B2 E7 02 82 72 6E 28 A6 BE 6D BF 8D
    // 10 | BE 40 A7 E6 2C D3 E2 B2 07 02 77 2A CD 34 BE E0
    //
    //--------------------------------------------------------------------------------
	
    localparam [15:0] lfsr_reset_state = 16'b1111111111111111;
    reg [15:0] lfsr_state = lfsr_reset_state;
    localparam [8:0] SR  = 9'b100011100; // K28.0 is used to signal a reset for the scrambler
    wire [15:0]  s0;
    wire [15:0]  s1;
    wire [17:0]  flipping;

	assign s0 = lfsr_state;

    // generate intermediate scrambler state
    assign s1[0]  = (in_data[8:0] == SR) ? lfsr_reset_state[0]  : s0[8];
    assign s1[1]  = (in_data[8:0] == SR) ? lfsr_reset_state[1]  : s0[9];
    assign s1[2]  = (in_data[8:0] == SR) ? lfsr_reset_state[2]  : s0[10];
    assign s1[3]  = (in_data[8:0] == SR) ? lfsr_reset_state[3]  : s0[11]                   ^ s0[8];
    assign s1[4]  = (in_data[8:0] == SR) ? lfsr_reset_state[4]  : s0[12]          ^ s0[8]  ^ s0[9];
    assign s1[5]  = (in_data[8:0] == SR) ? lfsr_reset_state[5]  : s0[13] ^ s0[8]  ^ s0[9]  ^ s0[10];
    assign s1[6]  = (in_data[8:0] == SR) ? lfsr_reset_state[6]  : s0[14] ^ s0[9]  ^ s0[10] ^ s0[11];
    assign s1[7]  = (in_data[8:0] == SR) ? lfsr_reset_state[7]  : s0[15] ^ s0[10] ^ s0[11] ^ s0[12];
    assign s1[8]  = (in_data[8:0] == SR) ? lfsr_reset_state[8]  : s0[0]  ^ s0[11] ^ s0[12] ^ s0[13];
    assign s1[9]  = (in_data[8:0] == SR) ? lfsr_reset_state[9]  : s0[1]  ^ s0[12] ^ s0[13] ^ s0[14];
    assign s1[10] = (in_data[8:0] == SR) ? lfsr_reset_state[10] : s0[2]  ^ s0[13] ^ s0[14] ^ s0[15];
    assign s1[11] = (in_data[8:0] == SR) ? lfsr_reset_state[11] : s0[3]  ^ s0[14] ^ s0[15];
    assign s1[12] = (in_data[8:0] == SR) ? lfsr_reset_state[12] : s0[4]  ^ s0[15];
    assign s1[13] = (in_data[8:0] == SR) ? lfsr_reset_state[13] : s0[5];
    assign s1[14] = (in_data[8:0] == SR) ? lfsr_reset_state[14] : s0[6];
    assign s1[15] = (in_data[8:0] == SR) ? lfsr_reset_state[15] : s0[7];                

    assign flipping[8:0]  = (in_data[8]  == 1'b0 && bypass0 == 1'b0) ? {1'b0, s0[8], s0[9], s0[10], s0[11], s0[12], s0[13], s0[14], s0[15]} : 9'b000000000;
    assign flipping[17:9] = (in_data[17] == 1'b0 && bypass1 == 1'b0) ? {1'b0, s1[8], s1[9], s1[10], s1[11], s1[12], s1[13], s1[14], s1[15]} : 9'b000000000;

initial begin
    out_data <= 72'b0;
    lfsr_state = 16'hFFFF;
end


always @(posedge clk) begin    
    //------------------------------------------
    // Apply vector to channel 0
    //------------------------------------------        
    out_data <= in_data ^ {flipping, flipping, flipping, flipping};

    lfsr_state[0]  = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[8];
    lfsr_state[1]  = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[9];
    lfsr_state[2]  = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[10];
    lfsr_state[3]  = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[11]                   ^ s1[8];
    lfsr_state[4]  = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[12]          ^ s1[8]  ^ s1[9];
    lfsr_state[5]  = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[13] ^ s1[8]  ^ s1[9]  ^ s1[10];
    lfsr_state[6]  = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[14] ^ s1[9]  ^ s1[10] ^ s1[11];
    lfsr_state[7]  = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[15] ^ s1[10] ^ s1[11] ^ s1[12];
    lfsr_state[8]  = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[0]  ^ s1[11] ^ s1[12] ^ s1[13];
    lfsr_state[9]  = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[1]  ^ s1[12] ^ s1[13] ^ s1[14];
    lfsr_state[10] = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[2]  ^ s1[13] ^ s1[14] ^ s1[15];
    lfsr_state[11] = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[3]  ^ s1[14] ^ s1[15];
    lfsr_state[12] = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[4]  ^ s1[15];
    lfsr_state[13] = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[5];
    lfsr_state[14] = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[6];
    lfsr_state[15] = (in_data[15:8] == SR) ? lfsr_reset_state[0]  : s1[7];                
end
endmodule
