`timescale 1ns/1ps

/*

	Schematic sheet: 85606-A- -1/8 CPU

*/

module jt_gng_a2(
	input	[12:0]	AB,
	input			WRAM_b,
	input			WRB_b,
	input			RDB_b,
	inout	[7:0]	DB,
	output	[2:0]	bank,
	output	[1:0]	counter,
	output			SRES_b,
	output			FLIP,
	input			ACLI_b,
	output			RGCS_b,
	output			BCS_b,
	output			SOUND,
	output			SCRPO_b,
	output			OKOUT_b,
	input			ECLK,
	input			EXTEN_b,
	output			CHARCS_b,
	output			SCRCS_b,
	output			INCS_b
);

reg [7:0] ram[0:8191];
reg [7:0] dread;
wire [7:0] D = WRB_b && !RDB_b ? dread : 8'hzz;

always @(AB) begin
	dread=ram[addr];
end


jt74245 i_jt74245 (.a(DB), .b(RDB_b), .dir(RDB_b), .en_b(WRAM_b));
wire [7:0] ext_decoded;
jt74139 i_jt74139 (.en1_b(EXTEN_b), .a1(AB[10:8]), .y1_b(ext_decoded), .en2_b(1'b1), .a2(2'b0) );
assign RGCS_b  = ext_decoded[0];
assign BCS_b   = ext_decoded[1];
assign SOUND   = ext_decoded[2];
assign SCRPO_b = ext_decoded[3];
assign OKOUT_b = ext_decoded[4];


endmodule // jt_gng_a2
