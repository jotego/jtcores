///////////////////////////////////////////////////////////////////////////////
// ./src/auxch/channel_managemnt.v : 
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

module channel_management(
        input wire sysclk,
        input wire reset_n,
        output wire [7:0] debug,

        input wire   hpd,
        output wire  present,
        input wire   auxch_in,
        output wire  auxch_out,
        output wire  auxch_tri,

        // Datapath requirements
        input wire  [2:0] stream_channel_count,
        input wire  [2:0] source_channel_count,

        // Datapath control
        output wire tx_clock_train,
        output wire tx_align_train,

        // Transceiver management
        output wire tx_powerup_channel,

        output wire tx_preemp_0p0,
        output wire tx_preemp_3p5,
        output wire tx_preemp_6p0,
           
        output wire tx_swing_0p4,
        output wire tx_swing_0p6,
        output wire tx_swing_0p8,
          
        input wire  tx_running,
        output wire tx_link_established,
        
        // On screen DP receiver conf.
        output wire [7:0] debug_dp_addr0,
        output wire [7:0] debug_dp_addr1,
        output wire [7:0] debug_dp_addr2,
        output wire [7:0] debug_dp_addr3,
        output wire [7:0] debug_dp_addr4,
        output wire [7:0] debug_dp_addr5,
        output wire [7:0] debug_dp_addr6,
        output wire [7:0] debug_dp_addr7,
        output wire [7:0] debug_dp_addr8,
        output wire [7:0] debug_dp_addr9,
        output wire [7:0] debug_dp_addrA,
        output wire [7:0] debug_dp_addrB,
        output wire [7:0] debug_dp_addrC
    );

    parameter [26:0] CLKPERMICROSECOND = 27'd28; 

    wire       edid_de;
    wire       dp_reg_de;
    wire       adjust_de;
    wire       status_de;
    wire [7:0] aux_data;
    wire [7:0] aux_addr;
    wire       invalidate;
    wire       tx_powerup;
    
    wire       preemp_0p0_i;
    wire       preemp_3p5_i;
    wire       preemp_6p0_i;
           
    wire       swing_0p4_i;
    wire       swing_0p6_i;
    wire       swing_0p8_i;
    
    wire       support_RGB444;
    wire       support_YCC444;
    wire       support_YCC422;
    
    //------------------------------------------
    // EDID data
    //-------------------------------------------
    wire        edid_valid;
    wire [15:0] pixel_clock_x10k;
    
    wire [11:0] h_visible_len;
    wire [11:0] h_blank_len;
    wire [11:0] h_front_len;
    wire [11:0] h_sync_len;
    
    wire [11:0] v_visible_len;
    wire [11:0] v_blank_len;
    wire [11:0] v_front_len;
    wire [11:0] v_sync_len;
    wire        interlaced;
    //------------------------------------------
    // Display port data
    //-------------------------------------------
    wire        dp_valid;
    wire [7:0]  dp_revision;
    wire [7:0]  dp_link_rate;
    wire [7:0]  dp_lane_count;
    wire [7:0]  dp_downstream_port;
    wire [7:0]  dp_downstream_port_count;
    wire        dp_link_rate_2_70;
    wire        dp_link_rate_1_62;
    wire        dp_extended_framing;
    wire [3:0]  dp_link_count;
    wire [7:0]  dp_max_downspread;
    wire [7:0]  dp_coding_supported;
    wire [15:0] dp_port0_capabilities;
    wire [15:0] dp_port1_capabilities;
    wire [7:0]  dp_norp;
    //------------------------------------------------------------------------
    
    wire       clock_locked;
    wire       equ_locked;
    wire       symbol_locked;
    wire       align_locked;
    //----------------------------------------------
    wire [7:0] interface_debug;
    wire [7:0] mgmt_debug;
   
    wire [2:0] sink_channel_count;
    wire [2:0] active_channel_count;

    wire       hpd_irq;
    wire       hpd_present;
    wire       hpd_read_linksink;


    // Feed the number of links from the registers into the link management logic
assign     sink_channel_count = 2'b01; //dp_link_count[2:0];
assign     tx_preemp_0p0 = preemp_0p0_i;
assign     tx_preemp_3p5 = preemp_3p5_i;
assign     tx_preemp_6p0 = preemp_6p0_i;
           
assign     tx_swing_0p4 = swing_0p4_i;
assign     tx_swing_0p6 = swing_0p6_i;
assign     tx_swing_0p8 = swing_0p8_i;

hotplug_decode #(.CLKPERMICROSECOND(CLKPERMICROSECOND)) i_hotplug_decode(
        .clk           (sysclk),
        .hpd           (hpd),
        .irq           (hpd_irq),
        .present       (hpd_present),
        .read_linksink (hpd_read_linksink)
    );
assign present = hpd_present;

