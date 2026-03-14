module SH2_regfile (
	input             CLK,
	input             RST_N,
	input             CE,
	input             EN,
	
	input       [4:0] WA_ADDR,
	input      [31:0] WA_D,
	input             WAE,
	input       [4:0] WB_ADDR,
	input      [31:0] WB_D,
	input             WBE,
	
	input       [4:0] RA_ADDR,
	output     [31:0] RA_Q,
	input       [4:0] RB_ADDR,
	output     [31:0] RB_Q,
	output     [31:0] R0_Q

`ifdef DEBUG
	                  ,
	output     [31:0] R0,
	output     [31:0] R1,
	output     [31:0] R2,
	output     [31:0] R3,
	output     [31:0] R4,
	output     [31:0] R5,
	output     [31:0] R6,
	output     [31:0] R7,
	output     [31:0] R8,
	output     [31:0] R9,
	output     [31:0] R10,
	output     [31:0] R11,
	output     [31:0] R12,
	output     [31:0] R13,
	output     [31:0] R14,
	output     [31:0] R15,
	output     [31:0] PR_
`endif
);
	
	// synopsys translate_off
	`define SIM
	// synopsys translate_on
	
`ifdef SIM

	reg [31:0]  GR[16+1];
	
	bit  [4:0] WB_ADDR_LATCH;
	bit [31:0] WB_D_LATCH;
	bit        WBE_LATCH;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			WB_ADDR_LATCH <= '0;
			WB_D_LATCH <= '0;
			WBE_LATCH <= 0;
		end
		else begin
			WBE_LATCH <= 0;
			if (CE) begin
				WB_ADDR_LATCH <= WB_ADDR;
				WB_D_LATCH <= WB_D;
				WBE_LATCH <= WBE;
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			GR <= '{'h01234567,'h11111111,'h89ABCDEF,'h11111111,'0,'0,'0,'0,'0,'0,'0,'0,'0,'0,'0,'0,'0};
		end
		else if (EN) begin
			if (WAE && CE) begin
				GR[WA_ADDR] <= WA_D;
			end
			if (WBE_SAVE) begin
				GR[WB_ADDR_LATCH] <= WB_D_LATCH;
			end
		end
	end

	assign RA_Q = GR[RA_ADDR];
	assign RB_Q = GR[RB_ADDR];
	
	reg [31:0] GR0;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			GR0 <= '0;
		end
		else if (EN) begin
			if (WAE && !WA_ADDR && CE) begin
				GR0 <= WA_D;
			end
			if (WBE_LATCH && !WB_ADDR_LATCH) begin
				GR0 <= WB_D_LATCH;
			end
		end
	end
	
	assign R0_Q = GR0;
	
`else
	
	bit  [4:0] WB_ADDR_LATCH;
	bit [31:0] WB_D_LATCH;
	bit        WBE_LATCH;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			WB_ADDR_LATCH <= '0;
			WB_D_LATCH <= '0;
			WBE_LATCH <= 0;
		end
		else begin
			WBE_LATCH <= 0;
			if (CE) begin
				WB_ADDR_LATCH <= WB_ADDR;
				WB_D_LATCH <= WB_D;
				WBE_LATCH <= WBE;
			end
		end
	end
	
	wire  [4:0] W_ADDR = CE ? WA_ADDR : WB_ADDR_LATCH;
	wire [31:0] REG_D = CE ? WA_D : WB_D_LATCH;
	wire        REG_WE = (WAE & ~WA_ADDR[4] & CE) | (WBE_LATCH & ~WB_ADDR_LATCH[4]);
	bit  [31:0] RAMA_Q, RAMB_Q;
	SH_regram regramA(.clock(CLK), .wraddress(W_ADDR[3:0]), .data(REG_D), .wren(REG_WE & EN), .rdaddress(RA_ADDR[3:0]), .q(RAMA_Q));
	SH_regram regramB(.clock(CLK), .wraddress(W_ADDR[3:0]), .data(REG_D), .wren(REG_WE & EN), .rdaddress(RB_ADDR[3:0]), .q(RAMB_Q));
	
	bit  [31:0] PR;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			PR <= '0;
		end
		else if (EN) begin
			if (WAE && WA_ADDR[4] && CE) begin
				PR <= WA_D;
			end
			if (WBE_LATCH && WB_ADDR_LATCH[4]) begin
				PR <= WB_D_LATCH;
			end
		end
	end
	assign RA_Q = RA_ADDR[4] ? PR : RAMA_Q;
	assign RB_Q = RB_ADDR[4] ? PR : RAMB_Q;
	
	bit  [31:0] GR0;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			GR0 <= '0;
		end
		else if (EN) begin
			if (WAE && !WA_ADDR && CE) begin
				GR0 <= WA_D;
			end
			if (WBE_LATCH && !WB_ADDR_LATCH) begin
				GR0 <= WB_D_LATCH;
			end
		end
	end
	assign R0_Q = GR0;
`endif

`ifdef DEBUG
	reg [31:0] DBG_GR[17];
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DBG_GR <= '{17{'0}};
		end
		else if (EN) begin
			if (WAE && CE) begin
				DBG_GR[WA_ADDR] <= WA_D;
			end
			if (WBE_LATCH) begin
				DBG_GR[WB_ADDR_LATCH] <= WB_D_LATCH;
			end
		end
	end
	
	assign R0 = DBG_GR[0];
	assign R1 = DBG_GR[1];
	assign R2 = DBG_GR[2];
	assign R3 = DBG_GR[3];
	assign R4 = DBG_GR[4];
	assign R5 = DBG_GR[5];
	assign R6 = DBG_GR[6];
	assign R7 = DBG_GR[7];
	assign R8 = DBG_GR[8];
	assign R9 = DBG_GR[9];
	assign R10 = DBG_GR[10];
	assign R11 = DBG_GR[11];
	assign R12 = DBG_GR[12];
	assign R13 = DBG_GR[13];
	assign R14 = DBG_GR[14];
	assign R15 = DBG_GR[15];
	assign PR_ = DBG_GR[16];
`endif
	
endmodule
