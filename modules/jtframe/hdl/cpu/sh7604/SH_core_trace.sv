module SH_core_trace
	import SH2_PKG::*;
(
	input             CLK,
	input             RST_N,
	input             RES_N,
	input             EN,
	input             CE,
	input      [31:0] PC,
	input      [31:0] GBR,
	input      [31:0] VBR,
	input        SR_t SR,
	input PipelineState_t PIPE,
	input  DecInstr_t ID_DECI,
	input      [31:0] MA_RDATA,
	input      [31:0] RD_SAVE,
	input      [31:0] BUS_DI,
	input       [3:0] MA_BA,
	input       [2:0] STATE,
	input             SLP,
	input             IF_STALL,
	input             ID_STALL,
	input             EX_STALL,
	input             MA_STALL,
	input             WB_STALL,
	input             BUS_WAIT,
	input             IF_ACTIVE,
	input             MA_ACTIVE,
	input             VECT_ACTIVE,
	input             INST_SPLIT,
	input             IFID_STALL,
	input             MAWB_STALL,
	input             INT_REQ,
	input             INT_REQ_LATCH,
	input             INT_ACP,
	input      [31:0] CTRL_WD,
	input       [4:0] REGS_WAN,
	input      [31:0] REGS_WAD,
	input             REGS_WAE,
	input       [4:0] REGS_WBN,
	input      [31:0] REGS_WBD,
	input             REGS_WBE
`ifdef VERILATOR_KEEP_CPU
	,input      [31:0] R0_RAW,
	input      [31:0] R1_RAW,
	input      [31:0] R2_RAW,
	input      [31:0] R3_RAW,
	input      [31:0] R4_RAW,
	input      [31:0] R5_RAW,
	input      [31:0] R6_RAW,
	input      [31:0] R7_RAW,
	input      [31:0] R8_RAW,
	input      [31:0] R9_RAW,
	input      [31:0] R10_RAW,
	input      [31:0] R11_RAW,
	input      [31:0] R12_RAW,
	input      [31:0] R13_RAW,
	input      [31:0] R14_RAW,
	input      [31:0] R15_RAW,
	input      [31:0] PR_RAW
`endif
);

