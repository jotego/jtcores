// Konami 053252
// furrtek 2025

module k053252(
	input PIN_RESET,
	input PIN_CLK,
	input [2:0] PIN_SEL,
	input PIN_CCS,
	input PIN_RW,
	input [3:0] PIN_AB,
	input [7:0] PIN_DB_IN,
	input PIN_HLD1,
	input PIN_VLD1,
	output [7:0] PIN_DB_OUT,
	output reg PIN_CLK1,
	output reg PIN_CLK2,
	output reg PIN_CLK3,
	output reg PIN_CLK4,
	output reg PIN_PE,
    output reg PIN_PQ,
    output reg PIN_CRES,
    output reg PIN_NHLD,
    output PIN_NHSY,
    output PIN_NVSY,
	output reg PIN_NVLD,
	output PIN_FCNT,
	output reg PIN_INT1,
	output reg PIN_INT2,
	output PIN_NCBK,
	output PIN_NCSY,
	output PIN_NVBK,
	output PIN_NHBS,
	output PIN_NHBK
);

// Clocks and reset

reg RESP;
reg D1;

always @(posedge PIN_CLK or negedge PIN_RESET) begin
	if (!PIN_RESET)
		RESP <= 1'b0;
	else
		RESP <= 1'b1;
end

always @(negedge PIN_CLK1) begin
	PIN_CLK4 <= PIN_CLK2;
end

always @(posedge PIN_CLK or negedge RESP) begin
	if (!RESP) begin
		PIN_CLK1 <= 1'b1;
		PIN_CLK2 <= 1'b1;
		PIN_CLK3 <= 1'b1;
		
		PIN_PE <= 1'b1;
		D1 <= 1'b0;
		PIN_PQ <= 1'b0;
	end else begin
		PIN_CLK1 <= ~PIN_CLK1;
		PIN_CLK2 <= ~PIN_CLK1 ^ PIN_CLK2;
		PIN_CLK3 <= ~|{PIN_CLK1, PIN_CLK2} ^ PIN_CLK3;
		
        PIN_PE <= PIN_CLK3;
        D1 <= ~PIN_PE;
        PIN_PQ <= D1;
	end
end

always @(*) begin
    case(PIN_SEL[1:0])
        2'd0: PIN_CRES <= RES_DELAY[1];
        2'd1: PIN_CRES <= RES_DELAY[3];
        2'd2: PIN_CRES <= RES_DELAY[7];
        2'd3: PIN_CRES <= 1'b0;
    endcase
end

reg CLKSEL;

always @(*) begin
    case(PIN_SEL[1:0])
        2'd0: CLKSEL <= PIN_CLK2;
        2'd1: CLKSEL <= PIN_CLK1;
        2'd2: CLKSEL <= PIN_CLK;
        2'd3: CLKSEL <= 1'b0;
    endcase
end

// Registers

reg [15:0] WR; // WR[15:14] are inverted !

always @(*) begin
    casez({PIN_CCS, PIN_RW, PIN_AB})
        6'b00_0000: WR <= 16'h0001;
        6'b00_0001: WR <= 16'h0002;
        6'b00_0010: WR <= 16'h0004;
        6'b00_0011: WR <= 16'h0008;
        6'b00_0100: WR <= 16'h0010;
        6'b00_0101: WR <= 16'h0020;
        6'b00_0110: WR <= 16'h0040;
        6'b00_0111: WR <= 16'h0080;
        6'b00_1000: WR <= 16'h0100;
        6'b00_1001: WR <= 16'h0200;
        6'b00_1010: WR <= 16'h0400;
        6'b00_1011: WR <= 16'h0800;
        6'b00_1100: WR <= 16'h1000;
        6'b00_1101: WR <= 16'h2000;
        6'b00_1110: WR <= 16'h4000;
        6'b00_1111: WR <= 16'h8000;
        default: WR <= 16'h0000;
    endcase
end

