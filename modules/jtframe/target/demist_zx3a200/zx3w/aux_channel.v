///////////////////////////////////////////////////////////////////////////////
// ./src/auxch/aux_channel.v : 
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

module aux_channel(
        input wire  clk,
        input wire  reset_n,
        output wire [7:0] debug_pmod,
        //------------------------------
        output reg   edid_de,
        output reg   dp_reg_de,
        output reg   adjust_de,
        output reg   status_de,
        output reg   [7:0] aux_addr,
        output reg   [7:0] aux_data,
        //------------------------------
        input wire  [2:0] link_count,
        //----------------------------
        input wire        hpd_irq,
        input wire        hpd_present,
        input wire        hpd_read_linksink,
        //------------------------------
        output reg   tx_powerup,
        output reg   tx_clock_train,
        output reg   tx_align_train,
        output reg   tx_link_established,
        //-------------------------------
        input wire       swing_0p4,
        input wire       swing_0p6,
        input wire       swing_0p8,
        input wire       preemp_0p0,
        input wire       preemp_3p5,
        input wire       preemp_6p0,
        input wire       clock_locked,
        input wire       equ_locked,
        input wire       symbol_locked,
        input wire       align_locked,
        //------------------------------
        input wire       aux_in,
        output wire      aux_out,
        output wire      aux_tri
    );

    parameter [26:0] CLKPERMICROSECOND = 27'd28;

    localparam [7:0] error = 8'h00, reset = 8'h01, check_presence = 8'h02;

    // Gathering Display information 
    localparam [7:0] edid_block0     = 8'h03, edid_block1    = 8'h04, edid_block2 = 8'h05, edid_block3 = 8'h06;
    localparam [7:0] edid_block4     = 8'h08, edid_block5    = 8'h09, edid_block6 = 8'h0A, edid_block7 = 8'h0B;

    // Gathering display Port information
    localparam [7:0] read_sink_count = 8'h0C, read_registers = 8'h0D;

    // Link configuration states 
    localparam [7:0] set_channel_coding = 8'h0E, set_speed_162    = 8'h0F, set_downspread   = 8'h10;
    localparam [7:0] set_link_count_1   = 8'h11, set_link_count_2 = 8'h12, set_link_count_4 = 8'h13;

    // Link training - clock recovery
    localparam [7:0] clock_training = 8'h14, clock_voltage_0p4 = 8'h15, clock_voltage_0p6 = 8'h16, clock_voltage_0p8 = 8'h17;
    localparam [7:0] clock_wait     = 8'h18, clock_test        = 8'h19, clock_adjust      = 8'h1A, clock_wait_after  = 8'h1B;

    // Link training - alignment and preemphasis
    localparam [7:0] align_training = 8'h1C; 
    localparam [7:0] align_p0_V0p4 = 8'h1D, align_p0_V0p6 = 8'h1E, align_p0_V0p8    = 8'h1F;
    localparam [7:0] align_p1_V0p4 = 8'h20, align_p1_V0p6 = 8'h21, align_p1_V0p8    = 8'h22;
    localparam [7:0] align_p2_V0p4 = 8'h23, align_p2_V0p6 = 8'h24, align_p2_V0p8    = 8'h25;
    localparam [7:0] align_wait0   = 8'h26, align_wait1   = 8'h27, align_wait2      = 8'h28, align_wait3 = 8'h29;
    localparam [7:0] align_test    = 8'h2A,  align_adjust = 8'h2B, align_wait_after = 8'h2C;   

    // Link up.
    localparam [7:0] switch_to_normal = 8'h2D, link_established = 8'h2E;

    // Checking the state of the link
    localparam [7:0] check_link = 8'h2F, check_wait = 8'h30;
                    
    reg  [7:0]  state            = error;
    reg  [7:0]  next_state       = error;
    reg  [7:0]  state_on_success = error;
    reg         retry_now;
    reg  [26:0] retry_count;
    reg         link_check_now;
    reg [26:0]  link_check_count;
    reg [14:0]  count_100us;
    
    reg       adjust_de_active;
    reg       dp_reg_de_active;
    reg       edid_de_active;
    reg       status_de_active;
    reg       msg_de;
    reg [7:0] msg;
    wire      msg_busy;

    wire       aux_tx_wr_en;
    wire [7:0] aux_tx_data;
    wire       aux_tx_full;

    wire       aux_rx_rd_en;
    wire [7:0] aux_rx_data;
    wire       aux_rx_empty;

    reg [7:0] link_count_sink;
    
    wire      channel_busy;
    wire      channel_timeout;
    
    reg [7:0] expected;
    reg [7:0] rx_byte_count;
    reg [7:0] aux_addr_i;
    reg reset_addr_on_change;
    
    reg       just_read_from_rx;
    reg  [3:0] powerup_mask;
  
