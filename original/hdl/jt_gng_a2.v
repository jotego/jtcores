`timescale 1ns/1ps

/*

	Schematic sheet: 85606-A- -1/8 CPU

*/

module jt_gng_a2(
	inout	[12:0]	AB,
	input			WRAM_b,
	input			WRB_b,
	input			RDB_b,
	inout	[7:0]	DB,
	output	[2:0]	bank,
	output	[1:0]	counter,
	output			SRES_b,
	output			FLIP,
	input			ALC1_b,
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

wire [7:0] Dram;

jt_gng_genram #(.addrw(13),.id(0)) u_2C (
	.A(AB), .D(Dram), .cs_b(WRAM_b), .rd_b(RDB_b), .wr_b(WRB_b));


jt74245 u_3B (.a(DB), .b(Dram), .dir(RDB_b), .en_b(WRAM_b));
wire [3:0] GRCS;
jt74139 u_9K (.en1_b(EXTEN_b), .a1(AB[12:11]), .y1_b(GRCS), .en2_b(1'b1), .a2(2'b0) );
assign CHARCS_b = GRCS[0];
assign SCRCS_b  = GRCS[1];
assign INCS_b   = GRCS[2];

wire [7:0] ext_decoded;
jt74138 u_3D (.e1_b(GRCS[3]), .e2_b(GRCS[3]), .e3(ECLK), .a(AB[10:8]), .y_b(ext_decoded));


wire [7:0] other;
jt74259 u_9B (.D(DB[0]), .A(AB[2:0]), .Q(other), .LE_b(ext_decoded[5]), .MR_b(ALC1_b));

assign counter = other[3:2];
assign SRES_b = other[1];
assign FLIP = other[0];

assign RGCS_b  = ext_decoded[0];
assign BCS_b   = ext_decoded[1];
assign SOUND   = ext_decoded[2];
assign SCRPO_b = ext_decoded[3];
assign OKOUT_b = ext_decoded[4];

wire [2:0] noConnIn_3C = 3'b111;
wire [2:0] noConnOut_3C;

jt74174 u_3C (.d({noConnIn_3C,DB[2:0]}), .q({noConnOut_3C,bank[2:0]}), .cl_b(ALC1_b), .clk(ext_decoded[6]));

`ifdef RAM_INFO
always @(posedge ext_decoded[6])
	$display("Bank set to %d",DB[2:0]);
`endif

endmodule // jt_gng_a2
