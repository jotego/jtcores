///////////////////////////////////////////////////////////////////////////////
// ./src/auxch/hotplug_decode.v : 
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
//`default_nettype none

module hotplug_decode (
    input wire  clk,
    input wire  hpd,
    output reg irq,
    output reg read_linksink,
    output reg present
);

   reg hpd_meta1, hpd_meta2;
   reg hpd_synced;
   reg hpd_last;

   reg [18:0] pulse_count;

   parameter [26:0] CLKPERMICROSECOND = 27'd28;

  initial begin
      hpd_meta1    = 1'b0;
      hpd_meta2    = 1'b0;
      hpd_synced   = 1'b0;
      hpd_last     = 1'b1;
      pulse_count  = 19'b0;
      present      = 1'b0;
      irq          = 1'b0;
      read_linksink = 1'b0;
  end 
  
  always @(posedge clk) begin
    hpd_last   <= hpd_synced;
    hpd_synced <= hpd_meta2;
    hpd_meta2  <= hpd_meta1;
    hpd_meta1  <= hpd;
  
    if (irq == 1'b1)
      irq <= 1'b0;
    if (read_linksink == 1'b1)
      read_linksink <= 1'b0;
    
    if (hpd_last != hpd_synced) begin
      if (hpd_synced == 1'b0)
        pulse_count <= 19'd0;
      else begin
        if (pulse_count >= 500*CLKPERMICROSECOND && pulse_count < 1000*CLKPERMICROSECOND)
          irq <= 1'b1;
        if (pulse_count >= 1000*CLKPERMICROSECOND && pulse_count < 2000*CLKPERMICROSECOND)
          read_linksink <= 1'b1;
      end
    end
    else begin
      if (pulse_count != 4000*CLKPERMICROSECOND)
        pulse_count = pulse_count + 19'd1;
      else
        present <= hpd_synced;
    end
  end
endmodule

//`default_nettype wire
