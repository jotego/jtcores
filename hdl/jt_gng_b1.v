`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-8/9 Scroll video RAM

*/

module jt_gng_b1(
	input		V1,
	input		V2,
	input		V4,
	input		V8,
	input		V16,
	input		V32,
	input		V64,
	input		V128,
	input		FLIP,
	output		V1F,
	output		V2F,
	output		V4F,
	output		V8F,
	output		V16F,
	output		V32F,
	output		V64F,
	output		V128F
);

assign {V1F,V2F,V4F,V8F,V16F,V32F,V64F,V128F} 
	= {8{FLIP}} ^ { V1,V2,V4,V8,V16,V32,V64,V128};

endmodule // jt_gng_b1

