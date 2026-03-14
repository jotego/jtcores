module SH7604_CACHE (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	input             EN,
	
	input             RES_N,
	
	input      [31:0] CBUS_A,
	input      [31:0] CBUS_DI,
	output     [31:0] CBUS_DO,
	input             CBUS_WR,
	input       [3:0] CBUS_BA,
	input             CBUS_REQ,
	input             CBUS_ID,
	input             CBUS_TAS,
	output            CBUS_BUSY,
	
	output     [31:0] IBUS_A,
	input      [31:0] IBUS_DI,
	output     [31:0] IBUS_DO,
	output      [3:0] IBUS_BA,
	output            IBUS_WE,
	output            IBUS_REQ,
	output            IBUS_PREREQ,
	output            IBUS_BURST,
	output            IBUS_LOCK,
	input             IBUS_WAIT
);

	import SH7604_PKG::*;
	
	// synopsys translate_off
	`define SIM
	// synopsys translate_on

	CCR_t CCR;
	
	bit  [31:0] IBADDR;
	bit  [31:0] IBDATA;
	bit   [3:0] IBBA;
	bit         IBWE;
	bit         IBREQ;
	bit         IBBURST;
	bit         IBLOCK;
	
	wire CCR_SEL = (CBUS_A == 32'hFFFFFE92);
	
	wire CACHE_AREA      = (CBUS_A[31:29] == 3'b000);
	wire NOCACHE_AREA    = (CBUS_A[31:29] == 3'b001);
	wire PURGE_AREA      = (CBUS_A[31:29] == 3'b010);
	wire CACHE_ADDR_AREA = (CBUS_A[31:29] == 3'b011);
	wire CACHE_DATA_AREA = (CBUS_A[31:29] == 3'b110);
	wire IO_AREA         = (CBUS_A[31:29] == 3'b111) && !CCR_SEL;
	
	
	bit   [3:0] WAY_HIT;
	bit   [3:0] WAY_TAG;
	
	bit  [31:0] CACHE_DATA;
	bit  [28:2] CACHE_WR_ADDR;
	bit   [3:0] CACHE_WR_BA;
	bit   [3:0] CACHE_WR_WAY;
	bit         CACHE_UPDATE;
	bit         CACHE_WRITE;
	bit         CACHE_READ;
	bit         CACHE_LINE_PURGE;
	bit         CACHE_DATA_WRITE;
	bit         CACHE_ADDR_WRITE;
	bit         CACHE_PURGE;
	bit   [5:0] LRU_DATA;
	
	function bit [3:0] WayFromLRU(input bit [5:0] lru, input bit two_way);
		bit [3:0] res;
	
		if (two_way) begin
			res = lru[0] ? 4'b0100 : 4'b1000;
		end else begin
			casez (lru)
				6'b111???: res = 4'b0001;
				6'b0??11?: res = 4'b0010;
				6'b?0?0?1: res = 4'b0100;
				6'b??0?00: res = 4'b1000;
				default:   res = 4'b0001;
			endcase
		end
		return res;
	endfunction
	
	function bit [5:0] LRUSelect(input bit [3:0] way, input bit [5:0] lru);
		bit [5:0] res;

		res = way[3] ? {lru[5],lru[4],1'b1,  lru[2],1'b1,  1'b1  } :
		      way[2] ? {lru[5],1'b1  ,lru[3],1'b1  ,lru[1],1'b0  } :
		      way[1] ? {1'b1  ,lru[4],lru[3],1'b0  ,1'b0  ,lru[0]} :
				way[0] ? {1'b0  ,1'b0  ,1'b0  ,lru[2],lru[1],lru[0]} :
				         {1'b0  ,1'b0  ,1'b0  ,lru[2],lru[1],lru[0]};
		return res;
	endfunction
	
	function bit [1:0] WayToAddr(input bit [3:0] way);
		bit [1:0] res;

		res = way[0] ? 2'b00 :
		      way[1] ? 2'b01 :
		      way[2] ? 2'b10 :
		      way[3] ? 2'b11 : 
				         2'b00;
		return res;
	endfunction
	
	function bit [3:0] AddrToWay(input bit [1:0] a);
		bit [3:0] res;
	
		case (a) 
			2'b00: res = 4'b0001;
			2'b01: res = 4'b0010;
			2'b10: res = 4'b0100;
			2'b11: res = 4'b1000;
		endcase
		return res;
	endfunction
	
	
`ifdef SIM
	`define VBIT 0
	`define TAG 19:1
	
	reg [25:0] WAY0 [64];
	reg [25:0] WAY1 [64];
	reg [25:0] WAY2 [64];
	reg [25:0] WAY3 [64];
	
	reg [7:0] DATA00 [256]; reg [7:0] DATA01 [256]; reg [7:0] DATA02 [256]; reg [7:0] DATA03 [256];
	reg [7:0] DATA10 [256]; reg [7:0] DATA11 [256]; reg [7:0] DATA12 [256]; reg [7:0] DATA13 [256];
	reg [7:0] DATA20 [256]; reg [7:0] DATA21 [256]; reg [7:0] DATA22 [256]; reg [7:0] DATA23 [256];
	reg [7:0] DATA30 [256]; reg [7:0] DATA31 [256]; reg [7:0] DATA32 [256]; reg [7:0] DATA33 [256];
	
	reg [5:0]  LRU [64];
	
	always_comb begin		
		WAY_TAG[0] = WAY0[CBUS_A[9:4]][`TAG] == CBUS_A[28:10];
		WAY_TAG[1] = WAY1[CBUS_A[9:4]][`TAG] == CBUS_A[28:10];
		WAY_TAG[2] = WAY2[CBUS_A[9:4]][`TAG] == CBUS_A[28:10];
		WAY_TAG[3] = WAY3[CBUS_A[9:4]][`TAG] == CBUS_A[28:10];
		
		WAY_HIT[0] = WAY_TAG[0] & WAY0[CBUS_A[9:4]][`VBIT];
		WAY_HIT[1] = WAY_TAG[1] & WAY1[CBUS_A[9:4]][`VBIT];
		WAY_HIT[2] = WAY_TAG[2] & WAY2[CBUS_A[9:4]][`VBIT];
		WAY_HIT[3] = WAY_TAG[3] & WAY3[CBUS_A[9:4]][`VBIT];
		
		CACHE_DATA = '0;
		if (CACHE_DATA_AREA) 
			case (CBUS_A[11:10])
				2'b00: CACHE_DATA = {DATA03[CBUS_A[9:2]],DATA02[CBUS_A[9:2]],DATA01[CBUS_A[9:2]],DATA00[CBUS_A[9:2]]};
				2'b01: CACHE_DATA = {DATA13[CBUS_A[9:2]],DATA12[CBUS_A[9:2]],DATA11[CBUS_A[9:2]],DATA10[CBUS_A[9:2]]};
				2'b10: CACHE_DATA = {DATA23[CBUS_A[9:2]],DATA22[CBUS_A[9:2]],DATA21[CBUS_A[9:2]],DATA20[CBUS_A[9:2]]};
				2'b11: CACHE_DATA = {DATA33[CBUS_A[9:2]],DATA32[CBUS_A[9:2]],DATA31[CBUS_A[9:2]],DATA30[CBUS_A[9:2]]};
			endcase
		else if (CACHE_ADDR_AREA) 
			case (CCR.W)
				2'b00: CACHE_DATA = {3'b000,WAY0[CBUS_A[9:4]][`TAG],LRU[CBUS_A[9:4]],1'b0,WAY0[CBUS_A[9:4]][`VBIT],2'b00};
				2'b01: CACHE_DATA = {3'b000,WAY1[CBUS_A[9:4]][`TAG],LRU[CBUS_A[9:4]],1'b0,WAY1[CBUS_A[9:4]][`VBIT],2'b00};
				2'b10: CACHE_DATA = {3'b000,WAY2[CBUS_A[9:4]][`TAG],LRU[CBUS_A[9:4]],1'b0,WAY2[CBUS_A[9:4]][`VBIT],2'b00};
				2'b11: CACHE_DATA = {3'b000,WAY3[CBUS_A[9:4]][`TAG],LRU[CBUS_A[9:4]],1'b0,WAY3[CBUS_A[9:4]][`VBIT],2'b00};
			endcase
		else
			case (1'b1)
				WAY_HIT[0]: CACHE_DATA = {DATA03[CBUS_A[9:2]],DATA02[CBUS_A[9:2]],DATA01[CBUS_A[9:2]],DATA00[CBUS_A[9:2]]};
				WAY_HIT[1]: CACHE_DATA = {DATA13[CBUS_A[9:2]],DATA12[CBUS_A[9:2]],DATA11[CBUS_A[9:2]],DATA10[CBUS_A[9:2]]};
				WAY_HIT[2]: CACHE_DATA = {DATA23[CBUS_A[9:2]],DATA22[CBUS_A[9:2]],DATA21[CBUS_A[9:2]],DATA20[CBUS_A[9:2]]};
				WAY_HIT[3]: CACHE_DATA = {DATA33[CBUS_A[9:2]],DATA32[CBUS_A[9:2]],DATA31[CBUS_A[9:2]],DATA30[CBUS_A[9:2]]};
			endcase
		
		LRU_DATA = LRU[CBUS_A[9:4]];
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			WAY0 <= '{64{'0}};   WAY1 <= '{64{'0}};   WAY2 <= '{64{'0}};	WAY3 <= '{64{'0}};
			DATA00 <= '{256{'0}};	DATA01 <= '{256{'0}};	DATA02 <= '{256{'0}};	DATA03 <= '{256{'0}};
			DATA10 <= '{256{'0}};	DATA11 <= '{256{'0}};	DATA12 <= '{256{'0}};	DATA13 <= '{256{'0}};
			DATA20 <= '{256{'0}};	DATA21 <= '{256{'0}};	DATA22 <= '{256{'0}};	DATA23 <= '{256{'0}};
			DATA30 <= '{256{'0}};	DATA31 <= '{256{'0}};	DATA32 <= '{256{'0}};	DATA33 <= '{256{'0}};
			LRU <= '{64{'0}};
		end
		else if (CE_R) begin
			if (CACHE_UPDATE) begin
				case (1'b1)
					CACHE_WR_WAY[0]: begin 
						{DATA03[CACHE_WR_ADDR[9:2]],DATA02[CACHE_WR_ADDR[9:2]],DATA01[CACHE_WR_ADDR[9:2]],DATA00[CACHE_WR_ADDR[9:2]]} <= IBUS_DI; 
						WAY0[CACHE_WR_ADDR[9:4]][`TAG] <= CACHE_WR_ADDR[28:10]; 
						WAY0[CACHE_WR_ADDR[9:4]][`VBIT] <= 1; 
					end
					CACHE_WR_WAY[1]: begin 
						{DATA13[CACHE_WR_ADDR[9:2]],DATA12[CACHE_WR_ADDR[9:2]],DATA11[CACHE_WR_ADDR[9:2]],DATA10[CACHE_WR_ADDR[9:2]]} <= IBUS_DI; 
						WAY1[CACHE_WR_ADDR[9:4]][`TAG] <= CACHE_WR_ADDR[28:10]; 
						WAY1[CACHE_WR_ADDR[9:4]][`VBIT] <= 1; 
					end
					CACHE_WR_WAY[2]: begin 
						{DATA23[CACHE_WR_ADDR[9:2]],DATA22[CACHE_WR_ADDR[9:2]],DATA21[CACHE_WR_ADDR[9:2]],DATA20[CACHE_WR_ADDR[9:2]]} <= IBUS_DI; 
						WAY2[CACHE_WR_ADDR[9:4]][`TAG] <= CACHE_WR_ADDR[28:10]; 
						WAY2[CACHE_WR_ADDR[9:4]][`VBIT] <= 1; 
					end
					CACHE_WR_WAY[3]: begin 
						{DATA33[CACHE_WR_ADDR[9:2]],DATA32[CACHE_WR_ADDR[9:2]],DATA31[CACHE_WR_ADDR[9:2]],DATA30[CACHE_WR_ADDR[9:2]]} <= IBUS_DI; 
						WAY3[CACHE_WR_ADDR[9:4]][`TAG] <= CACHE_WR_ADDR[28:10]; 
						WAY3[CACHE_WR_ADDR[9:4]][`VBIT] <= 1; 
					end
				endcase
			end
			else if (CACHE_WRITE) begin
				if (CACHE_WR_BA[0]) begin
					case (1'b1)
						CACHE_WR_WAY[0]: DATA00[CACHE_WR_ADDR[9:2]] <= CBUS_DI[7:0];
						CACHE_WR_WAY[1]: DATA10[CACHE_WR_ADDR[9:2]] <= CBUS_DI[7:0];
						CACHE_WR_WAY[2]: DATA20[CACHE_WR_ADDR[9:2]] <= CBUS_DI[7:0];
						CACHE_WR_WAY[3]: DATA30[CACHE_WR_ADDR[9:2]] <= CBUS_DI[7:0];
					endcase
				end
				if (CACHE_WR_BA[1]) begin
					case (1'b1)
						CACHE_WR_WAY[0]: DATA01[CACHE_WR_ADDR[9:2]] <= CBUS_DI[15:8];
						CACHE_WR_WAY[1]: DATA11[CACHE_WR_ADDR[9:2]] <= CBUS_DI[15:8];
						CACHE_WR_WAY[2]: DATA21[CACHE_WR_ADDR[9:2]] <= CBUS_DI[15:8];
						CACHE_WR_WAY[3]: DATA31[CACHE_WR_ADDR[9:2]] <= CBUS_DI[15:8];
					endcase
				end
				if (CACHE_WR_BA[2]) begin
					case (1'b1)
						CACHE_WR_WAY[0]: DATA02[CACHE_WR_ADDR[9:2]] <= CBUS_DI[23:16];
						CACHE_WR_WAY[1]: DATA12[CACHE_WR_ADDR[9:2]] <= CBUS_DI[23:16];
						CACHE_WR_WAY[2]: DATA22[CACHE_WR_ADDR[9:2]] <= CBUS_DI[23:16];
						CACHE_WR_WAY[3]: DATA32[CACHE_WR_ADDR[9:2]] <= CBUS_DI[23:16];
					endcase
				end
				if (CACHE_WR_BA[3]) begin
					case (1'b1)
						CACHE_WR_WAY[0]: DATA03[CACHE_WR_ADDR[9:2]] <= CBUS_DI[31:24];
						CACHE_WR_WAY[1]: DATA13[CACHE_WR_ADDR[9:2]] <= CBUS_DI[31:24];
						CACHE_WR_WAY[2]: DATA23[CACHE_WR_ADDR[9:2]] <= CBUS_DI[31:24];
						CACHE_WR_WAY[3]: DATA33[CACHE_WR_ADDR[9:2]] <= CBUS_DI[31:24];
					endcase
				end
			end
			else if (CACHE_LINE_PURGE) begin
				case (1'b1)
					CACHE_WR_WAY[0]: WAY0[CACHE_WR_ADDR[9:4]][`VBIT] <= 0;
					CACHE_WR_WAY[1]: WAY1[CACHE_WR_ADDR[9:4]][`VBIT] <= 0;
					CACHE_WR_WAY[2]: WAY2[CACHE_WR_ADDR[9:4]][`VBIT] <= 0;
					CACHE_WR_WAY[3]: WAY3[CACHE_WR_ADDR[9:4]][`VBIT] <= 0;
				endcase
			end
			else if (CACHE_DATA_WRITE) begin
				if (CACHE_WR_BA[0]) begin
					case (CACHE_WR_ADDR[11:10])
						2'b00: DATA00[CACHE_WR_ADDR[9:2]] <= CBUS_DI[7:0];
						2'b01: DATA10[CACHE_WR_ADDR[9:2]] <= CBUS_DI[7:0];
						2'b10: DATA20[CACHE_WR_ADDR[9:2]] <= CBUS_DI[7:0];
						2'b11: DATA30[CACHE_WR_ADDR[9:2]] <= CBUS_DI[7:0];
					endcase
				end
				if (CACHE_WR_BA[1]) begin
					case (CACHE_WR_ADDR[11:10])
						2'b00: DATA01[CACHE_WR_ADDR[9:2]] <= CBUS_DI[15:8];
						2'b01: DATA11[CACHE_WR_ADDR[9:2]] <= CBUS_DI[15:8];
						2'b10: DATA21[CACHE_WR_ADDR[9:2]] <= CBUS_DI[15:8];
						2'b11: DATA31[CACHE_WR_ADDR[9:2]] <= CBUS_DI[15:8];
					endcase
				end
				if (CACHE_WR_BA[2]) begin
					case (CACHE_WR_ADDR[11:10])
						2'b00: DATA02[CACHE_WR_ADDR[9:2]] <= CBUS_DI[23:16];
						2'b01: DATA12[CACHE_WR_ADDR[9:2]] <= CBUS_DI[23:16];
						2'b10: DATA22[CACHE_WR_ADDR[9:2]] <= CBUS_DI[23:16];
						2'b11: DATA32[CACHE_WR_ADDR[9:2]] <= CBUS_DI[23:16];
					endcase
				end
				if (CACHE_WR_BA[3]) begin
					case (CACHE_WR_ADDR[11:10])
						2'b00: DATA03[CACHE_WR_ADDR[9:2]] <= CBUS_DI[31:24];
						2'b01: DATA13[CACHE_WR_ADDR[9:2]] <= CBUS_DI[31:24];
						2'b10: DATA23[CACHE_WR_ADDR[9:2]] <= CBUS_DI[31:24];
						2'b11: DATA33[CACHE_WR_ADDR[9:2]] <= CBUS_DI[31:24];
					endcase
				end
			end
			else if (CACHE_ADDR_WRITE) begin
				case (CCR.W)
					2'b00: begin WAY0[CACHE_WR_ADDR[9:4]][`TAG] <= CACHE_WR_ADDR[28:10]; WAY0[CACHE_WR_ADDR[9:4]][`VBIT] <= CACHE_WR_ADDR[2]; end
					2'b01: begin WAY1[CACHE_WR_ADDR[9:4]][`TAG] <= CACHE_WR_ADDR[28:10]; WAY1[CACHE_WR_ADDR[9:4]][`VBIT] <= CACHE_WR_ADDR[2]; end
					2'b10: begin WAY2[CACHE_WR_ADDR[9:4]][`TAG] <= CACHE_WR_ADDR[28:10]; WAY2[CACHE_WR_ADDR[9:4]][`VBIT] <= CACHE_WR_ADDR[2]; end
					2'b11: begin WAY3[CACHE_WR_ADDR[9:4]][`TAG] <= CACHE_WR_ADDR[28:10]; WAY3[CACHE_WR_ADDR[9:4]][`VBIT] <= CACHE_WR_ADDR[2]; end
				endcase
			end
			else if (CCR.CP) begin
				WAY0 <= '{64{'0}};   
				WAY1 <= '{64{'0}};   
				WAY2 <= '{64{'0}};	
				WAY3 <= '{64{'0}};
				LRU <= '{64{'0}};
			end
			
			if (CACHE_UPDATE || CACHE_WRITE || CACHE_READ) begin
				LRU[CACHE_WR_ADDR[9:4]] <= LRUSelect(CACHE_WR_WAY, LRU[CACHE_WR_ADDR[9:4]]); 
			end
			else if (CACHE_ADDR_WRITE) begin
				LRU[CACHE_WR_ADDR[9:4]] <= CBUS_DI[9:4];
			end
		end
	end
	
