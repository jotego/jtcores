module SH7604_DIVU (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	input             EN,
	
	input             RES_N,
	
	input      [31:0] IBUS_A,
	input      [31:0] IBUS_DI,
	output     [31:0] IBUS_DO,
	input       [3:0] IBUS_BA,
	input             IBUS_WE,
	input             IBUS_REQ,
	output reg        IBUS_BUSY,
	output            IBUS_ACT,
	
	output            IRQ,
	output      [7:0] VEC
);

	import SH7604_PKG::*;
	
	DVSR_t      DVSR;
	DVDNT_t     DVDNTL;
	DVDNT_t     DVDNTH;
	DVCR_t      DVCR;
	DVDNT_t     DVDNTL2;
	DVDNT_t     DVDNTH2;
	VCRDIV_t    VCRDIV;
	bit         BUSY;
	
	wire REG_SEL = (IBUS_A >= 32'hFFFFFF00 && IBUS_A <= 32'hFFFFFF3F);
	wire DIV32_START = REG_SEL && IBUS_A[4:0] == 5'h04 && IBUS_WE && IBUS_REQ;
	wire DIV64_START = REG_SEL && IBUS_A[4:0] == 5'h14 && IBUS_WE && IBUS_REQ;
	
	
	bit  [ 5: 0] STEP;
	bit          DIV64;
	bit  [64: 0] R;
	bit  [64: 0] D;
	bit  [31: 0] Q;
	bit  [63: 0] R64,D64;
	bit          R_SIGN,D_SIGN;
	bit          T64;
	bit          OVF;
	wire [64: 0] SUM = $signed(R) - $signed(D);
	wire [64: 0] SUM64 = T64 ? $signed({R64[63],R64}) - $unsigned(D64) : $signed({R64[63],R64}) + $unsigned(D64);
	always @(posedge CLK or negedge RST_N) begin
		bit  [64: 0] VAL;
		bit          NEG;
		bit  [64: 0] NRES;
		bit          OVF0,OVF64_33;
		
		if (!RST_N) begin
			STEP <= 6'h3F;
			OVF <= 0;
		end
		else if (EN && CE_F) begin
			if (STEP == 6'd1) begin
				VAL <= {DVDNTH[31],DVDNTH,DVDNTL};
				NEG <= DVDNTH[31];
			end
			if (STEP == 6'd2) begin
				VAL <= {DVSR[31],DVSR,32'h00000000};
				NEG <= DVSR[31];
			end
//			if (STEP >= 6'd3 && STEP <= 6'd35) begin
//				SA <= R;
//				SB <= D;
//			end
			if (STEP == 6'd36) begin
				VAL <= R;
				NEG <= R_SIGN;
			end
			if (STEP == 6'd37) begin
				VAL <= {{33{Q[31]}},Q};
				NEG <= R_SIGN^D_SIGN;
			end
		end
		else if (EN && CE_R) begin
			if (STEP != 6'h3F) begin
				STEP <= STEP + 6'd1;
			end
			if (STEP == 6'h3F && (DIV32_START || DIV64_START)) begin
				STEP <= 6'd0;
				DIV64 <= DIV64_START;
				OVF0 <= 0;
				OVF <= 0;
			end
			
			NRES = (VAL^{65{NEG}}) + {{64{1'b0}},NEG};
			if (STEP == 6'd0) begin
				Q <= '0;
			end
			if (STEP == 6'd1) begin
				R <= NRES;
				R_SIGN <= NEG;
				R64 <= VAL[63:0];
			end
			if (STEP == 6'd2) begin
				D <= NRES;
				D_SIGN <= NEG;
				D64 <= VAL[63:0];
				T64 <= ~(R_SIGN^NEG);
				
				if (VAL[63:32] == 32'h00000000) OVF0 <= 1;
			end
			if (STEP >= 6'd3 && STEP <= 6'd35) begin
				R <= !SUM[64] ? SUM : R;
				Q <= {Q[30:0],~SUM[64]};
				D <= {D[64],D[64:1]};
				
				if (STEP >= 6'd3 && STEP <= 6'd5) begin
				R64 <= {SUM64[62:0],~(SUM64[63]^D_SIGN)};
				T64 <= ~(SUM64[63]^D_SIGN);
				end
				
				if (STEP == 6'd4) begin
					OVF64_33 <= T64; 
				end
				if (STEP == 6'd5 && (OVF0 || ((OVF64_33 != T64 || (OVF64_33 != (R_SIGN^D_SIGN) && T64 != (R_SIGN^D_SIGN))) && DIV64))) begin
					OVF <= 1; 
					R <= SUM;
					STEP <= 6'd38;
				end
			end
			if (STEP == 6'd36) begin
				R <= NRES;
			end
			if (STEP == 6'd37) begin
				Q <= NRES[31:0];
			end
			if (STEP == 6'd38) begin
				STEP <= 6'h3F;
			end
		end
	end
	
	wire OPERATE = (STEP != 6'h3F);
	
	
	//Registers
	always @(posedge CLK or negedge RST_N) begin
		bit          SND_UPD;
		
		if (!RST_N) begin
			DVSR <= DVSR_INIT;
			DVDNTL <= DVDNT_INIT;
			DVDNTH <= DVDNT_INIT;
			DVCR <= DVCR_INIT;
			VCRDIV <= VCRDIV_INIT;
			DVDNTL2 <= DVDNT_INIT;
			DVDNTH2 <= DVDNT_INIT;
			// synopsys translate_off
			
			// synopsys translate_on
		end
		else if (CE_R) begin
			if (!RES_N) begin
				DVSR <= DVSR_INIT;
				DVDNTL <= DVDNT_INIT;
				DVDNTH <= DVDNT_INIT;
				DVCR <= DVCR_INIT;
				VCRDIV <= VCRDIV_INIT;
				DVDNTL2 <= DVDNT_INIT;
				DVDNTH2 <= DVDNT_INIT;
			end
			else if (REG_SEL && IBUS_WE && IBUS_REQ && !OPERATE) begin
				case ({IBUS_A[4:2],2'b00})
					5'h00: DVSR <= IBUS_DI & DVSR_WMASK;
					5'h04: {DVDNTH,DVDNTL} <= {{32{IBUS_DI[31]}},IBUS_DI} & {DVDNT_WMASK,DVDNT_WMASK};
					5'h08: begin
						if (IBUS_BA[3:2]) DVCR[31:16] <= IBUS_DI[31:16] & DVCR_WMASK[31:16];
						if (IBUS_BA[1:0]) DVCR[15:0]  <= IBUS_DI[15:0]  & DVCR_WMASK[15:0];
					end
					5'h0C: begin
						if (IBUS_BA[1:0]) VCRDIV[15:0] <= IBUS_DI[15:0] & VCRDIV_WMASK[15:0];
					end
					5'h10: DVDNTH <= IBUS_DI & DVDNT_WMASK;
					5'h14: DVDNTL <= IBUS_DI & DVDNT_WMASK;
					5'h18: DVDNTH2 <= IBUS_DI & DVDNT_WMASK;
					5'h1C: DVDNTL2 <= IBUS_DI & DVDNT_WMASK;
					default:;
				endcase
			end
			
			SND_UPD <= 0;
			if (STEP >= 6'd3 && STEP <= 6'd35) begin
				{DVDNTH,DVDNTL} <= {DVDNTH[30:0],DVDNTL,~SUM[64]^R_SIGN};
			end
			if (STEP == 6'd37) begin
				DVDNTH <= R[31:0];
			end
			if (STEP == 6'd38) begin
				if (OVF) begin
					if (!DVCR.OVFIE) begin
						DVDNTL <= {R_SIGN^D_SIGN,{31{~(R_SIGN^D_SIGN)}}};
						if (DIV64) DVDNTH <= R64[63:32];
					end else  begin
						if (DIV64) DVDNTL <= R64[31:0];
						if (DIV64) DVDNTH <= R64[63:32];
					end
					DVCR.OVF <= 1;
				end else begin
					DVDNTL <= Q;
				end
				SND_UPD <= 1;
			end
			
			if (SND_UPD) begin
				DVDNTL2 <= DVDNTL;
				DVDNTH2 <= DVDNTH;
			end
		end
	end
	
	assign IRQ = DVCR.OVF & DVCR.OVFIE;
	assign VEC = VCRDIV[7:0];
	
	
	bit [31:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			REG_DO <= '0;
		end
		else if (CE_F) begin
			if (REG_SEL && !IBUS_WE && IBUS_REQ) begin
				case ({IBUS_A[4:2],2'b00})
					5'h00: REG_DO <= DVSR & DVSR_RMASK;
					5'h04: REG_DO <= DVDNTL & DVDNT_RMASK;
					5'h08: REG_DO <= DVCR & DVCR_RMASK;
					5'h0C: REG_DO <= {16'h0000,VCRDIV} & VCRDIV_RMASK;
					5'h10: REG_DO <= DVDNTH & DVDNT_RMASK;
					5'h14: REG_DO <= DVDNTL & DVDNT_RMASK;
					5'h18: REG_DO <= DVDNTH2 & DVDNT_RMASK;
					5'h1C: REG_DO <= DVDNTL2 & DVDNT_RMASK;
					default:REG_DO <= '0;
				endcase
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			BUSY <= 0;
		end
		else if (EN && CE_F) begin
			if (REG_SEL && IBUS_REQ && OPERATE && !BUSY) begin
				BUSY <= 1;
			end else if (!OPERATE && BUSY) begin
				BUSY <= 0;
			end
		end
	end
	
	assign IBUS_DO = REG_SEL ? (IBUS_BA != 4'b1111 ? {2{REG_DO[15:0]}} : REG_DO) : '0;
	assign IBUS_BUSY = BUSY;
	assign IBUS_ACT = REG_SEL;

endmodule
