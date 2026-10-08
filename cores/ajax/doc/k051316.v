// Konami 051316 "PSAC"
// Based on silicon
// 2022 Sean Gonsalves

// M12_DELAY is critical ! RAM access alternate between CPU and rendering at 12M
// The slots address/reads become swapped if M12 isn't stretched

module k051316(
	input M12, M6,
	input IOCS, VRCS,
	input RW,
	input [10:0] A,
	inout [7:0] D,
	input VSCN, HSCN, VRC, HRC,
	output [23:0] CA,
	output OBLK
);

reg [7:0] REG [0:14];
reg [1:0] OBLK_DELAY;
reg E43_Q;
reg R31_Q;
reg E37_Q;
reg [3:0] PRE_X;
reg [3:0] PRE_Y;
reg [23:0] OUT_REG;
wire [3:0] XFLIP;
wire [3:0] YFLIP;
wire [7:0] D_MUX;
wire [9:0] RAM_A;
reg [15:0] RAM_REG;
reg [15:0] PRE_REG;
reg [7:0] RAM_L_REG;
reg [7:0] RAM_R_REG;

// Internal RAM 2* 1024*8
wire [7:0] RAM_L_D;
wire [7:0] RAM_R_D;
RAM RAM_L(RAM_CLK, RAM_A, RAM_L_WE, D, RAM_L_D);
RAM RAM_R(RAM_CLK, RAM_A, RAM_R_WE, D, RAM_R_D);

// Register writes
always @(*) begin
	if (~(IOCS | RW) & (A[3:0] != 4'd15))
		REG[A[3:0]] <= D;
end

always @(posedge ~M6) begin
	OBLK_DELAY <= {OBLK_DELAY[0], ~|{YACC[23:20], XACC[23:20]}};
	E43_Q <= ~HRC;
	PRE_X <= XACC[14:11];
	PRE_Y <= YACC[14:11];
	OUT_REG <= {PRE_REG, YFLIP, XFLIP};
end

// Clocks and sequencing

assign L16 = ~&{VRC | E37_Q, ~E43_Q};

always @(posedge M12)
	R31_Q <= ~M6;

assign #1 M12_DELAY = M12;
assign RAM_CLK = ~&{REG[14][5] | M12, REG[14][4] | M12_DELAY};

assign R11 = ~|{RW, VRCS, M6, ~RAM_CLK};
assign RAM_L_WE = A[10] & R11;
assign RAM_R_WE = ~A[10] & R11;

always @(posedge ~R31_Q)
	{RAM_L_REG, RAM_R_REG} <= RAM_REG;

assign R37 = R31_Q & ~REG[14][7];
assign RAM_A = R37 ? {YACC[19:15], XACC[19:15]} : A[9:0];

always @(posedge E43_Q)
	E37_Q <= VSCN;

assign T114 = ~&{VRC, ~E43_Q};
assign E34 = ~&{~E43_Q, E37_Q};

assign T163 = &{~|{VRC, E37_Q} | E43_Q, ~&{E37_Q, HSCN} | ~M6};

// X counter

wire [15:0] XADDER_A;
wire [23:0] XADDER_B;
wire [23:0] XADDER_S;
reg [23:0] XPREV;
reg [23:0] XACC;

assign XADDER_A = ~T114 ? 16'd0 : E34 ? {REG[2], REG[3]} : {REG[4], REG[5]};
assign XADDER_B = ~T114 ? {REG[0], REG[1], 8'd0} : L16 ? XACC : XPREV;
assign XADDER_S = {{8{XADDER_A[15]}}, XADDER_A} + XADDER_B;

always @(posedge L16)
	XPREV <= XADDER_S;

always @(posedge T163)
	XACC <= XADDER_S;

// Y counter

wire [15:0] YADDER_A;
wire [23:0] YADDER_B;
wire [23:0] YADDER_S;
reg [23:0] YPREV;
reg [23:0] YACC;

assign YADDER_A = ~T114 ? 16'd0 : E34 ? {REG[8], REG[9]} : {REG[10], REG[11]};
assign YADDER_B = ~T114 ? {REG[6], REG[7], 8'd0} : L16 ? YACC : YPREV;
assign YADDER_S = {{8{YADDER_A[15]}}, YADDER_A} + YADDER_B;

always @(posedge L16)
	YPREV <= YADDER_S;

always @(posedge T163)
	YACC <= YADDER_S;

assign XFLIP = {4{(RAM_REG[14] & REG[14][1])}} ^ PRE_X;
assign YFLIP = {4{(RAM_REG[15] & REG[14][2])}} ^ PRE_Y;

always @(posedge R31_Q)
	PRE_REG <= RAM_REG;

always @(posedge ~RAM_CLK)
	RAM_REG <= {RAM_L_D, RAM_R_D};

assign CA_TEST = REG[14][0] ? XACC : YACC;
assign CA_READOUT = {REG[14][7] ? A[10] ? RAM_L_D : RAM_R_D : {REG[13][4:0], REG[12][7:5]}, REG[12][4:0], A};
assign CA = REG[14][6] ? CA_TEST : REG[14][0] ? OUT_REG : CA_READOUT;

assign OBLK = REG[14][3] ? ~RAM_CLK : ~OBLK_DELAY[1];

assign D_MUX = A[10] ? RAM_L_REG : RAM_R_REG;
assign D = (~VRCS & RW) ? D_MUX : 8'bzzzzzzzz;

endmodule
