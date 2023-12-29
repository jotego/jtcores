///////////////////////////////////////////////////////////////////////////////
// ./src/artix7/gtx_tx_reset_controller.v : 
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

///////////////////////////////////////////////////////////////////
// Transceiver and channel PLL control
// ===================================
//
// 1. Initial reset state
//    Set GTTXRESET High,
//    Set GTTXPMARESET low
//    Set TXPCSRESET low.
//    Set CPLLPD high
//    Set GTRESETSEL low.
//
// 2. Hold CPLLPD high until reference clock is seen on fabric
//
// 3. Wait at least 500ns
//
// 4. Start up the channel PLL
//    Drop CPLLPD
//    Assert CPLLLOCKEN
//
// 5. Wait for CPLLLOCK to go high
//
// 6. Start up the high speed transceiver
//    Assert GTTXUSERRDY
//    Drop GTTXRESET (you can use the CPLLLOCK signal is OK)
//
// 7. Monitor GTTXRESETDONE until it goes high
//
// The transceiver's TX Should then be operational.
//
///////////////////////////////////////////////////////////////////

module gtx_tx_reset_controller (
  input  wire clk,

  input  wire ref_clk,
  input  wire powerup_channel,
  
  input  wire plllock,
  
      
  input  wire txresetdone,

  output reg  tx_running,      //: out std_logic := '0';
  output reg  txreset,         //: out std_logic := '1';
  output reg  txuserrdy,       //: out std_logic := '0';
  output reg  txpmareset,      //: out std_logic := '1';
  output reg  txpcsreset,      //: out std_logic := '1';
  
  output reg  pllpd,           //: out std_logic := '1';
  output reg  pllreset,        //: out std_logic;
  output reg  plllocken,       //: out std_logic := '1';
  
  output reg  resetsel         //  out std_logic := '0'
);

    parameter [26:0] CLKPERMICROSECOND = 27'd28; 

    reg [3:0] state;
    reg [7:0] ref_clk_counter;
    reg [7:0] counter;
    reg       ref_clk_detect_last;
    reg       ref_clk_detect;       
    reg       ref_clk_detect_meta;  // TODO: Neet to set ASYNCREG
    reg       txresetdone_meta;     // TODO: Neet to set ASYNCREG
    reg       txresetdone_i;

initial begin
    state                = 4'b0000;
    ref_clk_counter      = 8'b00000000;
    counter              = 8'b00000000;

    ref_clk_detect_last  = 1'b0;
    ref_clk_detect       = 1'b0;       
    ref_clk_detect_meta  = 1'b0;
    txresetdone_meta     = 1'b1;
    txresetdone_i        = 1'b1;
    tx_running           = 1'b1;
    
    txreset    <= 1'b1;
    txuserrdy  <= 1'b0;
    txpmareset <= 1'b1;
    txpcsreset <= 1'b1;
    pllpd      <= 1'b1;
    pllreset   <= 1'b1;
    plllocken  <= 1'b0;
    resetsel   <= 1'b0;
end    
    
always @(posedge ref_clk) begin
     ref_clk_counter <= ref_clk_counter + 1;
end

always @(posedge clk) begin

    counter             <= counter + 1;

    case(state)
      4'b0000: begin // reset
                 txreset    <= 1'b1;
                 txuserrdy  <= 1'b0;
                 txpmareset <= 1'b0;
                 txpcsreset <= 1'b0;
                 pllpd      <= 1'b1;
                 pllreset   <= 1'b1;
                 plllocken  <= 1'b0;
                 resetsel   <= 1'b0;
                 state      <= 4'b0001;
               end

      4'b0001: begin // wait for reference clock
                 counter <= 8'b00000000;
                 if(ref_clk_detect == ref_clk_detect_last) begin
                   state <= 4'b0001;
                 end else begin
                   state <= 4'b0010;
                 end
               end

      4'b0010: begin // wait for 500ns
                 // counter will set high bit after 128 cycles
                 if(counter == 128*CLKPERMICROSECOND/100) begin
                   state <= 4'b0011;
                 end
               end
  
      4'b0011: begin // start up the PLL
                 pllpd     <= 1'b0;
                 pllreset  <= 1'b0;
                 plllocken <= 1'b1;
                 state     <= 4'b0100;
               end

      4'b0100: begin // Waiting for the PLL to lock
                 if(plllock == 1'b1) begin
                   state <= 4'b0101;
                 end
               end

      4'b0101: begin //- Starting up the GTX
                 txreset   <= 1'b0;
                 state     <= 4'b0110;
                 counter   <= 8'b00000000;
               end

      4'b0110: begin // wait for 500ns
                 // counter will set high bit after 128 cycles
                 if(counter == 128*CLKPERMICROSECOND/100) begin
                   state <= 4'b0111;
                 end
               end

      4'b0111: begin // power up the user data path
                 txuserrdy <= 1'b1;
                 if(txresetdone_i == 1'b1) begin
                   state <= 4'b1000;
                 end 
               end

      4'b1000: begin // All running
                 tx_running <= 1'b1;    
               end

      default: begin
                 state      <= 4'b0000;
               end
    endcase

    if(powerup_channel == 1'b0) begin
        state <= 4'b0000;
    end


    ref_clk_detect_last <= ref_clk_detect;
    ref_clk_detect      <= ref_clk_detect_meta;
    ref_clk_detect_meta <= ref_clk_counter[7];
            
    txresetdone_i    <= txresetdone_meta;
    txresetdone_meta <= txresetdone;
  end
endmodule
