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


jt74245 u_3B (.a(DB), .b(RDB_b), .dir(RDB_b), .en_b(WRAM_b));
wire [3:0] GRCS;
jt74139 u_9K (.en1_b(EXTEN_b), .a1(AB[12:11]), .y1_b(GRCS), .en2_b(1'b1), .a2(2'b0) );
assign CHARCS_b = GRCS[0];
assign SCRCS_b  = GRCS[1];
assign INCS_b   = GRCS[2];

wire [7:0] ext_decoded;
jt74138 u_3D (.e1_b(GRCS[3]), .e2_b(GRCS[3]), .e3(ECLK), .a(AB[10:8]), .y_b(ext_decoded));


wire [7:0] other;
jt74259 u_9B (.D(OB[0]), .A(AB[2:0]), .Q(other), .LE_b(ext_decoded[5]), .MR_b(ACLI_b));

assign counter = other[3:2];
assign SRES_b = other[1];
assign FLIP = other[0];

assign RGCS_b  = ext_decoded[0];
assign BCS_b   = ext_decoded[1];
assign SOUND   = ext_decoded[2];
assign SCRPO_b = ext_decoded[3];
assign OKOUT_b = ext_decoded[4];

jt74174 u_3C (.d(DB[2:0]), .q(bank[2:0]), .cl_b(ACLI_b), .clk(ext_decoded[6]));

endmodule // jt_gng_a2
