module SH7604_UBC
#(parameter bit DISABLE=0)
 (
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
	output            IBUS_BUSY,
	output            IBUS_ACT,
	
	output            IRQ
);

	import SH7604_PKG::*;

	BARx_t      BARAH;
	BARx_t      BARAL;
	BAMRx_t     BAMRAL;
	BAMRx_t     BAMRAH;
	BBRx_t      BBRA;
	BARx_t      BARBH;
	BARx_t      BARBL;
	BAMRx_t     BAMRBL;
	BAMRx_t     BAMRBH;
	BDRB_t      BDRBH;
	BDRB_t      BDRBL;
	BDMRB_t     BDMRBL;
	BDMRB_t     BDMRBH;
	BBRx_t      BBRB;
	BRCR_t      BRCR;
	
	wire REG_SEL = (IBUS_A >= 32'hFFFFFF40 && IBUS_A <= 32'hFFFFFF7C);
	
	//Registers
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			// synopsys translate_off
			BARAH <= BARx_INIT;
			BARAL <= BARx_INIT;
			BAMRAL <= BAMRx_INIT;
			BAMRAH <= BAMRx_INIT;
			BBRA <= BBRx_INIT;
			BARBH <= BARx_INIT;
			BARBL <= BARx_INIT;
			BAMRBL <= BAMRx_INIT;
			BAMRBH <= BAMRx_INIT;
			BDRBH <= BDRB_INIT;
			BDRBL <= BDRB_INIT;
			BDMRBL <= BDMRB_INIT;
			BDMRBH <= BDMRB_INIT;
			BBRB <= BBRx_INIT;
			BRCR <= BRCR_INIT;
			// synopsys translate_on
		end
		else if (EN && CE_R && !DISABLE) begin
			if (!RES_N) begin
				BARAH <= BARx_INIT;
				BARAL <= BARx_INIT;
				BAMRAL <= BAMRx_INIT;
				BAMRAH <= BAMRx_INIT;
				BBRA <= BBRx_INIT;
				BARBH <= BARx_INIT;
				BARBL <= BARx_INIT;
				BAMRBL <= BAMRx_INIT;
				BAMRBH <= BAMRx_INIT;
				BDRBH <= BDRB_INIT;
				BDRBL <= BDRB_INIT;
				BDMRBL <= BDMRB_INIT;
				BDMRBH <= BDMRB_INIT;
				BBRB <= BBRx_INIT;
				BRCR <= BRCR_INIT;
			end
			else if (REG_SEL && IBUS_WE && IBUS_REQ) begin
				case ({IBUS_A[5:2],2'b00})
					6'h00: begin
						if (IBUS_BA[3:2]) BARAH <= IBUS_DI[31:16] & BARx_WMASK;
						if (IBUS_BA[1:0]) BARAL <= IBUS_DI[15:0]  & BARx_WMASK;
					end
					6'h04: begin
						if (IBUS_BA[3:2]) BAMRAH <= IBUS_DI[31:16] & BAMRx_WMASK;
						if (IBUS_BA[1:0]) BAMRAL <= IBUS_DI[15:0]  & BAMRx_WMASK;
					end
					6'h08: begin
						if (IBUS_BA[3:2]) BBRA <= IBUS_DI[31:16] & BBRx_WMASK;
					end
					6'h20: begin
						if (IBUS_BA[3:2]) BARBH <= IBUS_DI[31:16] & BARx_WMASK;
						if (IBUS_BA[1:0]) BARBL <= IBUS_DI[15:0]  & BARx_WMASK;
					end
					6'h24: begin
						if (IBUS_BA[3:2]) BAMRBH <= IBUS_DI[31:16] & BAMRx_WMASK;
						if (IBUS_BA[1:0]) BAMRBL <= IBUS_DI[15:0]  & BAMRx_WMASK;
					end
					6'h28: begin
						if (IBUS_BA[3:2]) BBRB <= IBUS_DI[31:16] & BBRx_WMASK;
					end
					6'h30: begin
						if (IBUS_BA[3:2]) BDRBH <= IBUS_DI[31:16] & BDRB_WMASK;
						if (IBUS_BA[1:0]) BDRBL <= IBUS_DI[15:0]  & BDRB_WMASK;
					end
					6'h34: begin
						if (IBUS_BA[3:2]) BDMRBH <= IBUS_DI[31:16] & BDMRB_WMASK;
						if (IBUS_BA[1:0]) BDMRBL <= IBUS_DI[15:0]  & BDMRB_WMASK;
					end
					6'h38: begin
						if (IBUS_BA[3:2]) BRCR <= IBUS_DI[31:16] & BRCR_WMASK;
					end
					default:;
				endcase
			end
		end
	end
	
	assign IRQ = 0;
	
	
	bit [31:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			// synopsys translate_off
			REG_DO <= '0;
			// synopsys translate_on
		end
		else begin
			if (!RES_N) begin
				REG_DO <= '0;
			end else if (CE_F && !DISABLE) begin
				if (REG_SEL && !IBUS_WE && IBUS_REQ) begin
					case ({IBUS_A[5:2],2'b00})
						6'h00: REG_DO <= {BARAH,BARAL} & {BARx_RMASK,BARx_RMASK};
						6'h04: REG_DO <= {BAMRAH,BAMRAL} & {BAMRx_RMASK,BAMRx_RMASK};
						6'h08: REG_DO <= {BBRA,BBRA} & {BBRx_RMASK,BBRx_RMASK};
						6'h20: REG_DO <= {BARBH,BARBL} & {BARx_RMASK,BARx_RMASK};
						6'h24: REG_DO <= {BAMRBH,BAMRBL} & {BAMRx_RMASK,BAMRx_RMASK};
						6'h28: REG_DO <= {BBRB,BBRB} & {BBRx_RMASK,BBRx_RMASK};
						6'h30: REG_DO <= {BDRBH,BDRBL} & {BDRB_RMASK,BDRB_RMASK};
						6'h34: REG_DO <= {BDMRBH,BDMRBL} & {BDMRB_RMASK,BDMRB_RMASK};
						6'h38: REG_DO <= {BRCR,BRCR} & {BRCR_RMASK,BRCR_RMASK};
						default:REG_DO <= '0;
					endcase
				end
			end
		end
	end
	
	assign IBUS_DO = REG_SEL ? REG_DO : '0;
	assign IBUS_BUSY = 0;
	assign IBUS_ACT = REG_SEL;

endmodule
