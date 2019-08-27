`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-4/9 Object ROM

*/

module jt_gng_b4(
	input	[9:0]	AD,
	input	[3:0]	Vbeta,
	input			OBH4,
	input			OBH8,

	input		V1,
	input		V2,
	input		V4,
	input		V8,
	input		V16,
	input		V32,
	input		V64,
	input		V128,
	input		OH,
	input		VINZONE,
	input		FLIP,
	input		OBHFLIPq,
	input		G4_3H,		// C4

	output		BLTIMING,
	output		LV1,
	output		LV1_bq,
	output		OBFLIP1,
	output		OBFLIP2,
	output		DISPIM_bq,
	output		[3:0] COL,

	input		G6M,
	output		L6MB,
	output		OB6M,
	input		TR3_b,
	input		LHBL,	// D9
	// 1ST, 1CL, 1WR, 1LOAD in the schematics
	output		ST1_b,
	output		CL1_b,
	output		WR1_b,
	output		LOAD1_b,
	// 2ST, 2CL, 2WR, 2LOAD in the schematics
	output		ST2_b,
	output		CL2_b,
	output		WR2_b,
	output		LOAD2_b
);

// ROMs
reg [7:0] mem_3n[0:16383];
reg [7:0] mem_2n[0:16383];
reg [7:0] mem_1n[0:16383];
reg [7:0] mem_3l[0:16383];
reg [7:0] mem_2l[0:16383];
reg [7:0] mem_1l[0:16383];

wire [14:0] addr = { AD[8:0], OBH8, Vbeta, OBH4 };

wire [3:0] ROM_ce;
jt74139 u_dec (
	.en1_b	(1'b0),
	.a1		(AD[9:8]),
	.y1_b	(ROM_ce),
	// unused half
	.en2_b	(1'b1),
	.a2		(2'b0)
);

initial begin
	$readmemh("../../rom/3n.hex",mem_3n);
	$readmemh("../../rom/2n.hex",mem_2n);
	$readmemh("../../rom/1n.hex",mem_1n);
	$readmemh("../../rom/3l.hex",mem_3l);
	$readmemh("../../rom/2l.hex",mem_2l);
	$readmemh("../../rom/1l.hex",mem_1l);
end

reg [7:0] DN, DL;

always @(addr,ROM_ce) begin
	case( ROM_ce[2:0] )
		3'b110: begin
			DN <= mem_3n[addr];
			DL <= mem_3l[addr];
		end
		3'b101: begin
			DN <= mem_2n[addr];
			DL <= mem_2l[addr];
		end
		3'b011: begin
			DN <= mem_1n[addr];
			DL <= mem_1l[addr];
		end
		default: begin
			DN <= 8'hZZ;
			DL <= 8'hZZ;
		end
	endcase // ROM_ce
end

// shift registers
wire [1:0] S;
wire [3:0] QZ,QY,QX,QW;
wire G6M_buf;
assign #5 G6M_buf = G6M; // 6K

jt74194 u_1K (
	.D		(DN[7:4]),   // Z
	.S		(S		),
	.clk	(G6M_buf),
	.cl_b	(1'b1	),
	.R		(1'b0	),
	.L		(1'b0	),
	.Q		(QZ		)
);

jt74194 u_2K (
	.D		(DN[3:0]),   // Y
	.S		(S		),
	.clk	(G6M_buf),
	.cl_b	(1'b1	),
	.R		(1'b0	),
	.L		(1'b0	),
	.Q		(QY		)
);

jt74194 u_3K (
	.D		(DL[7:4]),   // X
	.S		(S		),
	.clk	(G6M_buf),
	.cl_b	(1'b1	),
	.R		(1'b0	),
	.L		(1'b0	),
	.Q		(QX		)
);

jt74194 u_4K (
	.D		(DL[3:0]),   // W
	.S		(S		),
	.clk	(G6M_buf),
	.cl_b	(1'b1	),
	.R		(1'b0	),
	.L		(1'b0	),
	.Q		(QW		)
);

jt74257 u_5K (
	.sel	(OBHFLIPq),
	.en_b	(timings[0]),
	.a		( {QW[0],QX[0],QY[0],QZ[0]} ),
	.b		( {QW[3],QX[3],QY[3],QZ[3]} ),
	.y		( COL )
);

assign #2 S[1] = ~OBHFLIPq | G4_3H; // 8K
assign #2 S[0] =  OBHFLIPq | G4_3H; // 6K

// timing

assign #2 L6MB = ~G6M;  // 8K
assign #2 OB6M = ~L6MB;  // 8K

reg [2:0] gal_14k[0:255];
wire [7:0] VV = {V128,V64,V32,V16,V8,V4,V2,V1};
reg [2:0] vgal;

initial begin
		$readmemh("../../rom/14k.hex",gal_14k);
end

always @(VV)
	vgal = gal_14k[VV];

assign BLTIMING = vgal[2];

assign #2 LV1 = ~V1; // 8K

reg [3:0] timings;
always @(posedge OH) // 11K
	timings <= { V1, vgal[0], vgal[1], VINZONE };

assign DISPIM_bq = timings[1]; // vgal[1]
assign #2 LV1_bq = ~timings[3]; // 8K
assign #2 OBFLIP2 = timings[3] & FLIP; // 7K
assign #2 OBFLIP1 = LV1_bq & FLIP; // 7K

wire [5:0] NoConn;

jt74139 u_9K (
	// unused half
	.en1_b	(1'b1	),
	.a1		(2'b0	),
	// 1ST, 2ST
	.en2_b	(timings[2]						),
	.a2		({G6M,timings[3]}				),
	.y2_b	({NoConn[1:0], ST1_b, ST2_b}	)
);

jt74139 u_10K (
	// 1LOAD, 2LOAD
	.en1_b	( vgal[0]		),
	.a1		({ TR3_b, V1 }	),
	.y1_b	({NoConn[3:2],LOAD1_b, LOAD2_b}),
	// 1ST, 2ST
	.en2_b	(DISPIM_bq						),
	.a2		({~LHBL,timings[3]}				),
	.y2_b	({CL2_b, CL1_b, NoConn[5:4]}	)
);

assign #2 WR2_b = ~&{ CL2_b, L6MB };
assign #2 WR1_b = ~&{ CL1_b, L6MB };



endmodule // jt_gng_b4