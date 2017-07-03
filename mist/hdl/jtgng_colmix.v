`timescale 1ns/1ps

module jtgng_colmix(
	input			rst,
	input			clk,	// 6*6=36 MHz
	input [1:0]		char,
	input [3:0]		cc,		// character color code
	input [7:0]		AB,
	input			blue_cs,
	input			redgreen_cs,
	input [7:0]		DB,
	output 	[3:0]	red,
	output 	[3:0]	green,
	output 	[3:0]	blue
);



endmodule // jtgng_colmix