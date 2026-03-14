module SH7604_MULT (
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
	output            CBUS_BUSY,
	
	input       [1:0] MAC_SEL,
	input       [3:0] MAC_OP,
	input             MAC_S,
	input             MAC_WE
);

	import SH7604_PKG::*;
	
	bit [31:0] MACL;
	bit [31:0] MACH;
	bit [31:0] MA;
	bit [31:0] MB;
	bit        MM_DONE;
	
	wire [63:0] SRES =   $signed(MA) *   $signed(MB);
	wire [63:0] URES = $unsigned(MA) * $unsigned(MB);
	wire [63:0] ACC64  = $signed({MACH,MACL}) + $signed(SRES);
	wire [32:0] ACC32  = $signed({MACL[31],MACL}) + $signed(SRES[32:0]);
	
	always @(posedge CLK or negedge RST_N) begin
		bit [ 1: 0] MM_CYC;
		bit         MUL_EXEC;
		bit         DMUL_EXEC;
		bit         MACW_EXEC;
		bit         MACL_EXEC;
		bit         SAT;
		bit         SIGNED;
		bit [15: 0] DW;
		
		if (!RST_N) begin
			MACL <= '0;
			MACH <= '0;
			MA <= '0;
			MB <= '0;
			MM_DONE <= 1;
			MM_CYC <= '0;
			MUL_EXEC <= 0;
			DMUL_EXEC <= 0;
			MACW_EXEC <= 0;
			MACL_EXEC <= 0;
			SIGNED <= 0;
			// synopsys translate_off
			MACL <= 32'h01234567;
			MACH <= 32'h89ABCDEF;
			// synopsys translate_on
		end
		else begin
			if (MAC_SEL && MAC_WE && EN && CE_R) begin
				MM_DONE <= 1;
				case (MAC_OP) 
					4'b0100,			//LDS Rm,MACx
					4'b1000: begin	//LDS @Rm+,MACx
						if (MAC_SEL[0]) MACL <= CBUS_DI;
						if (MAC_SEL[1]) MACH <= CBUS_DI;
					end
					4'b0001,				//MUL.L
					4'b0010,				//DMULU.L
					4'b0011: begin		//DMULS.L
						if (MAC_SEL[0]) MA <= CBUS_DI;
						if (MAC_SEL[1]) begin
							MB <= CBUS_DI;
							MUL_EXEC <= ~MAC_OP[1];
							DMUL_EXEC <= MAC_OP[1];
							SIGNED <= MAC_OP[0] & MAC_OP[1];
							MM_CYC <= 2'd3;
							MM_DONE <= 0;
						end
					end
					4'b0110,				//MULU.W
					4'b0111: begin		//MULS.W
						MA <= {{16{CBUS_DI[15]&MAC_OP[0]}},CBUS_DI[15:0]};
						MB <= {{16{CBUS_DI[31]&MAC_OP[0]}},CBUS_DI[31:16]};
						MUL_EXEC <= MAC_SEL[1];
						SIGNED <= MAC_OP[0];
						MM_CYC <= 2'd1;
						MM_DONE <= 0;
					end
					4'b1001: begin		//MAC.L @Rm+,@Rn+
						if (MAC_SEL[1]) MA <= CBUS_DI;
						if (MAC_SEL[0]) begin
							MB <= CBUS_DI;
							MACL_EXEC <= 1;
							SIGNED <= MAC_OP[0];
							SAT <= MAC_S;
							MM_CYC <= 2'd3;
							MM_DONE <= 0;
						end
					end
					4'b1011: begin		//MAC.W @Rm+,@Rn+
						DW = !CBUS_A[1] ? CBUS_DI[31:16] : CBUS_DI[15:0];
						if (MAC_SEL[1]) MA <= {{16{DW[15]&MAC_OP[0]}},DW};
						if (MAC_SEL[0]) begin
							MB <= {{16{DW[15]&MAC_OP[0]}},DW};
							MACW_EXEC <= 1;
							SIGNED <= MAC_OP[0];
							SAT <= MAC_S;
							MM_CYC <= 2'd1;
							MM_DONE <= 0;
						end
					end
					4'b1111: {MACH,MACL} <= '0;
				endcase
			end
			
			if (!MM_DONE && CE_R) begin
				if (MM_CYC) MM_CYC <= MM_CYC - 2'd1;
				if (MM_CYC == 2'd1) MM_DONE <= 1;
			end
			
			if (MUL_EXEC) begin
				if (SIGNED) MACL <= SRES[31:0];
				else        MACL <= URES[31:0];
				MUL_EXEC <= 0;
			end
			
			if (DMUL_EXEC) begin
				if (SIGNED) {MACH,MACL} <= SRES;
				else        {MACH,MACL} <= URES;
				DMUL_EXEC <= 0;
			end
			
			if (MACW_EXEC) begin
				if (!SAT) begin
					{MACH,MACL} <= ACC64;
				end else begin
					if (ACC32[32] != ACC32[31]) begin
						MACL <= {ACC32[32],{31{~ACC32[32]}}};
						MACH <= ACC64[63:32] | 32'h00000001;
					end else begin
						MACL <= ACC32[31:0];
//						MACH <= 32'h00000000;//??
					end
				end
				MACW_EXEC <= 0;
			end
			
			if (MACL_EXEC) begin
				if (!SAT) begin
					{MACH,MACL} <= ACC64;
				end else begin
					if (ACC64[63:48] != {16{ACC64[47]}}) begin
						{MACH,MACL} <= {{17{MA[31]^MB[31]}},{47{~(MA[31]^MB[31])}}};
					end else begin
						{MACH,MACL} <= ACC64;
					end
				end
				MACL_EXEC <= 0;
			end
		end
	end
	
	assign CBUS_DO = MAC_SEL[1] ? MACH : MACL;
	assign CBUS_BUSY = ~MM_DONE && |MAC_SEL;

endmodule
