`timescale 1ns / 1ps
//`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: AZXUNO
// Engineer: Miguel Angel Rodriguez Jodar
// 
// Create Date:    19:12:34 03/16/2017 
// Design Name:    
// Module Name:    config_retriever
// Project Name:   Modulo para extraer la configuracion inicial RGB-VGA de la SRAM
// Target Devices: ZXUNO Spartan 6
// Additional Comments: all rights reserved for now
//
//////////////////////////////////////////////////////////////////////////////////

module config_retriever (
  input  wire        clk,
  input  wire [20:0] sram_addr_in,
  input  wire        sram_we_n_in,
  input  wire        sram_oe_n_in,
  input  wire [7:0]  sram_data_to_chip,
  output wire [7:0]  sram_data_from_chip,
  
  output wire [19:0] sram_addr_out,
  output wire        sram_we_n_out,
  output wire        sram_oe_n_out,
  output wire        sram_ub_n_out,
  output wire        sram_lb_n_out,  
  inout  wire [15:0] sram_data,
  output wire        pwon_reset,

  output wire        vga_on,
  output wire        scanlines_off
  );
  
  reg [7:0] videoconfig = 8'h00;
  reg [31:0] shift_master_reset = 32'hFFFFFFFF;
  
  always @(posedge clk) begin
    shift_master_reset <= {shift_master_reset[30:0], 1'b0};
    if (shift_master_reset[16:15] == 2'b10)
      videoconfig <= sram_data[7:0];
  end
  assign pwon_reset = shift_master_reset[31];
  
  assign sram_addr_out = (pwon_reset == 1'b1)? 20'h08FD5  : sram_addr_in[19:0];
  assign sram_we_n_out = (pwon_reset == 1'b1)? 1'b1       : sram_we_n_in;
  assign sram_oe_n_out = (pwon_reset == 1'b1)? 1'b0       : sram_oe_n_in;
  assign sram_ub_n_out = (pwon_reset == 1'b1)? 1'b1       : ~sram_addr_in[20];
  assign sram_lb_n_out = (pwon_reset == 1'b1)? 1'b0       : sram_addr_in[20];
  assign sram_data     = (pwon_reset == 1'b1 || 
                          sram_we_n_in == 1'b1)? 16'hZZZZ : {sram_data_to_chip, sram_data_to_chip};
  assign sram_data_from_chip = (pwon_reset == 1'b1)? 8'hFF      :
                         (sram_we_n_in == 1'b1 && sram_addr_in[20])? sram_data[15:8] :
                         (sram_we_n_in == 1'b1 && ~sram_addr_in[20])? sram_data[7:0] : sram_data_to_chip;
                                                                                                                            
  assign vga_on = videoconfig[0];
  assign scanlines_off = ~videoconfig[1];
endmodule
