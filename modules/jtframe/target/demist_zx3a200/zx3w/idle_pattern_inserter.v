///////////////////////////////////////////////////////////////////////////////
// ./src/idle_pattern_inserter.v : 
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
module idle_pattern_inserter ( 
        input wire             clk,
        input wire             channel_ready,
        input wire             source_ready,
        input wire      [72:0] in_data, // Bit 72 is the switch point indicator
        output reg [71:0] out_data
);


    reg [16:0] count_to_switch;
    reg        source_ready_last;
    reg        idle_switch_point;
    
    reg [12:0] idle_count;    

    localparam [8:0] BS     = 9'b110111100;   // K28.5
    localparam [8:0] DUMMY  = 9'b000000011;   // 0x3
    localparam [8:0] VB_ID  = 9'b000001001;   // 0x09  VB-ID with no video asserted 
    localparam [8:0] Mvid   = 9'b000000000;   // 0x00
    localparam [8:0] Maud   = 9'b000000000;   // 0x00    

    reg [17:0] idle_data;
    reg        channel_ready_i;
    reg        channel_ready_meta;   // TODO: NEED TO SET ASYNCREG

initial begin
    channel_ready_i    = 1'b0;
    channel_ready_meta = 1'b0;
    out_data           = 72'b0;
    idle_data          = 18'b0;
    count_to_switch    = 17'b0;
    idle_count         = 13'b0;
end 



always @(posedge clk) begin
    if(count_to_switch[16] == 1'b1) begin
        out_data  <= in_data[71:0];
    end else begin
        // send idle pattern
        out_data   <= { idle_data, idle_data, idle_data, idle_data};
    end
    
    if(count_to_switch[16] == 1'b0) begin
        //------------------------------------------------------
        // The last tick over requires the source to be ready
        // and to be asserting that it is in the switch point.
        //------------------------------------------------------
        if(count_to_switch[15:0] == 16'hFFFF) begin
            //-------------------------------------
            // Bit 72 is the switch point indicator
            //-------------------------------------
            if(source_ready == 1'b1 && in_data[72] == 1'b1 && idle_switch_point == 1'b1) begin
               count_to_switch <= count_to_switch + 1;
            end
        end else begin
            //------------------------------------------------------
            // Wait while we send out at least 64k of idle patterns
            //------------------------------------------------------
            count_to_switch <= count_to_switch + 1;
        end
    end

    //-----------------------------------------------------------------------
    // If either the source drops or the channel is not ready, then reset
    // to emitting the idle pattern. 
    //-----------------------------------------------------------------------
    if(channel_ready_i == 1'b0 || (source_ready == 1'b0 && source_ready_last == 1'b1)) begin
        count_to_switch <= 17'b0;
    end
    source_ready_last  <= source_ready;
            
    //------------------------------------------------------
    // We can either be odd or even aligned, depending on
    //  where the last BS symbol was seen. We need to send
    //  the next one 8192 symbols later (4096 cycles)
    //------------------------------------------------------
    idle_switch_point <= 1'b0;
    case(idle_count)
        // For the even aligment
        0:       idle_data <= {DUMMY, DUMMY};
        2:       idle_data <= {VB_ID, BS   };
        4:       idle_data <= {Maud,  Mvid };
        6:       idle_data <= {Mvid,  VB_ID};
        8:       idle_data <= {VB_ID, Maud };
        10:      idle_data <= {Maud,  Mvid };
        12:      idle_data <= {Mvid,  VB_ID};
        14:      idle_data <= {DUMMY, Maud };
        // For the odd aligment
        1:       idle_data <= {BS,    DUMMY};
        3:       idle_data <= {Mvid,  VB_ID};             
        5:       idle_data <= {VB_ID, Maud };
        7:       idle_data <= {Maud,  Mvid };
        9:       idle_data <= {Mvid,  VB_ID};
        11:      idle_data <= {VB_ID, Maud };
        13:      idle_data <= {Mvid,  VB_ID};
        15:      idle_data <= {Maud,  Mvid };
        17:      idle_data <= {DUMMY, DUMMY};
        default: begin
                     idle_data <= {DUMMY, DUMMY}; // can switch to the actual video at any other time
                     idle_switch_point <= 1'b1;   // other than when the BS, VB-ID, Mvid, Maud sequence
                 end
    endcase 

    idle_count <= idle_count + 2;            
    //------------------------------------------------------ 
    // Sync with the BS stream of the input signal but only 
    // if we are switched over to it (indicated by the high
    // bit of count_to_switch being set)
    //------------------------------------------------------ 
    if(count_to_switch[16] == 1'b1) begin
        if(in_data[8:0] == BS) begin
            idle_count <= 13'b10;
        end else if(in_data[17:9] == BS) begin
            idle_count <= 13'b1;
        end 
    end 
    channel_ready_i     <= channel_ready_meta; 
    channel_ready_meta  <= channel_ready;
end

endmodule
