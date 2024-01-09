///////////////////////////////////////////////////////////////////////////////
// ./src/auxch/dp_register_decode.v : 
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

module dp_register_decode(
   input wire         clk,

   input wire         de,
   input wire  [7:0]  data,
   input wire  [7:0]  addr,
   input wire         invalidate,

   output reg        valid,
 
   output reg [7:0]  revision,
   output reg [7:0]  link_rate,
   output reg        link_rate_2_70,
   output reg        link_rate_1_62,
   output reg        link_rate_5_40,
   output reg        extended_framing,
   output reg [7:0]  lane_count,
   output reg [3:0]  link_count,
   output reg [7:0]  max_downspread,
   output reg [7:0] downstream_port,
   output reg [7:0] downstream_port_count,
   output reg [7:0]  coding_supported,
   output reg [15:0] port0_capabilities,
   output reg [15:0] port1_capabilities,
   output reg [7:0]  norp
);

initial begin
    valid              = 1'b0;
    revision           = 8'hFF;
    link_rate          = 8'hFF;
    link_rate_5_40     = 1'b0;
    link_rate_2_70     = 1'b0;
    link_rate_1_62     = 1'b1;
    extended_framing   = 1'b0;
    lane_count         = 8'hFF;
    link_count         = 3'b0;
    max_downspread     = 8'hFF;
    downstream_port    = 8'hFF;
    downstream_port_count = 8'hFF;
    coding_supported   = 8'hFF;
    port0_capabilities = 16'hFFFF;
    port1_capabilities = 16'hFFFF;
    norp               = 8'hFF;
end

always @(posedge clk) begin
    if(de == 1'b1) begin
        case(addr)
            8'h00: begin
                       valid    <= 1'b0;
                       revision <= data;
                   end
            8'h01: begin
                       link_rate <= data;
                       case(data) 
                              8'h06:   begin
                                           link_rate_5_40 <= 1'b0;
                                           link_rate_2_70 <= 1'b0;
                                           link_rate_1_62 <= 1'b1;
                                       end
                              8'h0A:   begin
                                           link_rate_5_40 <= 1'b0;
                                           link_rate_2_70 <= 1'b1;
                                           link_rate_1_62 <= 1'b1;
                                       end
                              8'h14:   begin
                                           link_rate_5_40 <= 1'b1;
                                           link_rate_2_70 <= 1'b1;
                                           link_rate_1_62 <= 1'b1;
                                       end
                              default: begin
                                           link_rate_5_40 <= 1'b0;
                                           link_rate_2_70 <= 1'b0;
                                           link_rate_1_62 <= 1'b1;
                                       end
                       endcase
                   end
            8'h02: begin
                       lane_count       <= data;
                       extended_framing <= data[7];
                       link_count       <= data[3:0];         
                   end
            8'h03: begin
                       max_downspread   <= data;
                   end
            8'h04: begin
                       norp             <= data;
                   end
            8'h05: begin
                       downstream_port  <= data;
                   end
            8'h06: begin
                       coding_supported <= data;    
                   end
            8'h07: begin
                       downstream_port_count <= data;
                   end
            8'h08: begin
                       port0_capabilities[7:0] <= data;
                   end
            8'h09: begin
                       port0_capabilities[15:8]<= data;
                   end
            8'h0A: begin
                       port1_capabilities[7:0] <= data;
                   end
            8'h0B: begin
                       port1_capabilities[15:8]<= data;
                       valid <= 1'b1;
                   end
        endcase

        //----------------------------------------------
        // Allow for an external event to invalidate the 
        // outputs (e.g. hot plug)
        //----------------------------------------------
    end
    else if (invalidate == 1'b1) begin
       valid <= 1'b0;
    end
end
endmodule