initial begin
    state            = error;
    next_state       = error;
    state_on_success = error;
    retry_now        = 1'b0;
    retry_count      = 27'h0200;
    link_check_now   = 1'b0;
    link_check_count = 27'h0200;
    count_100us      = CLKPERMICROSECOND * 100; 

    adjust_de_active     = 1'b0;
    dp_reg_de_active     = 1'b0;
    edid_de_active       = 1'b0;
    status_de_active     = 1'b0;
    msg_de               = 1'b0;
    msg                  = 8'b0;
    link_count_sink      = 8'b0;
    expected             = 8'b0;
    rx_byte_count        = 8'b0;
    aux_addr_i           = 8'b0;
    reset_addr_on_change = 1'b0;

    just_read_from_rx    = 1'b0;
    powerup_mask         = 4'b0;

    edid_de             = 1'b0;
    dp_reg_de           = 1'b0;
    adjust_de           = 1'b0;
    status_de           = 1'b0;
    aux_addr            = 8'b0;
    aux_data            = 8'b0;
    tx_powerup          = 1'b0;
    tx_clock_train      = 1'b0;
    tx_align_train      = 1'b0;
    tx_link_established = 1'b0;
end

dp_aux_messages i_aux_messages(
         .clk          (clk),
         // Interface to send messages
         .msg_de       (msg_de),
         .msg          (msg),
         .busy         (msg_busy),
         // Interface to the AUX Channel
         .aux_tx_wr_en (aux_tx_wr_en),
         .aux_tx_data  (aux_tx_data)
     );

aux_interface #(.CLKPERMICROSECOND(CLKPERMICROSECOND)) i_aux_interface( 
           .clk         (clk),
           .debug_pmod  (debug_pmod), 
            //---------------------------
            .aux_in     (aux_in),
            .aux_out    (aux_out),
            .aux_tri    (aux_tri),
            //----------------------------
           .tx_wr_en    (aux_tx_wr_en),
           .tx_data     (aux_tx_data),
           .tx_full     (aux_tx_full),
           //------------------------------
           .rx_rd_en    (aux_rx_rd_en),
           .rx_data     (aux_rx_data),
           .rx_empty    (aux_rx_empty),
           //------------------------------
           .busy        (channel_busy),
           .abort       (1'b0),   
           .timeout     (channel_timeout)
    );

    assign aux_rx_rd_en = (!channel_busy) & (!aux_rx_empty);  // CHECK THIS!
      
