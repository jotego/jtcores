//============================================================================
//  Konami TMNT for MiSTer
//
//  Copyright (C) 2022 Sean 'Furrtek' Gonsalves
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

// k051937 Sprite layer data processor
// Gets 8px rows from the GFX ROMs, juggles between four line buffers, does fine X flipping and scaling.

module k051937 (
	input clk_96M,	// DEBUG for delays

	input nRES,
	input clk_24M,

	output P1H,
	output P2H,

	input HVIN,
	output HVOT,

	input NRD, OBCS,

	input [2:0] AB,
	input AB10,

	output reg [7:0] DB_OUT,
	input [7:0] DB_IN,

	output NCSY, NVSY, NHSY,
	output NCBK, NVBK, NHBK, // blanking signals, CBK = combined V/H blanking

	output SHAD, NCO0, PCOF,
	output [11:0] OB,

	// Bitplanes in
	input [7:0] CD0,
	input [7:0] CD1,
	input [7:0] CD2,
	input [7:0] CD3,

	output [3:0] CAW,

	input [7:0] OC,
	input [8:0] HP,

	input CARY, LACH, HEND, OREG, OHF,

	output DB_DIR
);

wire nHVIN_DELAY, AN106_Q, AL36, AV104;
wire NEW_SPR, AR104_Q, PAIR, nPAIR, AR135_XQ;
wire SPR_HFLIP, AR135_Q, AR104_XQ;

wire [3:0] SH1_OUT;	// 3 ODD
wire [3:0] SH2_OUT;	// 2 ODD
wire [3:0] SH3_OUT;	// 1 ODD
wire [3:0] SH4_OUT;	// 0 ODD
wire [3:0] SH5_OUT;	// 3 EVEN
wire [3:0] SH6_OUT;	// 2 EVEN
wire [3:0] SH7_OUT;	// 1 EVEN
wire [3:0] SH8_OUT;	// 0 EVEN
wire [3:0] nROMRD;
wire nROMRDEN;

wire RAM_C_DOUT;
wire RAM_D_DOUT;
wire RAM_G_DOUT;
wire RAM_H_DOUT;
wire [11:0] RAM_A_DOUT;
wire [11:0] RAM_B_DOUT;
wire [11:0] RAM_E_DOUT;
wire [11:0] RAM_F_DOUT;
wire [7:0] RAM_ABCD_A;
wire [7:0] RAM_EFGH_A;
reg [11:0] RAM_A_DIN;
reg [11:0] RAM_B_DIN;
reg [11:0] RAM_E_DIN;
reg [11:0] RAM_F_DIN;

// Dual odd-even line buffers

ram_k051937_color RAMA(RAM_ABCD_A, RAM_ABCD_CK, RAM_A_DIN, RAM_A_WE, RAM_A_DOUT);
ram_k051937_color RAMB(RAM_ABCD_A, RAM_ABCD_CK, RAM_B_DIN, RAM_B_WE, RAM_B_DOUT);
ram_k051937_shadow RAMC(RAM_ABCD_A, RAM_ABCD_CK, RAM_C_DIN, RAM_C_WE, RAM_C_DOUT);
ram_k051937_shadow RAMD(RAM_ABCD_A, RAM_ABCD_CK, RAM_D_DIN, RAM_D_WE, RAM_D_DOUT);

ram_k051937_color RAME(RAM_EFGH_A, RAM_EFGH_CK, RAM_E_DIN, RAM_E_WE, RAM_E_DOUT);
ram_k051937_color RAMF(RAM_EFGH_A, RAM_EFGH_CK, RAM_F_DIN, RAM_F_WE, RAM_F_DOUT);
ram_k051937_shadow RAMG(RAM_EFGH_A, RAM_EFGH_CK, RAM_G_DIN, RAM_G_WE, RAM_G_DOUT);
ram_k051937_shadow RAMH(RAM_EFGH_A, RAM_EFGH_CK, RAM_H_DIN, RAM_H_WE, RAM_H_DOUT);

// CLOCK & VIDEO SYNC

