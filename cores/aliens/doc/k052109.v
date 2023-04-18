// TMNT arcade core
// Simulation blind schematic copy version
// Sean Gonsalves 2022
// k052109: Plane address generator
// Generates GFX ROM address in sequence according to contents of VRAM
// Handles coarse scrolling only, fine scrolling is done in the k051962

// CPU access read and write seems ok

`timescale 1ns/100ps

module k052109 (
	input nRES,
	output RST,
	input clk_24M,

	output clk_12M,

	input CRCS,		// CPU GFX ROM access
	input RMRD,
	input VCS,		// CPU VRAM access
	input NRD,		// CPU read
	output FIRQ,
	output IRQ,
	output NMI,
	output PQ,		// 6809
	output PE,		// 6809
	output HVOT,	// Frame sync tick
	output RDEN,	// ? Unused
	output WREN,	// ? Unused
	output WRP,		// ? Unused

	// CPU interface
	input [7:0] DB_IN,
	output [7:0] DB_OUT,
	input [15:0] AB,

	// VRAM interface
	output [15:0] VD_OUT,
	input [15:0] VD_IN,
	output [12:0] RA,
	output [1:0] RCS,
	output [2:0] ROE,
	output [2:0] RWE,

	// GFX ROMs interface
	output reg [2:1] CAB,
	output [10:0] VC,

	output VDE,	// ?

	// k051962 interface
	output [7:0] COL,				// Tile COL attribute bits
	output ZA1H, ZA2H, ZA4H,	// Plane A fine scroll
	output ZB1H, ZB2H, ZB4H,	// Plane B fine scroll
	output BEN,		// Reg 1E80 write

	output DB_DIR
);

wire [8:0] PXH;	// Not used anymore ?
wire [8:3] PXHF;	// H tile number, affected by FLIP_SCREEN
wire [7:0] ROW;
wire [10:0] MAP_A;
wire [10:0] MAP_B;
wire [2:0] ROW_A;
wire [2:0] ROW_B;
wire [9:0] SCROLL_RAM_A;

reg [5:0] REG1C00;	// Bits 6 and 7 unused ?
reg [7:0] REG1C80;
reg [3:0] REG1D00;
reg [7:0] REG1D80;
reg [7:0] RMRD_BANK;
reg [7:0] REG1F00;


// VRAM ADDRESS

// E40: Enable/disable scrolling entirely
assign E40 = (REG1C80[0] & PXH[5]) | (REG1C80[3] & ~PXH[5]);

// Flip H coordinate for scrolling if FLIP_SCREEN set
wire [5:0] FLIP_ADDER;
wire FLIP_SCREEN;
assign FLIP_ADDER = PXHF + {6{FLIP_SCREEN}};

// X/Y scroll table switch
// X scroll is raster based with selectable interval
// Y scroll is tile column based (320 / 8 = only 40 useful values)
wire AA38; // selects whether to read row or col scroll values
		   // scroll data is available at the same time for layer A and B
		   // as they are stored in different RAM chips but only one is
		   // read depending on PXH[5] because the address set varies (E40)
assign SCROLL_RAM_A = AA38 ? {1'b1, ROW[7:3], ROW[2:0] & {3{E40}}, PXH[3]} : {4'b0000, FLIP_ADDER};

// T5As:
wire nCPU_ACCESS;
wire [12:0] RA_MUX_A;
wire [12:0] RA_MUX_B;
wire [12:0] RA_MUX_C;
// PXH[2:1]	Address									Description
// 0			110 SCROLL_RAM_A						Scroll data
// 1			01 MAP_A[10:0]							Tilemap A
// 2			10 MAP_B[10:0]							Tilemap B
// 3			00 ROW[7:3] PXH[8:5] PXHF[4:3]	Fixmap
assign RA_MUX_A = ~PXH[1] ? {3'b110, SCROLL_RAM_A } : { 2'b01, MAP_A };
assign RA_MUX_B =  PXH[1] ? {2'b00, ROW[7:3], PXHF} : { 2'b10, MAP_B };
assign RA_MUX_C = ~PXH[2] ? RA_MUX_A : RA_MUX_B;
assign RA = nCPU_ACCESS ? RA_MUX_C : AB[12:0];

wire CPU_VRAM_CS0, CPU_VRAM_CS1, J140_nQ, J151;
assign ROE[0] = nCPU_ACCESS ? J140_nQ : RDEN;
assign ROE[1] = nCPU_ACCESS ? J151 : RDEN;
assign ROE[2] = nCPU_ACCESS ? 1'b1 : RDEN;	// Only CPU access ? What's the point ?

assign RCS[0] = nCPU_ACCESS ? 1'b0 : CPU_VRAM_CS0;
assign RCS[1] = nCPU_ACCESS ? 1'b0 : CPU_VRAM_CS1;


// Clocks

FDO J140(nclk_12M, clk_6M, RES_SYNC, J140_Q, J140_nQ);
assign J151 = J140_Q & REG1C00[5];

FDO H79(clk_6M, ~PE, nCPU_ACCESS, H79_Q, );
assign VDE = H79_Q | RMRD;

FDN K141(clk_24M, nclk_12M, RES_SYNC, clk_12M, nclk_12M);
FDN J114(clk_24M, ~^{nclk_12M, nclk_6M}, RES_SYNC, clk_6M, nclk_6M);

FDN J94(clk_24M, ~^{clk_3M, ~(nclk_12M & nclk_6M)}, RES_SYNC, clk_3M, nclk_3M);
FDE J79(~clk_24M, nclk_3M, RES_SYNC, nCPU_ACCESS,);

assign C92 = ~|{&{~CRCS, clk_3M, PE}, REG1C00[5]};

FDO K123(clk_24M, nclk_3M, RES_SYNC, K123_Q, K123_nQ);
FDO K148(clk_24M, K123_Q, RES_SYNC, K148_Q,);
FDE L120(clk_24M, K148_Q, RES_SYNC, PQ,);
FDO K130(clk_24M, K148_Q, RES_SYNC, K130_Q,);

reg [3:0] K77_Q;
always @(posedge clk_24M or negedge RES_SYNC) begin
	if (!RES_SYNC)
		K77_Q <= 4'b0000;
	else
		K77_Q <= {NRD & K123_Q, ~&{NRD, clk_3M, K123_nQ}, ~&{NRD, K123_nQ, K130_Q}, clk_3M};
end

// M6809 stuff
assign PE = K77_Q[0];
assign WRP = K77_Q[1];
assign WREN = K77_Q[2];
assign RDEN = K77_Q[3];


// GFX ROM ADDRESS

// Reg 1E80 bit 2: Enable tile flip Y when attribute bit 1 set
FDO C64(BEN, DB_IN[2], RES_SYNC, C64_Q,);
assign TILE_FLIP_Y = COL[1] & C64_Q;

// Latch row number for fix tile
wire [2:0] ROW_F;
FDG CC59(PXH[1], ROW[2], RES_SYNC, ROW_F[2],);
FDG CC68(PXH[1], ROW[1], RES_SYNC, ROW_F[1],);
FDG BB39(PXH[1], ROW[0], RES_SYNC, ROW_F[0],);

// Select tile line number according to current raster line and Y scroll
// T5As
wire [2:0] VC_MUX_B;
wire [2:0] VC_MUX_C;
// PXH[2:1]	Address						Description
// 0			CC59_Q CC68_Q BB39_Q		Fix
// 1			CC59_Q CC68_Q BB39_Q		Fix
// 2			ROW_A[2:0] 					Layer A
// 3			ROW_B[2:0]					Layer B
assign VC_MUX_B = PXH[1] ? ROW_B[2:0] : ROW_A[2:0];
assign VC_MUX_C = ~PXH[2] ? ROW_F : VC_MUX_B;

reg [10:0] CPU_ROM_A;
reg [10:0] RENDER_ROM_A;

// LTKs
always @(*) begin
	if (!C92) begin
		// LSBs delayed by BD3s
		CPU_ROM_A = AB[12:2];
	end

	if (!nCPU_ACCESS) begin
		// Why is this needed ? Really controlled by nCPU_ACCESS ?
		RENDER_ROM_A[2:0] = VC_MUX_C ^ {3{TILE_FLIP_Y}};
	end
end

// Catch tile number from VRAM
always @(negedge PXH[0])
	RENDER_ROM_A[10:3] <= VD_IN[7:0];

// Select between rendering and CPU ROM reading
assign VC = RMRD ? CPU_ROM_A : RENDER_ROM_A;


// CPU STUFF

// CPU data is presented to both VRAM chips
assign VD_OUT = {DB_IN, DB_IN};

// Reset input sync
FDE N122(clk_24M, 1'b1, nRES, RES_SYNC,);

// 8-frame delay for RES -> RST
// Same in k051962
wire TRIG_IRQ;
reg [7:0] RES_delay;
always @(posedge TRIG_IRQ or negedge RES_SYNC) begin
	if (!RES_SYNC)
		RES_delay <= 8'h00;
	else
		RES_delay <= {RES_delay[6:0], RES_SYNC};
end
assign RST = RES_delay[7];

// Interrupt flags
// Same in k051960
FDN P4(TRIG_IRQ, 1'b0, REG1D00[2], IRQ,);
FDN F27(TRIG_FIRQ, 1'b0, REG1D00[1], FIRQ,);
FDN CC52(TRIG_NMI, 1'b0, REG1D00[0], NMI,);

// VRAM and registers mapping / hardware configuration
// I don't really understand how this works, but it does
// Since this is PCB-related, it makes sense that REG1C00[4:0] is set at startup and never changed again
wire A126; // Selects RAM[2]
assign B123 = |{CPU_VRAM_CS0, RDEN, ~REG1C00[4]};
assign B129 = |{A126, RDEN, ~REG1C00[4]};
assign B121 = ~REG1C00[4] & REG1C00[3];
assign B119 = ~REG1C00[4] & REG1C00[2];
assign A154 = ~|{CPU_VRAM_CS1, RDEN};

assign B137 = ~&{A154, ~B119, ~B121};
assign B143 = ~&{A154, ~B119, B121};
assign B139 = ~&{A154, B119, ~B121};
assign VD_SEL = B129 & B139;	// VRAM upper/lower read select
assign DB_DIR = B137 & B123 & B143 & VD_SEL;

assign REG_WR = ~RWE[1];

// VRAM and register access only enabled when not reading GFX ROMs
assign E34 = ~|{VCS, RMRD};

reg [5:0] range;
always @(*) begin
	casez({E34, AB[15:13]})
		4'b1000: range <= 6'b111110;	// 0000~1FFF
		4'b1001: range <= 6'b111101;	// 2000~3FFF
		4'b1010: range <= 6'b111011;	// 4000~5FFF
		4'b1011: range <= 6'b110111;	// 6000~7FFF
		4'b1100: range <= 6'b101111;	// 8000~9FFF
		4'b1101: range <= 6'b011111;	// A000~BFFF
		default: range <= 6'b111111;
	endcase
end

/*
REG1C00_D[1:0]:

        Regs
   RWE0 RWE1 RWE2
   VCS0 VCS1
00 A~B  6~7  8~9  Reset state
01 8~9  4~5  6~7
10 6~7  2~3  4~5
11 4~5  0~1  2~3  TMNT setting

VCS2 is not a pin. RAM's CS is always tied down
*/

T5A A111(range[2], range[3], range[5], range[4], REG1C00[0], REG1C00[1], A111_OUT);
assign CPU_VRAM_CS0 = ~A111_OUT;
assign RWE[0] = WRP | CPU_VRAM_CS0;

T5A A106(range[1], range[2], range[4], range[3], REG1C00[0], REG1C00[1], A106_OUT);
assign A126 = ~A106_OUT;
assign RWE[2] = WRP | A126;

T5A A100(range[0], range[1], range[3], range[2], REG1C00[0], REG1C00[1], A100_OUT);
assign CPU_VRAM_CS1 = ~A100_OUT;
assign RWE[1] = WRP | CPU_VRAM_CS1;

// VRAM read by CPU - Upper/lower byte select
reg [15:0] VD_LATCH;
always @(*) begin
	if (!nclk_3M)
		VD_LATCH <= VD_IN;
end
assign DB_OUT = VD_SEL ? VD_LATCH[15:8] : VD_LATCH[7:0];


// H/V COUNTERS

// H counter
// 9-bit counter, resets to 9'h020 after 9'h19F, effectively counting 384 pixels
FDO H20(clk_6M, PE, RES_SYNC, PXH[0],);
C43 N16(clk_6M, 4'b0000, ~LINE_END, PXH[0], PXH[0], RES_SYNC, PXH[4:1], N16_COUT);
C43 G29(clk_6M, 4'b0001, ~LINE_END, N16_COUT, N16_COUT, RES_SYNC, PXH[8:5],);
assign PXHF = PXH[8:3] ^ {6{FLIP_SCREEN}};

// Set/reset at pixel 9'h05F, used to disable X/Y scrolling table read toggle during hblank ?
// See G4_Q signal
FDO G4(clk_6M, ~G2, RES_SYNC, G4_Q,);
assign G2 = ~&{~LINE_END, G4_Q | (N16_COUT & PXH[6])};
assign AA38 = ~G4_Q;

assign LINE_END = &{N16_COUT, PXH[8:7]};

// V counter
// 9-bit counter, resets to 9'h0F8 after 9'h1FF, effectively counting 264 raster lines
wire [8:0] ROW_RAW;
FDO G20(clk_6M, ~^{LINE_END, ~ROW_RAW[0]}, RES_SYNC, ROW_RAW[0],);
assign TRIG_FIRQ = ROW_RAW[0];

C43 J29(clk_6M, 4'b1100, ~H29_COUT, ROW_RAW[0], LINE_END & ROW_RAW[0], RES_SYNC, ROW_RAW[4:1], J29_COUT);
C43 H29(clk_6M, 4'b0111, ~H29_COUT, ROW_RAW[0], J29_COUT, RES_SYNC, ROW_RAW[8:5], H29_COUT);
assign HVOT = ~H29_COUT;

assign ROW = {ROW_RAW[7:0]} ^ {8{FLIP_SCREEN}};

// Trigger vblank IRQ at line 9h'1F8
FDO K42(ROW_RAW[4], &{ROW_RAW[7:5]}, RES_SYNC, TRIG_IRQ,);

// Trigger NMI every 32 lines ?
FDG CC13(ROW_RAW[2], CC13_nQ, RES_SYNC, CC13_Q, CC13_nQ);
FDG CC24(CC13_Q, CC24_nQ, RES_SYNC, TRIG_NMI, CC24_nQ);


// REGISTERS

wire D23  /* synthesis keep */ ;
assign D23 = ~&{(AB[12:7] == 6'b1_1100_0), REG_WR};
always @(posedge D23 or negedge RES_SYNC) begin
	if (!RES_SYNC)
		REG1C00 <= 6'h00;
	else
		REG1C00 <= DB_IN[5:0];
end

assign D7 = ~&{(AB[12:7] == 6'b1_1100_1), REG_WR};
always @(posedge D7 or negedge RES_SYNC) begin
	if (!RES_SYNC)
		REG1C80 <= 8'h00;
	else
		REG1C80 <= DB_IN;
end

assign D18 = ~&{(AB[12:7] == 6'b1_1101_0), REG_WR};
always @(posedge D18 or negedge RES_SYNC) begin
	if (!RES_SYNC)
		REG1D00 <= 4'h0;
	else
		REG1D00 <= DB_IN[3:0];
end

assign D12 = ~&{(AB[12:7] == 6'b1_1101_1), REG_WR};
always @(posedge D12 or negedge RES_SYNC) begin
	if (!RES_SYNC)
		REG1D80 <= 8'h00;
	else
		REG1D80 <= DB_IN;
end

assign D28 = ~&{(AB[12:7] == 6'b1_1110_0), REG_WR};
always @(posedge D28 or negedge RES_SYNC) begin
	if (!RES_SYNC)
		RMRD_BANK <= 8'h00;
	else
		RMRD_BANK <= DB_IN;
end

// Reg 1E80
assign BEN = ~&{(AB[12:7] == 6'b1_1110_1), REG_WR};
FDO M53(BEN, DB_IN[0], RES_SYNC, FLIP_SCREEN,);

assign D33 = ~&{(AB[12:7] == 6'b1_1111_0), REG_WR};
always @(posedge D33 or negedge RES_SYNC) begin
	if (!RES_SYNC)
		REG1F00 <= 8'h00;
	else
		REG1F00 <= DB_IN;
end


// Layer A and B scroll

assign BB33 = |{PXHF[8:7], ~PXHF[6:5], PXHF[4], PXH[3]}; // PXH=='h60

assign X57 = ~|{ROW[7:0]};
assign READ_SCROLL_A = &{~G4_Q,  PXH[5], REG1C80[1] | X57, RES_SYNC};
assign READ_SCROLL_B = &{~G4_Q, ~PXH[5], REG1C80[4] | X57, RES_SYNC};

k052109_scroll SCROLL_A(
	.RES_SYNC(RES_SYNC),
	.PXH(PXH[3:0]),
	.PXHF(PXHF),
	.ROW(ROW),
	.READ_SCROLL(READ_SCROLL_A),
	.VD_IN(VD_IN[15:8]),
	.FLIP_SCREEN(FLIP_SCREEN),
	.SCROLL_Y_EN(REG1C80[2]),
	.BB33(BB33),
	.MAP(MAP_A),
	.ROW_S(ROW_A),
	.FINE({ZA4H, ZA2H, ZA1H})
);

k052109_scroll SCROLL_B(
	.RES_SYNC(RES_SYNC),
	.PXH(PXH[3:0]),
	.PXHF(PXHF),
	.ROW(ROW),
	.READ_SCROLL(READ_SCROLL_B),
	.VD_IN(VD_IN[7:0]),
	.FLIP_SCREEN(FLIP_SCREEN),
	.SCROLL_Y_EN(REG1C80[5]),
	.BB33(BB33),
	.MAP(MAP_B),
	.ROW_S(ROW_B),
	.FINE({ZB4H, ZB2H, ZB1H})
);


// COL OUTPUTS

// Catch tile attributes for layer A and B (notation may be swapped)
// Fix attribute must go in one of these alternatively
reg [7:0] COL_ATTR_A;
always @(negedge PXH[0])
	COL_ATTR_A <= VD_IN[15:8];

reg [7:0] COL_ATTR_B;
always @(posedge J140_nQ)
	COL_ATTR_B <= VD_IN[15:8];

assign F130 = &{clk_6M, REG1C00[5], ~PXH[0]};

wire [7:0] COL_MUX;
assign COL_MUX = F130 ? COL_ATTR_B : COL_ATTR_A;

// COL_MUX[3:2]	{CAB, COL[3:2] out (COL_MUX_A)}
// 0					REG1D80[3:0]
// 1					REG1D80[7:4]
// 2					REG1F00[3:0]
// 3					REG1F00[7:4]

reg [1:0] COL_MUX_A;
always @(*) begin
	case(COL_MUX[3:2])
		2'd0: {CAB, COL_MUX_A} <= REG1D80[3:0];
		2'd1: {CAB, COL_MUX_A} <= REG1D80[7:4];
		2'd2: {CAB, COL_MUX_A} <= REG1F00[3:0];
		2'd3: {CAB, COL_MUX_A} <= REG1F00[7:4];
	endcase
end

assign COL = RMRD ? RMRD_BANK :
           { COL_MUX[7:4], REG1C00[5] ? COL_MUX[3:2] : COL_MUX_A, COL_MUX[1:0]};

endmodule
