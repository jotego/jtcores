///////////////////////////////////////////////////////////////////////////////
// ./src/auxch/link_signal_mgmt.v : 
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

module link_signal_mgmt(
        input wire        mgmt_clk,

        input wire        tx_powerup,
        
        input wire        status_de,
        input wire        adjust_de,
        input wire  [7:0] addr,
        input wire  [7:0] data,
        //-----------------------------------------
        input wire  [2:0] sink_channel_count,
        input wire  [2:0] source_channel_count,
        input wire  [2:0] stream_channel_count,
        output wire [2:0] active_channel_count,
        //-----------------------------------------
        output reg powerup_channel,
        //-----------------------------------------
        output reg   clock_locked,
        output reg   equ_locked,
        output reg   symbol_locked,
        output reg   align_locked,

        output  reg  preemp_0p0,
        output  reg  preemp_3p5,
        output  reg  preemp_6p0,
    
        output  reg  swing_0p4,
        output  reg  swing_0p6,
        output  reg  swing_0p8
    );

    reg         power_mask;
    wire [1:0]  preemp_level;
    wire  [1:0] voltage_level;
    reg  [23:0] channel_state;
    reg  [15:0] channel_adjust;
    reg  [2:0]  active_channel_count_i;
    reg  [2:0]  pipe_channel_count;


    assign active_channel_count = active_channel_count_i;
    assign voltage_level = channel_adjust[1:0];
    assign preemp_level  = channel_adjust[4:3];
    
initial begin
    active_channel_count_i = 3'b0;
        //-----------------------------------------
    powerup_channel = 4'b0;
        //-----------------------------------------
    clock_locked = 3'b0;
    equ_locked = 3'b0;
    symbol_locked = 3'b0;
    align_locked = 3'b0;
    channel_adjust = 15'b0;
    channel_state  = 24'b0;

    preemp_0p0 = 3'b0;
    preemp_3p5 = 3'b0;
    preemp_6p0 = 3'b0;
    
    swing_0p4 = 3'b0;
    swing_0p6 = 3'b0;
    swing_0p8 = 3'b0;
end

always @(posedge mgmt_clk) begin
    //--------------------------------------------------------
    // Work out how many channels will be active 
    // (the min of source_channel_count and sink_channel_count
    //
    // Also work out the power-up mask for the transceivers
    //---------------------------------------------------------
      pipe_channel_count <= 3'b001;
      active_channel_count_i <= 3'b001;
      power_mask             <= 1'b1;

    //-------------------------------------------
    // If the powerup is not asserted, then reset 
    // everything.
    //-------------------------------------------
    if(tx_powerup == 1'b1) begin
        powerup_channel  <= power_mask;
    end else begin
        powerup_channel  <= 0;
        channel_adjust   <= 15'b0;
        channel_state    <= 24'b0;
    end

    //-------------------------------------------
    // Decode the power and pre-emphasis levels
    //-------------------------------------------
    case(preemp_level)
        2'b00:   begin preemp_0p0 <= 1'b1; preemp_3p5 <= 1'b0; preemp_6p0 <= 1'b0; end
        2'b01:   begin preemp_0p0 <= 1'b0; preemp_3p5 <= 1'b1; preemp_6p0 <= 1'b0; end
        default: begin preemp_0p0 <= 1'b0; preemp_3p5 <= 1'b0; preemp_6p0 <= 1'b1; end
    endcase

    case(voltage_level)
        2'b00:   begin
                     swing_0p4 <= 1'b1;
                     swing_0p6 <= 1'b0;
                     swing_0p8 <= 1'b0;
                 end
        2'b01:   begin 
                     swing_0p4 <= 1'b0; 
                     swing_0p6 <= 1'b1;
                     swing_0p8 <= 1'b0;
                 end
        default: begin
                     swing_0p4 <= 1'b0;
                     swing_0p6 <= 1'b0; 
                     swing_0p8 <= 1'b1;
                 end
    endcase

    //---------------------------------------------
    // Receive the status data from the AUX channel
    //---------------------------------------------
    if(status_de == 1'b1) begin
        case(addr)
            8'b00000010: channel_state[7:0]   <= data;
            8'b00000011: channel_state[15:8]  <= data;                                  
            8'b00000100: channel_state[23:16] <= data;                                  
        endcase
    end

    //---------------------------------------------
    // Receive the channel adjustment request 
    //---------------------------------------------
    if(adjust_de == 1'b1) begin
        case(addr) 
            8'b00000000: channel_adjust[7:0] <= data;
            8'b00000001: channel_adjust[15:8] <= data;                                  
        endcase
    end 

    //---------------------------------------------
    // Update the status signals based on the 
    // register data recieved over from the AUX
    // channel. 
    //---------------------------------------------
    clock_locked  <= 1'b0;
    equ_locked    <= 1'b0;
    symbol_locked <= 1'b0;
    if((channel_state[3:0] & 4'h1) == 4'h1)
      clock_locked  <= 1'b1;
    if((channel_state[3:0] & 4'h3) == 4'h3)
      equ_locked    <= 1'b1;
    if((channel_state[3:0] & 4'h7) == 4'h7)
      symbol_locked <= 1'b1;
    align_locked <= channel_state[16];
end

endmodule