reg [1:0] REG0;
reg [7:0] REG1;
reg REG2;
reg [7:0] REG3;
reg REG4;
reg [7:0] REG5;
reg [2:0] REG6;
reg REG7_D7;
reg [1:0] REG7;
reg REG8;
reg [7:0] REG9;
reg [7:0] REG10;
reg [7:0] REG11;
reg [7:0] REG12;
reg [7:0] REG13;
reg REG13SET;

always @(*) begin
    if (!RESP) begin
        REG0 <= 2'b11;
        REG1 <= 8'h00;
        REG2 <= 1'b0;
        REG3 <= 8'h00;
        REG4 <= 1'b1;
        REG5 <= 8'h00;
        REG6 <= 3'h0;
        {REG7_D7, REG7} <= 3'h0;
        REG8 <= 1'b1;
        REG9 <= 8'h00;
        REG10 <= 8'h00;
        REG11 <= 8'h00;
        REG12 <= 8'h00;
        REG13 <= 8'h00;
        REG13SET <= 1'b0;
    end else begin
        if (WR[0]) REG0 <= PIN_DB_IN[1:0];
        if (WR[1]) REG1 <= PIN_DB_IN;
        if (WR[2]) REG2 <= PIN_DB_IN[0];
        if (WR[3]) REG3 <= PIN_DB_IN;
        if (WR[4]) REG4 <= PIN_DB_IN[0];
        if (WR[5]) REG5 <= PIN_DB_IN;
        if (WR[6]) REG6 <= PIN_DB_IN[2:0];
        if (WR[7]) {REG7_D7, REG7} <= {PIN_DB_IN[7], PIN_DB_IN[1:0]};
        if (WR[8]) REG8 <= PIN_DB_IN[0];
        if (WR[9]) REG9 <= PIN_DB_IN;
        if (WR[10]) REG10 <= PIN_DB_IN;
        if (WR[11]) REG11 <= PIN_DB_IN;
        if (WR[12]) REG12 <= PIN_DB_IN;
        if (WR[13]) begin
            REG13 <= PIN_DB_IN;
            REG13SET <= 1'b1;
        end
    end
end

assign R29B = WR[14] & RESP;
always @(posedge nPIN_NVBK or negedge R29B) begin
    if (!R29B)
        PIN_INT1 <= 1'b1;
    else
        PIN_INT1 <= 1'b0;
end

assign K4A = WR[15] & RESP;
always @(posedge CLKSEL or negedge K4A) begin
    if (!K4A)
        PIN_INT2 <= 1'b1;
    else
        PIN_INT2 <= PIN_INT2 & ~CNTD_TC;
end