aux_channel #(.CLKPERMICROSECOND(CLKPERMICROSECOND)) i_aux_channel( 
        .clk             (sysclk),
        .reset_n         (reset_n),
        .debug_pmod      (debug),
         //------------------------------
        .edid_de         (edid_de),
        .dp_reg_de       (dp_reg_de),
        .adjust_de       (adjust_de),
        .status_de       (status_de),
        .aux_addr        (aux_addr),
        .aux_data        (aux_data),
         //----------------------------
        .link_count      (active_channel_count),
        .hpd_irq         (hpd_irq),
        .hpd_present     (hpd_present),
        .hpd_read_linksink (hpd_read_linksink),
         //------------------------------
        .preemp_0p0      (preemp_0p0_i), 
        .preemp_3p5      (preemp_3p5_i),
        .preemp_6p0      (preemp_6p0_i),           
        .swing_0p4       (swing_0p4_i),
        .swing_0p6       (swing_0p6_i),
        .swing_0p8       (swing_0p8_i),
          
        .clock_locked    (clock_locked),
        .equ_locked      (equ_locked),
        .symbol_locked   (symbol_locked),
        .align_locked    (align_locked),
           
         //----------------------------
        .tx_powerup          (tx_powerup),
        .tx_clock_train      (tx_clock_train),
        .tx_align_train      (tx_align_train),
        .tx_link_established (tx_link_established),
         //----------------------------
        .aux_in     (auxch_in),
        .aux_out    (auxch_out),
        .aux_tri    (auxch_tri)
     );

// edid_decode i_edid_decode( 
//           .clk              (sysclk),
//           .edid_de          (edid_de),
//           .edid_addr        (aux_addr),
//           .edid_data        (aux_data),
//           .invalidate       (1'b0),
    
//           .valid            (edid_valid),
    
//           .support_RGB444   (support_RGB444),
//           .support_YCC444   (support_YCC444),
//           .support_YCC422   (support_YCC422),
    
//           .pixel_clock_x10k (pixel_clock_x10k),
    
//           .h_visible_len    (h_visible_len),
//           .h_blank_len      (h_blank_len),
//           .h_front_len      (h_front_len),
//           .h_sync_len       (h_sync_len),
    
//           .v_visible_len    (v_visible_len),
//           .v_blank_len      (v_blank_len),
//           .v_front_len      (v_front_len),
//           .v_sync_len       (v_sync_len),
//           .interlaced       (interlaced));

dp_register_decode i_dp_reg_decode( 
            .clk                (sysclk),
            .de                 (dp_reg_de),
            .addr               (aux_addr),
            .data               (aux_data),
            .invalidate         (~hpd_present),
            .valid              (dp_valid),
            
            .revision           (dp_revision),
            .link_rate          (dp_link_rate),
            .lane_count         (dp_lane_count),
            .link_rate_2_70     (dp_link_rate_2_70),
            .link_rate_1_62     (dp_link_rate_1_62),
            .extended_framing   (dp_extended_framing),
            .link_count         (dp_link_count),
            .max_downspread     (dp_max_downspread),
            .downstream_port    (dp_downstream_port),
            .downstream_port_count (dp_downstream_port_count),
            .coding_supported   (dp_coding_supported),
            .port0_capabilities (dp_port0_capabilities),
            .port1_capabilities (dp_port1_capabilities),
            .norp               (dp_norp)
       );

assign debug_dp_addr0 = dp_revision;
assign debug_dp_addr1 = dp_link_rate;
assign debug_dp_addr2 = dp_lane_count;
assign debug_dp_addr3 = dp_max_downspread;
assign debug_dp_addr4 = dp_norp;
assign debug_dp_addr5 = dp_downstream_port;
assign debug_dp_addr6 = dp_coding_supported;
assign debug_dp_addr7 = dp_downstream_port_count;
assign debug_dp_addr8 = dp_port0_capabilities[7:0];
assign debug_dp_addr9 = dp_port0_capabilities[15:8];
assign debug_dp_addrA = dp_port1_capabilities[7:0];
assign debug_dp_addrB = dp_port1_capabilities[15:8];
assign debug_dp_addrC = {2'b00, hpd_present, dp_valid, clock_locked, equ_locked, symbol_locked, align_locked};

link_signal_mgmt i_link_signal_mgmt(
        .mgmt_clk             (sysclk),

        .tx_powerup           (tx_powerup), 
        
        .status_de            (status_de),
        .adjust_de            (adjust_de),
        .addr                 (aux_addr),
        .data                 (aux_data),

        .sink_channel_count   (sink_channel_count),
        .source_channel_count (source_channel_count),
        .active_channel_count (active_channel_count),
        .stream_channel_count (stream_channel_count),

        .powerup_channel      (tx_powerup_channel),

        .clock_locked         (clock_locked),
        .equ_locked           (equ_locked),
        .symbol_locked        (symbol_locked),
        .align_locked         (align_locked),

        .preemp_0p0           (preemp_0p0_i), 
        .preemp_3p5           (preemp_3p5_i),
        .preemp_6p0           (preemp_6p0_i),
            
        .swing_0p4            (swing_0p4_i),
        .swing_0p6            (swing_0p6_i),
        .swing_0p8            (swing_0p8_i)
    );

endmodule
