// Konami 053936
// furrtek 2024

// `include "k054000_unit.v"

module k053936(
	input CLK,

	input [15:0] D,
	input [ 4:1] A,
    // compatibility with 8-bit CPUs (high)
    // leave low for 16-bit bus writes
	input N16_8,

	input HSYNC, VSYNC,
	input NUCS, NLCS, NWCS,
	output NDMA,	// Low during line parameter RAM access
	input NDTACK,

	input NLOE,
	output [2:0] LH, // External line parameter RAM address lower bits
	output [8:0] LA, // External line parameter RAM address

	input NOE,       // OE for pixel coordinate pins
	output [12:0] X, // pixel X coordinate
	output XH,
	output [12:0] Y, // pixel X coordinate
	output YH,
	output reg NOB	// pixel out of bounds
);

assign {X, XH, Y, YH} = NOE ? {28{1'bz}} : {X_REG, Y_REG};

assign {LA, LH} = NLOE ? {12{1'bz}} : {LA_REG, LH_SEL};

wire [15:8] MUX_D;
assign MUX_D = N16_8 ? D[7:0] : D[15:8];


wire vs_edge_n = ~&{VSYNC_l, ~VSYNC_ll};	// Low pulse on VSYNC rising edge
wire hs_edge_n = ~&{HSYNC_l, ~HSYNC_ll};	// Low pulse on HSYNC rising edge

reg VSYNC_l, VSYNC_ll, HSYNC_l, HSYNC_ll;
reg L132_QA;
reg L132_QC;
reg TICK_VSn;
reg TICK_HSn;
always @(posedge CLK) begin
	VSYNC_l  <= VSYNC;
	VSYNC_ll <= VSYNC_l;

	HSYNC_l  <= HSYNC;
	HSYNC_ll <= HSYNC_l;

	L132_QA  <= vs_edge_n & ~hs_edge_n;	// High when HSYNC rising edge without VSYNC rising edge at the same time, todo: check
	TICK_VSn <= vs_edge_n;
	L132_QC  <= vs_edge_n & hs_edge_n;	// Low when HSYNC rising edge or VSYNC rising edge at the same time, todo: check
	TICK_HSn <= hs_edge_n;
end

wire OOB_X = ~&{
	REGL6[5:0] | {
		~SUM_XR[23],
		{5{~&{SUM_XR[23], REGL6[5]}}} ^ SUM_XR[22:18]
	}
};

wire OOB_Y = ~&{
	REGU6[5:0] | {
		~SUM_YR[23],
		{5{~&{SUM_YR[23], REGU6[5]}}} ^ SUM_YR[22:18]
	}
};

reg OOB_WIN;
always @(posedge CLK or negedge REGL7[5]) begin
	if (!REGL7[5])
		OOB_WIN <= 1'b1;
	else
		OOB_WIN <= ~(REGL7[4] | (REGL7[3] ^ IN_LIMITS));
end

wire OOB_MIX = ~|{OOB_X, OOB_Y, OOB_WIN};

reg OOB_DELAYED;
always @(*) begin
	case(REGL7[1:0])
		2'd0: OOB_DELAYED <= OOB_MIX;
		2'd1: OOB_DELAYED <= OOB_SR[0];
		2'd2: OOB_DELAYED <= OOB_SR[1];
		2'd3: OOB_DELAYED <= OOB_SR[2];
	endcase
end

reg [2:0] OOB_SR;
always @(posedge CLK) begin
	OOB_SR <= {OOB_SR[1:0], OOB_MIX};
	NOB <= OOB_DELAYED;
end

reg [3:0] LHCNT;
always @(posedge CLK) begin
    if (!TICK_HSn)
    	LHCNT <= 4'd0;
    else if (LNOK)
    	LHCNT <= LHCNT + 1'b1;
end

wire [2:0] LH_SEL;
assign {LNRD_n, LH_SEL} = N16_8 ? LHCNT : {LHCNT[2:0], 1'b0};
assign L103A = N16_8 & ~LH[0];

assign NDMA = LNRD_n | ~REGL7[6];

assign LNOK = ~|{LNRD_n, NDTACK};	// Uses a delay cell
assign L99A = LNOK & REGL7[6]; //  REGL7[6] = line RAM enable

reg [3:0] L76;
reg [3:0] M80;
always @(*) begin
	({L99A, LNRD_n, LH[2:1], N16_8 & ~LH[0]}) // reads lower 8 bits
		5'b10_000: M80 <= 4'b1110;
		5'b10_010: M80 <= 4'b1101;
		5'b10_100: M80 <= 4'b1011;
		5'b10_110: M80 <= 4'b0111;
    	default:   M80 <= 4'b1111;
	endcase

	case({L99A, LNRD_n, LH})		// reads upper 8 bits from RAM
		5'b10_000: L76 <= 4'b1110;
		5'b10_010: L76 <= 4'b1101;
		5'b10_100: L76 <= 4'b1011;
		5'b10_110: L76 <= 4'b0111;
    	default:   L76 <= 4'b1111;
	endcase
end

// G140A = G3B = G5B = G186B
// G1A = G3A = G187A = F138A

wire L116 = L132_QC;	// Todo: Check

wire L114B = CLK | (REGL7[6] ? hs_edge_n : TICK_VSn);
wire F159  = CLK | (REGL7[6] ? TICK_VSn: L116);	// Uses a delay cell

// Really duplicated logic ?
wire H99 = ~|{TICK_VSn, L116};
wire H100A = ~|{TICK_VSn, L116};

wire H131A = ~|{H100A, L116};
wire H104A = ~|{H100A, ~L116};

wire F152 = ~|{H99, L116};
wire F140A = ~|{H99, ~L116};



reg [13:0] X_REG;
reg [13:0] Y_REG;
always @(posedge CLK) begin
	X_REG <= SUM_XR[23:10];
	Y_REG <= SUM_YR[23:10];
end

reg [23:0] SUM_XR;
reg [23:0] SUM_YR;
always @(posedge CLK) begin	// Uses CLK_DLY
	SUM_XR <= SUM_X;
	SUM_YR <= SUM_Y;
end

// E188A = E89B = F159

reg [23:0] SUM_XR_B;
reg [23:0] SUM_YR_B;
always @(posedge F159) begin
	SUM_XR_B <= SUM_X;
	SUM_YR_B <= SUM_Y;
end

wire [23:0] PREV_X;
assign PREV_X = L132_QA ? SUM_XR_B : SUM_XR;

wire [23:0] PREV_Y;
assign PREV_Y = L132_QA ? SUM_YR_B : SUM_YR;

// To check: B136/B177 A/B inputs really to G140A/F138A ?

initial begin
	// These need to be initialized to make sync signals processing work from t=0
	// Otherwise 3 clock edges are needed for the HSYNC and VSYNC input states to get in
	VSYNC_l <= 1'b0;
	VSYNC_ll <= 1'b0;
	HSYNC_l <= 1'b0;
	HSYNC_ll <= 1'b0;
	L132_QA <= 1'b0;	// If HSYNC and VSYNC were always low
	TICK_VSn <= 1'b1;
	L132_QC <= 1'b1;
	TICK_HSn <= 1'b1;

	// These need to be initialized otherwise adder outputs can never go out of x state
	SUM_XR <= 24'd0;
	SUM_YR <= 24'd0;
	SUM_XR_B <= 24'd0;
	SUM_YR_B <= 24'd0;
	XMUX_REG_A = 24'd0;
	XMUX_REG_B = 24'd0;
	YMUX_REG_A = 24'd0;
	YMUX_REG_B = 24'd0;
	
	{REGU0, REGL0} <= 16'd0;
	{REGU1, REGL1} <= 16'd0;
	{REGU2, REGL2} <= 16'd0;
	{REGU3, REGL3} <= 16'd0;
	{REGU4, REGL4} <= 16'd0;
	{REGU5, REGL5} <= 16'd0;
	{REGU6, REGL6} <= 16'd0;
	REGL7 <= 7'd0;
	{REGU8, REGL8} <= 10'd0;
	{REGU9, REGL9} <= 10'd0;
	{REGU10, REGL10} <= 9'd0;
	{REGU11, REGL11} <= 9'd0;
	{REGU12, REGL12} <= 10'd0;
	{REGU13, REGL13} <= 9'd0;
	{REGU14, REGL14} <= 9'd0;
end

// Video counters
reg [8:0] LA_REG;
reg [8:0] V;
always @(posedge CLK) begin
   	if (!TICK_VSn) begin
    	LA_REG <= {REGU14, REGL14};
		V <= {REGU13, REGL13};
    end else if (!TICK_HSn) begin
    	LA_REG <= LA_REG + 1'b1;
    	V <= V + 1'b1;
    end
end

reg [9:0] H;
always @(posedge CLK) begin
   	if (!TICK_HSn)
		H <= {REGU12, REGL12};
    else
    	H <= H + 1'b1;
end


// window detection
wire MATCHn1 = CLK | ~&{~(V ^ {REGU10, REGL10})}; // y max
wire MATCHn2 = CLK | ~&{~(V ^ {REGU11, REGL11})}; // y min
wire MATCHn3 = CLK | ~&{~(H ^ {REGU8, REGL8})};   // x min
wire MATCHn4 = CLK | ~&{~(H ^ {REGU9, REGL9})};   // x max

reg N120, N124;
always @(posedge TICK_VSn or negedge MATCHn1 or negedge MATCHn2) begin
	case({MATCHn1, MATCHn2}) // max,min
		2'b00:   N120 <= 1'b0;	// To check
		2'b01:   N120 <= 1'b1;
		2'b10:   N120 <= 1'b0;
		2'b11:   N120 <= REGL7[2];
		default: N120 <= N120;
	endcase
end

always @(posedge TICK_HSn or negedge MATCHn3 or negedge MATCHn4) begin
	case({MATCHn3, MATCHn4})
		2'b00: N124 <= 1'b0;	// To check
		2'b01: N124 <= 1'b1;
		2'b10: N124 <= 1'b0;
		2'b11: N124 <= REGL7[2];
	endcase
end

wire IN_LIMITS = N120 & N124;


// X
// H152A = J152A = L114B
reg [23:0] XMUX_REG_A;
always @(posedge L114B) begin
	XMUX_REG_A <= REGL6[6] ? {REGU4, REGL4, 8'd0} : {{8{REGU4[7]}}, REGU4, REGL4};
end
reg [23:0] XMUX_REG_B;
always @(posedge L114B) begin
	XMUX_REG_B <= REGL6[7] ? {REGU2, REGL2, 8'd0} : {{8{REGU2[7]}}, REGU2, REGL2};
end

reg [23:0] MUX_X;
always @(*) begin
	case({H104A, H131A, H100A})
    	3'b100: MUX_X <= XMUX_REG_A;	// H152A
    	3'b010: MUX_X <= XMUX_REG_B;	// J152A
    	3'b001: MUX_X <= {REGU0, REGL0, 8'd0};
    	default: MUX_X <= 24'd0;	// Shouldn't happen
	endcase
end

wire [23:0] SUM_X;
assign SUM_X = MUX_X + PREV_X;

// Y, exact same as X
// F154A = F154B = L114B
reg [23:0] YMUX_REG_A;
always @(posedge L114B) begin
	YMUX_REG_A <= REGU6[6] ? {REGU5, REGL5, 8'd0} : {{8{REGU5[7]}}, REGU5, REGL5};
end
reg [23:0] YMUX_REG_B;
always @(posedge L114B) begin
	YMUX_REG_B <= REGU6[7] ? {REGU3, REGL3, 8'd0} : {{8{REGU3[7]}}, REGU3, REGL3};
end

reg [23:0] MUX_Y;
always @(*) begin
	case({F140A, F152, H99})
    	3'b100: MUX_Y <= YMUX_REG_A;	// F154A
    	3'b010: MUX_Y <= YMUX_REG_B;	// F154B
    	3'b001: MUX_Y <= {REGU1, REGL1, 8'd0};
    	default: MUX_Y <= 24'd0;	// Shouldn't happen
	endcase
end

wire [23:0] SUM_Y;
assign SUM_Y = MUX_Y + PREV_Y;

reg [7:0] REGL0;
reg [7:0] REGL1;
reg [7:0] REGL2;
reg [7:0] REGL3;
reg [7:0] REGL4;
reg [7:0] REGL5;
reg [7:0] REGL6;
reg [7:0] REGL7;
reg [7:0] REGL8;
reg [7:0] REGL9;
reg [7:0] REGL10;
reg [7:0] REGL11;
reg [7:0] REGL12;
reg [7:0] REGL13;
reg [7:0] REGL14;

reg [7:0] REGU0;
reg [7:0] REGU1;
reg [7:0] REGU2;
reg [7:0] REGU3;
reg [7:0] REGU4;
reg [7:0] REGU5;
reg [7:0] REGU6;
//reg [7:0] REGU7;
reg [1:0] REGU8;
reg [1:0] REGU9;
reg REGU10;
reg REGU11;
reg [1:0] REGU12;
reg REGU13;
reg REGU14;

// Registers (all latches)
// L/U 2, 3, 4 and 5 are special cases (used by auto-load)
always @(*) begin
	if (!NWCS) begin
		if (!NLCS) begin
			case(A)
		    	4'd0: REGL0 <= D[7:0];
		    	4'd1: REGL1 <= D[7:0];
		    	4'd6: REGL6 <= D[7:0];
		    	4'd7: REGL7 <= D[6:0];
		    	4'd8: REGL8 <= D[7:0];
		    	4'd9: REGL9 <= D[7:0];
		    	4'd10: REGL10 <= D[7:0];
		    	4'd11: REGL11 <= D[7:0];
		    	4'd12: REGL12 <= D[7:0];
		    	4'd13: REGL13 <= D[7:0];
		    	4'd14: REGL14 <= D[7:0];
		    	// No reg 15
		    	default:;
			endcase
		end
		if (!NUCS) begin
			case(A)
		    	4'd0: REGU0 <= MUX_D;
		    	4'd1: REGU1 <= MUX_D;
		    	4'd6: REGU6 <= MUX_D;
		    	// Reg 7 doesn't have an upper byte
		    	4'd8: REGU8 <= MUX_D[9:8];
		    	4'd9: REGU9 <= MUX_D[9:8];
		    	4'd10: REGU10 <= MUX_D[8];
		    	4'd11: REGU11 <= MUX_D[8];
		    	4'd12: REGU12 <= MUX_D[9:8];
		    	4'd13: REGU13 <= MUX_D[8];
		    	4'd14: REGU14 <= MUX_D[8];
		    	// No reg 15
		    	default:;
			endcase
		end
	end

	// Reg 2
	if ((!REGL7[6] & ({A, NLCS, NWCS} == 6'b0010_00)) | (!CLK & !M80[0])) REGL2 <= D[7:0];
	if ((!REGL7[6] & ({A, NUCS, NWCS} == 6'b0010_00)) | (!CLK & !L76[0])) REGU2 <= MUX_D;

	// Reg 3
	if ((!REGL7[6] & ({A, NLCS, NWCS} == 6'b0011_00)) | (!CLK & !M80[1])) REGL3 <= D[7:0];
	if ((!REGL7[6] & ({A, NUCS, NWCS} == 6'b0011_00)) | (!CLK & !L76[1])) REGU3 <= MUX_D;

	// Reg 4
	if ((!REGL7[6] & ({A, NLCS, NWCS} == 6'b0100_00)) | (!CLK & !M80[2])) REGL4 <= D[7:0];
	if ((!REGL7[6] & ({A, NUCS, NWCS} == 6'b0100_00)) | (!CLK & !L76[2])) REGU4 <= MUX_D;

	// Reg 5
	if ((!REGL7[6] & ({A, NLCS, NWCS} == 6'b0101_00)) | (!CLK & !M80[3])) REGL5 <= D[7:0];
	if ((!REGL7[6] & ({A, NUCS, NWCS} == 6'b0101_00)) | (!CLK & !L76[3])) REGU5 <= MUX_D;
end

endmodule
