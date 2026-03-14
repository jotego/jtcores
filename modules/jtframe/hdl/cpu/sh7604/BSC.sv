module SH7604_BSC 
#(parameter bit [3:0] AREA_TIMIMG='0, //area [3..0]; 0-original,1-wait (for low latency memory)
            bit SIZE_BYTE_DISABLE=0, bit SIZE_WORD_DISABLE=0)
(
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	input             EN,
	
	input             RES_N,
	
	input             CLK4_CE,
	input             CLK16_CE,
	input             CLK64_CE,
	input             CLK256_CE,
	input             CLK1024_CE,
	input             CLK2048_CE,
	input             CLK4096_CE,
	
	output reg [26:0] A,
	input      [31:0] DI,
	output reg [31:0] DO,
	output reg        BS_N,
	output reg        CS0_N,
	output reg        CS1_N,
	output reg        CS2_N,
	output reg        CS3_N,
	output reg        RD_WR_N,
	output reg        CE_N,		//RAS_N
	output reg        OE_N,		//CAS_N
	output reg  [3:0] WE_N,		//CASxx_N, DQMxx
	output reg        RD_N,
	input             WAIT_N,
	input             BRLS_N,	//BACK_N
	output            BGR_N,	//BREQ_N
	output reg        IVECF_N,
	output reg        RFS,
	input       [5:0] MD,
	
	input      [31:0] CBUS_A,
	input      [31:0] CBUS_DI,
	output     [31:0] CBUS_DO,
	input       [3:0] CBUS_BA,
	input             CBUS_WE,
	input             CBUS_REQ,
	input             CBUS_PREREQ,
	input             CBUS_BURST,
	input             CBUS_LOCK,
	output            CBUS_BUSY,
	output            CBUS_ACT,
	
	input      [31:0] DBUS_A,
	input      [31:0] DBUS_DI,
	output     [31:0] DBUS_DO,
	input       [3:0] DBUS_BA,
	input             DBUS_WE,
	input             DBUS_REQ,
	input             DBUS_BURST,
	input             DBUS_LOCK,
	output            DBUS_BUSY,
	
	input       [3:0] VBUS_A,
	output      [7:0] VBUS_DO,
	input             VBUS_REQ,
	output            VBUS_BUSY,
	
	output            IRQ,
	
	output reg        CACK,
	output            BUS_RLS,
	
	input             FAST
	
);

	import SH7604_PKG::*;

	BCR1_t      BCR1;
	BCR2_t      BCR2;
	WCR_t       WCR;
	MCR_t       MCR;
	RTCSR_t     RTCSR;
	RTCNT_t     RTCNT;
	RTCOR_t     RTCOR;
	
	function bit [1:0] GetAreaW(input bit [1:0] area, input WCR_t WCR);
		bit [1:0] res;
	
		case (area)
			2'd0: res = WCR.W0;
			2'd1: res = WCR.W1;
			2'd2: res = WCR.W2;
			2'd3: res = WCR.W3;
		endcase
		return res;
	endfunction
	
	function bit [1:0] GetAreaIW(input bit [1:0] area, input WCR_t WCR);
		bit [1:0] res;
	
		case (area)
			2'd0: res = WCR.IW0;
			2'd1: res = WCR.IW1;
			2'd2: res = WCR.IW2;
			2'd3: res = WCR.IW3;
		endcase
		return res;
	endfunction
	
	function bit [1:0] GetAreaLW(input bit [1:0] area, input BCR1_t BCR1);
		bit [1:0] res;
	
		case (area)
			2'd0: res = BCR1.A0LW;
			2'd1: res = BCR1.A1LW;
			2'd2: res = BCR1.AHLW;
			2'd3: res = BCR1.AHLW;
		endcase
		return res;
	endfunction
	
	function bit [1:0] GetAreaSZ(input bit [1:0] area, input BCR1_t BCR1, input BCR2_t BCR2, input bit [1:0] a0sz, input bit [1:0] dramsz);
		bit [1:0] res;
	
		case (area)
			2'd0: res = a0sz;
			2'd1: res = BCR2.A1SZ;
			2'd2: res = BCR1.DRAM[2]    ? dramsz : BCR2.A2SZ;
			2'd3: res = ^BCR1.DRAM[1:0] ? dramsz : BCR2.A3SZ;
		endcase
		return res;
	endfunction	
	
	function bit IsSDRAMArea(input bit [1:0] area, input BCR1_t BCR1);
		bit       res;
	
		case (area)
			2'd0: res = 0;
			2'd1: res = 0;
			2'd2: res = BCR1.DRAM[2];
			2'd3: res = ~BCR1.DRAM[1] & BCR1.DRAM[0];
		endcase
		return res;
	endfunction 
	
	function bit [3:0] SDRAMAreaSel(input BCR1_t BCR1);
		return {~BCR1.DRAM[1] & BCR1.DRAM[0],BCR1.DRAM[2],2'b00};
	endfunction 
	
	function bit [3:0] SDRAMBank(input bit [26:0] A, input MCR_t MCR);
		bit       res;
	
		case ({MCR.SZ,MCR.AMX2,MCR.AMX})
			4'b1000: res = A[21];
			4'b1001: res = A[22];
			4'b1010: res = A[23];
			4'b1011: res = A[19];
			4'b1111: res = A[18];
			4'b0000: res = A[20];
			4'b0011: res = A[18];
			4'b0111: res = A[17];
			default: res = 0;
		endcase
		return res;
	endfunction 
	
	
	bit         BREQ;
	wire        BACK = ~BRLS_N;
	bit         BGR;
	wire        BRLS = ~BRLS_N;
	
	wire        MASTER = ~MD[5];
	wire [1:0]  A0_SZ = MD[4:3] + 2'b01;
	wire [1:0]  DRAM_SZ = {1'b1,MCR.SZ};
	
	typedef enum bit[3:0] {
		T0,  
		T1,T2,TW,								//ordinary,SRAM
		TRAS,TWCAS,TRCAS,TRD,TWNOP,TRFS1,TRFS2,//SDRAM
		TV1,TV2									//vector fetch
	} BusState_t;
	BusState_t BUS_STATE;
	
	bit        RFS_REQ;
	
	wire CBUS_PER_REQ = (CBUS_A[31:16] == 16'hFFFF) && CBUS_REQ; 
	wire CBUS_EXT_REQ = (CBUS_A[31:27] ==? 5'b00?00) && CBUS_REQ; 
	wire BUS_SEL = CBUS_EXT_REQ | DBUS_REQ | VBUS_REQ | RFS_REQ; 
	
	bit          BUSY;
	bit          CBUSY,CBUSY2,DBUSY,VBUSY;
	bit          CBUS_ACTIVE,DBUS_ACTIVE,VBUS_ACTIVE,REFRESH_ACTIVE;
	bit  [31: 0] DAT_BUF;
	bit  [ 7: 0] VEC_BUF;
	bit  [ 1: 0] RFS_WAIT_CNT;
	always @(posedge CLK or negedge RST_N) begin
		BusState_t  STATE_NEXT;
		bit         DBUS_SKIP;
		bit         CBUS_LOCK_INT,DBUS_LOCK_INT;
		bit [ 1: 0] CBUS_REQ_CNT;
		bit [ 2: 0] WAIT_CNT;
		bit [ 1: 0] RCD_WAIT_CNT;
		bit [ 1: 0] NOP_WAIT_CNT;
		bit [31: 0] BUS_DI_LATCH;
		bit         BUS_WE_LATCH;
		bit [ 3: 0] NEXT_BA;
		bit [ 1: 0] AREA_SZ;
		bit         LL;
		bit         CBUS_IS_SDRAM,DBUS_IS_SDRAM,BUS_IS_SDRAM,IS_SAME_BANK_SDRAM;
		bit [ 3: 0] SDRAM_AREA;
		bit [ 2: 0] BURST_CNT;
		bit         BURST_EN,BURST_SINGLE;
		bit         BURST_LAST,BURST_PRELAST;
		bit         SDRAM_PRECHARGE_PEND,SDRAM_INSERT_NOP,INSERT_WAIT;
		bit         DATA_LATCH;
		bit         DELAYED_RFS_REQ;
		
		if (!RST_N) begin
			CS0_N <= 1;
			CS1_N <= 1;
			CS2_N <= 1;
			CS3_N <= 1;
			BS_N <= 1;
			RD_WR_N <= 1;
			RD_N <= 1;
			WE_N <= 4'b1111;
			IVECF_N <= 1;
			CACK <= 0;
			BUSY <= 0;
			{CBUSY,CBUSY2,DBUSY,VBUSY} <= '0;
			{CBUS_ACTIVE,DBUS_ACTIVE,VBUS_ACTIVE,REFRESH_ACTIVE} <= '0;
			CBUS_REQ_CNT <= '0;
			BUS_STATE <= T0;
			WAIT_CNT <= '0;
			NEXT_BA <= '0;
		end
		else begin
			LL = AREA_TIMIMG[A[26:25]];
			AREA_SZ = GetAreaSZ(A[26:25],BCR1,BCR2,A0_SZ,DRAM_SZ);
			BURST_LAST = (BURST_CNT == {2'b11,~AREA_SZ[0]});
			BURST_PRELAST = (BURST_CNT == {1'b1,~AREA_SZ[0],1'b0});
						
			DATA_LATCH = 0;
			STATE_NEXT = BUS_STATE;
			case (BUS_STATE)
				T0: begin
				end
				
				T1: begin
					if (CE_R) begin
						BS_N <= 1;
						case (GetAreaW(A[26:25],WCR))
							2'b00: begin
								if (!NEXT_BA) begin
									if (CBUS_ACTIVE && !BUS_WE_LATCH) CBUSY <= 0;
									if (DBUS_ACTIVE && !BUS_WE_LATCH) DBUSY <= 0;
									BUSY <= 0;
								end
								STATE_NEXT = T2;
							end
							2'b01: begin
								WAIT_CNT <= 3'd0;
								STATE_NEXT = TW;
							end
							2'b10: begin
								WAIT_CNT <= 3'd1;
								STATE_NEXT = TW;
							end
							2'b11: begin
								case (GetAreaLW(A[26:25],BCR1))
									2'b00: WAIT_CNT <= 3'd2;
									2'b01: WAIT_CNT <= 3'd3;
									2'b10: WAIT_CNT <= 3'd4;
									2'b11: WAIT_CNT <= 3'd5;
								endcase
								STATE_NEXT = TW;
							end
						endcase
					end
				end
				
				TW: begin
					if (CE_R) begin
						if (WAIT_CNT && !FAST) begin
							WAIT_CNT <= WAIT_CNT - 3'd1;
						end
						else if (WAIT_N) begin
							if (!NEXT_BA) begin
								if (CBUS_ACTIVE && !BUS_WE_LATCH) CBUSY <= 0;
								if (DBUS_ACTIVE && !BUS_WE_LATCH) DBUSY <= 0;
								BUSY <= 0;
							end
							STATE_NEXT = T2;
						end
					end
				end
				
				T2: begin
					if (CE_F) begin
						DATA_LATCH = 1;
						CS0_N <= 1;
						CS1_N <= 1;
						CS2_N <= 1;
						CS3_N <= 1;
						RD_N <= 1;
						WE_N <= 4'b1111;
						CACK <= 0;
					end
					else if (CE_R) begin
						case (AREA_SZ)
							2'b10: BURST_CNT <= BURST_CNT + 3'd1;
							2'b11: BURST_CNT <= BURST_CNT + 3'd2;
							default:;
						endcase
						if (BURST_LAST) begin
							BURST_EN <= 0;
						end
						STATE_NEXT = T1;
						if (!NEXT_BA) begin
							if (BURST_EN && !BURST_LAST) begin
								CBUSY <= 1;
							end
							if (!BURST_EN || BURST_LAST) begin
								STATE_NEXT = T0;
							end
							RD_WR_N <= 1;
						end
						SDRAM_PRECHARGE_PEND <= 0;
					end
				end
				
				TRAS: begin
					if (CE_R) begin
						BS_N <= 1;
						if (BUS_WE_LATCH) begin
							if (WAIT_N || !LL) begin
								if (!NEXT_BA) begin
									BUSY <= 0;
								end
								NOP_WAIT_CNT <= 2'd1;
								STATE_NEXT = TWCAS;
							end
						end else begin
							STATE_NEXT = TRCAS;
						end
					end
				end
				
				TWCAS: begin
					if (CE_F) begin
						WE_N <= 4'b1111;
						CACK <= 0;
					end
					if (CE_R) begin
						if (!NEXT_BA) begin
							CS0_N <= 1;
							CS1_N <= 1;
							CS2_N <= 1;
							CS3_N <= 1;
							RD_WR_N <= 1;
						end
						SDRAM_PRECHARGE_PEND <= 0;
						STATE_NEXT = TWNOP;
					end
				end
				
				TWNOP: begin
					if (CE_R) begin
						if (NOP_WAIT_CNT) begin
							NOP_WAIT_CNT <= NOP_WAIT_CNT - 2'd1;
						end else begin
							STATE_NEXT = T0;
						end
					end
				end
				
				TRCAS: begin
					if (CE_R) begin
						if (RCD_WAIT_CNT && !FAST) begin
							RCD_WAIT_CNT <= RCD_WAIT_CNT - 2'd1;
						end
						else if (WAIT_N || !LL) begin
							if (!NEXT_BA) begin
								if (CBUS_ACTIVE && !BURST_SINGLE) CBUSY <= 0;
								if (DBUS_ACTIVE && !BURST_SINGLE) DBUSY <= 0;
								BUSY <= 0;
							end
							STATE_NEXT = TRD;
						end
					end
				end
				
				TRD: begin
					if (CE_F) begin
						if (BURST_CNT[2:1] == 2'd0 || !BURST_SINGLE) begin
							DATA_LATCH = 1;
						end
						RD_N <= 1;
						CACK <= 0;
					end
					else if (CE_R) begin
						if (!BURST_CNT[0]) begin
							if (CBUS_ACTIVE && (!BURST_SINGLE || BURST_PRELAST)) CBUSY <= 0;
							if (DBUS_ACTIVE && (!BURST_SINGLE || BURST_PRELAST)) DBUSY <= 0;
							BUSY <= 0;
						end 
						case (AREA_SZ)
							2'b10: BURST_CNT <= BURST_CNT + 3'd1;
							2'b11: BURST_CNT <= BURST_CNT + 3'd2;
							default:;
						endcase
						if (BURST_LAST) begin
							BURST_EN <= 0;
							CS0_N <= 1;
							CS1_N <= 1;
							CS2_N <= 1;
							CS3_N <= 1;
							RD_WR_N <= 1;
							SDRAM_PRECHARGE_PEND <= 0;
							STATE_NEXT = T0;
						end
					end
				end
				
				TRFS1: begin
					if (CE_R) begin
						if (RFS_WAIT_CNT && !FAST) begin
							RFS_WAIT_CNT <= RFS_WAIT_CNT - 2'd1;
						end
						else begin
							STATE_NEXT = TRFS2;
						end
					end
				end
				
				TRFS2: begin
					if (CE_R) begin
						CS0_N <= 1;
						CS1_N <= 1;
						CS2_N <= 1;
						CS3_N <= 1;
						STATE_NEXT = T0;
					end
				end
				
				TV1: begin
					if (CE_R) begin
						BS_N <= 1;
						if (WAIT_N) begin
							VBUSY <= 0;
							BUSY <= 0;
							STATE_NEXT = TV2;
						end
					end
				end
				
				TV2: begin
					if (CE_F) begin
						VEC_BUF <= DI[7:0];
						RD_N <= 1;
					end else if (CE_R) begin
						IVECF_N <= 1;
						RD_WR_N <= 1;
						STATE_NEXT = T0;
					end
				end
				
				default:;
			endcase
			
			if (CE_F) begin
				if (DATA_LATCH) begin
					case (AREA_SZ)
						2'b01: if (!SIZE_BYTE_DISABLE) begin
							case (A[1:0])
								2'b00: DAT_BUF[31:24] <= DI[7:0];
								2'b01: DAT_BUF[23:16] <= DI[7:0];
								2'b10: DAT_BUF[15: 8] <= DI[7:0];
								2'b11: DAT_BUF[ 7: 0] <= DI[7:0];
							endcase
						end
						2'b10: if (!SIZE_WORD_DISABLE) begin
							case (A[1])
								1'b0: DAT_BUF[31:16] <= DI[15:0];
								1'b1: DAT_BUF[15: 0] <= DI[15:0];
							endcase
						end
						2'b11: DAT_BUF <= DI;
						default:;
					endcase
				end
			end
			
			if (CE_R) begin
				if (BUS_STATE == T0 || BUS_STATE == T2 || BUS_STATE == TWCAS || BUS_STATE == TWNOP || BUS_STATE == TRD || BUS_STATE == TRFS2 || BUS_STATE == TV2) begin
					if (CBUS_EXT_REQ && !BUS_RLS && !BUSY && (BURST_CNT[0] || !BURST_EN)) begin
						CBUSY <= 1;
						CBUSY2 <= 0;
					end
					if (DBUS_REQ && !BUS_RLS && !BUSY && (BURST_CNT[0] || !BURST_EN)) begin
						DBUSY <= 1;
					end
					if (VBUS_REQ && !BUS_RLS && !BUSY) begin
						VBUSY <= 1;
					end
					if ((BUS_STATE == T2 || BUS_STATE == TWCAS || BUS_STATE == TWNOP || BUS_STATE == TRD || BUS_STATE == TRFS2 || BUS_STATE == TV2) && BUSY && !RD_WR_N && !BUS_RLS) begin
						if (CBUS_EXT_REQ && !CBUSY) CBUSY <= 1;
						if (DBUS_REQ && !DBUSY) DBUSY <= 1;
					end
					
					SDRAM_AREA = SDRAMAreaSel(BCR1);
					CBUS_IS_SDRAM = IsSDRAMArea(CBUS_A[26:25],BCR1); 
					DBUS_IS_SDRAM = IsSDRAMArea(DBUS_A[26:25],BCR1); 
					BUS_IS_SDRAM = IsSDRAMArea(A[26:25],BCR1);
					VBUS_ACTIVE <= 0;
					if (((BUS_STATE == T2 || BUS_STATE == TWCAS || BUS_STATE == TRD) && BUSY && NEXT_BA) || ((BUS_STATE == T2 || BUS_STATE == TRD) && BURST_EN && !BURST_LAST)) begin
						case (AREA_SZ)
							2'b01: if (!SIZE_BYTE_DISABLE) begin 
								A[3:0] <= A[3:0] + 4'd1; 
								case (A[1:0])
									2'b01: begin 
										DO <= {24'h000000,BUS_DI_LATCH[23:16]};
										WE_N <= ~{3'b000,BUS_WE_LATCH & NEXT_BA[2]};
										NEXT_BA <= {2'b00,NEXT_BA[1:0]};
									end
									2'b10: begin 
										DO <= {24'h000000,BUS_DI_LATCH[15: 8]}; 
										WE_N <= ~{3'b000,BUS_WE_LATCH & NEXT_BA[1]};
										NEXT_BA <= {3'b000,NEXT_BA[0]};
									end
									2'b11: begin 
										DO <= {24'h000000,BUS_DI_LATCH[ 7: 0]};
										WE_N <= ~{3'b000,BUS_WE_LATCH & NEXT_BA[0]}; 
										NEXT_BA <= 4'b0000;
									end
									default: begin
										WE_N <= 4'b1111;
										NEXT_BA <= 4'b0000;
									end
								endcase
							end
							2'b10: if (!SIZE_WORD_DISABLE) begin 
								A[3:0] <= A[3:0] + 4'd2; 
								case (A[1])
									1'b0: begin 
										DO <= {16'h0000,BUS_DI_LATCH[15: 0]};
										WE_N <= ~({2'b00,BUS_WE_LATCH,BUS_WE_LATCH} & {2'b00,NEXT_BA[1:0]}); 
										NEXT_BA <= 4'b0000;
									end
									1'b1: begin 
										DO <= 32'h00000000; 
										WE_N <= 4'b1111;
										NEXT_BA <= {2'b00,{2{BURST_EN}}};
									end
								endcase
							end
							2'b11: begin 
								A[3:0] <= A[3:0] + 4'd4; 
								WE_N <= 4'b1111;
								NEXT_BA <= 4'b0000;
							end
							default: ;
						endcase
						CS0_N <= ~(A[26:25] == 2'b00);
						CS1_N <= ~(A[26:25] == 2'b01);
						CS2_N <= ~(A[26:25] == 2'b10);
						CS3_N <= ~(A[26:25] == 2'b11);
						BS_N <= 0;
						RD_N <= BUS_WE_LATCH;
						CACK <= 1;
						STATE_NEXT = BUS_IS_SDRAM ? (!BUS_WE_LATCH ? TRD : TRAS) : T1;
					end
					else if (BUS_SEL && !BUS_RLS && ((!BGR && MASTER) || (BREQ && !MASTER))) begin
						BUSY <= 1;
						CBUSY <= CBUS_EXT_REQ;
						CBUSY2 <= 0;
						DBUSY <= DBUS_REQ;
						VBUSY <= VBUS_REQ;
						
						if (!CBUS_LOCK_INT) CBUS_ACTIVE <= 0;
						if (!DBUS_LOCK_INT) DBUS_ACTIVE <= 0;
						REFRESH_ACTIVE <= 0;
						if (((RFS_REQ && !CBUS_EXT_REQ && !DBUS_REQ) || DELAYED_RFS_REQ) && !CBUS_LOCK_INT && !DBUS_LOCK_INT) begin
							if (INSERT_WAIT && !BUS_WE_LATCH && !BUS_IS_SDRAM) begin
								A <= CBUS_A[26:0];
								INSERT_WAIT <= 0;
							end else if (BUS_STATE == T0 || BUS_STATE == T2 /*|| BUS_STATE == TWCAS*/ || (BUS_STATE == TWNOP && !NOP_WAIT_CNT) || BUS_STATE == TRD || BUS_STATE == TRFS2) begin
								REFRESH_ACTIVE <= 1;
								INSERT_WAIT <= ~FAST;
								A[24:0] <= '0;
								DO <= '0; 
								CS0_N <= 1;
								CS1_N <= 1;
								CS2_N <= ~SDRAM_AREA[2];
								CS3_N <= ~SDRAM_AREA[3];
								IVECF_N <= 1;
								BS_N <= 1;
								RD_WR_N <= 1;
								WE_N <= 4'b1111;
								RD_N <= 1;
								CACK <= 0;
								
								NEXT_BA <= 4'b0000;
								BUS_WE_LATCH <= 0;
								BUS_DI_LATCH <= '0;
								RFS_WAIT_CNT <= 2'd3;
								DELAYED_RFS_REQ <= 0;
								STATE_NEXT = TRFS1;
							end
						end 
						else if (VBUS_REQ && !CBUS_LOCK_INT && !DBUS_LOCK_INT) begin
							if (BUS_STATE == T0 || BUS_STATE == T2 || (BUS_STATE == TWNOP && !NOP_WAIT_CNT) || BUS_STATE == TRD || BUS_STATE == TRFS2) begin
								VBUS_ACTIVE <= 1;
								A <= {23'h000000,VBUS_A};
								DO <= '0; 
								CS0_N <= 1;
								CS1_N <= 1;
								CS2_N <= 1;
								CS3_N <= 1;
								IVECF_N <= 0;
								BS_N <= 0;
								RD_WR_N <= 1;
								WE_N <= 4'b1111;
								RD_N <= 0;
								CACK <= 0;
								
								NEXT_BA <= 4'b0000;
								BUS_WE_LATCH <= '0;
								BUS_DI_LATCH <= '0;
								STATE_NEXT = TV1;
							end
						end 
						else if ((DBUS_REQ && !CBUS_LOCK_INT && !(CBUS_EXT_REQ && DBUS_SKIP) && !(SDRAM_PRECHARGE_PEND && BUS_STATE != TRFS2 && BRLS && MASTER)) || (DBUS_REQ && DBUS_LOCK_INT && !CBUS_LOCK_INT)) begin
							IS_SAME_BANK_SDRAM = (SDRAMBank(A,MCR) == SDRAMBank(DBUS_A[26:0],MCR));
							SDRAM_INSERT_NOP <= IS_SAME_BANK_SDRAM && BUS_WE_LATCH && DBUS_IS_SDRAM;
							if (INSERT_WAIT && ((A[26:25] != DBUS_A[26:25] && !DBUS_WE && !BUS_WE_LATCH && !DBUS_IS_SDRAM) || (DBUS_WE && !BUS_WE_LATCH && !DBUS_IS_SDRAM) || (DBUS_WE && BUS_STATE == T0 && !DBUS_IS_SDRAM) || (!DBUS_LOCK_INT && !MASTER))) begin
								A <= DBUS_A[26:0];
								INSERT_WAIT <= 0;
							end else if (BUS_STATE == T0 || BUS_STATE == T2 || (BUS_STATE == TWCAS && !SDRAM_INSERT_NOP && !DELAYED_RFS_REQ) || (BUS_STATE == TWNOP && !NOP_WAIT_CNT) || BUS_STATE == TRD || BUS_STATE == TRFS2) begin
								DBUS_ACTIVE <= 1;
								DBUS_SKIP <= 1;
								DBUS_LOCK_INT <= DBUS_LOCK;
								case (GetAreaSZ(DBUS_A[26:25],BCR1,BCR2,A0_SZ,DRAM_SZ))
									2'b01: if (!SIZE_BYTE_DISABLE) begin 
										case (DBUS_A[1:0])
											2'b00: begin 
												DO <= {24'h000000,DBUS_DI[31:24]}; 
												WE_N <= ~{3'b000,DBUS_WE & DBUS_BA[3]};
												NEXT_BA <= {1'b0,DBUS_BA[2:0]};
												if (DBUS_WE) DBUSY <= 0;
											end
											2'b01: begin 
												DO <= {24'h000000,DBUS_DI[23:16]};
												WE_N <= ~{3'b000,DBUS_WE & DBUS_BA[2]};
												NEXT_BA <= {2'b00,DBUS_BA[1:0]};
												if (DBUS_WE) DBUSY <= 0;
											end
											2'b10: begin 
												DO <= {24'h000000,DBUS_DI[15: 8]}; 
												WE_N <= ~{3'b000,DBUS_WE & DBUS_BA[1]};
												NEXT_BA <= {3'b000,DBUS_BA[0]};
												if (DBUS_WE) DBUSY <= 0;
											end
											2'b11: begin 
												DO <= {24'h000000,DBUS_DI[ 7: 0]};
												WE_N <= ~{3'b000,DBUS_WE & DBUS_BA[0]}; 
												NEXT_BA <= 4'b0000;
												if (DBUS_WE) DBUSY <= 0;
											end
										endcase
									end
									2'b10: if (!SIZE_WORD_DISABLE) begin 
										case (DBUS_A[1])
											1'b0: begin 
												DO <= {16'h0000,DBUS_DI[31:16]}; 
												WE_N <= ~{2'b00,{2{DBUS_WE}} & DBUS_BA[3:2]};
												NEXT_BA <= {2'b00,DBUS_BA[1:0]};
												if (DBUS_WE) DBUSY <= 0;
											end
											1'b1: begin 
												DO <= {16'h0000,DBUS_DI[15: 0]}; 
												WE_N <= ~{2'b00,{2{DBUS_WE}} & DBUS_BA[1:0]};
												NEXT_BA <= 4'b0000;
												if (DBUS_WE) DBUSY <= 0;
											end
										endcase
									end
									2'b11: begin 
										DO <= DBUS_DI; 
										WE_N <= ~({DBUS_WE,DBUS_WE,DBUS_WE,DBUS_WE} & DBUS_BA);
										NEXT_BA <= 4'b0000;
										if (DBUS_WE) DBUSY <= 0;
									end
									default:; 
								endcase
								if (DBUS_IS_SDRAM && !DBUS_WE) begin
									if (!BURST_EN || BURST_LAST) begin
										BURST_CNT <= 3'd0;
										BURST_EN <= 1;
										BURST_SINGLE <= ~DBUS_BURST;
									end
								end else begin
									BURST_CNT <= 3'd0;
									BURST_EN <= 0;
									BURST_SINGLE <= 1;
								end
								RCD_WAIT_CNT <= 2'd1 + MCR.RCD;
								SDRAM_PRECHARGE_PEND <= MASTER;
								INSERT_WAIT <= ~FAST; 
								
								A <= DBUS_A[26:0];
								if (DBUS_IS_SDRAM && MCR.RFSH && MCR.RMD && MASTER) begin
									CS0_N <= 1;
									CS1_N <= 1;
									CS2_N <= 1;
									CS3_N <= 1;
									BS_N <= 1;
									RD_WR_N <= 1;
									RD_N <= 1;
								end else begin
									CS0_N <= ~(DBUS_A[26:25] == 2'b00);
									CS1_N <= ~(DBUS_A[26:25] == 2'b01);
									CS2_N <= ~(DBUS_A[26:25] == 2'b10);
									CS3_N <= ~(DBUS_A[26:25] == 2'b11);
									BS_N <= 0;
									RD_WR_N <= ~DBUS_WE;
									RD_N <= DBUS_WE;
								end
								CACK <= 1;
								
								BUS_WE_LATCH <= DBUS_WE;
								BUS_DI_LATCH <= DBUS_DI;
								DELAYED_RFS_REQ <= RFS_REQ;
								STATE_NEXT = DBUS_IS_SDRAM ? TRAS : T1;
								if (!(DBUS_A[31:27] ==? 5'b00?00)) begin
									BURST_CNT <= 3'd0;
									BURST_EN <= 0;
									BURST_SINGLE <= 1;
									
									CS0_N <= 1;
									CS1_N <= 1;
									CS2_N <= 1;
									CS3_N <= 1;
									WE_N <= '1;
									BS_N <= 1;
									RD_WR_N <= 1;
									RD_N <= 1;
									CACK <= 0;
									
									BUS_WE_LATCH <= 0;
									BUS_DI_LATCH <= '0;
									STATE_NEXT = T0;
								end
							end
						end
						else if ((CBUS_EXT_REQ && !(SDRAM_PRECHARGE_PEND && BUS_STATE != TRFS2 && BRLS && MASTER)) || (CBUS_EXT_REQ && CBUS_LOCK_INT)) begin
							IS_SAME_BANK_SDRAM = (SDRAMBank(A,MCR) == SDRAMBank(CBUS_A[26:0],MCR));
							SDRAM_INSERT_NOP = IS_SAME_BANK_SDRAM && BUS_WE_LATCH && CBUS_IS_SDRAM;
							if (INSERT_WAIT && ((A[26:25] != CBUS_A[26:25] && !CBUS_WE && !BUS_WE_LATCH && !CBUS_IS_SDRAM) || (CBUS_WE && !BUS_WE_LATCH && !CBUS_IS_SDRAM) || (CBUS_WE && BUS_STATE == T0 && !CBUS_IS_SDRAM) || (CBUS_WE && REFRESH_ACTIVE) || 
							                    (CBUS_WE && CBUS_REQ_CNT == 2'd3 && (BRLS || !MASTER) && !NOP_WAIT_CNT))) begin
								A <= CBUS_A[26:0];
								INSERT_WAIT <= 0;
								CBUS_REQ_CNT <= 2'd0;
							end else if (BUS_STATE == T0 || BUS_STATE == T2 || (BUS_STATE == TWCAS && !SDRAM_INSERT_NOP && !DELAYED_RFS_REQ) || (BUS_STATE == TWNOP && !NOP_WAIT_CNT) || BUS_STATE == TRD || BUS_STATE == TRFS2) begin
								CBUS_ACTIVE <= 1;
								DBUS_SKIP <= 0;
								if (CBUS_WE && CBUS_REQ_CNT < 2'd3) CBUS_REQ_CNT <= CBUS_REQ_CNT + 2'd1;
								else CBUS_REQ_CNT <= 2'd0;
								CBUS_LOCK_INT <= CBUS_LOCK;
								case (GetAreaSZ(CBUS_A[26:25],BCR1,BCR2,A0_SZ,DRAM_SZ))
									2'b01: if (!SIZE_BYTE_DISABLE) begin 
										case (CBUS_A[1:0])
											2'b00: begin 
												DO <= {24'h000000,CBUS_DI[31:24]}; 
												WE_N <= ~{3'b000,CBUS_WE & CBUS_BA[3]};
												NEXT_BA <= {1'b0,CBUS_BA[2:0]};
												if (CBUS_WE) CBUSY <= 0;
											end
											2'b01: begin 
												DO <= {24'h000000,CBUS_DI[23:16]};
												WE_N <= ~{3'b000,CBUS_WE & CBUS_BA[2]};
												NEXT_BA <= {2'b00,CBUS_BA[1:0]};
												if (CBUS_WE) CBUSY <= 0;
											end
											2'b10: begin 
												DO <= {24'h000000,CBUS_DI[15: 8]}; 
												WE_N <= ~{3'b000,CBUS_WE & CBUS_BA[1]};
												NEXT_BA <= {3'b000,CBUS_BA[0]};
												if (CBUS_WE) CBUSY <= 0;
											end
											2'b11: begin 
												DO <= {24'h000000,CBUS_DI[ 7: 0]};
												WE_N <= ~{3'b000,CBUS_WE & CBUS_BA[0]}; 
												NEXT_BA <= 4'b0000;
												if (CBUS_WE) CBUSY <= 0;
											end
										endcase
									end
									2'b10: if (!SIZE_WORD_DISABLE) begin 
										case (CBUS_A[1])
											1'b0: begin 
												DO <= {16'h0000,CBUS_DI[31:16]}; 
												WE_N <= ~{2'b00,{2{CBUS_WE}} & CBUS_BA[3:2]};
												NEXT_BA <= {2'b00,CBUS_BA[1:0]};
												if (CBUS_WE) CBUSY <= 0;
											end
											1'b1: begin 
												DO <= {16'h0000,CBUS_DI[15: 0]}; 
												WE_N <= ~{2'b00,{2{CBUS_WE}} & CBUS_BA[1:0]};
												NEXT_BA <= 4'b0000;
												if (CBUS_WE) CBUSY <= 0;
											end
										endcase
									end
									2'b11: begin 
										DO <= CBUS_DI; 
										WE_N <= ~({CBUS_WE,CBUS_WE,CBUS_WE,CBUS_WE} & CBUS_BA);
										NEXT_BA <= 4'b0000;
										if (CBUS_WE) CBUSY <= 0;
									end
									default:; 
								endcase
								if ((CBUS_BURST || CBUS_IS_SDRAM) && !CBUS_WE) begin
									if (!BURST_EN || BURST_LAST) begin
										BURST_CNT <= 3'd0;
										BURST_EN <= 1;
										BURST_SINGLE <= ~CBUS_BURST;
									end
								end else begin
									BURST_CNT <= 3'd0;
									BURST_EN <= 0;
									BURST_SINGLE <= 1;
								end
								RCD_WAIT_CNT <= 2'd1 + MCR.RCD;
								if (!CBUS_WE) SDRAM_PRECHARGE_PEND <= MASTER;
								INSERT_WAIT <= ~FAST;
								
								A <= CBUS_A[26:0];
								if (CBUS_IS_SDRAM && MCR.RFSH && MCR.RMD && MASTER) begin
									CS0_N <= 1;
									CS1_N <= 1;
									CS2_N <= 1;
									CS3_N <= 1;
									BS_N <= 1;
									RD_WR_N <= 1;
									WE_N <= '1;
									RD_N <= 1;
								end else begin
									CS0_N <= ~(CBUS_A[26:25] == 2'b00);
									CS1_N <= ~(CBUS_A[26:25] == 2'b01);
									CS2_N <= ~(CBUS_A[26:25] == 2'b10);
									CS3_N <= ~(CBUS_A[26:25] == 2'b11);
									BS_N <= 0;
									RD_WR_N <= ~CBUS_WE;
									RD_N <= CBUS_WE;
								end
								CACK <= 1;
								
								BUS_WE_LATCH <= CBUS_WE;
								BUS_DI_LATCH <= CBUS_DI; 
								DELAYED_RFS_REQ <= RFS_REQ && CBUS_IS_SDRAM;
								STATE_NEXT = CBUS_IS_SDRAM ? TRAS : T1;
							end
						end
					end
					else begin
						if (!CBUS_LOCK_INT) CBUS_ACTIVE <= 0;
						if (!DBUS_LOCK_INT) DBUS_ACTIVE <= 0;
						VBUS_ACTIVE <= 0;
						REFRESH_ACTIVE <= 0;
					end
				end
				else if ((BUS_STATE == T1 || BUS_STATE == TW || BUS_STATE == TRAS || BUS_STATE == TRCAS || BUS_STATE == TRFS1) && BUS_SEL && !BUS_RLS) begin
					if (!VBUSY && VBUS_REQ) VBUSY <= 1;
					if ((BUS_STATE == T1 || BUS_STATE == TW || BUS_STATE == TRAS) && !RD_WR_N) begin
						if (CBUS_EXT_REQ && !CBUSY) CBUSY <= 1;
						if (DBUS_REQ && !DBUSY) DBUSY <= 1;
					end
					if (CBUS_EXT_REQ && CBUS_WE && !BUS_RLS && BUSY) begin
						CBUSY2 <= 1;
					end
				end
				if (BUS_RLS) begin INSERT_WAIT <= 0; CBUS_REQ_CNT <= '0; end
			end
			if (CE_F) begin
				if (!CBUS_EXT_REQ && CBUS_PREREQ && BUS_STATE == T0 && !BUS_RLS) DBUS_SKIP <= 1;
			end
			BUS_STATE <= STATE_NEXT;
		end
	end
	
	assign RFS = BUS_STATE == TRFS1 && (RFS_WAIT_CNT == 2'd0 || RFS_WAIT_CNT == 2'd2);
	
	wire BUS_END = VBUS_ACTIVE ? !VBUSY :
	               DBUS_ACTIVE ? !DBUSY && !DBUS_LOCK :
						CBUS_ACTIVE ? !CBUSY && !CBUS_LOCK :
						1'b1;
	bit MST_BUS_RLS;
	bit SLV_BUS_RLS;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			BREQ <= 0;
			BGR <= 0;
			MST_BUS_RLS <= 0;
			SLV_BUS_RLS <= 1;
		end else if (CE_F) begin
			if (MASTER) begin
				if (BRLS && !BGR && BUS_STATE == T0 && BUS_END && !MST_BUS_RLS) begin
					BGR <= 1;
				end
				else if (BRLS && BGR && !MST_BUS_RLS) begin
					MST_BUS_RLS <= 1;
				end
				else if (!BRLS && MST_BUS_RLS) begin
					BGR <= 0;
					MST_BUS_RLS <= 0;
				end
			end
			else begin
				if (BUS_SEL && !BREQ && SLV_BUS_RLS) begin
					BREQ <= 1;
				end
				else if (BREQ && BACK && SLV_BUS_RLS) begin
					SLV_BUS_RLS <= 0;
				end
				else if ((BREQ && !CBUS_PREREQ && BUS_STATE == T0 && BUS_END && !SLV_BUS_RLS) ||
			            (BREQ && BUS_STATE == T0 && !RES_N && !SLV_BUS_RLS)) begin
					BREQ <= 0;
				end
				else if (!BREQ && !SLV_BUS_RLS) begin
					SLV_BUS_RLS <= 1;
				end
			end
		end
	end
	
	assign BGR_N = MASTER ? ~BGR : ~BREQ;
	assign BUS_RLS = MASTER ? MST_BUS_RLS : SLV_BUS_RLS;
	
		
	//Clock selector
	bit         RT_CE;
	always_comb begin
		case (RTCSR.CKS)
			3'b000: RT_CE = 0;
			3'b001: RT_CE = CLK4_CE;
			3'b010: RT_CE = CLK16_CE;
			3'b011: RT_CE = CLK64_CE;
			3'b100: RT_CE = CLK256_CE;
			3'b101: RT_CE = CLK1024_CE;
			3'b110: RT_CE = CLK2048_CE;
			3'b111: RT_CE = CLK4096_CE;
		endcase
	end
	
	//Registers
	wire REG_SEL = (CBUS_A >= 32'hFFFFFFE0);
	always @(posedge CLK or negedge RST_N) begin
		bit [ 7: 0] RTCNT_NEW;
		
		if (!RST_N) begin
			BCR1  <= BCR1_INIT;
			BCR2  <= BCR2_INIT;
			WCR   <= WCR_INIT;
			MCR   <= MCR_INIT;
			RTCSR <= RTCSR_INIT;
			RTCNT <= RTCNT_INIT;
			RTCOR <= RTCOR_INIT;
			RFS_REQ <= 0;
		end
		else if (CE_R) begin
			if (REG_SEL && CBUS_DI[31:16] == 16'hA55A && CBUS_WE && CBUS_REQ) begin
				case ({CBUS_A[4:2],2'b00})
					5'h00: BCR1  <= CBUS_DI[15:0] & BCR1_WMASK;
					5'h04: BCR2  <= CBUS_DI[15:0] & BCR2_WMASK;
					5'h08: WCR   <= CBUS_DI[15:0] & WCR_WMASK;
					5'h0C: MCR   <= CBUS_DI[15:0] & MCR_WMASK;
					5'h10: RTCSR <= CBUS_DI[15:0] & RTCSR_WMASK;
					5'h14: RTCNT <= CBUS_DI[7:0]  & RTCNT_WMASK;
					5'h18: RTCOR <= CBUS_DI[7:0]  & RTCOR_WMASK;
					default:;
				endcase
			end
			
			RTCNT_NEW = RTCNT + 8'd1;
			if (RT_CE) begin
				RTCNT <= RTCNT_NEW;
				if (RTCNT_NEW == RTCOR) begin
					RTCNT <= '0;
					RFS_REQ <= MCR.RFSH;
				end
			end
			if (BUS_STATE == TRFS1 && RFS_REQ) RFS_REQ <= 0;
		end
	end
	
	bit [31:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			REG_DO <= '0;
		end
		else if (CE_F) begin
			if (REG_SEL && !CBUS_WE && CBUS_REQ) begin
				REG_DO[31:16] <= 16'h0000;
				case ({CBUS_A[4:2],2'b00})
					5'h00: REG_DO[15:0] <= {MD[5],BCR1[14:0]} & BCR1_RMASK;
					5'h04: REG_DO[15:0] <= BCR2 & BCR2_RMASK;
					5'h08: REG_DO[15:0] <= WCR & WCR_RMASK;
					5'h0C: REG_DO[15:0] <= MCR & MCR_RMASK;
					5'h10: REG_DO[15:0] <= RTCSR & RTCSR_RMASK;
					5'h14: REG_DO[15:0] <= {8'h00,RTCNT} & RTCNT_RMASK;
					5'h18: REG_DO[15:0] <= {8'h00,RTCOR} & RTCOR_RMASK;
					default:REG_DO[15:0] <= '0;
				endcase
			end
		end
	end
		
	assign CBUS_DO = REG_SEL ? REG_DO : CBUS_ACTIVE ? DAT_BUF : '0;
	assign CBUS_BUSY = CBUSY | CBUSY2 | ((BUS_RLS | (BGR & MASTER) | (~BREQ & ~MASTER)) & CBUS_EXT_REQ) | ((DBUS_ACTIVE | VBUS_ACTIVE | REFRESH_ACTIVE) & ~CBUS_PER_REQ);
	assign CBUS_ACT = REG_SEL;
	
	assign DBUS_DO = DBUS_ACTIVE ? DAT_BUF : '0;
	assign DBUS_BUSY = DBUSY | ((BUS_RLS | (BGR & MASTER) | (~BREQ & ~MASTER)) & DBUS_REQ) | CBUS_ACTIVE | VBUS_ACTIVE | REFRESH_ACTIVE;
	
	assign VBUS_DO = VEC_BUF;
	assign VBUS_BUSY = VBUSY | ((BUS_RLS | BGR) & VBUS_REQ);
	
	assign OE_N = 1;
	assign CE_N = 1;
	assign IRQ = 0;
	

endmodule
