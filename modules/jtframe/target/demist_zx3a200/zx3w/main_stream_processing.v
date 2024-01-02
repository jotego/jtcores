///////////////////////////////////////////////////////////////////////////////
// ./src/main_stream_processing.v : 
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

module  main_stream_processing (
		    input wire         symbol_clk,
        input wire         tx_link_established,
        input wire         source_ready,
        input wire         tx_clock_train,
        input wire         tx_align_train,
        input wire [15:0]  audio_l,
        input wire [15:0]  audio_r,
        input wire  [72:0] in_data,
        output wire [79:0] tx_symbols
  );

wire [71:0] signal_data;
wire [71:0] audiovideo_data;
wire [71:0] sr_inserted_data;
wire [71:0] scrambled_data;
wire [79:0] before_skew;
wire [79:0] final_data;
 
//localparam [7:0] delay_index = 8'b11100100;

/////////////////////////////////////////////////////////
// Flick between the idle pattern and a valid data stream
// at the time when the in_data's high bit is set
/////////////////////////////////////////////////////////
idle_pattern_inserter i_idle_pattern_inserter( 
		.clk              (symbol_clk),
		.channel_ready    (tx_link_established),
		.source_ready     (source_ready),
		
		.in_data          (in_data),
		.out_data         (signal_data)
    );


// audio_packet_inserter i_audio_packet_inserter (
//		.clk              (symbol_clk),
//		.channel_ready    (tx_link_established),
//		.source_ready     (source_ready),
//		.audio_l          (audio_l),
//		.audio_r          (audio_r),
//		
//		.in_data          (signal_data),
//		.out_data         (audiovideo_data)
//    );
 assign audiovideo_data = signal_data;
 
/////////////////////////////////////////////////////////
// Change the 512th Blank Start (BS) symbol into a 
// Scrambler Reset (SR) symbol
/////////////////////////////////////////////////////////
//scrambler_reset_inserter i_scrambler_reset_inserter( 
//		.clk       (symbol_clk),
//		.in_data   (signal_data),
//		.out_data  (sr_inserted_data)
//	);
assign sr_inserted_data = audiovideo_data;

/////////////////////////////////////////////////////////
// Now scramble the data stream - only scrambles the data
// symbols, the K symbols go through unscrambled.
/////////////////////////////////////////////////////////
//scrambler_all_channels i_scrambler( 
//		.clk        (symbol_clk),
//		.bypass0    (1'b0),
//		.bypass1    (1'b0),
//		.in_data    (sr_inserted_data),
//		.out_data   (scrambled_data)
//	);
assign scrambled_data = sr_inserted_data;

/////////////////////////////////////////////////////////
// This allows the controller to send the two training 
// patterns, allowing the link drive levels to be set up
/////////////////////////////////////////////////////////
insert_training_pattern i_insert_training_pattern(
        .clk               (symbol_clk),
        .clock_train       (tx_clock_train),
        .align_train       (tx_align_train), 
        ///////////////////////////////////////////////////////
        // Adds one bit per symbol - the force_neg parity flag         
        // This takes the 72-bit wide data word to 80 bits.
        ///////////////////////////////////////////////////////
        .in_data           (scrambled_data),
        .out_data          (before_skew)
    );

/////////////////////////////////////////////////////////
// The last step is to skew the data channels (zero cycles
// cycles for channel zero, two cycle for channel one, 
// four for channel two and six for channel three.
/////////////////////////////////////////////////////////
//skew_channels i_skew_channels(
//        .clk               (symbol_clk),
//        .in_data           (before_skew),
//        .out_data          (tx_symbols)
//    );
assign tx_symbols = before_skew;  // solo tenemos un canal (lane)

endmodule