// Counter A
m74163 S45(1'b1, L38B,   CLKSEL, G51, RESP, ~REG11[3:0], , S45_TC);
m74163 L50(1'b1, S45_TC, CLKSEL, G51, RESP, ~REG11[7:4], , CNTA_TC);

// Counter B
m74163 D40(1'b1, G44,    CLKSEL, L37, RESP, ~REG5[3:0], , D40_TC);
m74163 C54(1'b1, D40_TC, CLKSEL, L37, RESP, ~REG5[7:4], , C54_TC);

reg CNTB_MID; // Bit 8 of counter B
always @(posedge CLKSEL) begin
    if (!RESP) begin
        CNTB_MID <= 1'b0;
    end else begin
        if (!L37)
            CNTB_MID <= REG4;
        else if (C54_TC)
            CNTB_MID <= ~CNTB_MID;
    end
end

assign CNTB_TC = ~|{CNTB_MID, ~C54_TC};

// Counter C

m74163 C9(1'b1, ~REG7_D7, CLKSEL, H29, RESP, {~REG12[0], 3'b000}, , C9_TC);
m74163 B54(1'b1, J31, CLKSEL, D35, RESP, ~REG12[7:4], , CNTC_TC);

reg [2:0] CNTC_MID; // Bits 4~6 of counter C
always @(posedge CLKSEL) begin
    if (!RESP) begin
        CNTC_MID <= 4'd0;
    end else begin
        if (!H29)
            CNTC_MID <= ~REG12[3:1];
        else if (C9_TC)
            CNTC_MID <= CNTC_MID + 1'b1;
    end
end

assign M11 = ~|{~CNTC_MID, ~C9_TC};

// Counter D

assign L38A = REG13SET & J31;
m74163 H35(1'b1, L38A, CLKSEL, ~CNTD_TC, RESP, ~REG13[3:0], , H35_TC);
m74163 J54(1'b1, H35_TC, CLKSEL, ~CNTD_TC, RESP, ~REG13[7:4], , CNTD_TC);

// H Counter

wire [9:0] HCNT;
m74163 G54(1'b1, ~REG7_D7, CLKSEL, H29, RESP, ~REG1[3:0], HCNT[3:0], G54_TC);
m74163 K54(1'b1,   G54_TC, CLKSEL, H29, RESP, ~REG1[7:4], HCNT[7:4], K54_TC);

reg [1:0] HCNT_MID; // Bits 8~9 of H counter
always @(posedge CLKSEL) begin
    if (!RESP) begin
        HCNT_MID <= 2'd0;
    end else begin
        if (!H29)
            HCNT_MID <= ~REG0;
        else if (K54_TC)
            HCNT_MID <= HCNT_MID + 1'b1;
    end
end
assign HCNT[9:8] = HCNT_MID;

assign G52 = ~&{HCNT, ~REG7_D7};

reg A13_Q;
always @(posedge CLKSEL or negedge RESP) begin
    if (!RESP)
        A13_Q <= 1'b0;
    else
        A13_Q <= PIN_HLD1;
end

assign H29 = PIN_SEL[2] ? A13_Q : G52;

always @(posedge CLKSEL or negedge RESP) begin
    if (!RESP)
        PIN_NHLD <= 1'b1;
    else
        PIN_NHLD <= H29;
end

reg nNHSY;
always @(posedge CLKSEL or negedge RESP) begin
    if (!RESP) begin
        nNHSY <= 1'b1;
    end else begin
        case({~H29, M11})   // J, K
            2'b00: nNHSY <= nNHSY;  // Latch
            2'b01: nNHSY <= 1'b0;   // Reset
            2'b10: nNHSY <= 1'b1;   // Set
            2'b11: nNHSY <= ~nNHSY; // Toggle
        endcase
    end
end

assign PIN_NHSY = ~nNHSY;

// V Counter

wire [8:0] VCNT;
m74163 P43(1'b1, J31,    CLKSEL, D35, RESP, ~REG9[3:0], VCNT[3:0], P43_TC);
m74163 R54(1'b1, P43_TC, CLKSEL, D35, RESP, ~REG9[7:4], VCNT[7:4], R54_TC);

reg VCNT_MID; // Bits 8 of V counter
always @(posedge CLKSEL) begin
    if (!RESP) begin
        VCNT_MID <= 1'b0;
    end else begin
        if (!D35)
            VCNT_MID <= ~REG8;
        else if (R54_TC)
            VCNT_MID <= ~VCNT_MID;
    end
end
assign VCNT[8] = VCNT_MID;

assign P41 = ~&{VCNT, J31};

reg D13_Q;
always @(posedge CLKSEL or negedge RESP) begin
    if (!RESP)
        D13_Q <= 1'b0;
    else
        D13_Q <= PIN_VLD1;
end

assign D35 = PIN_SEL[2] ? D13_Q : P41;

always @(posedge CLKSEL or negedge RESP) begin
    if (!RESP)
        PIN_NVLD <= 1'b1;
    else
        PIN_NVLD <= D35;
end

reg nNVSY;
always @(posedge CLKSEL or negedge RESP) begin
    if (!RESP) begin
        nNVSY <= 1'b1;
    end else begin
        case({~D35, CNTC_TC})   // J, K
            2'b00: nNVSY <= nNVSY;  // Latch
            2'b01: nNVSY <= 1'b0;   // Reset
            2'b10: nNVSY <= 1'b1;   // Set
            2'b11: nNVSY <= ~nNVSY; // Toggle
        endcase
    end
end

assign PIN_NVSY = ~nNVSY;

// Comparators

assign E78 = (HCNT[8:0] == ~{REG2, REG3}) & HCNT[9];
               
reg HBK_START;
always @(posedge CLKSEL or negedge RESP) begin
    if (!RESP)
        HBK_START <= 1'b0;
    else
        HBK_START <= E78;
end

reg K29;
always @(posedge CLKSEL or negedge RESP) begin
    if (!RESP) begin
        K29 <= 1'b1;
    end else begin
        case({HBK_START, CNTB_TC})   // J, K
            2'b00: K29 <= K29;      // Latch
            2'b01: K29 <= 1'b0;     // Reset
            2'b10: K29 <= 1'b1;     // Set
            2'b11: K29 <= ~K29;     // Toggle
        endcase
    end
end

assign PIN_NHBK = ~K29;

assign R29A = (VCNT[7:0] == ~REG10) & VCNT[8] & J31;

reg nPIN_NVBK;
always @(posedge CLKSEL or negedge RESP) begin
    if (!RESP) begin
        nPIN_NVBK <= 1'b1;
    end else begin
        case({R29A, CNTA_TC})   // J, K
            2'b00: nPIN_NVBK <= nPIN_NVBK;  // Latch
            2'b01: nPIN_NVBK <= 1'b0;       // Reset
            2'b10: nPIN_NVBK <= 1'b1;       // Set
            2'b11: nPIN_NVBK <= ~nPIN_NVBK; // Toggle
        endcase
    end
end

assign PIN_NVBK = ~nPIN_NVBK;

// Delays

// {A61, A38}
reg [7:0] RES_DELAY;
always @(posedge nPIN_NVBK or negedge RESP) begin
    if (!RESP) begin
        RES_DELAY <= 8'd0;
    end else begin
        RES_DELAY <= {RES_DELAY[6:0], RESP};
    end
end

// {S1, R3}
reg [7:0] NHBK_DELAY;
always @(posedge CLKSEL) begin
    NHBK_DELAY <= {NHBK_DELAY[6:0], PIN_NHBK};
end

assign PIN_NHBS = NHBK_DELAY[REG6];

// Misc

assign PIN_NCSY = ~|{nNVSY, nNHSY};
assign J31 = REG7_D7 | HBK_START;
assign PIN_NCBK = ~|{~PIN_NVBK, ~PIN_NHBS};
assign L37 = ~&{nNHSY, M11};
assign G51 = ~&{nNVSY, CNTC_TC};

reg F37, L42;
always @(posedge CLKSEL) begin
    F37 <= ~|{L37 & ~F37, ~RESP, CNTB_TC};
    L42 <= ~|{G51 & ~L42, ~RESP, CNTA_TC};
end
assign G44 = ~REG7_D7 & F37;
assign L38B = J31 & L42;

// This should be a 2-bit counter
reg B14, B3;
assign C4B = ~D35 & REG7[1];
always @(posedge CLKSEL or negedge RESP) begin
    if (!RESP) begin
        {B14, B3} <= 2'd0;
    end else begin
        B3 <= ~^{C4B, ~B3};
        B14 <= ~^{C4B & B3, ~B14};
    end
end

assign PIN_FCNT = REG7[0] ? B14 : B3;

assign PIN_DB_OUT = {VCNT[7:1], PIN_AB[0] ? VCNT[0] : VCNT[8]};

assign PIN_DB_DIR = (PIN_AB[3:1] == 3'd7) & ~PIN_CCS & PIN_RW;  // Unused because of separate IN/OUT bus in this model

endmodule
