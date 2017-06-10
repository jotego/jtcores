`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-3/9 Object data control

*/

module jt_gng_b3(
	inout	[1:0]		OB,
	input	[4:0]		OBA,
	inout	[7:0]		DEA,
	inout	[7:0]		DEB,
	input				OBASEL_b,
	input				OBBSEL_b,
	input				OBJABWR_b,
	input				G4H,
	input				OH,
	input				H1,
	input				H2,
	input				H4,
	input				H8,
	input				H16,
	input				H32,
	input				H64,
	input				H128,
	input				H256,
	input				LV1,
	input				TM2496_b,
	output				TR3_b,
	output	reg			OBHFLIPq,
	output	reg			COL4,
	output	reg			COL5,
	output				OBH4,
	output				OBH8,
	output	reg			HOVER,
	output	[3:0]		Vbeta,
	output				VINZONE,
	output	reg [9:0]	AD,
	output		[7:0]	DF,
	input				V128F,
	input				V64F,
	input				V32F,
	input				V16F,
	input				V8F,
	input				V4F,
	input				V2F,
	input				V1F,
	input				FLIP
);

wire [6:0] AdrH = {H256,H128,H64,H32,H16,H4,H2};
wire [7:0] Vin = {V128F,V64F,V32F,V16F,V8F,V4F,V2F,V1F};

reg  [6:0] AdrA, AdrB;
wire [7:0] DEA, DEB;
reg  wrA_b, wrB_b;
// 11H, 12H
jt_gng_genram #(.addrw(7),.id(5)) OBJRAM_A (.A(AdrA), .D(DEA), .cs_b(1'b0), .rd_b(1'b0), .wr_b(wrA_b));
// 11H, 12H
jt_gng_genram #(.addrw(7),.id(6)) OBJRAM_B (.A(AdrB), .D(DEB), .cs_b(1'b0), .rd_b(1'b0), .wr_b(wrB_b));

pullup( DEA[7], DEA[6], DEA[5], DEA[4], DEA[3], DEA[2], DEA[1], DEA[0]);
pullup( DEB[7], DEB[6], DEB[5], DEB[4], DEB[3], DEB[2], DEB[1], DEB[0]);

// 13H, 14H
always @(*) begin
	wrA_b = OBASEL_b ? 1'b1 : OBJABWR_b;
	AdrA = OBASEL_b ? AdrH : {OBA, OB };
end

// 13J, 14J
always @(*) begin
	wrB_b = OBBSEL_b ? 1'b1 : OBJABWR_b;
	AdrB = OBBSEL_b ? AdrH : {OBA, OB };
end

// 9H, 9J
assign #4 DF = !TM2496_b ? (LV1 ? DEB : DEA) : 8'h00;

wire [3:0] pixel_cnt;
jt74139 u_9K (.en1_b(H8), .a1({H4,H2}), .y1_b(pixel_cnt), .en2_b(1'b1), .a2(2'b0));

assign TR2_b = pixel_cnt[2];
wire TR2;
assign #2 TR2 = ~TR2_b; // 6H
assign #2 TR3_b = ~(H1 &~pixel_cnt[3]);

reg [7:0] ADaux;

// 6J
always @(posedge pixel_cnt[0])
	ADaux <= DF;

reg OBHFLIP, OBVFLIP_b;
reg [1:0] COLaux;

always @(posedge pixel_cnt[1]) begin
	AD <= {DF[7:6], ADaux }; // 5J
	// 8J
	HOVER <= DF[0];
	{COLaux, OBVFLIP_b, OBHFLIP } <= {DF[5:2]};
end

// 10J
always @(posedge OH)
	{COL5,COL4,OBHFLIPq} <= {COLaux,OBHFLIP};

assign OBH4 = H4 ^ ~OBHFLIP; // 6H, 5D
assign OBH8 = OBH4 ^ H8; // 5D

reg [7:0] Vq, VFq;

always @(posedge TR2) // 7J
	Vq <= DF;

always @(posedge G4H) // 8E, 7E
	VFq <= Vin;

wire [7:0] FLIPsum, VinFLIP, Vsum;
assign #2 FLIPsum = {{7{~FLIP}},1'b1};
assign #2 VinFLIP = VFq + FLIPsum;
assign #2 Vsum = VinFLIP + Vq;
assign #2 VINZONE = ~&Vsum[7:4];
assign #2 Vbeta = {4{~OBVFLIP_b}} ^ Vsum[3:0];

endmodule // jt_gng_b3