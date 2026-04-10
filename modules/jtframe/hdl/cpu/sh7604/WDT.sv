module SH7604_WDT
#(parameter bit DISABLE=0)
(
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	input             EN,
	
	input             RES_N,
	
	input             SBY,
	input             NMI,
	
	output reg        WDTOVF_N,
	
	input             CLK2_CE,
	input             CLK64_CE,
	input             CLK128_CE,
	input             CLK256_CE,
	input             CLK512_CE,
	input             CLK1024_CE,
	input             CLK4096_CE,
	input             CLK8192_CE,
	
	input      [31:0] IBUS_A,
	input      [31:0] IBUS_DI,
	output     [31:0] IBUS_DO,
	input       [3:0] IBUS_BA,
	input             IBUS_WE,
	input             IBUS_REQ,
	output            IBUS_BUSY,
	output            IBUS_ACT,
	
	output            ITI_IRQ,
	output            OVF,
	output            PRES,
	output            MRES
);

	import SH7604_PKG::*;
	
	WTCNT_t     WTCNT;
	WTCSR_t     WTCSR;
	RSTCSR_t    RSTCSR;
	bit         WRES;
	
	//Clock selector
	bit         WT_CE;
	always_comb begin
		case (WTCSR.CKS)
			3'b000: WT_CE = CLK2_CE;
			3'b001: WT_CE = CLK64_CE;
			3'b010: WT_CE = CLK128_CE;
			3'b011: WT_CE = CLK256_CE;
			3'b100: WT_CE = CLK512_CE;
			3'b101: WT_CE = CLK1024_CE;
			3'b110: WT_CE = CLK4096_CE;
			3'b111: WT_CE = CLK8192_CE;
		endcase
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			// synopsys translate_off
			WDTOVF_N <= 1;
			WRES <= 0;
			// synopsys translate_onn
		end
		else begin
			if (!RES_N) begin
				WDTOVF_N <= 1;
				WRES <= 0;
			end else if (EN && CE_R && !DISABLE) begin
				if (WT_CE) begin
					if (WTCNT == 8'hFF && WTCSR.WTIT) begin
						WDTOVF_N <= 0;
						WRES <= RSTCSR.RSTE;
					end
				end
				
				if (!WDTOVF_N && CLK128_CE) WDTOVF_N <= 1;
				if (WRES && CLK512_CE) WRES <= 0;
			end
		end
	end	
	
	assign PRES = WRES & ~RSTCSR.RSTS;
	assign MRES = WRES &  RSTCSR.RSTS;
	
	bit          SBY_TME;
	always @(posedge CLK or negedge RST_N) begin
		bit          NMI_OLD;
		
		if (!RST_N) begin
			SBY_TME <= 0;
			// synopsys translate_off
			NMI_OLD <= 0;
			// synopsys translate_onn
		end
		else begin
			if (!RES_N) begin
				SBY_TME <= 0;
			end else if (EN && CE_R && !DISABLE) begin
				NMI_OLD <= NMI;
				if (NMI && !NMI_OLD && SBY) begin
					SBY_TME <= 1;
				end
				if (OVF) begin
					SBY_TME <= 0;
				end
			end
		end
	end	
	
	//Registers
	wire REG_SEL = (IBUS_A >= 32'hFFFFFE80 && IBUS_A <= 32'hFFFFFE8F);
	bit  [ 7: 0] OPEN_BUS;
	bit          IBUS_REQ_OLD;
	always @(posedge CLK or negedge RST_N) begin
		bit          TM_EN;
		bit          OVF_SET;
		
		if (!RST_N) begin
			// synopsys translate_off
			WTCNT  <= WTCNT_INIT;
			WTCSR  <= WTCSR_INIT;
			RSTCSR <= RSTCSR_INIT;
			// synopsys translate_on
			OVF <= 0;
			TM_EN <= 0;
			OVF_SET <= 0;
		end
		else begin
			if (!RES_N) begin
				WTCNT  <= WTCNT_INIT;
				WTCSR  <= WTCSR_INIT;
				RSTCSR <= RSTCSR_INIT;
				OVF <= 0;
				TM_EN <= 0;
				OVF_SET <= 0;
//			end else if (SBY) begin
//				WTCNT <= WTCNT_INIT;//?
//				WTCSR[7:3] <= WTCSR_INIT[7:3];
//				RSTCSR <= RSTCSR_INIT;
			end else if (EN && CE_R && !DISABLE) begin
				if (CLK2_CE) begin
					TM_EN <= WTCSR.TME | SBY_TME;
				end
				
				OVF <= 0;
				if (!TM_EN) begin
					WTCNT <= WTCNT_INIT;
					WTCSR.OVF <= 0;
				end else if (WT_CE) begin
					WTCNT <= WTCNT + 8'd1;
					if (WTCNT == 8'hFF) begin
						if (SBY_TME) begin
							OVF <= 1;
						end
						else if (!WTCSR.WTIT) begin
							WTCSR.OVF <= 1;
						end
						else begin
							RSTCSR.WOVF <= 1;
							WTCSR <= 8'h18;
						end
					end
				end
				
				if (REG_SEL && IBUS_WE && !IBUS_REQ && IBUS_REQ_OLD) begin
					if (IBUS_BA == 4'b1100 || IBUS_BA == 4'b0011) begin
						case (IBUS_A[2:0])
							3'h0: begin
								if (IBUS_DI[15:8] == 8'h5A) WTCNT <= IBUS_DI[7:0] & WTCNT_WMASK;
								else if (IBUS_DI[15:8] == 8'hA5) begin
									WTCSR[6:0] <= IBUS_DI[6:0] & WTCSR_WMASK[6:0];
									if (!IBUS_DI[7] && OVF_SET) begin WTCSR.OVF <= 0; OVF_SET <= 0; end
								end
							end
							3'h2:  begin
								if (IBUS_DI[15:8] == 8'h5A) RSTCSR[6:0] <= IBUS_DI[6:0] & RSTCSR_WMASK[6:0];
								else if (IBUS_DI[15:8] == 8'hA5 && !IBUS_DI[7]) RSTCSR[7] <= 0;
							end
							default:;
						endcase
					end
					
					case (IBUS_A[2:0])
						3'h4:    OPEN_BUS <= IBUS_DI[15:8];
						default: OPEN_BUS <= IBUS_DI[7:0];
					endcase
				end
				if (REG_SEL && !IBUS_WE && !IBUS_REQ && IBUS_REQ_OLD) begin
					case (IBUS_A[2:0])
						3'h4:;
						default: OPEN_BUS <= REG_DO;
					endcase
					if (IBUS_A[2:0] == 3'h0 && WTCSR.OVF) OVF_SET <= 1;
				end
			end
		end
	end
	
	assign ITI_IRQ = WTCSR.OVF;
	
	bit  [ 7: 0] REG_DO;
	bit  [ 1: 0] BUSY;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			REG_DO <= '0;
			BUSY <= '0;
		end
		else begin
			if (!RES_N) begin
				REG_DO <= '0;
				BUSY <= '0;
			end else if (CE_F && !DISABLE) begin
				if (REG_SEL && !IBUS_WE && IBUS_REQ && !BUSY[0]) begin
					case (IBUS_A[2:0])
						3'h0: REG_DO <= (WTCSR | 8'h18) & WTCSR_RMASK;
						3'h1: REG_DO <= WTCNT & WTCNT_RMASK;
						3'h2: REG_DO <= '1;
						3'h3: REG_DO <= (RSTCSR | 8'h1F) & RSTCSR_RMASK;
						3'h4: REG_DO <= OPEN_BUS;
						3'h5: REG_DO <= '1;
						3'h6: REG_DO <= '1;
						3'h7: REG_DO <= '1;
						default:;
					endcase
				end
			end else if (CE_R && !DISABLE) begin
				IBUS_REQ_OLD <= IBUS_REQ;
				if (REG_SEL && !IBUS_WE && IBUS_REQ && !IBUS_REQ_OLD) begin
					BUSY[0] <= 1;
				end else if (BUSY[0]) begin
					BUSY[0] <= 0;
				end
				BUSY[1] <= BUSY[0];
			end
		end
	end
	
	assign IBUS_DO = REG_SEL ? {4{REG_DO}} : '0;
	assign IBUS_BUSY = |BUSY;
	assign IBUS_ACT = REG_SEL;
	
endmodule
