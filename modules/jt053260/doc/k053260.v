// Konami 053260 "KDSC"
// Based on silicon
// 2023 Sean Gonsalves

// Should push out a pair of samples every 64 CLKs (2 channels * 16 bits * 2 main CLK per bit).
// SY should be CLK/2 (== NE).
// SH1 and SH2 should be alternating pulses 16 CLKs high and 48 CLKs low, changing on SY negedge.
// STBI (YM2151 SH1 output) is used for sync. The falling edge marks the beginning of the CH1 period.

// CLK _|'|_|'|_|'|_|'|_|'|_|'|_|'|_|'|_|'|_|'|
// NE  _|'''|___|'''|___|'''|___|'''|___|'''|___
// NQ  ___|'''|___|'''|___|'''|___|'''|___|'''|___
// SY  _|'''|___|'''|___|'''|___|'''|___|'''|___

`include "YFD2.v"

module k053260(
	input CLK,					// YM2151 clock
	input nRES,					// Reset
	input ST1, ST2,				// Config ?
	output TIM2,
	output NE, NQ,				// 6809 E/Q
	input STBI, AUX1, AUX2,		// YM2151 SH1 for sync, two possible input streams
	output SY, SH1, SH2, SO		// For YM3012, SY must be CLK/2
);

assign AS245 = 0;	// Reg 2E bit 2: Enable aux input 1
assign AV193 = 0;	// Reg 2E bit 3: Enable aux input 2

// CLOCKS

reg AS1, AS24, AH101, AJ249, AE85, AE11, AF33, AH2, AJ20, AK62;
wire AR0, RES_SYNC;

assign SO = 1'b0;

assign RES_SYNC = nRES & AS24;

assign AE104 = ~&{AE85, AH101};
assign AD17 = ~|{AE104, AE11};
assign AF26 = ~&{AD17, ~AF33};
assign AJ19 = ~|{AF26, ~AH2};

assign SH1 = ~|{~AJ20, ~AH2};
assign SH2 = ~|{AJ20, ~AH2};
assign SY = ~AH101;	//AH141;

assign CLK_INV = ~CLK;
assign AF39 = ~AF33;

always @(posedge CLK_INV) begin
	AS1 <= STBI;
	AS24 <= ~AR0;
	AH101 <= ~&{AH101, RES_SYNC};

	// First counter block
	AE85 <= ~&{RES_SYNC, ~AE85 ^ AH101};
	AE11 <= ~&{RES_SYNC, AE11 ^ AE104};
	AF33 <= ~&{RES_SYNC, ~AF33 ^ AD17};
	AH2 <= ~&{RES_SYNC, AH2 ^ AF26};
	AJ20 <= ~&{RES_SYNC, ~AJ20 ^ AJ19};

	AK62 <= AN10;
end

assign AM32 = ~AJ20;
assign AD102 = ~AE85;
assign AN10 = AH2;
assign AD0 = ~AE11;
assign AH66 = ~AK62;
assign AM29 = AJ20;

// AB248 -> input clock divided by 16
YFD2 Cell_AM254(AM32, nAM254, nRES, , nAM254);
YFD2 Cell_AS254(nAM254, nAS254, nRES, , nAS254);
YFD2 Cell_AT254(nAS254, nAT254, nRES, , nAT254);
YFD2 Cell_AV218(nAT254, nAV218, nRES, , nAV218);
assign AB248 = ~|{nAM254, nAS254, nAT254, nAV218};

reg C248, B214, C216, C204, C254;

assign B236 = ~&{AB248, C248};
assign A217 = ~|{B236, ~B214};
assign C210 = ~&{A217, C216};
assign C211 = ~|{C210, ~C204};
assign B220 = ~C211;

always @(posedge AM32 or negedge nRES) begin
	// Second counter block
	if (!nRES) begin
		{C248, B214, C216, C204, C254} <= 5'd0;
	end else begin
		C248 <= ~&{B220, ~C248 ^ AB248};
		B214 <= &{B220, ~(B214 ^ B236)};
		C216 <= &{B220, ~(~C216 ^ A217)};
	    C204 <= ~&{B220, C204 ^ C210};
	    C254 <= C211;
	end
end

assign TIM2 = C254;

always @(negedge CLK_INV) begin
	AJ249 <= AH101;
end

assign NE = ~AH101;
assign NQ = AJ249;

YFD2 Cell_AR0(AS1, 1'b1, RES_SYNC, AR0, );

// MISC 2

reg AL112, AH106, AL99, AM120;

always @(posedge CLK_INV) begin
	//if (!UNK3) begin
		AL112 <= ~({AM29, AF27} == 2'd0);
		AH106 <= ~({AM29, AF27} == 2'd1);
		AL99 <= ~({AM29, AF27} == 2'd2);
		AM120 <= ~({AM29, AF27} == 2'd3);
	//end
end

// YM IN

reg [12:0] AUX1_SR;
reg [12:0] AUX2_SR;
reg [12:0] AUX1_REG;
reg [12:0] AUX2_REG;
wire [12:0] AUXMUX;
wire [2:0] AUXMUX_S;
wire [8:0] AUXMUX_D;

always @(posedge ~AH101) begin	// AH178 = ~AH101
	AUX1_SR <= {AUX1, AUX1_SR[12:1]};
	AUX2_SR <= {AUX2, AUX2_SR[12:1]};
end

always @(posedge AH66 or negedge nRES) begin
	if (!nRES) begin
		AUX1_REG <= 13'd0;
		AUX2_REG <= 13'd0;
	end else begin
		AUX1_REG <= AUX1_SR;
		AUX2_REG <= AUX2_SR;
	end
end

assign {AUXMUX_S, AUXMUX} = AN10 ? AUX2_REG : AUX1_REG;
assign AUXMUX_SIGN = AUXMUX[9];
assign AUXMUX_D = AUXMUX_SIGN ? ~AUXMUX[8:0] : AUXMUX[8:0];

// YM EXP DECODE

reg [7:0] DEC_S;

always @(*) begin
	case(AUXMUX_S)
		3'd0: DEC_S <= 8'b00000000;	// Shouldn't be used
		3'd1: DEC_S <= 8'b00000010;
		3'd2: DEC_S <= 8'b00000100;
		3'd3: DEC_S <= 8'b00001000;
		3'd4: DEC_S <= 8'b00010000;
		3'd5: DEC_S <= 8'b00100000;
		3'd6: DEC_S <= 8'b01000000;
		3'd7: DEC_S <= 8'b10000000;
	endcase
end

// YM DEC

wire [15:0] YMDEC;
wire [15:0] YMDEC_COM;

assign YMDEC[0] = &{DEC_S[1], AUXMUX_D[0]};
assign YMDEC[1] = ~&{
						~&{DEC_S[1], AUXMUX_D[1]},
						~&{DEC_S[2], AUXMUX_D[0]}
						};
assign YMDEC[2] = ~&{
						~&{DEC_S[1], AUXMUX_D[2]},
						~&{DEC_S[6], AUXMUX_D[1]},	// Should be DEC_S[2] ?
						~&{DEC_S[3], AUXMUX_D[0]}
						};
assign YMDEC[3] = ~&{
						~&{DEC_S[4], AUXMUX_D[0]},
						~&{DEC_S[3], AUXMUX_D[1]},
						~&{DEC_S[2], AUXMUX_D[2]},
						~&{DEC_S[3], AUXMUX_D[3]}
						};
assign YMDEC[4] = ~&{
						~&{DEC_S[1], AUXMUX_D[4]},
						~&{DEC_S[2], AUXMUX_D[3]},
						~&{DEC_S[3], AUXMUX_D[2]},
						~&{DEC_S[4], AUXMUX_D[1]},
						~&{DEC_S[5], AUXMUX_D[0]}
						};
assign YMDEC[5] = ~&{
						~&{DEC_S[4], AUXMUX_D[2]},
						~&{DEC_S[5], AUXMUX_D[1]},
						~&{DEC_S[6], AUXMUX_D[0]},
						~&{DEC_S[1], AUXMUX_D[5]},
						~&{DEC_S[2], AUXMUX_D[4]},
						~&{DEC_S[3], AUXMUX_D[3]}
						};
assign YMDEC[6] = ~&{
						~&{DEC_S[3], AUXMUX_D[4]},
						~&{DEC_S[5], AUXMUX_D[5]},	// Should be DEC_S[2] ?
						~&{DEC_S[1], AUXMUX_D[6]},
						&{~&{DEC_S[1], AUXMUX_D[0]}, ~&{DEC_S[6], AUXMUX_D[1]}},
						~&{DEC_S[5], AUXMUX_D[2]},
						~&{DEC_S[4], AUXMUX_D[3]}
						};
assign YMDEC[7] = ~&{
						~&{DEC_S[3], AUXMUX_D[5]},
						~&{DEC_S[2], AUXMUX_D[6]},
						~&{DEC_S[4], AUXMUX_D[4]},
						&{~&{DEC_S[1], AUXMUX_D[1]}, ~&{DEC_S[6], AUXMUX_D[2]}},
						~&{DEC_S[5], AUXMUX_D[3]},
						~&{DEC_S[1], AUXMUX_D[7]}
						};
assign YMDEC[8] = ~&{
						~&{
							~&{DEC_S[3], AUXMUX_D[6]},
							~&{DEC_S[2], AUXMUX_D[7]},
							~&{DEC_S[1], AUXMUX_D[8]}
						},
						&{~&{DEC_S[6], AUXMUX_D[3]}, ~&{DEC_S[1], AUXMUX_D[2]}},
						~&{DEC_S[5], AUXMUX_D[4]},
						~&{DEC_S[4], AUXMUX_D[5]}
						};
assign YMDEC[9] = ~&{
						~&{DEC_S[2], AUXMUX_D[8]},
						~&{DEC_S[3], AUXMUX_D[7]},
						~&{DEC_S[4], AUXMUX_D[6]},
						~&{DEC_S[5], AUXMUX_D[5]},
						&{~&{DEC_S[6], AUXMUX_D[4]}, ~&{DEC_S[1], AUXMUX_D[3]}}
						};
assign YMDEC[10] = ~&{
						~&{DEC_S[3], AUXMUX_D[8]},
						~&{DEC_S[4], AUXMUX_D[7]},
						~&{DEC_S[5], AUXMUX_D[6]},
						~&{DEC_S[6], AUXMUX_D[5]},
						~&{DEC_S[1], AUXMUX_D[4]}
						};
assign YMDEC[11] = ~&{
						~&{DEC_S[1], AUXMUX_D[5]},
						~&{DEC_S[6], AUXMUX_D[6]},
						~&{DEC_S[5], AUXMUX_D[7]},
						~&{DEC_S[4], AUXMUX_D[8]}
						};
assign YMDEC[12] = ~&{
						~&{DEC_S[5], AUXMUX_D[8]},
						~&{DEC_S[6], AUXMUX_D[7]},
						~&{DEC_S[1], AUXMUX_D[6]}
						};
assign YMDEC[13] = ~&{
						~&{DEC_S[6], AUXMUX_D[8]},
						~&{DEC_S[1], AUXMUX_D[7]}
						};
assign YMDEC[14] = &{DEC_S[1], AUXMUX_D[6]};

assign YMDEC_COM = AUXMUX_SIGN ? ~YMDEC : YMDEC;

reg [15:0] YMDEC_REG0;
reg [15:0] YMDEC_REG1;
reg [15:0] YMDEC_REG2;
reg [15:0] YMDEC_REG3;

// Register linear sample data for each YM channel after conversion from FP
always @(posedge AM120 or negedge AV193) begin
	if (!AV193)
        YMDEC_REG0 <= 16'd0;
    else
		YMDEC_REG0 <= YMDEC_COM;
end
always @(posedge AL99 or negedge AS245) begin
	if (!AS245)
        YMDEC_REG1 <= 16'd0;
    else
		YMDEC_REG1 <= YMDEC_COM;
end
always @(posedge AL112 or negedge AS245) begin
	if (!AS245)
        YMDEC_REG2 <= 16'd0;
    else
		YMDEC_REG2 <= YMDEC_COM;
end
always @(posedge AH106 or negedge AV193) begin
	if (!AV193)
        YMDEC_REG3 <= 16'd0;
    else
		YMDEC_REG3 <= YMDEC_COM;
end

reg [15:0] YM_MUX;

always @(*) begin
	if (AD102) begin
		case({AN10, AD0})
			2'b00: YM_MUX <= YMDEC_REG0;
			2'b01: YM_MUX <= YMDEC_REG1;
			2'b10: YM_MUX <= YMDEC_REG2;
			2'b11: YM_MUX <= YMDEC_REG3;
		endcase
	end else begin
		YM_MUX <= 16'd0;
	end
end

endmodule