`else
	`define VBIT 0
	`define TAG  19:1
	
	wire  [1:0] CRAM_WRWAY = CACHE_DATA_WRITE ? CACHE_WR_ADDR[11:10] : WayToAddr(CACHE_WR_WAY);
	wire  [9:0] CRAM_WRADDR = {CRAM_WRWAY,CACHE_WR_ADDR[9:2]};
	wire [31:0] CRAM_D = CACHE_UPDATE ? IBUS_DI : CBUS_DI;
	wire  [3:0] CRAM_WE = {4{CACHE_UPDATE}} | (CACHE_WR_BA & {4{CACHE_WRITE | CACHE_DATA_WRITE}});
	
	wire  [1:0] CRAM_RDWAY = CACHE_DATA_AREA ? CBUS_A[11:10] : CACHE_ADDR_AREA ? CCR.W : WayToAddr(WAY_HIT);
	wire  [9:0] CRAM_RDADDR = {CRAM_RDWAY,CBUS_A[9:2]};
	
	bit  [31:0] CRAM_Q;
	CACHE_RAM ram0(.wrclock(CLK), .wraddress(CRAM_WRADDR), .data(CRAM_D[ 7: 0]), .wren(CRAM_WE[0] & EN & CE_R), .rdclock(CLK), .rdaddress(CRAM_RDADDR), .q(CRAM_Q[ 7: 0]));
	CACHE_RAM ram1(.wrclock(CLK), .wraddress(CRAM_WRADDR), .data(CRAM_D[15: 8]), .wren(CRAM_WE[1] & EN & CE_R), .rdclock(CLK), .rdaddress(CRAM_RDADDR), .q(CRAM_Q[15: 8]));
	CACHE_RAM ram2(.wrclock(CLK), .wraddress(CRAM_WRADDR), .data(CRAM_D[23:16]), .wren(CRAM_WE[2] & EN & CE_R), .rdclock(CLK), .rdaddress(CRAM_RDADDR), .q(CRAM_Q[23:16]));
	CACHE_RAM ram3(.wrclock(CLK), .wraddress(CRAM_WRADDR), .data(CRAM_D[31:24]), .wren(CRAM_WE[3] & EN & CE_R), .rdclock(CLK), .rdaddress(CRAM_RDADDR), .q(CRAM_Q[31:24]));
	
	
	wire [19:0] CTAG_D = CACHE_UPDATE ? {CACHE_WR_ADDR[28:10],1'b1} : CACHE_ADDR_WRITE ? {CACHE_WR_ADDR[28:10],CACHE_WR_ADDR[2]} : '0;
	wire  [3:0] CTAG_WE = ({4{CACHE_UPDATE | CACHE_LINE_PURGE}} & CACHE_WR_WAY) | ({4{CACHE_ADDR_WRITE}} & AddrToWay(CCR.W));
	
	bit  [19:0] CTAG0_Q;
	bit  [19:0] CTAG1_Q;
	bit  [19:0] CTAG2_Q;
	bit  [19:0] CTAG3_Q;
	CACHE_TAG tag0(.clock(CLK), .wraddress(CACHE_WR_ADDR[9:4]), .data(CTAG_D), .wren(CTAG_WE[0] & EN & CE_R), .rdaddress(CBUS_A[9:4]), .q(CTAG0_Q));
	CACHE_TAG tag1(.clock(CLK), .wraddress(CACHE_WR_ADDR[9:4]), .data(CTAG_D), .wren(CTAG_WE[1] & EN & CE_R), .rdaddress(CBUS_A[9:4]), .q(CTAG1_Q));
	CACHE_TAG tag2(.clock(CLK), .wraddress(CACHE_WR_ADDR[9:4]), .data(CTAG_D), .wren(CTAG_WE[2] & EN & CE_R), .rdaddress(CBUS_A[9:4]), .q(CTAG2_Q));
	CACHE_TAG tag3(.clock(CLK), .wraddress(CACHE_WR_ADDR[9:4]), .data(CTAG_D), .wren(CTAG_WE[3] & EN & CE_R), .rdaddress(CBUS_A[9:4]), .q(CTAG3_Q));
	
	reg [63:0] TAG_DIRTY[4];
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			TAG_DIRTY <= '{'1,'1,'1,'1};
		end
		else if (EN && CE_R) begin
			if (CTAG_WE[0]) TAG_DIRTY[0][CACHE_WR_ADDR[9:4]] <= CACHE_LINE_PURGE;
			if (CTAG_WE[1]) TAG_DIRTY[1][CACHE_WR_ADDR[9:4]] <= CACHE_LINE_PURGE;
			if (CTAG_WE[2]) TAG_DIRTY[2][CACHE_WR_ADDR[9:4]] <= CACHE_LINE_PURGE;
			if (CTAG_WE[3]) TAG_DIRTY[3][CACHE_WR_ADDR[9:4]] <= CACHE_LINE_PURGE;
		end
		else if (CCR.CP) begin
			TAG_DIRTY <= '{'1,'1,'1,'1};
		end
	end
	
	always_comb begin	
		bit [3:0] DIRTY;
		
		DIRTY[0] = TAG_DIRTY[0][CBUS_A[9:4]];
		DIRTY[1] = TAG_DIRTY[1][CBUS_A[9:4]];
		DIRTY[2] = TAG_DIRTY[2][CBUS_A[9:4]];
		DIRTY[3] = TAG_DIRTY[3][CBUS_A[9:4]];
	
		WAY_TAG[0] = CTAG0_Q[`TAG] == CBUS_A[28:10];
		WAY_TAG[1] = CTAG1_Q[`TAG] == CBUS_A[28:10];
		WAY_TAG[2] = CTAG2_Q[`TAG] == CBUS_A[28:10];
		WAY_TAG[3] = CTAG3_Q[`TAG] == CBUS_A[28:10];
		
		WAY_HIT[0] = WAY_TAG[0] & CTAG0_Q[`VBIT] & ~DIRTY[0];
		WAY_HIT[1] = WAY_TAG[1] & CTAG1_Q[`VBIT] & ~DIRTY[1];
		WAY_HIT[2] = WAY_TAG[2] & CTAG2_Q[`VBIT] & ~DIRTY[2];
		WAY_HIT[3] = WAY_TAG[3] & CTAG3_Q[`VBIT] & ~DIRTY[3];
		
		if (CACHE_ADDR_AREA) 
			case (CCR.W)
				2'b00: CACHE_DATA = {3'b000,CTAG0_Q[`TAG],LRU_B_Q,1'b0,CTAG0_Q[`VBIT],2'b00};
				2'b01: CACHE_DATA = {3'b000,CTAG1_Q[`TAG],LRU_B_Q,1'b0,CTAG1_Q[`VBIT],2'b00};
				2'b10: CACHE_DATA = {3'b000,CTAG2_Q[`TAG],LRU_B_Q,1'b0,CTAG2_Q[`VBIT],2'b00};
				2'b11: CACHE_DATA = {3'b000,CTAG3_Q[`TAG],LRU_B_Q,1'b0,CTAG3_Q[`VBIT],2'b00};
			endcase
		else
			CACHE_DATA = CRAM_Q;
	end
	
	reg [63:0] LRU_DIRTY;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			LRU_DIRTY <= '1;
		end
		else if (EN && CE_R) begin
			if (LRU_WE) LRU_DIRTY[LRU_WRADDR] <= 0;
		end
		else if (CCR.CP) begin
			LRU_DIRTY <= '1;
		end
	end
	
	wire  [5:0] LRU_WRADDR = CACHE_WR_ADDR[9:4];
	wire  [5:0] LRU_A_RDADDR = CACHE_WR_ADDR[9:4];
	wire  [5:0] LRU_B_RDADDR = CBUS_A[9:4];
	wire  [5:0] LRU_D = CACHE_ADDR_WRITE ? CBUS_DI[9:4] : LRUSelect(CACHE_WR_WAY, LRU_A_Q & {6{~LRU_DIRTY[LRU_A_RDADDR]}});
	wire        LRU_WE = CACHE_UPDATE | CACHE_WRITE | CACHE_READ | CACHE_ADDR_WRITE;
	
	bit  [5:0] LRU_A_Q,LRU_B_Q;
	CACHE_LRU lru_a(.clock(CLK), .wraddress(LRU_WRADDR), .data(LRU_D), .wren(LRU_WE & EN & CE_R), .rdaddress(LRU_A_RDADDR), .q(LRU_A_Q));
	CACHE_LRU lru_b(.clock(CLK), .wraddress(LRU_WRADDR), .data(LRU_D), .wren(LRU_WE & EN & CE_R), .rdaddress(LRU_B_RDADDR), .q(LRU_B_Q));
	
	always_comb begin	
		bit       DIRTY;

		DIRTY = LRU_DIRTY[LRU_B_RDADDR];
		
		LRU_DATA = LRU_B_Q & {6{~DIRTY}};
	end
	
	