// Reset input sync
FDE AS24(clk_24M, 1'b1, nRES, RES_SYNC,);

// Clocks
FDN AS44(clk_24M, nclk_12M, RES_SYNC, clk_12M, nclk_12M);
FDN AS51(clk_24M, ~^{nclk_12M, nclk_6M}, RES_SYNC, clk_6M, nclk_6M);
FDN AT130(clk_24M, ~^{clk_3M, ~&{nclk_6M, nclk_12M}}, RES_SYNC, clk_3M, nclk_3M);


wire [8:0] PXH;

// NHSY generation
wire D89;
assign H91 = ~&{(~NHSY | ~D89), (PXH[5] | D89)};
assign NCBK = NVBK & NHBK;
FDN F89(clk_6M, H91, RES_SYNC & ~NHBK, NHSY,);

// H/V COUNTERS

FDE AS65(clk_24M, clk_3M, RES_SYNC, AS65_Q,);	// = PE

// H counter
// 9-bit counter, resets to 9'h020 after 9'h19F, effectively counting 384 pixels
FDO K89(clk_6M, AS65_Q, RES_SYNC, PXH[0],);
C43 C89(clk_6M, 4'b0000, nNEW_LINE, PXH[0], PXH[0], RES_SYNC, PXH[4:1], C89_COUT);
C43 E93(clk_6M, 4'b0001, nNEW_LINE, C89_COUT, C89_COUT, RES_SYNC, PXH[8:5],);
assign P1H = PXH[0];
assign P2H = PXH[1];

assign G137 = &{C89_COUT, PXH[8:7]};
assign nNEW_LINE = ~|{G137, nHVIN_DELAY};
assign D89 = ~&{~PXH[4], PXH[3:0]};

wire [8:0] ROW;

// V counter
// 9-bit counter, resets to 9'h0F8 after 9'h1FF, effectively counting 264 raster lines
FDO F117(clk_6M, ~|{(~ROW[0] ^ G137), nHVIN_DELAY}, RES_SYNC, ROW[0],);
C43 B90(clk_6M, 4'b1100, HVOT, ROW[0], G137 & ROW[0], RES_SYNC, ROW[4:1], B90_CO);
C43 A89(clk_6M, 4'b0111, HVOT, ROW[0], B90_CO, RES_SYNC, ROW[8:5], A89_CO);

FDO F110(ROW[8], &{ROW[3:1]}, RES_SYNC, , NVBK);	// B138
LTL F132(ROW[4], NHSY, RES_SYNC, NVSY,);

assign NCSY = &{NVSY, NHSY};
assign HVOT = ~|{A89_CO, nHVIN_DELAY};


wire [3:0] AP4_Q;
C43 AP4(clk_12M, {3'b000, HP[0]}, AR44_Q, CARY, CARY, nRES, AP4_Q,);


FDM AR33(clk_12M, CARY, AR33_Q,);
FDM AN93(clk_12M, ~&{AP4_Q[0], AR33_Q}, AN93_Q, );	// AR76
FDM AM104(clk_12M, AN93_Q, AM104_Q, ); // do not write pixel if AN93_Q is low
									   // do not count if AM104_Q is low
									   // AM104_Q = AN93_Q delayed 1 tick


assign H137 = nNEW_LINE & (NHBK | (PXH[6] & C89_COUT));
FDO F103(clk_6M, H137, RES_SYNC, NHBK,);


assign AT137 = clk_24M;	// AT137 must be used for delaying M24 !
FDM AV96(~AT137, clk_12M, AV96_Q,);
assign AV139 = ~&{AT137, AV96_Q};

wire AN106_XQ;
assign AM1 = ~|{AV139, (AN106_Q & ~clk_6M)};
//TESTING
//assign AK13 = AM1;	// Must be delayed !
reg AK13, RAM_EFGH_CK;
always @(negedge clk_96M) begin
	AK13 <= AM1;
	RAM_EFGH_CK <= ~AM1;
end
//assign #1 RAM_EFGH_CK = ~AM1;		// Test mode ignored

assign AM12 = ~|{AV139, (AN106_XQ & ~clk_6M)};
//TESTING
//assign AJ1 = AM12;	// Must be delayed !
reg AJ1, RAM_ABCD_CK;
always @(negedge clk_96M) begin
	AJ1 <= AM12;
	RAM_ABCD_CK <= ~AM12;
end
//assign #1 RAM_ABCD_CK = ~AM12;		// Test mode ignored

// Simplification of ROM CPU readback mux - TO TEST
always @(*) begin
	case(nROMRD)
		4'b1110: DB_OUT <= CD0;
		4'b1101: DB_OUT <= CD1;
		4'b0011: DB_OUT <= CD2;
		4'b0111: DB_OUT <= CD3;
		default: DB_OUT <= 8'd0;	// Shouldn't happen
	endcase
end

assign AL36 = AB10 & ~|{nROMRDEN, OBCS};
assign AAD112 = ~&{AL36, AB[1:0] == 2'd0};
assign AAD114 = ~&{AL36, AB[1:0] == 2'd1};
assign AAD116 = ~&{AL36, AB[1:0] == 2'd2};
assign AAD104 = ~&{AL36, AB[1:0] == 2'd3};

assign CAW[0] = AV104 | AAD112;
assign CAW[1] = AV104 | AAD114;
assign CAW[2] = AV104 | AAD116;
assign CAW[3] = AV104 | AAD104;

assign AAC92 = ~|{NRD, OREG, ~AB[2]};
assign nROMRD[0] = AAD112 & ~&{AAC92, AB[1:0] == 2'd0};
assign nROMRD[1] = AAD114 & ~&{AAC92, AB[1:0] == 2'd1};
assign nROMRD[2] = AAD116 & ~&{AAC92, AB[1:0] == 2'd2};
assign nROMRD[3] = AAD104 & ~&{AAC92, AB[1:0] == 2'd3};

wire [3:0] CD_DIR;
assign CD_DIR = {4{~NRD}} | nROMRD;

assign DB_DIR = NRD | &{nROMRD};	// AAD151 AAD142


// Odd shifters for each bitplane
SHIFTER SH1(clk_12M, {~AS84_XQ, ~AS90_XQ}, {CD3[7], CD3[5], CD3[3], CD3[1]}, SH1_OUT);
SHIFTER SH2(clk_12M, {~AS84_XQ, ~AS90_XQ}, {CD2[7], CD2[5], CD2[3], CD2[1]}, SH2_OUT);
SHIFTER SH3(clk_12M, {~AS84_XQ, ~AS90_XQ}, {CD1[7], CD1[5], CD1[3], CD1[1]}, SH3_OUT);
SHIFTER SH4(clk_12M, {~AS84_XQ, ~AS90_XQ}, {CD0[7], CD0[5], CD0[3], CD0[1]}, SH4_OUT);

// Even shifters for each bitplane
SHIFTER SH5(clk_12M, {~AS84_XQ, ~AS90_XQ}, {CD3[6], CD3[4], CD3[2], CD3[0]}, SH5_OUT);
SHIFTER SH6(clk_12M, {~AS84_XQ, ~AS90_XQ}, {CD2[6], CD2[4], CD2[2], CD2[0]}, SH6_OUT);
SHIFTER SH7(clk_12M, {~AS84_XQ, ~AS90_XQ}, {CD1[6], CD1[4], CD1[2], CD1[0]}, SH7_OUT);
SHIFTER SH8(clk_12M, {~AS84_XQ, ~AS90_XQ}, {CD0[6], CD0[4], CD0[2], CD0[0]}, SH8_OUT);

FDM AS129(clk_12M, AR110_Q, AS129_Q, AS129_XQ);

wire [3:0] PIXELA;
wire [3:0] PIXELB;

assign MUX_SH48 = SPR_HFLIP ? SH4_OUT[3] : SH8_OUT[0];	// AP158 AP156
assign MUX_SH84 = SPR_HFLIP ? SH8_OUT[3] : SH4_OUT[0];
FDM AW89(clk_12M, MUX_SH48, MUX_SH48_D,);
assign PIXELA[3] = AR135_Q ? 1'b0 : AS129_Q ? MUX_SH84 : MUX_SH48;
assign PIXELB[3] = AR104_XQ ? 1'b0 : AS129_Q ? MUX_SH48_D : MUX_SH84;

assign MUX_SH37 = SPR_HFLIP ? SH3_OUT[3] : SH7_OUT[0];	// AP154 AP142
assign MUX_SH73 = SPR_HFLIP ? SH7_OUT[3] : SH3_OUT[0];
FDM AW95(clk_12M, MUX_SH37, MUX_SH37_D,);
assign PIXELA[2] = AR135_Q ? 1'b0 : AS129_Q ? MUX_SH73 : MUX_SH37;
assign PIXELB[2] = AR104_XQ ? 1'b0 : AS129_Q ? MUX_SH37_D : MUX_SH73;

assign MUX_SH26 = SPR_HFLIP ? SH2_OUT[3] : SH6_OUT[0];	// AP152 AP150
assign MUX_SH62 = SPR_HFLIP ? SH6_OUT[3] : SH2_OUT[0];
FDM AW104(clk_12M, MUX_SH26, MUX_SH26_D,);
assign PIXELA[1] = AR135_Q ? 1'b0 : AS129_Q ? MUX_SH62 : MUX_SH26;
assign PIXELB[1] = AR104_XQ ? 1'b0 : AS129_Q ? MUX_SH26_D : MUX_SH62;

assign MUX_SH15 = SPR_HFLIP ? SH1_OUT[3] : SH5_OUT[0];	// AX128 AX130
assign MUX_SH51 = SPR_HFLIP ? SH5_OUT[3] : SH1_OUT[0];
FDM AX132(clk_12M, MUX_SH15, MUX_SH15_D,);
assign PIXELA[0] = AR135_Q ? 1'b0 : AS129_Q ? MUX_SH51 : MUX_SH15;
assign PIXELB[0] = AR104_XQ ? 1'b0 : AS129_Q ? MUX_SH15_D :  MUX_SH51;


// ROOT SHEET 3

// Render counters
wire [8:1] RENDERH;
C43 G89(clk_12M, HP[4:1], AP71_Q, AM104_Q, AM104_Q, 1'b1, RENDERH[4:1], G89_CO);
C43 S89(clk_12M, HP[8:5], AP71_Q, G89_CO, G89_CO, 1'b1, RENDERH[8:5],);


/*assign CD0_OUT = nROMRD[0] ? 8'h00 : DB_IN;	// TODO
assign CD1_OUT = nROMRD[1] ? 8'h00 : DB_IN;
assign CD2_OUT = nROMRD[2] ? 8'h00 : DB_IN;
assign CD3_OUT = nROMRD[3] ? 8'h00 : DB_IN;*/


// PALETTE LATCHES

reg [7:0] PAL_LATCH1;
reg [7:0] PAL_LATCH2;
always @(posedge clk_12M) begin
	if (!NEW_SPR)
		PAL_LATCH1 <= OC;	// AG64_Q AG4_Q
	PAL_LATCH2 <= PAL_LATCH1;
end

always @(posedge AK13) begin
	RAM_E_DIN[11:4] <= ~PAIR ? PAL_LATCH2 : 8'd0;
	RAM_F_DIN[11:4] <= ~PAIR ? PAL_LATCH2 : 8'd0;
end
always @(posedge AJ1) begin
	RAM_A_DIN[11:4] <= PAIR ? PAL_LATCH2 : 8'd0;
	RAM_B_DIN[11:4] <= PAIR ? PAL_LATCH2 : 8'd0;
end

// LB ADDRESS

FDO AB95(AAC98, DB_IN[3], RES_SYNC, AB95_Q,);
assign K108 = PXH[0] ^ AB95_Q;
assign AK183 = ~K108;

assign RAM_ABCD_A = PAIR ? RENDERH[8:1] : PXH[8:1] ^ {8{AB95_Q}};
assign RAM_EFGH_A = PAIR ? PXH[8:1] ^ {8{AB95_Q}} : RENDERH[8:1];

// SHADOW

reg AK196_Q, AK154_Q;
always @(posedge PXH[0]) begin
	AK196_Q <= PAIR ? RAM_G_DOUT : RAM_C_DOUT;
	AK154_Q <= PAIR ? RAM_H_DOUT : RAM_D_DOUT;
end
FDM AL196(clk_6M, K108 ? AK154_Q : AK196_Q, AL196_Q,);

wire [2:0] REG1;

assign AAC104 = |{AV104, OREG, ~(AB[1:0] == 2'd1)};
FDO AJ128(AAC104, DB_IN[0], RES_SYNC, REG1[0],);
FDO AJ91(AAC104, DB_IN[1], RES_SYNC, REG1[1],);
FDO AJ84(AAC104, DB_IN[2], RES_SYNC, , REG1[2]);

assign SHAD = ^{AL196_Q, REG1[0]};

assign AK112 = PAL_LATCH1[7] | REG1[1];


assign SHADOWA = &{~REG1[2], AK112, &{PIXELA}};
FDM AJ55(clk_12M, SHADOWA, AJ55_Q,);

assign SHADOWB = &{~REG1[2], AK112, &{PIXELB}};
FDM AJ135(clk_12M, SHADOWB, AJ135_Q,);

FDM AH65(AJ1, &{AJ55_Q, PAIR}, RAM_C_DIN,);
FDM AH108(AJ1, &{AJ135_Q, PAIR}, RAM_D_DIN,);
FDM AH132(AK13, &{AJ55_Q, ~PAIR}, RAM_G_DIN,);
FDM AH114(AK13, &{AJ135_Q, ~PAIR}, RAM_H_DIN,);


// ROOT SHEET 7

FDO AT106(clk_24M, nclk_3M, RES_SYNC, AT106_Q, AT106_XQ);
FDO AT89(clk_24M, AT106_Q, RES_SYNC, AT89_Q,);
FDO AT96(clk_24M, AT89_Q, RES_SYNC, AT96_Q,);

FDO AV89(clk_24M, ~&{AT106_XQ, AT96_Q, NRD}, RES_SYNC, AV104,);


assign AR73 = ~|{(SPR_HFLIP & NEW_SPR), (OHF & ~NEW_SPR)};
FDM AR128(clk_12M, AR73, , SPR_HFLIP);

assign AAC98 = |{AV104, OREG, AB[1:0]};
FDO AM90(AAC98, DB_IN[5], RES_SYNC, , nROMRDEN);


assign AN116 = HVIN & nRES;
FDN AN130(clk_12M, ~^{AP134, ~FLIP}, AN116, FLIP,);
FDN AN106(clk_12M, FLIP, AN116, AN106_Q, AN106_XQ);
assign PAIR = AN106_Q;		// Must be delayed !
//assign nPAIR = AN106_XQ;	// Must be delayed !


FDM AR16(~clk_12M, ~|{~PXH[0], clk_6M}, AR16_Q,);
assign AS34 = ~|{AR16_Q & ~OHF, 1'b1 & OHF};
FDM AS90(clk_12M, AS34, , AS90_XQ);

assign AS36 = ~|{1'b1 & ~OHF, AR16_Q & OHF};
FDM AS84(clk_12M, AS36, , AS84_XQ);

// RAM block WEs
assign AM128 = ~&{|{PIXELA}, AR135_XQ, AN93_Q};
assign AL89 = ~&{|{PIXELB}, AR104_Q, AM104_Q};
assign AL79 = SHADOWB | AL89;
assign AL77 = SHADOWA | AM128;

wire [7:0] WE_MUX;
assign WE_MUX = PAIR ? {AM128, PXH[0], AL89, PXH[0], AL79, PXH[0], AL77, PXH[0]} : {PXH[0], AM128, PXH[0], AL89, PXH[0], AL79, PXH[0], AL77};

reg [7:0] WE_MUX_REG;
always @(posedge clk_12M)
	WE_MUX_REG <= WE_MUX;

reg [3:0] WE_MUX_REG_A;
reg [3:0] WE_MUX_REG_B;
always @(posedge AM12)
	WE_MUX_REG_A <= {WE_MUX_REG[7], WE_MUX_REG[5], WE_MUX_REG[3], WE_MUX_REG[1]};
assign RAM_C_WE = ~WE_MUX_REG_A[3];
assign RAM_D_WE = ~WE_MUX_REG_A[2];
assign RAM_A_WE = ~WE_MUX_REG_A[1];
assign RAM_B_WE = ~WE_MUX_REG_A[0];
always @(posedge AM1)
	WE_MUX_REG_B <= {WE_MUX_REG[6], WE_MUX_REG[4], WE_MUX_REG[2], WE_MUX_REG[0]};
assign RAM_G_WE = ~WE_MUX_REG_B[3];
assign RAM_H_WE = ~WE_MUX_REG_B[2];
assign RAM_E_WE = ~WE_MUX_REG_B[1];
assign RAM_F_WE = ~WE_MUX_REG_B[0];

// ROOT SHEET 8

reg [11:0] PARITY_SEL_REG;	// Final output on OB* pins

assign RAOE = &{(1'b0 | ~nROMRDEN), (NRD | nROMRDEN)};

// All the muxes are test mode related, safe to ignore
assign OB = PARITY_SEL_REG;

// PIXEL LATCHES

reg [3:0] PIXELA_LATCH;
reg [3:0] PIXELB_LATCH;
always @(posedge clk_12M) begin
	PIXELA_LATCH <= PIXELA;
	PIXELB_LATCH <= PIXELB;
end
always @(posedge AK13) begin
	RAM_E_DIN[3:0] <= ~PAIR ? PIXELB_LATCH : 4'd0;
	RAM_F_DIN[3:0] <= ~PAIR ? PIXELA_LATCH : 4'd0;
end
always @(posedge AJ1) begin
	RAM_A_DIN[3:0] <= PAIR ? PIXELB_LATCH : 4'd0;
	RAM_B_DIN[3:0] <= PAIR ? PIXELA_LATCH : 4'd0;
end

// FINAL OUTPUT

wire [11:0] PAIR_SEL_EVEN = PAIR ? RAM_E_DOUT : RAM_A_DOUT;
wire [11:0] PAIR_SEL_ODD = PAIR ? RAM_F_DOUT : RAM_B_DOUT;

reg [11:0] PAIR_SEL_EVEN_REG;	// A/E
reg [11:0] PAIR_SEL_ODD_REG;	// B/F
always @(posedge PXH[0]) begin
	PAIR_SEL_EVEN_REG <= PAIR_SEL_EVEN;
	PAIR_SEL_ODD_REG <= PAIR_SEL_ODD;
end

wire [11:0] PARITY_SEL = K108 ? PAIR_SEL_EVEN_REG : PAIR_SEL_ODD_REG;

always @(posedge clk_6M)
	PARITY_SEL_REG <= PARITY_SEL;

assign PCOF = ~|{~PARITY_SEL_REG[3:0]}; // high if data[3:0] == 'b1111
assign NCO0 = ~&{~PARITY_SEL_REG[3:0]}; //  low if data[3:0] == 'b0000


// DELAYS

reg [5:0] LACH_DELAY;
always @(posedge clk_12M or negedge nRES) begin
	if (!nRES) begin
		LACH_DELAY <= 6'b000000;
	end else begin
		LACH_DELAY <= {LACH_DELAY[4:0], LACH};
	end
end
assign AR44_Q = LACH_DELAY[2];
assign AP71_Q = LACH_DELAY[5];
assign NEW_SPR = LACH_DELAY[4];

// HVIN sync
reg [7:0] DELAY_HVIN;
always @(posedge clk_6M or negedge RES_SYNC) begin
	if (!RES_SYNC) begin
		DELAY_HVIN <= 8'hFF;
	end else begin
		DELAY_HVIN <= {DELAY_HVIN[6:0], HVIN};
	end
end

assign nHVIN_DELAY = ~DELAY_HVIN[7];

FDN AN84(clk_6M, AN15_Q, nRES, AN84_Q,);
FDM AP52(~clk_12M, AN84_Q | clk_6M, AP52_Q,);
reg [4:0] AN15_DELAY;
always @(posedge clk_12M or negedge nRES) begin
	if (!nRES) begin
		AN15_DELAY <= 5'b00000;
	end else begin
		AN15_DELAY <= {AN15_DELAY[3:0], AP52_Q};
	end
end
assign AP134 = ~AN15_DELAY[4];

reg [6:0] NEWLINE_DELAY;
always @(posedge clk_6M or negedge nRES) begin
	if (!nRES) begin
		NEWLINE_DELAY <= 7'b0000000;
	end else begin
		NEWLINE_DELAY <= {NEWLINE_DELAY[5:0], nNEW_LINE};
	end
end
assign AN15_Q = NEWLINE_DELAY[6];

FJD AR4(clk_12M, ~LACH, HEND & AR16_Q, AN15_Q & nRES, , AR4_Q);
BD3 AS135(AR4_Q, AS135_OUT);

reg [3:0] AS135_DELAY;
always @(posedge clk_12M or negedge nRES) begin
	if (!nRES) begin
		AS135_DELAY <= 4'b0000;
	end else begin
		AS135_DELAY <= {AS135_DELAY[2:0], AS135_OUT};
	end
end
assign AR84_Q = AS135_DELAY[3];
FDM AR135(clk_12M, AR84_Q, AR135_Q, AR135_XQ);
FDM AR110(clk_12M, AP4_Q[0], AR110_Q, AR110_XQ);
assign AR116 = ~|{(AR84_Q & AR110_XQ), (AR135_Q & AR110_Q)};
FDM AR104(clk_12M, AR116, AR104_Q, AR104_XQ);

endmodule
