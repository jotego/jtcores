///////////////////////////////////////////////////////////////////////////////
// ./src/test_streams/insert_main_stream_attrbutes_one_channel.v : 
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
module insert_main_stream_attrbutes_one_channel(
        input wire  clk,
        //---------------------------------------------------
        // This determines how the MSA is packed
        //---------------------------------------------------      
        input wire  active,
        //---------------------------------------------------
        // The MSA values (some are range reduced and could 
        // be 16 bits ins size)
        //---------------------------------------------------      
        input wire  [23:0] M_value,
        input wire  [23:0] N_value,
        input wire  [11:0] H_visible,
        input wire  [11:0] V_visible,
        input wire  [11:0] H_total,
        input wire  [11:0] V_total,
        input wire  [11:0] H_sync_width,
        input wire  [11:0] V_sync_width,
        input wire  [11:0] H_start,
        input wire  [11:0] V_start,
        input wire         H_vsync_active_high,
        input wire         V_vsync_active_high,
        input wire         flag_sync_clock,
        input wire         flag_YCCnRGB,
        input wire         flag_422n444,
        input wire         flag_range_reduced,
        input wire         flag_interlaced_even,
        input wire         flag_YCC_colour_709,
        input wire   [1:0] flags_3d_Indicators,
        input wire   [4:0] bits_per_colour,
        //---------------------------------------------------
        // The stream of pixel data coming in and out
        //---------------------------------------------------
        input wire      [72:0] in_data,
        output reg [72:0] out_data);

    localparam [8:0] SS  = 9'b101011100;   // K28.2
    localparam [8:0] SE  = 9'b111111101;   // K29.7
    localparam [8:0] BS  = 9'b110111100;   // K28.5

  //  wire [8:0] msa [39:0];

    reg [7:0] misc0;
    reg [7:0] misc1;
    
    reg [4:0] count;

    reg [0:0] last_was_bs;
    reg [0:0] armed;

initial begin
        count       <= 5'b00000;
        armed       <= 1'b0;
        last_was_bs <= 1'b0;
    end