reg hpd_last = 1'b0;  
always @(posedge clk) begin
    if (reset_n == 1'b0)
      state <= reset;
    else begin   
      hpd_last <= hpd_present;
      if (hpd_present == 1'b1 && hpd_last == 1'b0) begin
        state            <= error;
        next_state       <= error;
        state_on_success <= error;
      end
      else if (hpd_read_linksink == 1'b1 || hpd_irq == 1'b1) begin
        state            <= error;
        next_state       <= read_sink_count;
        state_on_success <= read_registers;
      end 
      //-----------------------------------------
      // Are we going to change state this cycle?
      //-----------------------------------------
      msg_de <= 1'b0;
       
      if(next_state != state) begin
          //-----------------------------------------------------------
          // Get ready to count how many reply bytes have been received
          //-----------------------------------------------------------
          rx_byte_count <= 0;
          
          //-------------------------------------------------
          // Controlling which FSM state to go to on success
          //-------------------------------------------------
          case(next_state)
              reset:              state_on_success <= check_presence;
              check_presence:     state_on_success <= read_sink_count; //edid_block0;
              edid_block0:        state_on_success <= edid_block1;
              edid_block1:        state_on_success <= edid_block2;
              edid_block2:        state_on_success <= edid_block3;
              edid_block3:        state_on_success <= edid_block4;
              edid_block4:        state_on_success <= edid_block5;
              edid_block5:        state_on_success <= edid_block6;
              edid_block6:        state_on_success <= edid_block7;
              edid_block7:        state_on_success <= read_sink_count; 
              read_sink_count:    state_on_success <= read_registers;        
              read_registers:     state_on_success <= set_channel_coding;
              set_channel_coding: state_on_success <= set_speed_162;                        
              set_speed_162:      state_on_success <= set_downspread;                        
              set_downspread:     state_on_success <= set_link_count_1;                        
              set_link_count_1:   state_on_success <= clock_training; 
              set_link_count_2:   state_on_success <= clock_training; 
              set_link_count_4:   state_on_success <= clock_training; 
              //----- Display Port clock training -------------------                        
              clock_training:     state_on_success <= clock_voltage_0p4;
              clock_voltage_0p4:  state_on_success <= clock_wait;
              clock_voltage_0p6:  state_on_success <= clock_wait;
              clock_voltage_0p8:  state_on_success <= clock_wait;
              clock_wait:         state_on_success <= clock_test;                        
              clock_test:         state_on_success <= clock_adjust;
              clock_adjust:       state_on_success <= clock_wait_after;
              clock_wait_after:   if(clock_locked == 1'b1) begin
                                      state_on_success <= align_training;
                                  end else if(swing_0p8 == 1'b1) begin
                                      state_on_success <= clock_voltage_0p8;
                                  end else if(swing_0p6 == 1'b1) begin
                                      state_on_success <= clock_voltage_0p6;
                                  end else begin
                                      state_on_success <= clock_voltage_0p4;
                                  end
              //----- Display Port Alignment traning ------------                        
              align_training:     if(swing_0p8 == 1'b1) begin
                                       state_on_success <= align_p0_V0p8;
                                  end else if(swing_0p6 == 1'b1) begin
                                       state_on_success <= align_p0_V0p6;
                                  end else begin
                                       state_on_success <= align_p0_V0p4;
                                  end
              align_p0_V0p4:      state_on_success <= align_wait0;
              align_p0_V0p6:      state_on_success <= align_wait0;
              align_p0_V0p8:      state_on_success <= align_wait0;
              align_p1_V0p4:      state_on_success <= align_wait0;
              align_p1_V0p6:      state_on_success <= align_wait0;
              align_p1_V0p8:      state_on_success <= align_wait0;
              align_p2_V0p4:      state_on_success <= align_wait0;
              align_p2_V0p6:      state_on_success <= align_wait0;
              align_p2_V0p8:      state_on_success <= align_wait0;
              align_wait0:        state_on_success <= align_wait1;                        
              align_wait1:        state_on_success <= align_wait2;                        
              align_wait2:        state_on_success <= align_wait3;                        
              align_wait3:        state_on_success <= align_test;                        
              align_test:         state_on_success <= align_adjust;                        
              align_adjust:       state_on_success <= align_wait_after;
              align_wait_after:   if(symbol_locked == 1'b1) begin
                                             state_on_success <= switch_to_normal;
                                  end else if(swing_0p8 == 1'b1) begin
                                      if(preemp_6p0 == 1'b1) begin
                                          state_on_success <= align_p2_V0p8;
                                      end else if(preemp_3p5 == 1'b1) begin
                                          state_on_success <= align_p1_V0p8;
                                      end else begin
                                          state_on_success <= align_p0_V0p8;
                                      end
                                  end else if(swing_0p6 == 1'b1) begin
                                      if(preemp_6p0 == 1'b1) begin
                                          state_on_success <= align_p2_V0p6;
                                      end else if(preemp_3p5 == 1'b1) begin
                                          state_on_success <= align_p1_V0p6;
                                      end else begin
                                          state_on_success <= align_p0_V0p6;
                                      end
                                  end else begin
                                      if(preemp_6p0 == 1'b1) begin
                                          state_on_success <= align_p2_V0p4;
                                      end else if(preemp_3p5 == 1'b1) begin
                                          state_on_success <= align_p1_V0p4;
                                      end else begin
                                          state_on_success <= align_p0_V0p4;
                                      end 
                                  end                        
              switch_to_normal:   state_on_success <= link_established;  
              link_established:   state_on_success <= link_established;
              check_link:         state_on_success <= check_wait;
              check_wait:         if(clock_locked == 1'b1 && equ_locked == 1'b1 && symbol_locked == 1'b1 && align_locked == 1'b1) begin
                                      state_on_success <= link_established;
                                  end else begin
                                      state_on_success <= error;
                                  end 
              error:              state_on_success <= error;
          endcase
  
          //----------------------------------------------------------
          // Controlling what message will be sent, how many words are 
          // expected back, and where it will be routed
          //
          // NOTE: If you set 'expected' incorrectly then bytes will
          //       get left in the RX FIFO, potentially corrupting things
          //----------------------------------------------------------
          msg_de               <= 1'b1;
          status_de_active     <= 1'b0;
          adjust_de_active     <= 1'b0;
          dp_reg_de_active     <= 1'b0;
          edid_de_active       <= 1'b0;
          reset_addr_on_change <= 1'b0;                
          case(next_state)
              reset:                begin msg <= 8'h00; expected <= 8'h00; end
              check_presence:       begin msg <= 8'h01; expected <= 8'h01; reset_addr_on_change <= 1'b1; end
  
              edid_block0:          begin msg <= 8'h02; expected <= 8'h11; edid_de_active <= 1'b1; end
              edid_block1:          begin msg <= 8'h02; expected <= 8'h11; edid_de_active <= 1'b1; end
              edid_block2:          begin msg <= 8'h02; expected <= 8'h11; edid_de_active <= 1'b1; end
              edid_block3:          begin msg <= 8'h02; expected <= 8'h11; edid_de_active <= 1'b1; end
              edid_block4:          begin msg <= 8'h02; expected <= 8'h11; edid_de_active <= 1'b1; end
              edid_block5:          begin msg <= 8'h02; expected <= 8'h11; edid_de_active <= 1'b1; end
              edid_block6:          begin msg <= 8'h02; expected <= 8'h11; edid_de_active <= 1'b1; end
              edid_block7:          begin msg <= 8'h02; expected <= 8'h11; edid_de_active <= 1'b1; end
                      
              read_sink_count:      begin msg <= 8'h03; expected <= 8'h02; reset_addr_on_change <= 1'b1; end
              read_registers:       begin msg <= 8'h04; expected <= 8'h0D; dp_reg_de_active <= 1'b1; end
              set_channel_coding:   begin msg <= 8'h06; expected <= 8'h01;  end
              set_speed_162:        begin msg <= 8'h07; expected <= 8'h01;  end
              set_downspread:       begin msg <= 8'h08; expected <= 8'h01;  end
              set_link_count_1:     begin msg <= 8'h09; expected <= 8'h01;  end
              set_link_count_2:     begin msg <= 8'h0A; expected <= 8'h01;  end
              set_link_count_4:     begin msg <= 8'h0B; expected <= 8'h01;  end
                      
              clock_training:       begin msg <= 8'h0C; expected <= 8'h01;  end
              clock_voltage_0p4:    begin msg <= 8'h14; expected <= 8'h01; end
              clock_voltage_0p6:    begin msg <= 8'h16; expected <= 8'h01; end
              clock_voltage_0p8:    begin msg <= 8'h18; expected <= 8'h01; end
              clock_wait:           begin msg <= 8'h00; expected <= 8'h00;  reset_addr_on_change <= 1'b1; end
              clock_test:           begin msg <= 8'h0D; expected <= 8'h09;  status_de_active <= 1'b1; reset_addr_on_change <= 1'b1; end
              clock_adjust:         begin msg <= 8'h0E; expected <= 8'h03;  adjust_de_active <= 1'b1; end
              clock_wait_after:     begin msg <= 8'h00; expected <= 8'h00;  end
                      
              align_training:       begin msg <= 8'h0F; expected <= 8'h01; end
              align_p0_V0p4:        begin msg <= 8'h14; expected <= 8'h01; end
              align_p0_V0p6:        begin msg <= 8'h16; expected <= 8'h01; end
              align_p0_V0p8:        begin msg <= 8'h18; expected <= 8'h01; end
              align_p1_V0p4:        begin msg <= 8'h24; expected <= 8'h01; end
              align_p1_V0p6:        begin msg <= 8'h26; expected <= 8'h01; end
              align_p1_V0p8:        begin msg <= 8'h28; expected <= 8'h01; end
              align_p2_V0p4:        begin msg <= 8'h34; expected <= 8'h01; end
              align_p2_V0p6:        begin msg <= 8'h36; expected <= 8'h01; end
              align_p2_V0p8:        begin msg <= 8'h38; expected <= 8'h01; end
              align_wait0:          begin msg <= 8'h00; expected <= 8'h00; end
              align_wait1:          begin msg <= 8'h00; expected <= 8'h00; end
              align_wait2:          begin msg <= 8'h00; expected <= 8'h00; end
              align_wait3:          begin msg <= 8'h00; expected <= 8'h00;  reset_addr_on_change <= 1'b1; end
              align_test:           begin msg <= 8'h0D; expected <= 8'h09;  status_de_active <= 1'b1; reset_addr_on_change <= 1'b1; end
              align_adjust:         begin msg <= 8'h0E; expected <= 8'h03;  adjust_de_active <= 1'b1; end
              align_wait_after:     begin msg <= 8'h00; expected <= 8'h00; end
              switch_to_normal:     begin msg <= 8'h11; expected <= 8'h01; end
              link_established:     begin msg <= 8'h00; expected <= 8'h00; reset_addr_on_change <= 1'b1; end
              check_link:           begin msg <= 8'h0D; expected <= 8'h09; status_de_active <= 1'b1;  end
              check_wait:           begin msg <= 8'h00; expected <= 8'h00; end
              error:                begin msg <= 8'h00; end
              default:              begin msg <= 8'h00; end
          endcase
  
          //------------------------------------------------------
          // Set the control signals the state for the link state,  
          // transceivers andmain channel pipeline 
          //------------------------------------------------------
          tx_powerup          <= 1'b0; 
          tx_clock_train      <= 1'b0; 
          tx_align_train      <= 1'b0; 
          tx_link_established <= 1'b0;
          case(next_state)
              clock_training:       begin tx_powerup <= 1'b1; tx_clock_train <= 1'b1; end
              clock_voltage_0p4:    begin tx_powerup <= 1'b1; tx_clock_train <= 1'b1; end
              clock_voltage_0p6:    begin tx_powerup <= 1'b1; tx_clock_train <= 1'b1; end
              clock_voltage_0p8:    begin tx_powerup <= 1'b1; tx_clock_train <= 1'b1; end
              clock_wait:           begin tx_powerup <= 1'b1; tx_clock_train <= 1'b1; end
              clock_test:           begin tx_powerup <= 1'b1; tx_clock_train <= 1'b1; end
              clock_adjust:         begin tx_powerup <= 1'b1; tx_clock_train <= 1'b1; end
              clock_wait_after:     begin tx_powerup <= 1'b1; tx_clock_train <= 1'b1; end
                      
              align_training:       begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_p0_V0p4:        begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_p0_V0p6:        begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_p0_V0p8:        begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_p1_V0p4:        begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_p1_V0p6:        begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_p1_V0p8:        begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_p2_V0p4:        begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_p2_V0p6:        begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_p2_V0p8:        begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_wait0:          begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_wait1:          begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_wait2:          begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_wait3:          begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_test:           begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_adjust:         begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              align_wait_after:     begin tx_powerup <= 1'b1; tx_align_train <= 1'b1; end
              switch_to_normal:     begin tx_powerup <= 1'b1; end
              link_established:     begin tx_powerup <= 1'b1; tx_link_established <= 1'b1; end
              check_link:           begin tx_powerup <= 1'b1; tx_link_established <= 1'b1; end
              check_wait:           begin tx_powerup <= 1'b1; tx_link_established <= 1'b1; end
          endcase
      end
  
      //------------------------------------------------------
      // Manage the small timer that counts how long we have 
      // been in the current state (used for implementing 
      // short waits for some FSM states) 
      //------------------------------------------------------
      if(state == next_state) begin
          count_100us <= count_100us - 1;
      end else begin
          count_100us <= CLKPERMICROSECOND * 100 -1;                                        
          if(reset_addr_on_change == 1'b1) begin
              aux_addr_i <= 8'h0;
          end                                       
      end
      state <= next_state;
              
      //-----------------------------------------------------------
      // How a short wait is implemented...
      //
      // Has the 100us pause expired, when no data was expected?
      // If so, move to the next test.            
      //-----------------------------------------------------------
      if(expected == 8'h00 && count_100us == 14'd0) begin
          next_state <= state_on_success;
      end
              
      //------------------------------------------------------------
      // Processing the data that has been received from the sink
      // over the AUX channel. The data bytes are just streamed out
      // to a downstream component that uses the values, and may 
      // set flags that feed back in to control the FSM.
      //------------------------------------------------------------
      edid_de    <= 1'b0;
      adjust_de  <= 1'b0;
      dp_reg_de  <= 1'b0;                                
      status_de  <= 1'b0;
      if(channel_busy == 1'b0) begin
          if(just_read_from_rx == 1'b1) begin
              // Is this a short read?
              if(rx_byte_count != expected-1 && aux_rx_empty == 1'b1) begin
                  next_state <= error;
              end
                                  
              if(rx_byte_count == 8'h00) begin
                  //------------------------------------------------
                  // Is the Ack missing? This doesn't work correctly
                  // if only byte is expected, as it gets overwritten 
                  // by the following 'if' statement.
                  //
                  // Do not change this behaviour, by what it should do
                  // is test for "In progress" or "Again" requests, and 
                  // retry the current operation.
                  //---------------------------------------------------- 
                  if(aux_rx_data != 8'h00) begin
                      next_state <= error;
                  end
                  if(rx_byte_count == expected-1 && aux_rx_empty == 1'b1) begin
                      next_state <= state_on_success;
                  end
                  //--------------------------------------------
                  // Has the Sink indicated that we should retry
                  // the current command, to allow the sink time
                  // to process the request?
                  //
                  // This only works if there is just one byte
                  // in the FIFO. This only works for DPCD
                  // transactions that aeert "AUX DEFER"
                  //--------------------------------------------
                  if(aux_rx_data == 8'h20) begin
                     // just flip states to force a retry.
                      state      <= state_on_success;
                      next_state <= state;  
                  end
              end else begin
                  //-----------------------------------------------------------------
                  // Process a non-ack data byte, routing it out using the DE signals
                  //-----------------------------------------------------------------
                  edid_de    <= edid_de_active;
                  adjust_de  <= adjust_de_active;
                  dp_reg_de  <= dp_reg_de_active;                                
                  status_de  <= status_de_active;                                
  
                  aux_data   <= aux_rx_data;
                  aux_addr   <= aux_addr_i;
                  aux_addr_i <= aux_addr_i+1;                        
                          
                  if(rx_byte_count == expected-1 && aux_rx_empty == 1'b1) begin
                      next_state <= state_on_success;
                      if(reset_addr_on_change == 1'b1) begin
                          aux_addr_i <= 8'h00; 
                      end
                  end
              end
          end
      end
  
      //---------------------------------------------------
      // Manage the AUX channel timeout and the retry to  
      // establish a link. 
      //-----------------------------------------------------------                            
      //    if channel_timeout = 1'b1 or (state /= reset and state /= link_established and retry_now = 1'b1) then
      if(channel_timeout == 1'b1 || (state != reset      && state != link_established &&
                                     state != check_link && state != check_wait       && retry_now == 1'b1)) begin
          next_state <= reset;
          state      <= error;
      end 
      
      //-----------------------------------------------
      // If the link was established, then every 
      // now and then check the state of the link  
      //-----------------------------------------------
      if(state == link_established && link_check_now == 1'b1) begin
          next_state <= check_link;  
      end
  
      //-----------------------------------------------
      // If the full message has been received, then 
      // read any waiting data out of the FIFO.
      // Also update the count of bytes read.
      //-----------------------------------------------
      if(channel_busy == 1'b0 && aux_rx_empty == 1'b0) begin
          just_read_from_rx <= 1'b1;
      end else begin
          just_read_from_rx <= 1'b0;
      end
      if(just_read_from_rx == 1'b1) begin
          rx_byte_count <= rx_byte_count+1;
      end
  
      //---------------------------------------
      // Manage the reset timer
      //---------------------------------------
      if(retry_count == 0) begin
          retry_now   <= 1'b1;
          retry_count <= CLKPERMICROSECOND * 500000 -1;
      end else begin
          retry_now   <= 1'b0;
          retry_count <= retry_count - 1;
      end
      if(link_check_count == 0) begin
          link_check_now   <= 1'b1;
          // PPS actually became a 2Hz pulse....
          link_check_count <= CLKPERMICROSECOND * 1000000 -1;
      end else begin
          link_check_now   <= 1'b0;
          link_check_count <= link_check_count - 1;
      end
    end
  end        
endmodule
