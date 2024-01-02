///////////////////////////////////////////////////////////////////////////////
// ./src/auxch/aux_interface.v : 
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

module aux_interface(
       input wire        clk,
       output wire [7:0] debug_pmod,
       //----------------------------
       input wire        aux_in,
       output reg   aux_out,
       output reg   aux_tri,
       //----------------------------
       input wire        tx_wr_en,
       input wire  [7:0] tx_data,
       output wire       tx_full,
       //----------------------------                                  
       input wire        rx_rd_en,
       output reg [7:0] rx_data,
       output wire       rx_empty,
       //----------------------------
       output wire       busy,
       input wire        abort,
       output reg   timeout
     );

    parameter [26:0] CLKPERMICROSECOND = 27'd28;

    //----------------------------------------
    // A small fifo to send data from
    //----------------------------------------
    localparam [3:0] tx_idle      = 4'b0000; 
    localparam [3:0] tx_sync      = 4'b0001;
    localparam [3:0] tx_sync2     = 4'b0111;
    localparam [3:0] tx_start     = 4'b0010;
    localparam [3:0] tx_send_data = 4'b0011;
    localparam [3:0] tx_stop      = 4'b0100;
    localparam [3:0] tx_flush     = 4'b0101;
    localparam [3:0] tx_waiting   = 4'b0110;
    localparam [3:0] tx_precharge = 4'b1000;
    
    reg  [3:0] tx_state = tx_idle;
    reg  [7:0] tx_fifo [31:0];
    reg  [4:0] tx_rd_ptr;
    reg  [4:0] tx_wr_ptr;
    wire [4:0] tx_wr_ptr_plus_1;

    reg [15:0] timeout_count;

    wire tx_empty;
    wire tx_full_i;
    reg  [7:0] tx_rd_data;
    reg  tx_rd_en;
    
    reg  snoop;
    
    reg        [7:0] bit_counter;
    localparam [7:0] bit_counter_max = CLKPERMICROSECOND / 2 -1;

    reg [15:0] data_sr;
    reg [15:0] busy_sr;
    
    localparam [2:0] rx_waiting        = 3'b000;
    localparam [2:0] rx_receiving_data = 3'b001;
    localparam [2:0] rx_done           = 3'b010;
    reg  [2:0] rx_state;
    reg  [7:0] rx_fifo [31:0];
    reg  [4:0] rx_wr_ptr;
    wire [4:0] rx_wr_ptr_plus_1;
    reg  [4:0] rx_rd_ptr;
    reg  rx_reset;
    wire rx_empty_i;
    wire rx_full;
    reg [7:0] rx_wr_data;
    reg rx_wr_en;

    reg [5:0]  rx_count;
    reg [15:0] rx_buffer;
    reg [15:0] rx_bits;
    reg        rx_a_bit;
    reg        rx_last;
    reg        rx_synced;
    reg        rx_meta;   // TODO: Need to set ASYNCREG attribute
    reg        rx_finished;
    reg [9:0]  rx_holdoff;
    reg [3:0]   debug_pmod_high;

initial begin
    aux_out   = 1'b0;
    aux_tri   = 1'b1;
    rx_data   = 8'b0;
    timeout   = 1'b0;
 
    tx_state = tx_idle;
    tx_rd_ptr        = 4'b0000;
    tx_wr_ptr        = 4'b0000;
    timeout_count    = 16'b0;
    tx_rd_data       = 8'b0;
    tx_rd_en         = 1'b0;

    snoop            = 1'b0;

    bit_counter  = 8'b0;

    data_sr    = 16'b0;
    busy_sr    = 16'b0;

    rx_state        = rx_waiting;
    rx_wr_ptr       = 5'b0;
    rx_rd_ptr       = 5'b0;
    rx_reset        = 1'b0;
    rx_wr_data      = 8'b0;
    rx_wr_en        = 1'b0;

    rx_wr_data      = 8'b0;
    rx_wr_en        = 1'b0;
    rx_count        = 6'b0;
    rx_buffer       = 16'b0;
    rx_bits         = 16'b0;

    rx_a_bit        = 1'b0;
    rx_last         = 1'b0;
    rx_synced       = 1'b0;
    rx_meta         = 1'b0;
    rx_finished     = 1'b0;
    rx_holdoff      = 10'b0;
    debug_pmod_high = 4'b0000;