always @(*) begin
        case(bits_per_colour)
           5'b00110: misc0[7:5] = 3'b000;  //  6 bpc
           5'b01000: misc0[7:5] = 3'b001;  //  8 bpp
           5'b01010: misc0[7:5] = 3'b010;  // 10 bpp
           5'b01100: misc0[7:5] = 3'b011;  // 12 bpp
           5'b10000: misc0[7:5] = 3'b100;  // 16 bpp 
           default:  misc0[7:5] = 3'b001;  // default to 8                                     
        endcase
    
        misc0[4]          = flag_YCC_colour_709;
        misc0[3]          = flag_range_reduced;
        if(flag_YCCnRGB == 1'b0) begin
            misc0[2:1] = 2'b00;  // RGB444
        end else if(flag_422n444 == 1'b1) begin
            misc0[2:1] = 2'b01;  // YCC422
        end else begin
            misc0[2:1] = 2'b10;  // YCC444
        end 
        misc0[0]          = flag_sync_clock;   

        misc1 = {5'b00000, flags_3d_Indicators, flag_interlaced_even};
    end

always @(posedge clk) begin
    // default to copying the input data across
    out_data <= in_data;
  
    case(count)
        5'b00000: out_data[17:0] <= in_data[17:0]; // while waiting for BS symbol
        5'b00001: out_data[17:0] <= in_data[17:0]; // reserved for VB-ID, Maud, Mvid 
        5'b00010: out_data[17:0] <= in_data[17:0]; // reserved for VB-ID, Maud, Mvid
        5'b00011: out_data[17:0] <= in_data[17:0]; // reserved for VB-ID, Maud, Mvid
        5'b00100: out_data[17:0] <= in_data[17:0]; // reserved for VB-ID, Maud, Mvid
        5'b00101: out_data[17:0] <= in_data[17:0]; // reserved for VB-ID, Maud, Mvid
        5'b00110: out_data[17:0] <= in_data[17:0]; // reserved for VB-ID, Maud, Mvid
        5'b00111: out_data[17:0] <= {SS, SS}; 

        5'b01000: out_data[17:0] <= {1'b0, M_value[15:8],            1'b0, M_value[23:16]};
        5'b01001: out_data[17:0] <= {1'b0, 4'b0000, H_total[11:8],   1'b0, M_value[7:0]};
        5'b01010: out_data[17:0] <= {1'b0, 4'b0000, V_total[11:8],   1'b0, H_total[7:0]};
        5'b01011: out_data[17:0] <= {1'b0, H_vsync_active_high, 3'b000, H_sync_width[11:8], 1'b0, V_total[7:0]};
        5'b01100: out_data[17:0] <= {1'b0, M_value[23:16],           1'b0, H_sync_width[7:0]};
        5'b01101: out_data[17:0] <= {1'b0, M_value[7:0],             1'b0, M_value[15:8]};
        5'b01110: out_data[17:0] <= {1'b0, H_start[7:0],             1'b0, 4'b0000, H_start[11:8]};
        5'b01111: out_data[17:0] <= {1'b0, V_start[7:0],             1'b0, 4'b0000, V_start[11:8]};
        5'b10000: out_data[17:0] <= {1'b0, V_sync_width[7:0],        1'b0, V_vsync_active_high, 3'b000, V_sync_width[11:8]};
        5'b10001: out_data[17:0] <= {1'b0, M_value[15:8],            1'b0, M_value[23:16]};
        5'b10010: out_data[17:0] <= {1'b0, 4'b0000, H_visible[11:8], 1'b0, M_value[7:0]};
        5'b10011: out_data[17:0] <= {1'b0, 4'b0000, V_visible[11:8], 1'b0, H_visible[7:0]};
        5'b10100: out_data[17:0] <= {1'b0, 8'b00000000,              1'b0, V_visible[7:0]};
        5'b10101: out_data[17:0] <= {1'b0, M_value[23:16],           1'b0, 8'b00000000};
        5'b10110: out_data[17:0] <= {1'b0, M_value[7:0],             1'b0, M_value[15: 8]};
        5'b10111: out_data[17:0] <= {1'b0, N_value[15: 8],           1'b0, N_value[23:16]}; 
        5'b11000: out_data[17:0] <= {1'b0, misc0,                    1'b0, N_value[7:0]}; 
        5'b11001: out_data[17:0] <= {1'b0, 8'b00000000,              1'b0, misc1}; 
        5'b11010: out_data[17:0] <= {1'b0, 8'b00000000,              SE};
        default:  out_data[17:0] <= in_data[17:0];
    endcase

    //----------------------------------------------------------
    // Update the counter
    //----------------------------------------------------------
    if(count == 5'b11011) begin
        count <= 5'b00000;
    end else if(count != 5'b00000) begin
        count <= count + 1;
    end 

    //-------------------------------------------
    // Was the BS in the channel 0's data1 symbol
    // during the last cycle? 
    //-------------------------------------------            
    if(last_was_bs == 1'b1) begin
        //-------------------------------
        // This time in_ch0_data0 = VB-ID
        // First, see if this is a line in 
        // the VSYNC
        //-------------------------------
        if(in_data[0] == 1'b1) begin
            if(armed == 1'b1) begin
                count <= 5'b00001;
                armed <= 1'b0;
            end
        end else begin
            // Not in the Vblank. so arm the trigger to send the MSA 
            // when the next BS with Vblank asserted occurs                      
            armed <= active;
        end
    end

    //-------------------------------------------
    // Is the BS in the channel 0's data0 symbol? 
    //-------------------------------------------
    if(in_data[8:0] == BS) begin
        //-------------------------------
        // This time in_data(17 downto 9) = VB-ID
        // First, see if this is a line in 
        // the VSYNC
        //-------------------------------
        if(in_data[9] == 1'b1) begin
            if(armed == 1'b1) begin
                count <= 5'b00001;
                armed <= 1'b0;
            end
        end else begin
            // Not in the Vblank. so arm the trigger to send the MSA 
            // when the next BS with Vblank asserted occurs                      
            armed <= 1'b1;
        end
    end
            
    //-------------------------------------------
    // Is the BS in the channel 0's data1 symbol? 
    //-------------------------------------------
    if(in_data[17:9] == BS) begin
        last_was_bs <= 1'b1;
    end else begin
        last_was_bs <= 1'b0;               
    end
end

endmodule
