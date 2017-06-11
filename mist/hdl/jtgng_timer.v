`timescale 1ns/1ps

module jtgng_timer(
	input				clk,	// 6MHz
	input				rst,
	output	reg [8:0]	V,
	output	reg [8:0]	H,
	output	reg			Hinit,
	output	reg			LHBL,
	output	reg			LVBL,
	output	reg			G4_3H,	// high on 3/4 H transition
	output	reg			G4H, // high on 4H transition
	output	reg			OH   // high on 0H transition
);

// H/V counters
always @(negedge clk) begin
	if( rst ) begin
		{ Hinit, H } <= 10'd0;
		LHBL <= 1'd0;
		V <= 9'd250;
	end
	else if(Hinit) begin
		{ Hinit, H } <= 10'h80;
		V <= &V ? 9'd250 : V + 1'd1;
	end
	else 
		{ Hinit, H } <= H + 1'b1;
end

// L Horizontal/Vertical Blanking
always @(negedge clk) begin
	if( &H[2:0] )
		LHBL <= H[8];
	if( V==9'd496 ) LVBL <= 1'b0;
	if( V==9'd272 ) LVBL <= 1'b1;
end

// H indicators
always @(negedge clk) begin
	G4H <= &H[1:0];
	OH  <= &H[2:0];
end

always @(posedge clk) begin
	G4_3H <= &H[1:0];
end

endmodule // jtgng_timer