end
    assign debug_pmod = {debug_pmod_high, 3'b000, snoop};
    
    //--------------------------------------------
    // Async logic for the FIFO state and pointers
    //--------------------------------------------
    assign rx_wr_ptr_plus_1 = rx_wr_ptr + 5'b00001;
    assign tx_wr_ptr_plus_1 = tx_wr_ptr + 5'b00001;
    assign rx_empty_i   = ((rx_wr_ptr        == rx_rd_ptr) ? 1'b1 : 1'b0);
    assign rx_full      = ((rx_wr_ptr_plus_1 == rx_rd_ptr) ? 1'b1 : 1'b0);
    assign tx_empty     = ((tx_wr_ptr        == tx_rd_ptr) ? 1'b1 : 1'b0);
    assign tx_full_i    = ((tx_wr_ptr_plus_1 == tx_rd_ptr) ? 1'b1 : 1'b0);
    assign rx_empty     = rx_empty_i;
    assign tx_full      = tx_full_i;
    assign busy         = ((tx_empty == 1'b1 && tx_state == tx_idle) ? 1'b0 : 1'b1);
  
always @(posedge clk) begin
    //--------------------------------
    // Defaults, overwritten as needed
    //--------------------------------
    tx_rd_en <= 1'b0;
    rx_reset <= 1'b0;
    timeout  <= 1'b0;

    //---------------------------------
    // Is it time to send the next bit?
    //---------------------------------
    if(bit_counter == bit_counter_max) begin
     
        bit_counter <= 8'h00;            
        aux_out     <= data_sr[15];
        aux_tri     <= ~busy_sr[15];
        data_sr     <= { data_sr[14:0], 1'b0 };
        busy_sr     <= { busy_sr[14:0], 1'b0 };
        //-------------------------------------------------
        // Logic to signal the RX module ignore the data we
        // are actually sending for 10 cycles. This is safe 
        // as the sync pattern is quite long.
        //-----------------------------------------
        if(tx_state == tx_waiting) begin 
            rx_holdoff <= {rx_holdoff[8:0], 1'b0};
        end else begin
            rx_holdoff <= 10'h3FF;
        end

        //------------------------------------------------
        // Debug signals that are presented to the outside
        //------------------------------------------------
        case(tx_state)
            tx_idle:      debug_pmod_high <= 4'h0;  
            tx_sync:      debug_pmod_high <= 4'h1;
            tx_start:     debug_pmod_high <= 4'h2;
            tx_send_data: debug_pmod_high <= 4'h3;
            tx_stop:      debug_pmod_high <= 4'h4;
            tx_flush:     debug_pmod_high <= 4'h5;
            tx_waiting:   debug_pmod_high <= 4'h6;
            default:      debug_pmod_high <= 4'hA;
        endcase

        //-----------------------------------
        // What to do with with the FSM  state
        // NOTE THAT HAPPENS WHEN BIT 14 OF BUSY_SR 
        // IS ZERO, as BIT 15 WILL JUST BE MOVED INTO
        // THE OUTPUT REGISTERS.
        //-----------------------------------
        if(busy_sr[14] == 1'b0) begin
            case(tx_state)
                tx_idle: begin
                             if(tx_empty == 1'b0) begin
                                 data_sr  <= 16'b0101010101010101;
                                 busy_sr  <= 16'b1111111111111111;
                                 tx_state <= tx_precharge;
                             end
                         end
                tx_precharge: begin
                             data_sr <= 16'b0101010101010101;
                             busy_sr <= 16'b1111111111111111;
                             tx_state <= tx_sync;
                         end
                tx_sync: begin
                             data_sr <= 16'b0101010101010101;
                             busy_sr <= 16'b1111111111111111;
                             tx_state <= tx_sync2;
                         end
                tx_sync2: begin
                             data_sr <= 16'b0101010101010101;
                             busy_sr <= 16'b1111111111111111;
                             tx_state <= tx_start;
                         end
                tx_start: begin
                             //---------------------------------------------------
                              // Just send the start pattern.
                              //
                              // The TX fifo must have something in it to get here.
                              //---------------------------------------------------
                              data_sr <= 16'b1111000000000000;
                              busy_sr <= 16'b1111111100000000;
                              tx_state <= tx_send_data;
                              rx_reset <= 1'b1;
                              tx_rd_en <= 1'b1;
                          end 
                tx_send_data: begin
                                  data_sr <= {tx_rd_data[7], ~tx_rd_data[7], tx_rd_data[6], ~tx_rd_data[6],
                                              tx_rd_data[5], ~tx_rd_data[5], tx_rd_data[4], ~tx_rd_data[4],
                                              tx_rd_data[3], ~tx_rd_data[3], tx_rd_data[2], ~tx_rd_data[2],
                                              tx_rd_data[1], ~tx_rd_data[1], tx_rd_data[0], ~tx_rd_data[0]};
                                  busy_sr <= 16'b1111111111111111;
                                  if(tx_empty == 1'b1) begin
                                     // Send this word, and follow it up with a STOP
                                     tx_state <= tx_stop;
                                  end else begin
                                     // Send this word, and also read the next one from the FIFO
                                     tx_rd_en <= 1'b1;                                  
                                  end
                              end
                tx_stop: begin
                            //----------------------
                            // Send the STOP pattern
                            //----------------------
                            data_sr    <= 16'b1111000000000000;
                            busy_sr    <= 16'b1111111100000000;
                            tx_state   <= tx_flush;
                          end
                tx_flush: begin
                             //-------------------------------------------
                             // Just wait here until we are no longer busy
                             //-------------------------------------------
                             tx_state <= tx_waiting;
                          end 
            endcase
        end
    end else  begin
        //----------------------------------
        // Not time yet to send the next bit
        //----------------------------------
        bit_counter <= bit_counter + 1;
    end
     
    //---------------------------------------------
    // How the RX process indicates that we are now 
    // free to send another transaction
    //---------------------------------------------
    if(tx_state == tx_waiting && rx_finished == 1'b1) begin
        tx_state <= tx_idle;
    end

    //-------------------------------------------
    // Managing the TX FIFO 
    // As soon as a word appears in the FIFO it 
    // is sent. As it takes 8us to send a byte, the 
    // FIFO can be filled quicker than data is sent,
    // ensuring we don't have underrun the TX FIFO 
    // and send a short message.
    //-------------------------------------------
    if(tx_full_i == 1'b0 && tx_wr_en == 1'b1) begin
        tx_fifo[tx_wr_ptr] <= tx_data;
        tx_wr_ptr <= tx_wr_ptr+1;
    end

    if(tx_empty == 1'b0 && tx_rd_en == 1'b1) begin
          tx_rd_data <= tx_fifo[tx_rd_ptr];
          tx_rd_ptr  <= tx_rd_ptr + 1;
    end
    //------------------------------------------------  
    // Managing the RX FIFO 
    //
    // The contents of the FIFO is reset during the TX
    // of a new transaction. Pointer updates are
    // seperated from the data read / writes to allow
    // the reset to work.
    //------------------------------------------------
    if(rx_full == 1'b0 && rx_wr_en == 1'b1) begin
        rx_fifo[rx_wr_ptr] <= rx_wr_data;
    end

    if(rx_empty_i == 1'b0 && rx_rd_en == 1'b1) begin
        rx_data   <= rx_fifo[rx_rd_ptr];
    end

    if(rx_reset == 1'b1) begin
        rx_wr_ptr <= rx_rd_ptr;
    end else  begin
        if(rx_full == 1'b0 && rx_wr_en == 1'b1) begin
          rx_wr_ptr <= rx_wr_ptr+1;
        end

        if(rx_empty_i == 1'b0 && rx_rd_en == 1'b1) begin
           rx_rd_ptr <= rx_rd_ptr + 1;
        end
    end
    
    //----------------------------------------
    // Manage the timeout. If it is 
    // waiting for a reply for over 400us) begin
    // signal a timeout to the upper FSM.
    //----------------------------------------
    if(bit_counter == bit_counter_max) begin 
        if(tx_state == tx_waiting) begin 
            if(timeout_count == 400*CLKPERMICROSECOND) begin
                tx_state      <= tx_idle;
                timeout       <= 1'b1;
            end else  begin
                timeout_count <= timeout_count + 1;
            end
        end else  begin
            timeout_count <= 0;
        end
    end
    if(abort == 1'b1) begin
        tx_state <= tx_idle;
    end
end

always @(posedge clk) begin
    rx_wr_en    <= 1'b0;
    rx_finished <= 1'b0;
    
    //--------------------------------
    // Is it time to sample a new half-bit?
    //--------------------------------
    if(rx_count == CLKPERMICROSECOND/2 -1) begin  
        rx_a_bit <= 1'b1;
        rx_buffer <= { rx_buffer[14:0], rx_synced};
        rx_bits   <= { rx_bits[14:0],   1'b1};
        rx_count <= 5'b00000;
    end else  begin
        rx_count <= rx_count+1;
        rx_a_bit <= 1'b0;
    end
    
    //--------------------------------------
    // Have we just sampled a new half-bit?
    //--------------------------------------
    if(rx_a_bit == 1'b1) begin 
        case(rx_state)
            rx_waiting: begin
                            //---------------------------------------------------
                            // Are we seeing the end of the SYNC/START sequence?
                            //---------------------------------------------------
                            if(rx_buffer == 16'b0101010111110000) begin
                                rx_bits <= 16'h0000;
                                if(rx_holdoff[9] == 1'b0) begin
                                     //------------------------------------
                                     // Yes, switch to receiving bits, but,
                                     // but only if(the TX modules hasn't
                                     // transmitted for a short while....
                                     //------------------------------------
                                    rx_state <= rx_receiving_data;
                                end
                            end
                        end
            rx_receiving_data: begin
                                    //-------------------------------------------------------
                                    // Have we just received the 16th half-bit of the a byte?
                                    //-------------------------------------------------------
                                    if(rx_bits[15] == 1'b1) begin
                                        rx_bits <= 16'h0000;
                                        //----------------------------------------------
                                        // Are we missing transistions that are required
                                        // for valid data bytes?
                                        //
                                        // Or in other words, is this an error or (more 
                                        // usually) the STOP pattern?
                                        //-----------------------------------------------
                                        if(rx_buffer[15] == rx_buffer[14] || rx_buffer[13] == rx_buffer[12] ||
                                           rx_buffer[11] == rx_buffer[10] || rx_buffer[9]  == rx_buffer[8]  ||
                                           rx_buffer[7]  == rx_buffer[6]  || rx_buffer[5]  == rx_buffer[4]  ||
                                           rx_buffer[3]  == rx_buffer[2]  || rx_buffer[1]  == rx_buffer[0] ) begin
                                           //--------------------------------------------------------
                                           // Yes, We finished receiving data, or truncate any errors
                                           //--------------------------------------------------------
                                            rx_state <= rx_waiting;
                                            if(rx_holdoff[9] == 1'b0) begin
                                                rx_finished <= 1'b1;
                                            end
                                        end else begin
                                            //-------------------------------------------------
                                            // Looks like a valid byte, so write it to the FIFO
                                            //--------------------------------------------------
                                            rx_wr_data <= { rx_buffer[15], rx_buffer[13], rx_buffer[11], rx_buffer[9],
                                                            rx_buffer[7],  rx_buffer[5],  rx_buffer[3],  rx_buffer[1]};
                                            rx_wr_en <= 1'b1;
                                        end
                                    end
                               end
            rx_done:  begin 
                           //  waiting to be reset (so I ignore noise!)
                          rx_state <= rx_done;
                      end 
            default:  begin
                          rx_state <= rx_waiting;
                      end
            endcase
    end
    //-----------------------------------------------
    // Detect the change on the AUX line, and 
    // make sure we sample the data mid-way through
    // the half-bit (e.g 0.25us, 0.75us, 1.25 us...)
    // from when the last transition was seen.
    //----------------------------------------------
    if(rx_synced != rx_last) begin
        rx_count <= CLKPERMICROSECOND / 4;
    end
    
    //-----------------------------------------------
    // The transmitted resets the RX FSM when it is
    // sending a request. This is a counter measure
    // against line noise when neigher end is driving
    // the link.
    //-----------------------------------------------
    if(rx_reset == 1'b1) begin
        rx_state <= rx_waiting;
    end
    
    rx_last   <= rx_synced;
    //--------------------------
    // Synchronise the RX signal
    //--------------------------
    rx_synced <= rx_meta;
    snoop     <= rx_meta;
    //------------------------------------------------------
    // This is done to convert Zs or Xs in simulations to 0s
    //------------------------------------------------------
    if(aux_in == 1'b1) begin
        rx_meta <= 1'b1;
    end else  begin
        rx_meta <= 1'b0;
    end
    
    if(abort == 1'b1) begin
        rx_state <= rx_waiting;
    end

end

endmodule
