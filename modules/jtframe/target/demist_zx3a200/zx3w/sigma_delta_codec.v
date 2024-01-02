`timescale 1ns / 1ps
//`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.05.2023 00:49:04
// Design Name: 
// Module Name: sigma_delta_codec
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

`define MSBI 7 // Most significant Bit of DAC input

module sigma_delta_codec (
  input wire clk,
  input wire [15:0] audio_l,
  input wire [15:0] audio_r,
  output wire sd_audio_l,
  output wire sd_audio_r 
  );
  
  wire [7:0] audio8il = audio_l[15:8] ^ 8'h80;
  wire [7:0] audio8ir = audio_r[15:8] ^ 8'h80;
  sd_dac izquierdo (clk, 1'b0, audio8il, sd_audio_l);
  sd_dac derecho   (clk, 1'b0, audio8ir, sd_audio_r);
endmodule

module sd_dac (
	input wire Clk,
	input wire Reset,
	input wire [`MSBI:0] DACin, // DAC input (excess 2**MSBI)
	output reg DACout // This is the average output that feeds low pass filter
	);
	
	reg [`MSBI+2:0] DeltaAdder; // Output of Delta adder
	reg [`MSBI+2:0] SigmaAdder; // Output of Sigma adder
	reg [`MSBI+2:0] SigmaLatch = 1'b1 << (`MSBI+1); // Latches output of Sigma adder
	reg [`MSBI+2:0] DeltaB; // B input of Delta adder

	always @(SigmaLatch) DeltaB = {SigmaLatch[`MSBI+2], SigmaLatch[`MSBI+2]} << (`MSBI+1);
	always @(DACin or DeltaB) DeltaAdder = DACin + DeltaB;
	always @(DeltaAdder or SigmaLatch) SigmaAdder = DeltaAdder + SigmaLatch;
	always @(posedge Clk)
	begin
		if(Reset)
		begin
			SigmaLatch <= 1'b1 << (`MSBI+1);
			DACout <= 1'b0;
		end
		else
		begin
			SigmaLatch <= SigmaAdder;
			DACout <= SigmaLatch[`MSBI+2];
		end
	end
endmodule

//`default_nettype wire
