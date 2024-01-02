///////////////////////////////////////////////////////////////////////////////
// insert_training_pattern.v : 
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

module  insert_training_pattern(
        input wire         clk,
        input wire         clock_train,
        input wire         align_train,
		
        input wire  [71:0] in_data,
        output wire [79:0] out_data
    );

	////////////////////////////////////////////////////////
	//
	// This is designed so the change over from test patterns
	// to data stream happens seamlessly - e.g. the value for 
	// presented on data_in when clock_train and align_train
	// are both become zero is guaranteed to be sent
	//
	// +----+--------------------+--------------------+
	// |Word| Training pattern 1 | Training pattern 2 |
	// |    | Code  MSB    LSB   | Code   MSB     LSB |
	// +----+--------------------+-------------------+
	// |  0 | D10.2 1010101010   | K28.5- 0101111100  |
	// |  1 | D10.2 1010101010   | D11.6  0110001011  |
	// |  2 | D10.2 1010101010   | K28.5+ 1010000011  |
	// |  3 | D10.2 1010101010   | D11.6  0110001011  |
	// |  4 | D10.2 1010101010   | D10.2  1010101010  |
	// |  5 | D10.2 1010101010   | D10.2  1010101010  |
	// |  6 | D10.2 1010101010   | D10.2  1010101010  |
	// |  7 | D10.2 1010101010   | D10.2  1010101010  |
	// |  8 | D10.2 1010101010   | D10.2  1010101010  |
	// |  9 | D10.2 1010101010   | D10.2  1010101010  |
	// +----+--------------------+--------------------+
	// Patterns are transmitted LSB first.
	////////////////////////////////////////////////////////

    reg         clock_train_meta, clock_train_i;   // TODO: NEED TO SET ASYNCREG!
    reg         align_train_meta, align_train_i;   // TODO: NEED TO SET ASYNCREG!
    reg   [2:0] state;
    reg   [9:0] hold_at_state_one = 10'b1111111111;
    reg  [79:0] delay_line [5:0];
    
    localparam [8:0] CODE_K28_5 = 9'b110111100;
    localparam [8:0] CODE_D11_6 = 9'b011001011;
    localparam [8:0] CODE_D10_2 = 9'b001001010;

    localparam [19:0] p0 = {1'b0, CODE_D11_6, 1'b1, CODE_K28_5};
    localparam [19:0] p1 = {1'b0, CODE_D11_6, 1'b0, CODE_K28_5};
    localparam [19:0] p2 = {1'b0, CODE_D10_2, 1'b0, CODE_D10_2};
    localparam [19:0] p3 = {1'b0, CODE_D10_2, 1'b0, CODE_D10_2};
    localparam [19:0] p4 = {1'b0, CODE_D10_2, 1'b0, CODE_D10_2};

    assign out_data = delay_line[5];
	
initial begin
    clock_train_meta  = 1'b0;
    clock_train_i     = 1'b0;
    align_train_meta  = 1'b0;
    align_train_i     = 1'b0;
    delay_line[0]     = 80'b0;
    delay_line[1]     = 80'b0;
    delay_line[2]     = 80'b0;
    delay_line[3]     = 80'b0;
    delay_line[4]     = 80'b0;
    delay_line[5]     = 80'b0;
end

always @(posedge clk) begin
  // Move the delay line along 
	delay_line[5] <= delay_line[4];
	delay_line[4] <= delay_line[3];
	delay_line[3] <= delay_line[2];
	delay_line[2] <= delay_line[1];
	delay_line[1] <= delay_line[0];
	delay_line[0] <= { 1'b0, in_data[71:63], 1'b0, in_data[62:54],
  				       1'b0, in_data[53:45], 1'b0, in_data[44:36],
				       1'b0, in_data[35:27], 1'b0, in_data[26:18],
				       1'b0, in_data[17:9],  1'b0, in_data[8:0]};

    // Do we need to hold at state 1 until valid data has filtered down the delay line?
    if(align_train_i == 1'b1 ||  clock_train_i == 1'b1) begin
	   hold_at_state_one <= 10'b1111111111;
	end else begin
	   hold_at_state_one <= {1'b0, hold_at_state_one[9:1] };
	end
            
    // Do we need to overwrite the data in slot 5 with the sync patterns?
	case(state)
		3'b101: begin
		            state <= 3'b100; 
		            delay_line[5] <= {p0, p0, p0, p0};
				end

		3'b100: begin
		            state <= 3'b011;
					delay_line[5] <= {p1, p1, p1, p1};
			    end

		3'b011: begin 
		            state <= 3'b010;
					delay_line[5] <= {p2, p2, p2, p2};
				end

		3'b010: begin
		            state <= 3'b001;
					delay_line[5] <= {p3, p3, p3, p3};
				end

		3'b001: begin
		            state <= 3'b000; 
					delay_line[5] <= {p4, p4, p4, p4};
					if(align_train_i == 1'b1) begin
						state <= 3'b101;
					end else if(hold_at_state_one[0] == 1'b1) begin
						state <= 3'b001;
					end
				end

		default: begin
					state <= 3'b000;
					if(align_train_i == 1'b1) begin
						state <= 3'b101;
					end else if(hold_at_state_one[0] == 1'b1) begin
						state <= 3'b001;
					end
				end
	endcase
	 
	// Synchronize the control signals
	clock_train_meta <= clock_train;
	clock_train_i    <= clock_train_meta;
	align_train_meta <= align_train;
	align_train_i    <= align_train_meta;                
end
endmodule
