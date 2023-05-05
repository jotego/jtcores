// TMNT arcade core
// Simulation blind schematic copy version
// Sean Gonsalves 2022
`timescale 1ns/1ns

// Read tests/notes.txt !
// TODO: Why is there an OA_in (external sprite RAM address bus) ? Get rid of it if it's for a test mode.

// Internal RAM blocks are named according to their disposition on the die, they do NOT match which attribute byte they stored
// ATTR0 (sprite active flag and priority) only read from external RAM for loading, not stored
// RAM_F: ATTR1	Sprite size, tile code MSBs
// RAM_E: ATTR2	Tile code LSBs
// RAM_C: ATTR3	Attributes
// RAM_D: ATTR4	Zoom Y, flip Y, Y position MSB
// RAM_B: ATTR5	Y position LSBs
// RAM_A: ATTR6	Zoom X, flip X, X position MSB
// RAM_G: ATTR7	X position LSBs

module k051960 (
	input nRES,
	output RST,
	input clk_24M,
	output clk_6M, clk_12M,

	output P1H,
	output P2H,
	
	input HVIN,
	output HVOT,	// Frame sync tick
	
	output PQ, PE,	// 6809

	output WRP, WREN, RDEN,	// ? Unused
	input NRD,		// CPU read
	input OBCS,
	output IRQ, FIRQ, NMI,

	// CPU interface
	input [7:0] DB_IN,
	output [7:0] DB_OUT,
	input [10:0] AB,
	
	// k051937 interface
	output OHF, OREG, HEND, LACH, CARY,
	output [8:0] HP,	// X position
	output [7:0] OC,	// Attributes

	// GFX ROMs interface
	output [17:0] CA,

	// External RAM interface
	input [9:0] OA_in,
	output [9:0] OA_out,
	output OWR, OOE,
	input [7:0] OD_in,
	output [7:0] OD_out,
	
	output DB_DIR
);

wire [8:0] PXH;
wire [7:0] ROW;

wire [9:0] ATTR_A;
wire [6:0] SPR_PRIO;

wire [7:0] RAM_din;

wire [7:0] RAM_A_dout;
wire [7:0] RAM_B_dout;
wire [7:0] RAM_C_dout;
wire [7:0] RAM_D_dout;
wire [7:0] RAM_E_dout;
wire [7:0] RAM_F_dout;
wire [7:0] RAM_G_dout;

wire [6:0] PARSE_A;

wire RAM_DATA_WR;

wire [7:0] SPR_YDIFF;
reg [2:0] SPR_SIZE;
reg [12:0] SPR_CODE;

wire [3:0] R50_Q;
wire [3:0] S28_Q;

reg [3:0] AM195_Q;
reg [3:2] AN195_Q;
wire [3:0] SUBTILE_H;
wire [5:1] TILE_CODE_PRE;

wire [6:0] KREG_A;
wire [6:0] KREG_B;
wire [6:0] KREG_C;
wire [6:0] KREG_D;

wire [7:0] REG2;
wire [7:0] REG3;
wire [1:0] REG4;

wire [3:0] TILE_ROW;

reg [5:0] SPR_ATTR_ZY_DELAY;
reg SPR_Y8, SPR_VFLIP;

wire [17:0] CA_RENDER;

// Reset input sync
FDE AA1(clk_24M, 1'b1, nRES, RES_SYNC, );

// Clocks
FDN AA51(clk_24M, nclk_12M, RES_SYNC, clk_12M, nclk_12M);
FDN AA70(clk_24M, ~^{nclk_12M, nclk_6M}, RES_SYNC, clk_6M, nclk_6M);

FDO AB91(clk_24M, ~clk_6M, RES_SYNC, AB91_Q, AB91_XQ);
FDO AB12(~clk_24M, AB91_Q, RES_SYNC, , AB12_XQ);
assign AB19 = AB12_XQ & AB91_XQ;

FDN AA141(clk_24M, ~^{clk_3M, ~&{nclk_12M, nclk_6M}}, RES_SYNC, clk_3M, nclk_3M);
FDE AA128(~clk_24M, nclk_3M, RES_SYNC, nCPU_ACCESS, );
assign CPU_ACCESS = ~nCPU_ACCESS;

FDO AA121(clk_24M, nclk_3M, RES_SYNC, AA121_Q, AA121_XQ);
FDO AA85(clk_24M, AA121_Q, RES_SYNC, AA85_Q, );
FDE AA41(clk_24M, AA85_Q, RES_SYNC, PQ, );
FDO AA63(clk_24M, AA85_Q, RES_SYNC, AA63_Q, );
assign AA96 = ~&{AA63_Q, AA121_XQ};
assign AA94 = ~&{NRD, AA63_Q, AA121_XQ};
assign AA113 = ~&{NRD, ~nclk_3M, AA121_XQ};
assign AA92 = NRD | AA121_Q;

wire [3:0] AA11_Q;
FDR AA11(clk_24M, {AA92, AA113, AA94, AA96}, RES_SYNC, AA11_Q);

// M6809 stuff
assign AB98 = ~AA11_Q[0];
assign WRP = AA11_Q[1];
assign WREN = AA11_Q[2];
assign RDEN = AA11_Q[3];

FDE AA103(clk_24M, clk_3M, RES_SYNC, PE, );


// H/V COUNTERS

// H counter
// 9-bit counter, resets to 9'h020 after 9'h19F, effectively counting 384 pixels
FDO T121(clk_6M, PE, RES_SYNC, PXH[0], );
C43 R207(clk_6M, 4'b0000, HRST, PXH[0], PXH[0], RES_SYNC, PXH[4:1], R207_COUT);
C43 P233(clk_6M, 4'b0001, HRST, R207_COUT, R207_COUT, RES_SYNC, PXH[8:5], );
assign P1H = PXH[0];
assign P2H = PXH[1];
assign LINE_END = &{R207_COUT, PXH[8:7]};
assign HRST = ~LINE_END;

// HVIN sync
reg [7:0] DELAY_HVIN;
always @(posedge clk_6M or negedge RES_SYNC) begin
	if (!RES_SYNC) begin
		DELAY_HVIN <= 8'h00;
	end else begin
		DELAY_HVIN <= {DELAY_HVIN[6:0], ~HVIN};
	end
end

// V counter
// 9-bit counter, resets to 9'h0F8 after 9'h1FF, effectively counting 264 raster lines
wire [8:0] ROW_RAW;
FDO T247(clk_6M, ~|{DELAY_HVIN[7], ^{LINE_END, ~ROW_RAW[0]}}, RES_SYNC, ROW_RAW[0], );

// DEBUG START - FOR SIMULATION ONLY
reg [7:0] SIM_V_COUNTER;
always @(posedge clk_6M or posedge ~RES_SYNC) begin
	if (!HVOT)
		SIM_V_COUNTER <= 8'b0111_1100;	// Load
	else if (!RES_SYNC)
		SIM_V_COUNTER <= 8'b1111_0111;	// Reset value for simulation
	else if (LINE_END & ROW_RAW[0])
		SIM_V_COUNTER <= SIM_V_COUNTER + 1'b1;
	else
		SIM_V_COUNTER <= SIM_V_COUNTER;
end
assign ROW_RAW[8:1] = SIM_V_COUNTER;
assign T53_COUT = &{ROW_RAW[8:0]};
// DEBUG STOP - FOR SIMULATION ONLY
// Normal logic:
//C43 S233(clk_6M, 4'b1100, HVOT, ROW_RAW[0], LINE_END & ROW_RAW[0], RES_SYNC, ROW_RAW[4:1], S233_COUT);
//C43 T53(clk_6M, 4'b0111, HVOT, ROW_RAW[0], S233_COUT, RES_SYNC, ROW_RAW[8:5], T53_COUT);
assign HVOT = ~T53_COUT;


wire FLIP_SCREEN;
assign ROW = {ROW_RAW[7:0]} ^ {8{FLIP_SCREEN}};

// Start vblank at line 9h'1F0 included, stop at 9'h110 excluded
FDO T192(ROW_RAW[4], &{ROW_RAW[7:4]}, RES_SYNC, VBLANK, );


// INTERNAL RAM

// Internal RAM WEs
wire Z95, VBLANK_SYNC;
assign RAM_F_WE = &{AB98, VBLANK_SYNC, Z95, ATTR_A[2:0] == 3'b001};	// ATTR1
assign RAM_E_WE = &{AB98, VBLANK_SYNC, Z95, ATTR_A[2:0] == 3'b010};	// ATTR2
assign RAM_C_WE = &{AB98, VBLANK_SYNC, Z95, ATTR_A[2:0] == 3'b011};	// ATTR3
assign RAM_D_WE = &{AB98, VBLANK_SYNC, Z95, ATTR_A[2:0] == 3'b100};	// ATTR4
assign RAM_B_WE = &{AB98, VBLANK_SYNC, Z95, ATTR_A[2:0] == 3'b101};	// ATTR5
assign RAM_A_WE = &{AB98, VBLANK_SYNC, Z95, ATTR_A[2:0] == 3'b110};	// ATTR6
assign RAM_G_WE = &{AB98, VBLANK_SYNC, Z95, ATTR_A[2:0] == 3'b111};	// ATTR7

// Internal RAM address - 8-to-1 bus mux
reg [6:0] RAM_addr;
wire X148, Y72, Y73;

always @(*) begin
	case({X148, Y72, Y73})
		// Front
		3'd0: RAM_addr <= SPR_PRIO[6:0];	// B1
		3'd1: RAM_addr <= ATTR_A[9:3];	// B2
		3'd2: RAM_addr <= KREG_C;			// A2
		3'd3: RAM_addr <= KREG_D;			// A1
		// Back
		3'd4: RAM_addr <= KREG_B;			// B1
		3'd5: RAM_addr <= KREG_A;			// B2
		3'd6: RAM_addr <= PARSE_A[6:0];	// A2
		3'd7: RAM_addr <= OA_in[9:3];		// A1 Shouldn't be used outside of test mode ?
	endcase
end

// Sprite RAM reg to feed internal RAM
reg [7:0] RAM_din_latch;
always @(posedge clk_3M)
	RAM_din_latch <= OD_in;

assign RAM_din = RAM_DATA_WR ? RAM_din_latch : 8'h00;

ram_sim #(8, 7, "") RAMA(RAM_addr, ~RAM_A_WE, AB19, RAM_din, RAM_A_dout);
ram_sim #(8, 7, "") RAMB(RAM_addr, ~RAM_B_WE, AB19, RAM_din, RAM_B_dout);
ram_sim #(8, 7, "") RAMC(RAM_addr, ~RAM_C_WE, AB19, RAM_din, RAM_C_dout);
ram_sim #(8, 7, "") RAMD(RAM_addr, ~RAM_D_WE, AB19, RAM_din, RAM_D_dout);
ram_sim #(8, 7, "") RAME(RAM_addr, ~RAM_E_WE, AB19, RAM_din, RAM_E_dout);
ram_sim #(8, 7, "") RAMF(RAM_addr, ~RAM_F_WE, AB19, RAM_din, RAM_F_dout);
ram_sim #(8, 7, "") RAMG(RAM_addr, ~RAM_G_WE, AB19, RAM_din, RAM_G_dout);

// Sprite RAM CPU read
wire [7:0] EXRAM_D_LATCH;
LT4 AE121(nclk_3M, OD_in[7:4], EXRAM_D_LATCH[7:4], );
LT4 AD121(nclk_3M, OD_in[3:0], EXRAM_D_LATCH[3:0], );

// Select between reg 0 read and sprite RAM read
wire nREG0_R;
assign DB_OUT[0] = nREG0_R ? EXRAM_D_LATCH[0] : ~VBLANK_SYNC;
assign DB_OUT[7:1] = EXRAM_D_LATCH[7:1];

// Sprite RAM data bus output is always = CPU bus input
assign OD_out = DB_IN;


// ADDER CHAIN (multiplier)

assign AN143 = SPR_ATTR_ZY_DELAY[1] & SPR_YDIFF[0];
wire [4:0] AX101_S;
wire [2:0] AR101_S;
A4H AX101(SPR_YDIFF[0] ? SPR_ATTR_ZY_DELAY[5:2] : 4'b0000, SPR_YDIFF[1] ? SPR_ATTR_ZY_DELAY[4:1] : 4'b0000, SPR_YDIFF[1] & SPR_ATTR_ZY_DELAY[0] & AN143, AX101_S[3:0], AX101_S[4]);
A2N AR101({SPR_YDIFF[1], SPR_YDIFF[1] & SPR_ATTR_ZY_DELAY[5]}, {1'b0, SPR_YDIFF[0]}, AX101_S[4], AR101_S[1:0], AR101_S[2]);

wire [4:0] AW101_S;
wire [2:0] AP101_S;
A4H AW101({AR101_S[0], AX101_S[3:1]}, SPR_YDIFF[2] ? SPR_ATTR_ZY_DELAY[4:1] : 4'b0000, SPR_YDIFF[2] & SPR_ATTR_ZY_DELAY[0] & AX101_S[0], AW101_S[3:0], AW101_S[4]);
A2N AP101({SPR_YDIFF[2], SPR_YDIFF[2] & SPR_ATTR_ZY_DELAY[5]}, AR101_S[2:1], AW101_S[4], AP101_S[1:0], AP101_S[2]);

wire [4:0] AV101_S;
wire [2:0] AP121_S;
A4H AV101({AP101_S[0], AW101_S[3:1]}, SPR_YDIFF[3] ? SPR_ATTR_ZY_DELAY[4:1] : 4'b0000, SPR_YDIFF[3] & SPR_ATTR_ZY_DELAY[0] & AW101_S[0], AV101_S[3:0], AV101_S[4]);
A2N AP121({SPR_YDIFF[3], SPR_YDIFF[3] & SPR_ATTR_ZY_DELAY[5]}, AP101_S[2:1], AV101_S[4], AP121_S[1:0], AP121_S[2]);

wire [4:0] AU101_S;
wire [2:0] AN101_S;
A4H AU101({AP121_S[0], AV101_S[3:1]}, SPR_YDIFF[4] ? SPR_ATTR_ZY_DELAY[4:1] : 4'b0000, SPR_YDIFF[4] & SPR_ATTR_ZY_DELAY[0] & AV101_S[0], AU101_S[3:0], AU101_S[4]);
A2N AN101({SPR_YDIFF[4], SPR_YDIFF[4] & SPR_ATTR_ZY_DELAY[5]}, AP121_S[2:1], AU101_S[4], AN101_S[1:0], AN101_S[2]);

wire [4:0] AM101_S;
wire [2:0] AL101_S;
A4H AM101({AN101_S[0], AU101_S[3:1]}, SPR_YDIFF[5] ? SPR_ATTR_ZY_DELAY[4:1] : 4'b0000, SPR_YDIFF[5] & SPR_ATTR_ZY_DELAY[0] & AU101_S[0], AM101_S[3:0], AM101_S[4]);
A2N AL101({SPR_YDIFF[5], SPR_YDIFF[5] & SPR_ATTR_ZY_DELAY[5]}, AN101_S[2:1], AM101_S[4], AL101_S[1:0], AL101_S[2]);

wire [4:0] AK101_S;
wire [2:0] AJ101_S;
A4H AK101({AL101_S[0], AM101_S[3:1]}, SPR_YDIFF[6] ? SPR_ATTR_ZY_DELAY[4:1] : 4'b0000, SPR_YDIFF[6] & SPR_ATTR_ZY_DELAY[0] & AM101_S[0], AK101_S[3:0], AK101_S[4]);
A2N AJ101({SPR_YDIFF[6], SPR_YDIFF[6] & SPR_ATTR_ZY_DELAY[5]}, AL101_S[2:1], AK101_S[4], AJ101_S[1:0], AJ101_S[2]);
assign AL147 = (SPR_YDIFF[6] & SPR_ATTR_ZY_DELAY[0]) ^ AM101_S[0];

wire [4:0] AH27_S;
wire [2:0] AH81_S;
A4H AH27({AJ101_S[0], AK101_S[3:1]}, SPR_YDIFF[7] ? SPR_ATTR_ZY_DELAY[4:1] : 4'b0000, SPR_YDIFF[7] & SPR_ATTR_ZY_DELAY[0] & AK101_S[0], AH27_S[3:0], AH27_S[4]);
A2N AH81({SPR_YDIFF[7], SPR_YDIFF[7] & SPR_ATTR_ZY_DELAY[5]}, AJ101_S[2:1], AH27_S[4], AH81_S[1:0], AH81_S[2]);
assign AJ141 = (SPR_YDIFF[7] & SPR_ATTR_ZY_DELAY[0]) ^ AK101_S[0];

wire [8:0] MUL_REG;
KREG #(8) AF1(clk_6M, RES_SYNC, {AH81_S, AH27_S, AJ141}, ~P1, MUL_REG[8:1]);


// DELAYS / LATCHES
// TODO: Document these

reg [2:0] SPR_SIZE_DELAY;
wire [2:0] SPR_SIZE_DELAY2;
wire SPR_CODE_DELAY1;
wire SPR_CODE_DELAY3;
wire SPR_CODE_DELAY5;

KREG #(8) AN221(
	clk_6M,
	RES_SYNC,
	{SPR_CODE[3], SPR_CODE[5], SPR_VFLIP, AL147, SPR_SIZE_DELAY[0], SPR_SIZE_DELAY[1], SPR_SIZE_DELAY[2], SPR_CODE[1]},
	~P1,
	{SPR_CODE_DELAY3, SPR_CODE_DELAY5, SPR_VFLIP_DELAY, MUL_REG[0], SPR_SIZE_DELAY2[0], SPR_SIZE_DELAY2[1], SPR_SIZE_DELAY2[2], SPR_CODE_DELAY1}
);


// Get sprite priority and active flag from sprite RAM ATTR0
assign Y133 = ~|{ATTR_A[2:0]};
// Y2 Y28
KREG #(8) Y2(clk_3M, RES_SYNC, OD_in, Y133, {SPR_ACTIVE, SPR_PRIO});

wire [3:0] K94_Q;
wire [3:0] G95_Q;
wire [3:0] D124_Q;
wire [3:0] E95_Q;
KREG #(4) K94(clk_6M, RES_SYNC, {TILE_ROW[3], TILE_CODE_PRE[1], TILE_CODE_PRE[3], TILE_CODE_PRE[5]}, ~P133, K94_Q);
KREG #(4) G95(clk_6M, RES_SYNC, {TILE_ROW[3], TILE_CODE_PRE[1], TILE_CODE_PRE[3], TILE_CODE_PRE[5]}, ~P131, G95_Q);
KREG #(4) D124(clk_6M, RES_SYNC, {TILE_ROW[3], TILE_CODE_PRE[1], TILE_CODE_PRE[3], TILE_CODE_PRE[5]}, ~P137, D124_Q);
KREG #(4) E95(clk_6M, RES_SYNC, {TILE_ROW[3], TILE_CODE_PRE[1], TILE_CODE_PRE[3], TILE_CODE_PRE[5]}, ~P135, E95_Q);


// ROOT SHEET 2

// 8-frame delay for RES -> RST
reg [7:0] RES_delay;
always @(posedge VBLANK or negedge RES_SYNC) begin
	if (!RES_SYNC)
		RES_delay <= 8'd0;
	else
		RES_delay <= {RES_delay[6:0], RES_SYNC};
end
assign RST = RES_delay[7];

// 7-stage delay
reg [6:0] HRST_delay;
always @(posedge clk_6M or negedge RES_SYNC) begin
	if (!RES_SYNC)
		HRST_delay <= 7'd0;
	else
		HRST_delay <= {HRST_delay[5:0], HRST};
end


wire ROM_READ;
assign A152 = |{AB[10:3]};
assign A124 = ~|{OBCS, RDEN, A152, ~(AB[2:0] == 3'd0)};
assign A126 = ~|{~AB[10], OBCS, RDEN, ROM_READ};
assign DB_DIR = ~|{A126, A124};

assign OREG = A152 | OBCS;

assign A133 = ~&{AB[10], ~ROM_READ};
assign OD_DIR = |{A133, OBCS, WREN};
assign OWR = |{A133, OBCS, WRP};


// ATTR LATCHES

// RAM A LATCH - X Zoom
// RAM C LATCH - Sprite attribute byte (palette...)
// RAM F LATCH - Tile code MSBs
// RAM G LATCH - Sprite X position - Passed directly to k051937
reg [5:0] SPR_ATTR_ZX;
reg [7:0] SPR_COL;
reg [7:0] SPR_COL_DELAY;
reg [1:0] AD227_Q;
reg [7:0] SPR_ATTR_X;
always @(posedge clk_12M or negedge RES_SYNC) begin
	if (!RES_SYNC) begin
		SPR_ATTR_ZX <= 6'h00;
		SPR_COL <= 8'h00;
		SPR_COL_DELAY <= 8'h00;
		{SPR_SIZE, SPR_CODE[12:8]} <= 8'h00;
		SPR_ATTR_X <= 8'h00;
		SPR_CODE[0] <= 1'b0;
		SPR_CODE[2] <= 1'b0;
		SPR_CODE[4] <= 1'b0;
		SPR_CODE[6] <= 1'b0;
		SPR_CODE[7] <= 1'b0;
	end else begin
		if (!LACH) begin
			SPR_ATTR_ZX <= RAM_A_dout[7:2];
			SPR_COL <= RAM_C_dout;
			{SPR_SIZE, SPR_CODE[12:8]} <= RAM_F_dout;
			SPR_ATTR_X <= RAM_G_dout;
			
			SPR_CODE[0] <= RAM_E_dout[0];
			SPR_CODE[2] <= RAM_E_dout[2];
			SPR_CODE[4] <= RAM_E_dout[4];
			SPR_CODE[6] <= RAM_E_dout[6];
			SPR_CODE[7] <= RAM_E_dout[7];
			// HERE

		end
		
		SPR_COL_DELAY <= SPR_COL;
		
		AD227_Q[1:0] <= SPR_CODE[12:11];
	end
end

assign HP[7:0] = SPR_ATTR_X;

assign OC = ROM_READ ? {REG4, REG3[7:2]} : SPR_COL_DELAY;

assign SPR_H64P = &{|{SPR_SIZE_DELAY2[1:0]}, SPR_SIZE_DELAY2[2]};
assign SPR_W64P = &{|{SPR_SIZE[1], ~SPR_SIZE[0]}, SPR_SIZE[2]};
// Triggers on some values of SPR_SIZE_DELAY2
assign SPR_HEIGHT0 = ~(^{SPR_SIZE_DELAY2[1:0]} | ~SPR_SIZE_DELAY2[2]) & (~&{~SPR_SIZE_DELAY2[2], SPR_SIZE_DELAY2[1]});

// Sprite Y position check
wire [7:0] SPR_ATTR_Y;
// AK221 AK195
KREG #(8) AK221(clk_6M, RES_SYNC, RAM_B_dout, ~P1, SPR_ATTR_Y);

wire [7:0] ROW_REG;
// AM221 AH221
KREG #(8) AM221(clk_6M, RES_SYNC, ROW, ~HRST_delay[0], ROW_REG);

wire [4:0] AJ191_S;
wire [4:0] AL191_S;
A4H AL191(ROW_REG[7:4], SPR_ATTR_Y[7:4], AJ191_S[4], AL191_S[3:0], AL191_S[4]);
A4H AJ191(ROW_REG[3:0], SPR_ATTR_Y[3:0], ~FLIP_SCREEN, AJ191_S[3:0], AJ191_S[4]);

// AH1 AW163
KREG #(8) AH1(clk_6M, RES_SYNC, {AL191_S[3:0], AJ191_S[3:0]}, ~P1, SPR_YDIFF);


// ROM ADDRESS GEN 2
wire [3:0] J115_OUT;
wire L101_Q, L126_Q;
DE2 J115(L101_Q, L126_Q, J115_OUT);

reg [2:0] SEL0;
reg [2:0] SEL1;
reg [2:0] SEL2;
reg [2:0] SEL3;
always @(posedge clk_6M or negedge RES_SYNC) begin
	if (!RES_SYNC) begin
		SEL0 <= 3'd0;
		SEL1 <= 3'd0;
		SEL2 <= 3'd0;
		SEL3 <= 3'd0;
	end else begin
		if (!P133)
			SEL0 <= TILE_ROW[2:0];
		if (!P131)
			SEL1 <= TILE_ROW[2:0];
		if (!P137)
			SEL2 <= TILE_ROW[2:0];
		if (!P135)
			SEL3 <= TILE_ROW[2:0];
	end
end

// J115 and the three U24's
reg [2:0] TILE_ROW_OUT;
always @(*) begin
	case({L101_Q, L126_Q})
		2'd0: TILE_ROW_OUT <= SEL0;
		2'd1: TILE_ROW_OUT <= SEL1;
		2'd2: TILE_ROW_OUT <= SEL2;
		2'd3: TILE_ROW_OUT <= SEL3;
	endcase
end

reg N126_Q, M132_Q, M145_Q;
always @(posedge clk_12M or negedge RES_SYNC) begin
	if (!RES_SYNC) begin
		{M145_Q, M132_Q, N126_Q} <= 3'd0;
	end else begin
		if (!LACH)
			{M145_Q, M132_Q, N126_Q} <= TILE_ROW_OUT;
	end
end

FDR Z251(clk_12M, {SPR_HFLIP ^ SUBTILE_H[0], M145_Q, M132_Q, N126_Q}, RES_SYNC, CA_RENDER[3:0]);


// Half KREGs

// AH273 AG267
KREG #(2) AH273(clk_12M, RES_SYNC, RAM_A_dout[1:0], ~LACH, {SPR_HFLIP, HP[8]});
assign OHF = SPR_HFLIP;

wire C131_Q;
assign D121 = ~|{C131_Q, &{PE, clk_3M, AB[10], ~OBCS}};

wire [3:0] T227_OUT;
LT4 T227(D121, AB[5:2], T227_OUT, );

wire [7:4] CA_CPU;
assign CA[17:0] = ROM_READ ? {REG3[1:0], REG2[7:0], CA_CPU, T227_OUT} : CA_RENDER;

U24 H95({K94_Q[0], J115_OUT[0]}, {G95_Q[0], J115_OUT[1]}, {D124_Q[0], J115_OUT[2]}, {E95_Q[0], J115_OUT[3]}, H95_OUT);
U24 K132({K94_Q[1], J115_OUT[0]}, {G95_Q[1], J115_OUT[1]}, {D124_Q[1], J115_OUT[2]}, {E95_Q[1], J115_OUT[3]}, K132_OUT);
U24 H127({K94_Q[2], J115_OUT[0]}, {G95_Q[2], J115_OUT[1]}, {D124_Q[2], J115_OUT[2]}, {E95_Q[2], J115_OUT[3]}, H127_OUT);
U24 H121({K94_Q[3], J115_OUT[0]}, {G95_Q[3], J115_OUT[1]}, {D124_Q[3], J115_OUT[2]}, {E95_Q[3], J115_OUT[3]}, H121_OUT);


wire [3:0] N94_Q;
wire [5:0] TILE_CODE;
wire SUBTILE_V;
FDR N94(clk_12M, ~LACH ? {~H121_OUT, ~H127_OUT, ~K132_OUT, ~H95_OUT} : N94_Q, RES_SYNC, N94_Q);
assign {SUBTILE_V, TILE_CODE[1], TILE_CODE[3], TILE_CODE[5]} = N94_Q;

// Horizontal tile number substitution
wire [2:0] SUBTILE_HFLIP;
assign SUBTILE_HFLIP = {3{SPR_HFLIP}} ^ SUBTILE_H[3:1];
// 4-to-1 mux
reg [2:0] HTILE_SUB;
always @(*) begin
	case({~SPR_W64P, ~SPR_SIZE[0]})
		2'd0: HTILE_SUB <= SUBTILE_HFLIP[2:0];										// B1
		2'd1: HTILE_SUB <= {SPR_CODE[4], SUBTILE_HFLIP[1:0]};					// B2
		2'd2: HTILE_SUB <= {SPR_CODE[4], SPR_CODE[2], SUBTILE_HFLIP[0]};	// A2
		2'd3: HTILE_SUB <= {SPR_CODE[4], SPR_CODE[2], SPR_CODE[0]};			// A1
	endcase
end
assign {TILE_CODE[4], TILE_CODE[2], TILE_CODE[0]} = HTILE_SUB;


// Vertical tile number substitution
wire [2:0] SUBTILE_VFLIP;
assign SUBTILE_VFLIP = {3{SPR_VFLIP_DELAY}} ^ MUL_REG[6:4];
// 4-to-1 mux
reg [2:0] VTILE_SUB;
always @(*) begin
	case({~SPR_H64P, ~SPR_HEIGHT0})
		2'd0: VTILE_SUB <= SUBTILE_VFLIP[2:0];													// B1
		2'd1: VTILE_SUB <= {SPR_CODE_DELAY5, SUBTILE_VFLIP[1:0]};						// B2
		2'd2: VTILE_SUB <= {SPR_CODE_DELAY5, SPR_CODE_DELAY3, SUBTILE_VFLIP[0]};	// A2
		2'd3: VTILE_SUB <= {SPR_CODE_DELAY5, SPR_CODE_DELAY3, SPR_CODE_DELAY1};		// A1
	endcase
end
assign {TILE_CODE_PRE[5], TILE_CODE_PRE[3], TILE_CODE_PRE[1]} = VTILE_SUB;


FDR Y255(clk_12M, {TILE_CODE[2:0], SUBTILE_V}, RES_SYNC, CA_RENDER[7:4]);
FDR Y229(clk_12M, {SPR_CODE[6], TILE_CODE[5:3]}, RES_SYNC, CA_RENDER[11:8]);
FDR AD255(clk_12M, SPR_CODE[10:7], RES_SYNC, CA_RENDER[15:12]);
assign CA_RENDER[17:16] = AD227_Q[1:0];

LT4 T208(D121, AB[9:6], CA_CPU, );


wire W101_CO;
FDO V110(VBLANK, P94_Q, RES_SYNC, V110_Q, );
assign V89 = ~VBLANK | V110_Q;
FDO V82(clk_6M, V89, RES_SYNC, , V82_XQ);
assign V101 = ~&{(W101_CO | ~VBLANK_SYNC), (V89 | V82_XQ)};
assign V117 = ~&{VBLANK, V101};
FDN V103(clk_6M, V117, RES_SYNC, , VBLANK_SYNC);


// REGISTERS

assign nREG0_W = |{~(AB[2:0] == 3'd0), A152, OBCS, WRP};
assign nREG0_R = |{OBCS, RDEN, ~(AB[2:0] == 3'd0), A152};
assign nREG2_W = |{~(AB[2:0] == 3'd2), A152, OBCS, WRP};
assign nREG3_W = |{~(AB[2:0] == 3'd3), A152, OBCS, WRP};
assign nREG4_W = |{~(AB[2:0] == 3'd4), A152, OBCS, WRP};

// Reg 0
wire [3:0] D94_Q;
FDR D94(nREG0_W, {DB_IN[2:0], DB_IN[5]}, RES_SYNC, D94_Q);
assign ROM_READ = D94_Q[0];
FDO C131(nREG0_W, DB_IN[6], RES_SYNC, C131_Q, );
FDO P94(nREG0_W, DB_IN[4], RES_SYNC, P94_Q, );
FDO P103(nREG0_W, DB_IN[3], RES_SYNC, FLIP_SCREEN, );

// Reg 2
FDR V229(nREG2_W, DB_IN[3:0], RES_SYNC, REG2[3:0]);
FDR W229(nREG2_W, DB_IN[7:4], RES_SYNC, REG2[7:4]);

// Reg 3
FDR V255(nREG3_W, DB_IN[3:0], RES_SYNC, REG3[3:0]);
FDR W255(nREG3_W, DB_IN[7:4], RES_SYNC, REG3[7:4]);

// Reg 4
FDO W194(nREG4_W, DB_IN[0], RES_SYNC, REG4[0], );
FDO V214(nREG4_W, DB_IN[1], RES_SYNC, REG4[1], );

assign OOE = CPU_ACCESS ? NRD : 1'b0;


// Interrupt flags
FDO A94(ROW_RAW[2], ~A94_Q, RES_SYNC, A94_Q, );
FDO B108(A94_Q, ~B108_Q, RES_SYNC, B108_Q, );

FDO C101(VBLANK, 1'b1, D94_Q[1], , IRQ);
FDO C121(ROW_RAW[0], 1'b1, D94_Q[2], , FIRQ);
FDO B101(B108_Q, 1'b1, D94_Q[3], , NMI);

// Sprite tile width counter
T5A AC232(SUBTILE_H[0], &{SUBTILE_H[1:0]}, &{SUBTILE_H[3:0]}, &{SUBTILE_H[2:0]}, ~SPR_SIZE[0], ~SPR_W64P, AC232_X);
assign HEND = ~AC232_X;
assign X192 = ~|{~PXH[0], HEND};
assign #1 test2 = clk_6M;
C43 AB233(clk_12M, 4'b0000, AB122, ~test2, X192, RES_SYNC, SUBTILE_H, );		// clk_6M must be delayed !


// This counter keeps track of the sprite currently being rendered - Independent from the parsing counter
wire [6:0] COUNT_UNK;
C43 R50(clk_6M, 4'b0000, HRST_delay[5], N121, 1'b1, RES_SYNC, R50_Q, R50_CO);
C43 S28(clk_6M, 4'b0000, HRST_delay[5], N121, R50_CO, RES_SYNC, S28_Q, );
assign COUNT_UNK = {S28_Q[2:0], R50_Q};

// How does this work ? Why are there 4 registers keeping sprite #s for rendering ?
KREG #(7) V53(clk_6M, RES_SYNC, COUNT_UNK, ~P133, KREG_A);
KREG #(7) V1(clk_6M, RES_SYNC, COUNT_UNK, ~P131, KREG_B);
KREG #(7) V27(clk_6M, RES_SYNC, COUNT_UNK, ~P135, KREG_C);
KREG #(7) S2(clk_6M, RES_SYNC, COUNT_UNK, ~P137, KREG_D);

wire C94_XQ;
assign C130 = ~&{HRST_delay[6], ~&{C130, HRST_delay[0]}};	// Combinational loop !
assign E141 = ~&{C94_XQ, C130};
assign N121 = &{~PXH[0], E141};
C43 W49(clk_6M, 4'b0000, HRST, N121, ~PARSE_DONE, RES_SYNC, PARSE_A[3:0], W49_COUT);
C43 W1(clk_6M, 4'b0000, HRST, N121, W49_COUT, RES_SYNC, {PARSE_DONE, PARSE_A[6:4]}, );

assign P1 = ~&{E141, ~PXH[0]};	// And a bunch of inverters


// VRAM copy counter - Sprite #
wire W101_QD;
assign RAM_DATA_WR = W101_QD;
assign Z95 = ~&{RAM_DATA_WR, ~SPR_ACTIVE};	// SPR_ACTIVE must be delayed !
assign Z81 = ~PXH[0] & ~&{Z95, ~&{ATTR_A[2:0]}};
C43 X1(clk_6M, 4'b0000, VBLANK_SYNC, ~PXH[0], Z81, RES_SYNC, ATTR_A[6:3], X1_CO);
C43 W101(clk_6M, 4'b0000, VBLANK_SYNC, ~PXH[0], X1_CO, VBLANK_SYNC, {W101_QD, ATTR_A[9:7]}, W101_CO);

// VRAM copy counter - Attr #
wire [3:0] Z9_Q;
C43 Z9(clk_6M, 4'b0000, VBLANK_SYNC & Z95, ~PXH[0], ~PXH[0], RES_SYNC, Z9_Q, );
assign ATTR_A[2:0] = Z9_Q[2:0];

// Select between CPU and render access to sprite RAM
assign OA_out = CPU_ACCESS ? AB[9:0] : ATTR_A;


// MISC

// Sprite raster match
assign AH189 = ~|{MUL_REG[6:5]};
assign AH187 = ~|{MUL_REG[6:4]};
T5A AP176(AH187, AH189, 1'b1, ~MUL_REG[6], ~SPR_HEIGHT0, ~SPR_H64P, AP176_OUT);
assign AD134 = ~|{MUL_REG[8:7], AN195_Q[3], AP176_OUT};

// Intra-tile vertical flip
assign TILE_ROW = {4{SPR_VFLIP_DELAY}} ^ MUL_REG;

// TODO: Document this
wire M116, J148, B94_XQ, B115_XQ, B122_XQ;
assign C115 = ~|{&{~M116, ~J148, C94_XQ}, &{~J148, M116, B122_XQ}};
FDN C94(clk_6M, C115, RES_SYNC, , C94_XQ);
assign C108 = ~|{&{~M116, J148, C94_XQ}, &{~M116, ~J148, B122_XQ}, &{~J148, M116, B115_XQ}};
FDN B122(clk_6M, C108, RES_SYNC, , B122_XQ);
assign B129 = ~|{&{~M116, J148, B122_XQ}, &{~M116, ~J148, B115_XQ}, &{~J148, M116, B94_XQ}};
FDN B115(clk_6M, B129, RES_SYNC, , B115_XQ);
assign B141 = ~|{&{~M116, J148, B115_XQ}, &{~M116, ~J148, B94_XQ}, &{~J148, M116, 1'b1}};
FDN B94(clk_6M, B141, RES_SYNC, , B94_XQ);

FDO J108(clk_6M, HEND & P1H, RES_SYNC, J108_Q, );
FDO J101(clk_6M, J108_Q, RES_SYNC, , J101_XQ);
FDO J130(clk_6M, HRST_delay[6] & ~&{~J121, J120}, RES_SYNC, J130_Q, );

assign E138 = |{C94_XQ, B122_XQ, B115_XQ, B94_XQ};
assign J120 = ~&{J130_Q, J101_XQ};

assign J121 = &{P1H, E138, ~VBLANK_SYNC, J120};
assign AB122 = ~J120 & LACH;
assign J150 = J121 & P1H;
assign J148 = J150 | ~HRST_delay[5];

C11 L126(clk_6M, 1'b0, ~HRST_delay[5], RES_SYNC, J121, L126_Q, );
C11 L101(clk_6M, 1'b0, ~HRST_delay[5], RES_SYNC, L126_Q & J121, L101_Q, );

C11 P38(clk_6M, 1'b0, ~HRST_delay[5], RES_SYNC, P121, P38_Q, );
C11 P110(clk_6M, 1'b0, ~HRST_delay[5], RES_SYNC, P38_Q & P121, P110_Q, );

wire [3:0] P126_OUT;
DE2 P126(P110_Q, P38_Q, P126_OUT);
assign P121 = &{~PXH[0], AD134, ~VBLANK_SYNC, ~C94_XQ};
assign M116 = P121 | ~HRST_delay[5];
assign P133 = ~P121 | P126_OUT[0];
assign P131 = ~P121 | P126_OUT[1];
assign P137 = ~P121 | P126_OUT[2];
assign P135 = ~P121 | P126_OUT[3];


// Sprite X zoom and accumulator

// Accumulator
reg [6:0] SPR_ZX_ACC;
wire M94_XQ;
always @(posedge clk_12M or negedge RES_SYNC) begin
	if (!RES_SYNC) begin
		SPR_ZX_ACC <= 7'h00;
	end else begin
		SPR_ZX_ACC <= M94_XQ ? ({1'b0, SPR_ATTR_ZX} + SPR_ZX_ACC) : {1'b0, SPR_ATTR_ZX};
	end
end
assign CARY = SPR_ZX_ACC[6];


// RAM REGISTERS

// Sprite Y zoom
reg [7:0] SPR_ATTR_ZY;
always @(posedge clk_6M or negedge RES_SYNC) begin
	if (!RES_SYNC) begin
		SPR_ATTR_ZY <= 8'h00;
		
		SPR_Y8 <= 1'b0;
		SPR_VFLIP <= 1'b0;
		SPR_ATTR_ZY_DELAY <= 6'h00;
		
		AM195_Q <= 4'h0;
		AN195_Q <= 4'h0;
	end else begin
		if (!P1) begin
			SPR_ATTR_ZY <= RAM_D_dout;
			
			SPR_Y8 <= SPR_ATTR_ZY[0] ^ AL191_S[4];
			SPR_VFLIP <= SPR_ATTR_ZY[1];
			SPR_ATTR_ZY_DELAY <= SPR_ATTR_ZY[7:2];
			
			AM195_Q <= {PARSE_DONE, VBLANK_SYNC, RAM_F_dout[6:5]};	// Part of sprite size attribute
			{AN195_Q, SPR_SIZE_DELAY[0], SPR_SIZE_DELAY[1]} <= {~&{SPR_Y8, AN195_Q[2]}, ~|{AM195_Q[3:2]}, AM195_Q[1:0]};
		end
	end
end

// Sprite tile code
wire [3:0] AX163_Q;
KREG AX163(clk_6M, RES_SYNC, {RAM_F_dout[7], RAM_E_dout[1], RAM_E_dout[3], RAM_E_dout[5]}, ~P1, AX163_Q);
always @(posedge clk_6M or negedge RES_SYNC) begin
	if (!RES_SYNC) begin
		SPR_CODE[5] <= 1'b0;
		SPR_CODE[3] <= 1'b0;
		SPR_CODE[1] <= 1'b0;
		SPR_SIZE_DELAY[2] <= 1'b0;
	end else begin
		if (!P1) begin
			SPR_CODE[5] <= AX163_Q[0];
			SPR_CODE[3] <= AX163_Q[1];
			SPR_CODE[1] <= AX163_Q[2];
			SPR_SIZE_DELAY[2] <= AX163_Q[3];
		end
	end
end


// SEQUENCING

assign #1 test = clk_6M;
assign L141 = test & J121;	// clk_6M must be delayed !
// This is a 3-stage delay
FDO M108(clk_12M, L141, RES_SYNC, M108_Q, LACH);
FDO M101(clk_12M, M108_Q, RES_SYNC, M101_Q, );
FDO M94(clk_12M, M101_Q, RES_SYNC, , M94_XQ);

// RAM sequencing stuff
assign Y70 = ~&{~VBLANK_SYNC, ~&{~VBLANK_SYNC, ~clk_3M, ~L101_Q}};
assign Y72 = ~Y70;
assign Y141 = ~&{~VBLANK_SYNC, ~&{~VBLANK_SYNC, ~clk_3M, L101_Q}};
assign X148 = ~Y141;
assign Y81 = ~&{~&{RAM_DATA_WR, VBLANK_SYNC}, ~&{~VBLANK_SYNC, clk_3M}, ~&{~VBLANK_SYNC, ~clk_3M, L126_Q}};
assign Y73 = ~Y81;

endmodule