`endif
	
	
	wire HIT = WAY_HIT[0] | WAY_HIT[1] | WAY_HIT[2] | WAY_HIT[3];
	
	bit         IBDATA_RDY;
	bit         IBUS_WRITE;
	bit         IBUS_WRITE_PEND;
	bit         IBUS_READ;
	bit         IBUS_READ_PEND;
	bit         IBUS_READARRAY;
	always @(posedge CLK or negedge RST_N) begin
		bit [ 1: 0] ARRAY_POS;
		bit         IBUS_END;
		
		if (!RST_N) begin
			IBADDR <= '0;
			IBDATA <= '0;
			IBBA <= '0;
			IBWE <= '0;
			IBREQ <= 0;
			IBBURST <= 0;
			IBLOCK <= 0;
			ARRAY_POS <= '0;
			CACHE_WR_ADDR <= '0;
			CACHE_WR_BA <= '0;
			CACHE_WR_WAY <= 0;
			CACHE_UPDATE <= 0;
			CACHE_WRITE <= 0;
			CACHE_READ <= 0;
			CACHE_LINE_PURGE <= 0;
			CACHE_DATA_WRITE <= 0;
			CACHE_ADDR_WRITE <= 0;
			
			IBDATA_RDY <= 0;
			IBUS_WRITE <= 0;
			IBUS_WRITE_PEND <= 0;
			IBUS_READ <= 0;
			IBUS_READARRAY <= 0;
			IBUS_READ_PEND <= 0;
		end
		else if (EN && CE_R) begin
			if (!RES_N) begin
				IBUS_WRITE_PEND <= 0;
			end
		end
		else if (EN && CE_F) begin
			CACHE_UPDATE <= 0;
			CACHE_WRITE <= 0;
			CACHE_READ <= 0;
			CACHE_LINE_PURGE <= 0;
			CACHE_DATA_WRITE <= 0;
			CACHE_ADDR_WRITE <= 0;
			
			IBDATA_RDY <= 0;
			if (!IBUS_WAIT) begin
				if (IBUS_WRITE) begin
					IBREQ <= 0;
					IBUS_WRITE <= 0;
				end
				else if (IBUS_READ) begin
					IBREQ <= 0;
					IBDATA_RDY <= 1;
					IBUS_READ <= 0;
				end
				else if (IBUS_READARRAY) begin
					IBADDR <= {IBADDR[31:4],IBADDR[3:2] + 2'd1,2'b00};
					if (IBADDR[3:2] == ARRAY_POS) begin
						IBREQ <= 0;
						IBDATA_RDY <= 1;
						IBUS_READARRAY <= 0;
					end
					if (IBADDR[3:2] == ARRAY_POS - 2'd1) begin
						IBLOCK <= 0;
					end
					CACHE_WR_ADDR <= IBADDR[28:2];
					CACHE_WR_BA <= 4'b1111;
					CACHE_UPDATE <= CBUS_ID ? ~CCR.ID : ~CCR.OD;
				end
			end
			IBUS_END = 0;//(IBREQ && IBUS_WRITE && !IBUS_WAIT);
			
			if (CBUS_REQ) begin
				if (CBUS_WR) begin
					if ((CACHE_AREA || NOCACHE_AREA || IO_AREA)) begin
						if (!IBREQ || IBUS_END) begin
							IBADDR <= CBUS_A;
							IBDATA <= CBUS_DI;
							IBBA <= CBUS_BA;
							IBWE <= 1;
							IBREQ <= 1;
							IBBURST <= 0;
							IBLOCK <= 0;
							IBUS_WRITE <= 1;
							IBUS_WRITE_PEND <= 0;
						end else if (!IBUS_WRITE_PEND) begin
							IBUS_WRITE_PEND <= 1;
						end
					end
					
					if (CACHE_AREA && HIT && CCR.CE && (!IBREQ || IBUS_END)) begin
						CACHE_WR_ADDR <= CBUS_A[28:2];
						CACHE_WR_BA <= CBUS_BA;
						CACHE_WR_WAY <= WAY_HIT;
						CACHE_WRITE <= 1;
					end
					else if (PURGE_AREA) begin
						CACHE_WR_ADDR <= CBUS_A[28:2];
						CACHE_WR_BA <= 4'b1111;
						CACHE_WR_WAY <= WAY_TAG;
						CACHE_LINE_PURGE <= 1;
					end
					else if (CACHE_DATA_AREA) begin
						CACHE_WR_ADDR <= CBUS_A[28:2];
						CACHE_WR_BA <= CBUS_BA;
						CACHE_DATA_WRITE <= 1;
					end
					else if (CACHE_ADDR_AREA) begin
						CACHE_WR_ADDR <= CBUS_A[28:2];
						CACHE_WR_BA <= 4'b1111;
						CACHE_ADDR_WRITE <= 1;
					end
				end
				else begin
					if (((CACHE_AREA && (!CCR.CE || CBUS_TAS)) || NOCACHE_AREA || IO_AREA) && !IBUS_READ) begin
						if (!IBREQ || IBUS_END) begin
							IBADDR <= CBUS_A;
							IBBA <= CBUS_BA;
							IBWE <= 0;
							IBREQ <= 1;
							IBBURST <= 0;
							IBLOCK <= CBUS_TAS;
							IBUS_READ <= 1;
							IBUS_READ_PEND <= 0;
						end else if (!IBUS_READ_PEND) begin
							IBUS_READ_PEND <= 1;
						end
					end
					else if (CACHE_AREA && CCR.CE && !CBUS_TAS && !IBUS_READARRAY) begin
						if (HIT) begin
							CACHE_WR_ADDR <= CBUS_A[28:2];
							CACHE_WR_WAY <= WAY_HIT;
							CACHE_READ <= 1;
						end
						else begin
							if (!IBREQ || IBUS_END) begin
								IBADDR <= {CBUS_A[31:4],CBUS_A[3:2] + 2'd1,2'b00};
								IBBA <= 4'b1111;
								IBWE <= 0;
								IBREQ <= 1;
								IBBURST <= 1;
								IBLOCK <= 0;
								ARRAY_POS <= CBUS_A[3:2];
								CACHE_WR_WAY <= WayFromLRU(LRU_DATA, CCR.TW);
								IBUS_READARRAY <= 1;
								IBUS_READ_PEND <= 0;
							end else if (!IBUS_READ_PEND) begin
								IBUS_READ_PEND <= 1;
							end
						end
					end
				end
			end
			
		end
	end
	
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			CCR <= '0;
			// synopsys translate_off
			CCR <= 8'h00;
			// synopsys translate_on
		end
		else if (!RES_N) begin
			CCR <= CCR_INIT;
		end
		else if (CE_R) begin
			if (CCR_SEL && CBUS_WR && CBUS_REQ) begin
				CCR <= CBUS_DI[7:0] & CCR_WMASK;
			end
			if (CCR.CP) CCR.CP <= 0;
		end
	end
	
	assign CBUS_DO = CCR_SEL ? {4{CCR & CCR_RMASK}} : 
	                 IBDATA_RDY ? IBUS_DI : 
						  CACHE_DATA;
	assign CBUS_BUSY = CBUS_REQ && (IBUS_READ || IBUS_READARRAY || IBUS_READ_PEND || IBUS_WRITE_PEND);
						  
	assign IBUS_A = IBADDR;
	assign IBUS_DO = IBDATA;
	assign IBUS_BA = IBBA;
	assign IBUS_WE = IBWE;
	assign IBUS_REQ = IBREQ;
	assign IBUS_PREREQ = CBUS_REQ && ((!CBUS_WR && ((CACHE_AREA && (!CCR.CE)) || (NOCACHE_AREA && !CBUS_TAS))) || (!CBUS_WR && CACHE_AREA && CCR.CE && !HIT)) && !IBREQ;
	assign IBUS_BURST = IBBURST; 
	assign IBUS_LOCK = IBLOCK;

endmodule
