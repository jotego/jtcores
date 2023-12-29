`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.05.2023 23:33:17
// Design Name: 
// Module Name: i2s_sound
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module i2s_sound (
  input wire clk,
  input wire [15:0] audio_l,
  input wire [15:0] audio_r,
  output reg i2s_bclk,
  output wire i2s_lrclk,
  output wire i2s_dout
  );
  
  parameter [15:0] CLKMHZ = 16'd50;
  localparam [7:0] PRESCALER = 1; // (CLKMHZ * 500 / (64*192)) -1;  // duración de un semiperiodo de BCLK para 192 kHz
  
  reg counter = 0;
  reg [5:0] cntbit = 0;
  reg [63:0] sr_sample;

  initial i2s_bclk = 1'b0;
  
  assign i2s_lrclk = cntbit[5];
  assign i2s_dout = sr_sample[63];
  
  always @(posedge clk) begin
    counter <= ~counter;
    if (counter == PRESCALER) begin
      i2s_bclk <= ~i2s_bclk;
      if (i2s_bclk == 1'b1) begin   // flanco negativo de BCLK...
        cntbit <= cntbit + 1;
        if (cntbit == 0)
          sr_sample <= {audio_l, 16'h0000, audio_r, 16'h0000};          
        else
          sr_sample <= {sr_sample[62:0], 1'b0};
      end
    end
  end  
endmodule
