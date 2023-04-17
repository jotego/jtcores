// TMNT arcade core
// Simulation blind schematic copy version
// Sean Gonsalves 2022
// k051962: Plane data processor
// Gets 8px rows from the GFX ROMs, selects which pixel must be used (fine scrolling)
// and delays pixel + COL values for each layer so that they're output all at the same time

`timescale 1ns/100ps

module k051962 (
	input nRES,
	output RST,
	input clk_24M,

	output clk_6M, clk_12M,
	output P1H,

	input CRCS,
	input BEN,		// Reg 1E80 write
	input RMRD,		// Unused, only usefull on the real chip to set the DB pins direction
	input ZA1H, ZA2H, ZA4H,	// Plane A fine scroll
	input ZB1H, ZB2H, ZB4H,	// Plane B fine scroll
	input [7:0] COL,			// Tile COL attribute bits

	input [31:0] VC,	// GFX ROM data

	// Layers
	output reg [11:0] DSA,
	output reg [11:0] DSB,
	output reg [7:0] DFI,	// Fix layer can only use COL[3:0]

	// Opacity signals
	output NSAC,
	output NSBC,
	output NFIC,

	// Video sync and blanking
	output NVBK,
	output NHBK,
	output OHBK,
	output NVSY,
	output NHSY,
	output NCSY,

	// CPU interface
	input [7:0] DB_IN,
	output reg [7:0] DB_OUT,
	input [1:0] AB,

	output DB_DIR
);

wire [8:0] PXH;

// TIMING GEN

// Reset input sync
FDE BB8(clk_24M, 1'b1, nRES, RES_SYNC,);

// Clocks
FDN Z4(clk_24M, nclk_12M, RES_SYNC, clk_12M, nclk_12M);
FDN Z47(clk_24M, ~^{nclk_6M, nclk_12M}, RES_SYNC, clk_6M, nclk_6M);
FDG Z68(clk_24M, clk_6M, RES_SYNC, , T61);
FDN Z19(clk_24M, ~^{clk_3M, ~&{nclk_6M, nclk_12M}}, RES_SYNC, clk_3M,);

// GFX data latch sequence
assign V154 = ~&{PXH[2:0]};
assign X80 = ~&{~PXH[2:1], PXH[0]};
assign X78 = ~&{PXH[2], ~PXH[1], PXH[0]};

// NHSY generation
FDG AA86(clk_6M, ~LINE_END & (OHBK | (Z99_COUT & PXH[6])), RES_SYNC, OHBK, AA86_nQ);
FDN Z81(PXH[4], ~&{AA86_nQ, Z80}, RES_SYNC, Z81_Q,);
FDN Z88(PXH[3], Z81_Q, RES_SYNC, Z88_Q,);
FDN Y86(PXH[1], Z88_Q, RES_SYNC, NHSY,);

// NHBK generation
assign Y151 = PXH[0] & PXH[3] & ~|{PXH[2:1]};
FDG Y100(clk_6M, Y151, RES_SYNC, Y100_Q,);
FDG AA77(Y100_Q, OHBK, RES_SYNC, NHBK,);

FDG Z59(clk_24M, clk_3M, RES_SYNC, Z59_Q,);

// H counter
// 9-bit counter, resets to 9'h020 after 9'h19F, effectively counting 384 pixels
FDG Y77(clk_6M, Z59_Q, RES_SYNC, PXH[0],);
C43 Z99(clk_6M, 4'b0000, ~LINE_END, PXH[0], PXH[0], RES_SYNC, PXH[4:1], Z99_COUT);
C43 AA108(clk_6M, 4'b0001, ~LINE_END, Z99_COUT, Z99_COUT, RES_SYNC, PXH[8:5],);
assign P1H = PXH[0];
assign Z80 = ~PXH[6];

assign LINE_END = &{Z99_COUT, PXH[8:7]};

// V counter
// 9-bit counter, resets to 9'h0F8 after 9'h1FF, effectively counting 264 raster lines
wire [8:0] ROW;
FDG BB87(clk_6M, ~^{LINE_END, ~ROW[0]}, RES_SYNC, ROW[0],);
C43 BB105(clk_6M, 4'b1100, ~CC107_COUT, ROW[0], LINE_END & ROW[0], RES_SYNC, ROW[4:1], BB105_COUT);
C43 CC107(clk_6M, 4'b0111, ~CC107_COUT, ROW[0], BB105_COUT, RES_SYNC, ROW[8:5], CC107_COUT);

// Vblank output at line 9h'1F8
FDG CC87(ROW[4], &{ROW[7:5]}, RES_SYNC, VBK, NVBK);
LTL CC98(ROW[8], NHSY, RES_SYNC, NVSY,);
assign NCSY = NVSY & NHSY;

// 8-frame delay for RES -> RST
// Same in k052109
reg [7:0] RES_delay;
always @(posedge VBK or negedge RES_SYNC) begin
	if (!RES_SYNC)
		RES_delay <= 8'h00;
	else
		RES_delay <= {RES_delay[6:0], RES_SYNC};
end
assign RST = RES_delay[7];


// ROM READBACK MUX

always @(*) begin
	case(AB)
		2'd0: DB_OUT <= VC[7:0];
		2'd1: DB_OUT <= VC[15:8];
		2'd2: DB_OUT <= VC[23:16];
		2'd3: DB_OUT <= VC[31:24];
	endcase
end


// SCROLLING

// Reg 1E80
FDG S77(BEN, DB_IN[0], RES_SYNC, FLIP_SCREEN,);
FDG S86(BEN, DB_IN[1], RES_SYNC, TILE_FLIP_X_EN,);

// COL[0] delayed twice
FDM J61(CLK_6M, V154 ? ~J61_nQ : COL[0], , J61_nQ);
FDM K83(CLK_6M, L77 ? ~K83_nQ : J61_nQ, , K83_nQ);

// COL[0] delayed once
FDM M61(CLK_6M, X80 ? ~M61_nQ : COL[0], , M61_nQ);

assign FLIP_X_A = ~&{TILE_FLIP_X_EN, DSA[10]} ^ FLIP_SCREEN;
assign FLIP_X_B = ~&{TILE_FLIP_X_EN, K83_nQ} ^ FLIP_SCREEN;
assign FLIP_X_F = ~&{TILE_FLIP_X_EN, M61_nQ} ^ FLIP_SCREEN;

assign T19 = ~&{ZA1H, ZA2H, ZA4H};
wire [2:0] PX_SEL_A;
assign PX_SEL_A = {ZA4H, ZA2H, ZA1H} ^ {3{FLIP_X_A}};

assign L77 = ~&{ZB1H, ZB2H, ZB4H};
wire [2:0] PX_SEL_B;
assign PX_SEL_B = {ZB4H, ZB2H, ZB1H} ^ {3{FLIP_X_B}};

FDG X116(PXH[1], PXH[2], RES_SYNC, X116_Q,);
wire [2:0] PX_SEL_F;
assign PX_SEL_F = {X116_Q, ~PXH[1], P1H} ^ {3{FLIP_X_F}};

// Layer A 8-pixel row color delay
// VC[31:24]: Color bits 3
// VC[23:16]: Color bits 2
// VC[15:8]: Color bits 1
// VC[7:0]: Color bits 0
reg [31:0] LA_DELAY_A;
reg [31:0] LA_DELAY_B;
reg [31:0] LA_DELAY_C;
always @(posedge clk_6M) begin
	if (!X78) LA_DELAY_A <= VC;
	if (!V154) LA_DELAY_B <= LA_DELAY_A;
	if (!T19) LA_DELAY_C <= LA_DELAY_B;
end

// Select pixel depending on fine X scroll
reg [3:0] LA_COLOR;
always @(*) begin
	case(PX_SEL_A)
		3'd0: LA_COLOR <= {LA_DELAY_C[24], LA_DELAY_C[16], LA_DELAY_C[8], LA_DELAY_C[0]};
		3'd1: LA_COLOR <= {LA_DELAY_C[25], LA_DELAY_C[17], LA_DELAY_C[9], LA_DELAY_C[1]};
		3'd2: LA_COLOR <= {LA_DELAY_C[26], LA_DELAY_C[18], LA_DELAY_C[10], LA_DELAY_C[2]};
		3'd3: LA_COLOR <= {LA_DELAY_C[27], LA_DELAY_C[19], LA_DELAY_C[11], LA_DELAY_C[3]};
		3'd4: LA_COLOR <= {LA_DELAY_C[28], LA_DELAY_C[20], LA_DELAY_C[12], LA_DELAY_C[4]};
		3'd5: LA_COLOR <= {LA_DELAY_C[29], LA_DELAY_C[21], LA_DELAY_C[13], LA_DELAY_C[5]};
		3'd6: LA_COLOR <= {LA_DELAY_C[30], LA_DELAY_C[22], LA_DELAY_C[14], LA_DELAY_C[6]};
		3'd7: LA_COLOR <= {LA_DELAY_C[31], LA_DELAY_C[23], LA_DELAY_C[15], LA_DELAY_C[7]};
	endcase
end

// Layer A palette delay
reg [7:0] LA_PAL_DELAY_A;
reg [7:0] LA_PAL_DELAY_B;
reg [3:0] LA_PAL_DELAY_C;
always @(posedge clk_6M) begin
	if (!X78) LA_PAL_DELAY_A <= COL;
	if (!V154) LA_PAL_DELAY_B <= LA_PAL_DELAY_A;
	if (!T19) begin
		DSA[11:8] <= LA_PAL_DELAY_B[3:0];
		LA_PAL_DELAY_C <= LA_PAL_DELAY_B[7:4];
	end
end

always @(*) begin
	if (!T61) DSA[7:4] <= LA_PAL_DELAY_C;
end


// Layer B 8-pixel row color delay
// VC[31:24]: Color bits 3
// VC[23:16]: Color bits 2
// VC[15:8]: Color bits 1
// VC[7:0]: Color bits 0
reg [31:0] LB_DELAY_A;
reg [31:0] LB_DELAY_B;
always @(posedge clk_6M) begin
	if (!V154) LB_DELAY_A <= VC;
	if (!L77) LB_DELAY_B <= LB_DELAY_A;
end

// Select pixel depending on fine X scroll
reg [3:0] LB_COLOR;
always @(*) begin
	case(PX_SEL_B)
		3'd0: LB_COLOR <= {LB_DELAY_B[24], LB_DELAY_B[16], LB_DELAY_B[8], LB_DELAY_B[0]};
		3'd1: LB_COLOR <= {LB_DELAY_B[25], LB_DELAY_B[17], LB_DELAY_B[9], LB_DELAY_B[1]};
		3'd2: LB_COLOR <= {LB_DELAY_B[26], LB_DELAY_B[18], LB_DELAY_B[10], LB_DELAY_B[2]};
		3'd3: LB_COLOR <= {LB_DELAY_B[27], LB_DELAY_B[19], LB_DELAY_B[11], LB_DELAY_B[3]};
		3'd4: LB_COLOR <= {LB_DELAY_B[28], LB_DELAY_B[20], LB_DELAY_B[12], LB_DELAY_B[4]};
		3'd5: LB_COLOR <= {LB_DELAY_B[29], LB_DELAY_B[21], LB_DELAY_B[13], LB_DELAY_B[5]};
		3'd6: LB_COLOR <= {LB_DELAY_B[30], LB_DELAY_B[22], LB_DELAY_B[14], LB_DELAY_B[6]};
		3'd7: LB_COLOR <= {LB_DELAY_B[31], LB_DELAY_B[23], LB_DELAY_B[15], LB_DELAY_B[7]};
	endcase
end

// Layer B palette delay
reg [7:0] LB_PAL_DELAY_A;
reg [3:0] LB_PAL_DELAY_B;
always @(posedge clk_6M) begin
	if (!V154) LB_PAL_DELAY_A <= COL;
	if (!L77) begin
		DSB[11:8] <= LB_PAL_DELAY_A[3:0];
		LB_PAL_DELAY_B <= LB_PAL_DELAY_A[7:4];
	end
end

// Where's COL0 on the schematics ?
always @(*) begin
	if (!T61) DSB[7:4] <= LB_PAL_DELAY_B;
end


// Layer Fix 8-pixel row color delay
// VC[31:24]: Color bits 3
// VC[23:16]: Color bits 2
// VC[15:8]: Color bits 1
// VC[7:0]: Color bits 0
reg [31:0] LF_DELAY_A;
always @(posedge clk_6M) begin
	if (!X80) LF_DELAY_A <= VC;
end

// Select pixel
reg [3:0] LF_COLOR;
always @(*) begin
	case(PX_SEL_F)
		3'd0: LF_COLOR <= {LF_DELAY_A[24], LF_DELAY_A[16], LF_DELAY_A[8], LF_DELAY_A[0]};
		3'd1: LF_COLOR <= {LF_DELAY_A[25], LF_DELAY_A[17], LF_DELAY_A[9], LF_DELAY_A[1]};
		3'd2: LF_COLOR <= {LF_DELAY_A[26], LF_DELAY_A[18], LF_DELAY_A[10], LF_DELAY_A[2]};
		3'd3: LF_COLOR <= {LF_DELAY_A[27], LF_DELAY_A[19], LF_DELAY_A[11], LF_DELAY_A[3]};
		3'd4: LF_COLOR <= {LF_DELAY_A[28], LF_DELAY_A[20], LF_DELAY_A[12], LF_DELAY_A[4]};
		3'd5: LF_COLOR <= {LF_DELAY_A[29], LF_DELAY_A[21], LF_DELAY_A[13], LF_DELAY_A[5]};
		3'd6: LF_COLOR <= {LF_DELAY_A[30], LF_DELAY_A[22], LF_DELAY_A[14], LF_DELAY_A[6]};
		3'd7: LF_COLOR <= {LF_DELAY_A[31], LF_DELAY_A[23], LF_DELAY_A[15], LF_DELAY_A[7]};
	endcase
end

// Layer Fix palette delay
reg [3:0] LF_PAL_DELAY_A;
always @(posedge clk_6M) begin
	if (!X80) LF_PAL_DELAY_A <= COL[7:4];
end

// Where's COL0 on the schematics ?
always @(*) begin
	if (!T61) DFI[7:4] <= LF_PAL_DELAY_A;
end


// OUTPUT LATCHES

always @(*) begin
	if (!T61) begin
		DSA[3:0] <= LA_COLOR;
		DSB[3:0] <= LB_COLOR;
		DFI[3:0] <= LF_COLOR;
	end
end
assign NSAC = |{LA_COLOR};
assign NSBC = |{LB_COLOR};
assign NFIC = |{LF_COLOR};

assign DB_DIR = ~&{~CRCS, RMRD};

endmodule