`ifdef VERILATOR_KEEP_CPU

/* verilator tracing_on */
	bit [31:0] TRACE_PC;
	bit [31:0] TRACE_COMMIT_PC;
	bit [31:0] TRACE_GBR;
	bit [31:0] TRACE_VBR;
	bit [31:0] TRACE_SR;
	bit [31:0] TRACE_EX_PC;
	bit [31:0] TRACE_MA_PC;
	bit [31:0] TRACE_WB_PC;
	bit [31:0] TRACE_DBG_PC;
	bit [31:0] TRACE_DBG_SR;
	bit [31:0] TRACE_DBG_R0;
	bit [31:0] TRACE_DBG_R1;
	bit [31:0] TRACE_DBG_R2;
	bit [31:0] TRACE_DBG_R3;
	bit [31:0] TRACE_DBG_R4;
	bit [31:0] TRACE_DBG_R5;
	bit [31:0] TRACE_DBG_R6;
	bit [31:0] TRACE_DBG_R7;
	bit [31:0] TRACE_DBG_R8;
	bit [31:0] TRACE_DBG_R9;
	bit [31:0] TRACE_DBG_R10;
	bit [31:0] TRACE_DBG_R11;
	bit [31:0] TRACE_DBG_R12;
	bit [31:0] TRACE_DBG_R13;
	bit [31:0] TRACE_DBG_R14;
	bit [31:0] TRACE_DBG_R15;
	bit [31:0] TRACE_DBG_PR;
	bit [31:0] TRACE_R0;
	bit [31:0] TRACE_R1;
	bit [31:0] TRACE_R2;
	bit [31:0] TRACE_R3;
	bit [31:0] TRACE_R4;
	bit [31:0] TRACE_R5;
	bit [31:0] TRACE_R6;
	bit [31:0] TRACE_R7;
	bit [31:0] TRACE_R8;
	bit [31:0] TRACE_R9;
	bit [31:0] TRACE_R10;
	bit [31:0] TRACE_R11;
	bit [31:0] TRACE_R12;
	bit [31:0] TRACE_R13;
	bit [31:0] TRACE_R14;
	bit [31:0] TRACE_R15;
	bit [31:0] TRACE_PR;
	bit  [1:0] TRACE_EX_MEM_SZ;
	bit  [1:0] TRACE_MA_MEM_SZ;
	bit [31:0] TRACE_MA_ADDR;
	bit [31:0] TRACE_MA_RDATA;
	bit [31:0] TRACE_RD_SAVE;
	bit [31:0] TRACE_BUS_DI;
	bit [31:0] TRACE_MA_WD;
	bit  [3:0] TRACE_MA_BA;
	bit  [2:0] TRACE_STATE;
	bit        TRACE_SLEEP;
	bit        TRACE_IF_STALL;
	bit        TRACE_ID_STALL;
	bit        TRACE_EX_STALL;
	bit        TRACE_MA_STALL;
	bit        TRACE_WB_STALL;
	bit        TRACE_BUS_WAIT;
	bit        TRACE_IF_ACTIVE;
	bit        TRACE_MA_ACTIVE;
	bit        TRACE_VECT_ACTIVE;
	bit        TRACE_INST_SPLIT;
	bit        TRACE_IFID_STALL;
	bit        TRACE_MAWB_STALL;
	bit        TRACE_INT_REQ;
	bit        TRACE_INT_REQ_LATCH;
	bit        TRACE_INT_ACCEPT;
	bit        TRACE_INT_ENTRY;
	bit        TRACE_STACK_BUSY;
	bit        TRACE_VALID;
	bit [31:0] TRACE_SEQ;
	bit        TRACE_COMMIT_DLY;
	bit [31:0] TRACE_PC_DLY;
	bit [31:0] TRACE_GBR_DLY;
	bit [31:0] TRACE_VBR_DLY;
	bit [31:0] TRACE_SR_DLY;
	bit [31:0] TRACE_R0_DLY;
	bit [31:0] TRACE_R1_DLY;
	bit [31:0] TRACE_R2_DLY;
	bit [31:0] TRACE_R3_DLY;
	bit [31:0] TRACE_R4_DLY;
	bit [31:0] TRACE_R5_DLY;
	bit [31:0] TRACE_R6_DLY;
	bit [31:0] TRACE_R7_DLY;
	bit [31:0] TRACE_R8_DLY;
	bit [31:0] TRACE_R9_DLY;
	bit [31:0] TRACE_R10_DLY;
	bit [31:0] TRACE_R11_DLY;
	bit [31:0] TRACE_R12_DLY;
	bit [31:0] TRACE_R13_DLY;
	bit [31:0] TRACE_R14_DLY;
	bit [31:0] TRACE_R15_DLY;
	bit [31:0] TRACE_PR_DLY;
/* verilator tracing_off */

	wire TRACE_REG_WRITE = REGS_WAE | REGS_WBE;
	wire TRACE_COMMIT    = EN && CE && !WB_STALL && (!INST_SPLIT | TRACE_REG_WRITE);
	wire [31:0] TRACE_NEXT_PC = PIPE.WB.DI.PCW ? PIPE.WB.RES : PIPE.WB.PC + 32'd2;
	wire TRACE_STACK_BUSY_NX =
		((PIPE.EX.DI.RA.N == SP) & (PIPE.EX.DI.RA.R | PIPE.EX.DI.RA.W)) |
		((PIPE.EX.DI.RB.N == SP) & (PIPE.EX.DI.RB.R | PIPE.EX.DI.RB.W)) |
		((PIPE.MA.DI.RA.N == SP) & (PIPE.MA.DI.RA.R | PIPE.MA.DI.RA.W)) |
		((PIPE.MA.DI.RB.N == SP) & (PIPE.MA.DI.RB.R | PIPE.MA.DI.RB.W)) |
		((PIPE.WB.DI.RA.N == SP) & (PIPE.WB.DI.RA.R | PIPE.WB.DI.RA.W)) |
		((PIPE.WB.DI.RB.N == SP) & (PIPE.WB.DI.RB.R | PIPE.WB.DI.RB.W));
	bit [31:0] CTRL_WD_MA, CTRL_WD_WB;

	function bit trace_reg_match(input [4:0] wn, input [3:0] rn);
		trace_reg_match = !wn[4] && wn[3:0] == rn;
	endfunction

	function bit trace_pr_match(input [4:0] wn);
		trace_pr_match = wn[4];
	endfunction

	function [31:0] trace_gr_next(input [3:0] rn, input [31:0] raw_value);
		if (REGS_WBE && trace_reg_match(REGS_WBN, rn)) begin
			trace_gr_next = REGS_WBD;
		end else if (REGS_WAE && trace_reg_match(REGS_WAN, rn)) begin
			trace_gr_next = REGS_WAD;
		end else begin
			trace_gr_next = raw_value;
		end
	endfunction

	function [31:0] trace_pr_next(input [31:0] raw_value);
		if (REGS_WBE && trace_pr_match(REGS_WBN)) begin
			trace_pr_next = REGS_WBD;
		end else if (REGS_WAE && trace_pr_match(REGS_WAN)) begin
			trace_pr_next = REGS_WAD;
		end else begin
			trace_pr_next = raw_value;
		end
	endfunction

	task clear_trace;
		begin
			TRACE_PC            <= '0;
			TRACE_COMMIT_PC     <= '0;
			TRACE_GBR           <= '0;
			TRACE_VBR           <= '0;
			TRACE_SR            <= '0;
			TRACE_EX_PC         <= '0;
			TRACE_MA_PC         <= '0;
			TRACE_WB_PC         <= '0;
			TRACE_DBG_PC        <= '0;
			TRACE_DBG_SR        <= '0;
			TRACE_DBG_R0        <= '0;
			TRACE_DBG_R1        <= '0;
			TRACE_DBG_R2        <= '0;
			TRACE_DBG_R3        <= '0;
			TRACE_DBG_R4        <= '0;
			TRACE_DBG_R5        <= '0;
			TRACE_DBG_R6        <= '0;
			TRACE_DBG_R7        <= '0;
			TRACE_DBG_R8        <= '0;
			TRACE_DBG_R9        <= '0;
			TRACE_DBG_R10       <= '0;
			TRACE_DBG_R11       <= '0;
			TRACE_DBG_R12       <= '0;
			TRACE_DBG_R13       <= '0;
			TRACE_DBG_R14       <= '0;
			TRACE_DBG_R15       <= '0;
			TRACE_DBG_PR        <= '0;
			TRACE_R0            <= '0;
			TRACE_R1            <= '0;
			TRACE_R2            <= '0;
			TRACE_R3            <= '0;
			TRACE_R4            <= '0;
			TRACE_R5            <= '0;
			TRACE_R6            <= '0;
			TRACE_R7            <= '0;
			TRACE_R8            <= '0;
			TRACE_R9            <= '0;
			TRACE_R10           <= '0;
			TRACE_R11           <= '0;
			TRACE_R12           <= '0;
			TRACE_R13           <= '0;
			TRACE_R14           <= '0;
			TRACE_R15           <= '0;
			TRACE_PR            <= '0;
			TRACE_EX_MEM_SZ     <= '0;
			TRACE_MA_MEM_SZ     <= '0;
			TRACE_MA_ADDR       <= '0;
			TRACE_MA_RDATA      <= '0;
			TRACE_RD_SAVE       <= '0;
			TRACE_BUS_DI        <= '0;
			TRACE_MA_WD         <= '0;
			TRACE_MA_BA         <= '0;
			TRACE_STATE         <= '0;
			TRACE_SLEEP         <= '0;
			TRACE_IF_STALL      <= '0;
			TRACE_ID_STALL      <= '0;
			TRACE_EX_STALL      <= '0;
			TRACE_MA_STALL      <= '0;
			TRACE_WB_STALL      <= '0;
			TRACE_BUS_WAIT      <= '0;
			TRACE_IF_ACTIVE     <= '0;
			TRACE_MA_ACTIVE     <= '0;
			TRACE_VECT_ACTIVE   <= '0;
			TRACE_INST_SPLIT    <= '0;
			TRACE_IFID_STALL    <= '0;
			TRACE_MAWB_STALL    <= '0;
			TRACE_INT_REQ       <= '0;
			TRACE_INT_REQ_LATCH <= '0;
			TRACE_INT_ACCEPT    <= '0;
			TRACE_INT_ENTRY     <= '0;
			TRACE_STACK_BUSY    <= '0;
			TRACE_VALID         <= '0;
			TRACE_SEQ           <= '0;
			TRACE_COMMIT_DLY    <= '0;
			TRACE_PC_DLY        <= '0;
			TRACE_GBR_DLY       <= '0;
			TRACE_VBR_DLY       <= '0;
			TRACE_SR_DLY        <= '0;
			TRACE_R0_DLY        <= '0;
			TRACE_R1_DLY        <= '0;
			TRACE_R2_DLY        <= '0;
			TRACE_R3_DLY        <= '0;
			TRACE_R4_DLY        <= '0;
			TRACE_R5_DLY        <= '0;
			TRACE_R6_DLY        <= '0;
			TRACE_R7_DLY        <= '0;
			TRACE_R8_DLY        <= '0;
			TRACE_R9_DLY        <= '0;
			TRACE_R10_DLY       <= '0;
			TRACE_R11_DLY       <= '0;
			TRACE_R12_DLY       <= '0;
			TRACE_R13_DLY       <= '0;
			TRACE_R14_DLY       <= '0;
			TRACE_R15_DLY       <= '0;
			TRACE_PR_DLY        <= '0;
			CTRL_WD_MA          <= '0;
			CTRL_WD_WB          <= '0;
		end
	endtask

	task latch_debug_trace;
		begin
			TRACE_DBG_PC        <= PC;
			TRACE_PC            <= PC;
			TRACE_DBG_SR        <= SR & 32'h0000_03f3;
			TRACE_DBG_R0        <= R0_RAW;
			TRACE_DBG_R1        <= R1_RAW;
			TRACE_DBG_R2        <= R2_RAW;
			TRACE_DBG_R3        <= R3_RAW;
			TRACE_DBG_R4        <= R4_RAW;
			TRACE_DBG_R5        <= R5_RAW;
			TRACE_DBG_R6        <= R6_RAW;
			TRACE_DBG_R7        <= R7_RAW;
			TRACE_DBG_R8        <= R8_RAW;
			TRACE_DBG_R9        <= R9_RAW;
			TRACE_DBG_R10       <= R10_RAW;
			TRACE_DBG_R11       <= R11_RAW;
			TRACE_DBG_R12       <= R12_RAW;
			TRACE_DBG_R13       <= R13_RAW;
			TRACE_DBG_R14       <= R14_RAW;
			TRACE_DBG_R15       <= R15_RAW;
			TRACE_DBG_PR        <= PR_RAW;
			TRACE_EX_PC         <= PIPE.EX.PC;
			TRACE_MA_PC         <= PIPE.MA.PC;
			TRACE_WB_PC         <= PIPE.WB.PC;
			TRACE_EX_MEM_SZ     <= PIPE.EX.DI.MEM.SZ;
			TRACE_MA_MEM_SZ     <= PIPE.MA.DI.MEM.SZ;
			TRACE_MA_ADDR       <= PIPE.MA.ADDR;
			TRACE_MA_RDATA      <= MA_RDATA;
			TRACE_RD_SAVE       <= RD_SAVE;
			TRACE_BUS_DI        <= BUS_DI;
			TRACE_MA_WD         <= PIPE.MA.WD;
			TRACE_MA_BA         <= MA_BA;
			TRACE_STATE         <= STATE;
			TRACE_SLEEP         <= SLP;
			TRACE_IF_STALL      <= IF_STALL;
			TRACE_ID_STALL      <= ID_STALL;
			TRACE_EX_STALL      <= EX_STALL;
			TRACE_MA_STALL      <= MA_STALL;
			TRACE_WB_STALL      <= WB_STALL;
			TRACE_BUS_WAIT      <= BUS_WAIT;
			TRACE_IF_ACTIVE     <= IF_ACTIVE;
			TRACE_MA_ACTIVE     <= MA_ACTIVE;
			TRACE_VECT_ACTIVE   <= VECT_ACTIVE;
			TRACE_INST_SPLIT    <= INST_SPLIT;
			TRACE_IFID_STALL    <= IFID_STALL;
			TRACE_MAWB_STALL    <= MAWB_STALL;
			TRACE_INT_REQ       <= INT_REQ;
			TRACE_INT_REQ_LATCH <= INT_REQ_LATCH;
			TRACE_INT_ACCEPT    <= INT_ACP;
			TRACE_INT_ENTRY     <= VECT_ACTIVE | PIPE.EX.DI.VECR | PIPE.MA.DI.VECR | PIPE.WB.DI.VECR;
			TRACE_STACK_BUSY    <= TRACE_STACK_BUSY_NX;
		end
	endtask

	task latch_ctrl_trace;
		begin
			if (!EX_STALL) begin
				CTRL_WD_MA <= CTRL_WD;
			end
			if (!MA_STALL && !INST_SPLIT) begin
				CTRL_WD_WB <= CTRL_WD_MA;
			end else if (!(IF_ACTIVE & BUS_WAIT) && MAWB_STALL) begin
				CTRL_WD_WB <= CTRL_WD_MA;
			end
		end
	endtask

	task latch_commit_trace;
		begin
			TRACE_VALID <= TRACE_COMMIT_DLY;
			if (TRACE_COMMIT_DLY) begin
				TRACE_SEQ <= TRACE_SEQ + 32'd1;
				TRACE_COMMIT_PC <= TRACE_PC_DLY;
				TRACE_R0  <= TRACE_R0_DLY;
				TRACE_R1  <= TRACE_R1_DLY;
				TRACE_R2  <= TRACE_R2_DLY;
				TRACE_R3  <= TRACE_R3_DLY;
				TRACE_R4  <= TRACE_R4_DLY;
				TRACE_R5  <= TRACE_R5_DLY;
				TRACE_R6  <= TRACE_R6_DLY;
				TRACE_R7  <= TRACE_R7_DLY;
				TRACE_R8  <= TRACE_R8_DLY;
				TRACE_R9  <= TRACE_R9_DLY;
				TRACE_R10 <= TRACE_R10_DLY;
				TRACE_R11 <= TRACE_R11_DLY;
				TRACE_R12 <= TRACE_R12_DLY;
				TRACE_R13 <= TRACE_R13_DLY;
				TRACE_R14 <= TRACE_R14_DLY;
				TRACE_R15 <= TRACE_R15_DLY;
				TRACE_PR  <= TRACE_PR_DLY;
				TRACE_SR  <= TRACE_SR_DLY;
				TRACE_GBR <= TRACE_GBR_DLY;
				TRACE_VBR <= TRACE_VBR_DLY;
			end
			TRACE_COMMIT_DLY <= TRACE_COMMIT;
			if (TRACE_COMMIT) begin
				TRACE_PC_DLY  <= TRACE_NEXT_PC;
				TRACE_R0_DLY  <= trace_gr_next(4'd0, R0_RAW);
				TRACE_R1_DLY  <= trace_gr_next(4'd1, R1_RAW);
				TRACE_R2_DLY  <= trace_gr_next(4'd2, R2_RAW);
				TRACE_R3_DLY  <= trace_gr_next(4'd3, R3_RAW);
				TRACE_R4_DLY  <= trace_gr_next(4'd4, R4_RAW);
				TRACE_R5_DLY  <= trace_gr_next(4'd5, R5_RAW);
				TRACE_R6_DLY  <= trace_gr_next(4'd6, R6_RAW);
				TRACE_R7_DLY  <= trace_gr_next(4'd7, R7_RAW);
				TRACE_R8_DLY  <= trace_gr_next(4'd8, R8_RAW);
				TRACE_R9_DLY  <= trace_gr_next(4'd9, R9_RAW);
				TRACE_R10_DLY <= trace_gr_next(4'd10, R10_RAW);
				TRACE_R11_DLY <= trace_gr_next(4'd11, R11_RAW);
				TRACE_R12_DLY <= trace_gr_next(4'd12, R12_RAW);
				TRACE_R13_DLY <= trace_gr_next(4'd13, R13_RAW);
				TRACE_R14_DLY <= trace_gr_next(4'd14, R14_RAW);
				TRACE_R15_DLY <= trace_gr_next(4'd15, R15_RAW);
				TRACE_PR_DLY  <= trace_pr_next(PR_RAW);
				TRACE_SR_DLY  <= SR & 32'h0000_03f3;
				TRACE_GBR_DLY <= GBR;
				TRACE_VBR_DLY <= VBR;
			end
		end
	endtask

	always @(posedge CLK) begin
		if (!RST_N || !RES_N) begin
			clear_trace();
		end else begin
			latch_debug_trace();
			latch_ctrl_trace();
			latch_commit_trace();
		end
	end

`endif

endmodule
