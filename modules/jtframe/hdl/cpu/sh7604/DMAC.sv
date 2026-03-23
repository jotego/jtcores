module SH7604_DMAC (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	input             EN,
	
	input             RES_N,
	input             NMI_N,
	
	input             DREQ0,
	output            DACK0,
	input             DREQ1,
	output            DACK1,
	
	input             RXI_IRQ,
	input             TXI_IRQ,
	
	input      [31:0] IBUS_A,
	input      [31:0] IBUS_DI,
	output     [31:0] IBUS_DO,
	input       [3:0] IBUS_BA,
	input             IBUS_WE,
	input             IBUS_REQ,
	output            IBUS_ACT,
	
	output     [31:0] DBUS_A,
	input      [31:0] DBUS_DI,
	output     [31:0] DBUS_DO,
	output      [3:0] DBUS_BA,
	output            DBUS_WE,
	output            DBUS_REQ,
	output            DBUS_LOCK,
	output            DBUS_BURST,
	input             DBUS_WAIT,
	
	input             BSC_ACK,
	
	output            DMAC0_IRQ,
	output      [7:0] DMAC0_VEC,
	output            DMAC1_IRQ,
	output      [7:0] DMAC1_VEC
);

	import SH7604_PKG::*;

	SARx_t      SAR[2];
	DARx_t      DAR[2];
	TCRx_t      TCR[2];
	CHCRx_t     CHCR[2];
	DRCRx_t     DRCR[2];
	VCRDMAx_t   VCRDMA0;
	VCRDMAx_t   VCRDMA1;
	DMAOR_t     DMAOR;
		
	function bit [3:0] BAFromAddr(input bit [1:0] addr, input bit [1:0] sz);
		bit [3:0] res;
	
		case (sz)
			2'b00: res = {~addr[1]&~addr[0],~addr[1]&addr[0],addr[1]&~addr[0],addr[1]&addr[0]};
			2'b01: res = {~addr[1]         ,~addr[1]        ,addr[1]                 ,addr[1]};
			2'b10: res = 4'b1111;
			2'b11: res = 4'b1111;
		endcase
		return res;
	endfunction
	
	function bit [31:0] GetAddrInc(input bit [1:0] sz);
		bit [31:0] res;
	
		case (sz)
			2'b00: res = 32'd1;
			2'b01: res = 32'd2;
			2'b10: res = 32'd4;
			2'b11: res = 32'd4;
		endcase
		return res;
	endfunction
	
	wire REG1_SEL = (IBUS_A >= 32'hFFFFFE71 && IBUS_A <= 32'hFFFFFE72);
	wire REG2_SEL = (IBUS_A >= 32'hFFFFFF80 && IBUS_A <= 32'hFFFFFFB3);

	wire CH_EN[2] = '{DMAOR.DME & CHCR[0].DE, DMAOR.DME & CHCR[1].DE};
	wire CH_AVAIL[2] = '{~CHCR[0].TE & ~DMAOR.NMIF & ~DMAOR.AE, ~CHCR[1].TE & ~DMAOR.NMIF & ~DMAOR.AE};

	bit         CH_REQ[2];
	bit         CH_REQ_CLR[2];
	always @(posedge CLK or negedge RST_N) begin
		bit         DREQ0_REQ;
		bit         DREQ1_REQ;
		bit         DREQ0_OLD;
		bit         DREQ1_OLD;
		
		if (!RST_N) begin
			DREQ0_REQ <= 0;
			DREQ1_REQ <= 0;
			DREQ0_OLD <= 0;
			DREQ1_OLD <= 0;
			CH_REQ <= '{0,0};
		end
		else if (CE_R) begin
			DREQ0_OLD <= DREQ0;
			if (!CHCR[0].DS) DREQ0_REQ <= ~DREQ0 ^ CHCR[0].DL;
			else DREQ0_REQ <= (~DREQ0 ^ CHCR[0].DL) & (DREQ0_OLD ^ CHCR[0].DL);
			
			if (!CH_REQ[0] && CH_EN[0] && CH_AVAIL[0]) begin
				if (CHCR[0].AR) CH_REQ[0] <= 1;
				else 
					case(DRCR[0].RS)
						2'b00: CH_REQ[0] <= DREQ0_REQ;
						2'b01: CH_REQ[0] <= RXI_IRQ;
						2'b10: CH_REQ[0] <= TXI_IRQ;
						2'b11: CH_REQ[0] <= 0;
					endcase
			end
			else if (CH_REQ_CLR[0] || !CH_EN[0]) begin
				CH_REQ[0] <= 0;
			end
			
			DREQ1_OLD <= DREQ1;
			if (!CHCR[1].DS) DREQ1_REQ <= ~DREQ1 ^ CHCR[1].DL;
			else DREQ1_REQ <= (~DREQ1 ^ CHCR[1].DL) & (DREQ1_OLD ^ CHCR[1].DL);
			
			if (!CH_REQ[1] && CH_EN[1] && CH_AVAIL[1]) begin
				if (CHCR[1].AR) CH_REQ[1] <= 1;
				else 
					case(DRCR[1].RS)
						2'b00: CH_REQ[1] <= DREQ1_REQ;
						2'b01: CH_REQ[1] <= RXI_IRQ;
						2'b10: CH_REQ[1] <= TXI_IRQ;
						2'b11: CH_REQ[1] <= 0;
					endcase
			end
			else if (CH_REQ_CLR[1] || !CH_EN[1]) begin
				CH_REQ[1] <= 0;
			end
		end
	end
	
	bit         DMA_REQ;
	bit         DMA_REQ_CLR;
	bit         DMA_CH;
	bit         RB_PRIO;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DMA_REQ <= 0;
			DMA_CH <= 0;
			RB_PRIO <= 0;
		end
		else if (CE_R) begin
			if (!DMA_REQ) begin
				if ((CH_REQ[0] && CH_EN[0] && CH_AVAIL[0]) && 
				    (CH_REQ[1] && CH_EN[1] && CH_AVAIL[1]) && DMAOR.PR) begin
					DMA_REQ <= 1;
					DMA_CH <= RB_PRIO;
				end
				else if (CH_REQ[0] && CH_EN[0] && CH_AVAIL[0]) begin
					DMA_REQ <= 1;
					DMA_CH <= 0;
				end
				else if (CH_REQ[1] && CH_EN[1] && CH_AVAIL[1]) begin
					DMA_REQ <= 1;
					DMA_CH <= 1;
				end
			end
			else if (DMA_REQ_CLR) begin
				DMA_REQ <= 0;
				RB_PRIO <= ~RB_PRIO;
			end
		end
	end
	
	bit         DMA_WR;
	bit         DMA_RD;
	bit         DMA_BURST;
	bit         DMA_LOCK;
	bit  [31:0] RD_BUF[4];
	bit   [1:0] LW_CNT;
	bit   [1:0] SA_BA;
	always @(posedge CLK or negedge RST_N) begin
		bit  [31:0] AR_INC;
		bit  [23:0] TCR_NEXT;
		bit         RD_BUF_LATCH;
		bit         CHCR_TE_OLD[2];
		
		if (!RST_N) begin
			SAR <= '{2{SARx_INIT}};
			DAR <= '{2{DARx_INIT}};
			TCR <= '{2{TCRx_INIT}};
			CHCR <= '{2{CHCRx_INIT}};
			CHCR_TE_OLD <= '{2{1'b0}};
			
			DMA_WR <= 0;
			DMA_RD <= 0;
			DMA_BURST <= 0;
			DMA_LOCK <= 0;
			CH_REQ_CLR <= '{0,0};
			DMA_REQ_CLR <= 0;
			LW_CNT <= '0;
			RD_BUF_LATCH <= 0;
		end
		else begin
			AR_INC = GetAddrInc(CHCR[DMA_CH].TS);
			TCR_NEXT = TCR[DMA_CH] - 24'd1;
			
			CH_REQ_CLR[0] <= 0;
			CH_REQ_CLR[1] <= 0;
			DMA_REQ_CLR <= 0;
			if (DMA_REQ && !DMA_RD && !DMA_WR && CE_F) begin
				if (!CHCR[DMA_CH].TA || (CHCR[DMA_CH].TA && !CHCR[DMA_CH].AM)) begin
					DMA_RD <= 1;
					LW_CNT <= &CHCR[DMA_CH].TS ? 2'd3 : 2'd0;
					CH_REQ_CLR[DMA_CH] <= CHCR[DMA_CH].TA & ~CHCR[DMA_CH].AM;
					DMA_BURST <= &CHCR[DMA_CH].TS;
					DMA_LOCK <= ~CHCR[DMA_CH].TA | CHCR[DMA_CH].TB | &CHCR[DMA_CH].TS;
				end
				else begin
					DMA_WR <= 1;
					LW_CNT <= &CHCR[DMA_CH].TS ? 2'd3 : 2'd0;
					CH_REQ_CLR[DMA_CH] <= 1;
					DMA_BURST <= &CHCR[DMA_CH].TS;
					DMA_LOCK <= CHCR[DMA_CH].TB | &CHCR[DMA_CH].TS;
				end
			end
			else if ((DMA_RD || DMA_WR) && !DBUS_WAIT && CE_F) begin
				if (DMA_RD) begin
					if (&CHCR[DMA_CH].TS || CHCR[DMA_CH].SM == 2'b01) SAR[DMA_CH] <= SAR[DMA_CH] + AR_INC;
					else if                (CHCR[DMA_CH].SM == 2'b10) SAR[DMA_CH] <= SAR[DMA_CH] - AR_INC;
					
					if (!CHCR[DMA_CH].TA && !LW_CNT) begin
						DMA_RD <= 0;
						DMA_WR <= 1;
						DMA_BURST <= &CHCR[DMA_CH].TS;
						DMA_LOCK <= CHCR[DMA_CH].TB | &CHCR[DMA_CH].TS;
						LW_CNT <= &CHCR[DMA_CH].TS ? 2'd3 : 2'd0;
						CH_REQ_CLR[DMA_CH] <= 1;
						if (!TCR_NEXT) begin
							DMA_LOCK <= 0;
						end
					end
					else if (CHCR[DMA_CH].TA && !CHCR[DMA_CH].AM && !LW_CNT) begin
						CH_REQ_CLR[DMA_CH] <= 1;
						DMA_REQ_CLR <= 1;
						LW_CNT <= &CHCR[DMA_CH].TS ? 2'd3 : 2'd0;
						
						if (!CHCR[DMA_CH].TB) DMA_RD <= 0;
						
						TCR[DMA_CH] <= TCR_NEXT;
						if (!TCR_NEXT) begin
							CHCR[DMA_CH].TE <= 1;
							DMA_RD <= 0;
							DMA_BURST <= 0;
						end
					end
					RD_BUF_LATCH <= 1;
					SA_BA <= SAR[DMA_CH][1:0];
				end
				else if (DMA_WR) begin
					if      (CHCR[DMA_CH].DM == 2'b01) DAR[DMA_CH] <= DAR[DMA_CH] + AR_INC;
					else if (CHCR[DMA_CH].DM == 2'b10) DAR[DMA_CH] <= DAR[DMA_CH] - AR_INC;
					
					if (LW_CNT == 2'd1) begin
						if (!CHCR[DMA_CH].TB) DMA_LOCK <= 0;
					end 
					if (!LW_CNT || !TCR_NEXT) begin
						if (!CHCR[DMA_CH].TA) begin
							DMA_WR <= 0;
							if (CHCR[DMA_CH].TB) begin
								DMA_RD <= 1;
								DMA_BURST <= &CHCR[DMA_CH].TS;
								DMA_LOCK <= 1;
								LW_CNT <= &CHCR[DMA_CH].TS ? 2'd3 : 2'd0;
							end
						end 
						else if (CHCR[DMA_CH].TA && CHCR[DMA_CH].AM) begin
							CH_REQ_CLR[DMA_CH] <= 1;
							LW_CNT <= &CHCR[DMA_CH].TS ? 2'd3 : 2'd0;
							
							if (!CHCR[DMA_CH].TB) DMA_WR <= 0;
						end
						
						DMA_REQ_CLR <= 1;
					end
					
					TCR[DMA_CH] <= TCR_NEXT;
					if (TCR_NEXT == 24'd1) begin
						if (&CHCR[DMA_CH].TS) DMA_LOCK <= 0;
					end
					if (!TCR_NEXT) begin
						CHCR[DMA_CH].TE <= 1;
						DMA_RD <= 0;
						DMA_WR <= 0;
						DMA_BURST <= 0;
					end
				end
				
				if (LW_CNT) LW_CNT <= LW_CNT - 2'd1;
				else LW_CNT <= &CHCR[DMA_CH].TS ? 2'd3 : 2'd0;
					
				RD_BUF[1] <= RD_BUF[0];
				RD_BUF[2] <= RD_BUF[1];
				RD_BUF[3] <= RD_BUF[2];
			end
			
			if (RD_BUF_LATCH && CE_R) begin
				RD_BUF[0] <= DBUS_DI;
				RD_BUF_LATCH <= 0;
			end
			
			if (CE_R) begin
				if (REG2_SEL && IBUS_WE && IBUS_REQ) begin
					case ({IBUS_A[5:2],2'b00})
						6'h00: SAR[0]  <= IBUS_DI;
						6'h04: DAR[0]  <= IBUS_DI;
						6'h08: TCR[0]  <= IBUS_DI[23:0];
						6'h0C: begin
							CHCR[0][31:2] <= IBUS_DI[31:2] & CHCRx_WMASK[31:2];
							if (!IBUS_DI[1] && CHCR_TE_OLD[0]) begin CHCR[0][1] <= 0; CHCR_TE_OLD[0] <= 0; end
							CHCR[0][0] <= IBUS_DI[0] & CHCRx_WMASK[0];
						end
						6'h10: SAR[1]  <= IBUS_DI;
						6'h14: DAR[1]  <= IBUS_DI;
						6'h18: TCR[1]  <= IBUS_DI[23:0];
						6'h1C: begin
							CHCR[1][31:2] <= IBUS_DI[31:2] & CHCRx_WMASK[31:2];
							if (!IBUS_DI[1] && CHCR_TE_OLD[1]) begin CHCR[1][1] <= 0; CHCR_TE_OLD[1] <= 0; end
							CHCR[1][0] <= IBUS_DI[0] & CHCRx_WMASK[0];
						end
						default:;
					endcase
				end
			end
			if (CE_F) begin
				if (REG2_SEL && !IBUS_WE && IBUS_REQ) begin
					case ({IBUS_A[5:2],2'b00})
						6'h0C: CHCR_TE_OLD[0] <= CHCR[0].TE;
						6'h1C: CHCR_TE_OLD[1] <= CHCR[1].TE;
					endcase
				end
			end
		end
	end
	
	wire DMA_ACCESS = DMA_RD | DMA_WR;
	
	bit [31:0] DBUS_DO_TEMP;
	always_comb begin
		case (CHCR[DMA_CH].TS)
			2'b00: 
				case (SA_BA)
					2'b00: DBUS_DO_TEMP = {4{DBUS_DI[31:24]}};
					2'b01: DBUS_DO_TEMP = {4{DBUS_DI[23:16]}};
					2'b10: DBUS_DO_TEMP = {4{DBUS_DI[15: 8]}};
					2'b11: DBUS_DO_TEMP = {4{DBUS_DI[ 7: 0]}};
				endcase
			2'b01: 
				case (SA_BA[1])
					1'b0: DBUS_DO_TEMP = {2{DBUS_DI[31:16]}};
					1'b1: DBUS_DO_TEMP = {2{DBUS_DI[15: 0]}};
				endcase
			2'b10: DBUS_DO_TEMP = DBUS_DI;
			2'b11: DBUS_DO_TEMP = RD_BUF[3];
		endcase
	end
	
	assign DBUS_A = DMA_RD ? SAR[DMA_CH] & 32'h07FFFFFF : 
	                DMA_WR ? DAR[DMA_CH] & 32'h07FFFFFF : 
	                '0;
	assign DBUS_DO = DBUS_DO_TEMP;
	assign DBUS_BA = DMA_RD ? BAFromAddr(SAR[DMA_CH][1:0],CHCR[DMA_CH].TS) : 
	                 DMA_WR ? BAFromAddr(DAR[DMA_CH][1:0],CHCR[DMA_CH].TS) : 
	                 '0;
	assign DBUS_WE = DMA_RD ? 1'b0 : 
	                 DMA_WR ? 1'b1 : 
	                 1'b0;
	assign DBUS_REQ = DMA_ACCESS;
	assign DBUS_BURST = DMA_BURST;
	assign DBUS_LOCK  = DMA_LOCK;
	
	assign DACK0 = (BSC_ACK & !DMA_CH & ((DMA_RD & (~CHCR[0].AM | CHCR[0].TA)) | (DMA_WR & (CHCR[0].AM | CHCR[0].TA)))) ^ ~CHCR[0].AL;
	assign DACK1 = (BSC_ACK &  DMA_CH & ((DMA_RD & (~CHCR[1].AM | CHCR[1].TA)) | (DMA_WR & (CHCR[1].AM | CHCR[1].TA)))) ^ ~CHCR[1].AL;
	
	assign DMAC0_IRQ = CHCR[0].TE & CHCR[0].IE;
	assign DMAC0_VEC = VCRDMA0.VC;
	assign DMAC1_IRQ = CHCR[1].TE & CHCR[1].IE;
	assign DMAC1_VEC = VCRDMA1.VC;
	
	//Registers
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DRCR[0] <= DRCRx_INIT;
			DRCR[1] <= DRCRx_INIT;
			VCRDMA0 <= VCRDMAx_INIT;
			VCRDMA1 <= VCRDMAx_INIT;
			DMAOR <= DMAOR_INIT;
			// synopsys translate_off
			DMAOR.DME <= 1;
			// synopsys translate_on
		end
		else if (CE_R) begin
			if (!RES_N) begin
				DRCR[0] <= DRCRx_INIT;
				DRCR[1] <= DRCRx_INIT;
				VCRDMA0 <= VCRDMAx_INIT;
				VCRDMA1 <= VCRDMAx_INIT;
				DMAOR <= DMAOR_INIT;
				// synopsys translate_off
				DMAOR.DME <= 1;
				// synopsys translate_on
			end
			else if (REG1_SEL && IBUS_WE && IBUS_REQ) begin
				if (IBUS_BA[2]) DRCR[0] <= IBUS_DI[23:16] & DRCRx_WMASK;
				if (IBUS_BA[1]) DRCR[1] <= IBUS_DI[15: 8] & DRCRx_WMASK;
			end
			else if (REG2_SEL && IBUS_WE && IBUS_REQ) begin
				case ({IBUS_A[5:2],2'b00})
					6'h20: VCRDMA0 <= IBUS_DI & VCRDMAx_WMASK;
					6'h28: VCRDMA1 <= IBUS_DI & VCRDMAx_WMASK;
					6'h30: begin
						DMAOR[31:3] <= IBUS_DI[31:3] & DMAOR_WMASK[31:3];
						DMAOR[2:1]  <= DMAOR[2:1] & IBUS_DI[2:1];
						DMAOR[0]    <= IBUS_DI[0] & DMAOR_WMASK[0];
					end
					default:;
				endcase
			end
			
			if (!NMI_N) DMAOR.NMIF <= 1;
		end
	end
	
	bit [31:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			REG_DO <= '0;
		end
		else if (CE_F) begin
			if (REG1_SEL && !IBUS_WE && IBUS_REQ) begin
				REG_DO <= {8'h00,DRCR[0] & DRCRx_RMASK,DRCR[1] & DRCRx_RMASK,8'h00};
			end
			else if (REG2_SEL && !IBUS_WE && IBUS_REQ) begin
				case ({IBUS_A[5:2],2'b00})
					6'h00: REG_DO <= SAR[0];
					6'h04: REG_DO <= DAR[0];
					6'h08: REG_DO <= {8'h00,TCR[0]};
					6'h0C: REG_DO <= CHCR[0] & CHCRx_RMASK;
					6'h10: REG_DO <= SAR[1];
					6'h14: REG_DO <= DAR[1];
					6'h18: REG_DO <= {8'h00,TCR[1]};
					6'h1C: REG_DO <= CHCR[1] & CHCRx_RMASK;
					6'h20: REG_DO <= VCRDMA0 & VCRDMAx_RMASK;
					6'h28: REG_DO <= VCRDMA1 & VCRDMAx_RMASK;
					6'h30: REG_DO <= DMAOR & DMAOR_RMASK;
					default:REG_DO <= '0;
				endcase
			end
		end
	end
	
	assign IBUS_DO = REG1_SEL || REG2_SEL ? REG_DO : '0;
	assign IBUS_ACT = REG1_SEL | REG2_SEL;
	

endmodule
