module SH7604_SCI 
#(parameter bit DISABLE=0)
(
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	input             EN,
	
	input             RES_N,
	
	input             RXD,
	output reg        TXD,
	output            SCKO,
	input             SCKI,
	
	input             CLK4_CE,
	input             CLK16_CE,
	input             CLK64_CE,
	input             CLK256_CE,
	
	input      [31:0] IBUS_A,
	input      [31:0] IBUS_DI,
	output     [31:0] IBUS_DO,
	input       [3:0] IBUS_BA,
	input             IBUS_WE,
	input             IBUS_REQ,
	output            IBUS_BUSY,
	output            IBUS_ACT,
	
	output            TEI_IRQ,
	output            TXI_IRQ,
	output            RXI_IRQ,
	output            ERI_IRQ
);

	import SH7604_PKG::*;

	RDR_t       RDR;
	TDR_t       TDR;
	SMR_t       SMR;
	SCR_t       SCR;
	SSR_t       SSR;
	BRR_t       BRR;
	bit   [7:0] RSR;
	bit   [7:0] TSR;
	bit         TEI;
	bit         TXI;
	bit         RXI;
	bit         ERI;
	
	bit         SCE_R;
	bit         SCE_F;
	bit         TX_RUN;
	
	wire REG_SEL = (IBUS_A >= 32'hFFFFFE00 && IBUS_A <= 32'hFFFFFE05);
//	wire SSR_READ = REG_SEL && IBUS_A[2:0] == 3'h4 && !IBUS_WE && IBUS_REQ;
	wire SSR_WRITE = REG_SEL && IBUS_A[2:0] == 3'h4 && IBUS_WE && IBUS_REQ;
	
	//Baud rate generator
	bit         INT_SCK;
	bit         INT_CE_R;
	bit         INT_CE_F;
	bit         EXT_CE_R;
	bit         EXT_CE_F;
	always @(posedge CLK or negedge RST_N) begin
		bit   [12:0] CNT;
		bit         CS_CE;
		bit         SCKI_OLD;
		
		if (!RST_N) begin
			// synopsys translate_off
			INT_CE_R <= 0;
			INT_CE_F <= 0;
			EXT_CE_R <= 0;
			EXT_CE_F <= 0;
			// synopsys translate_on
			CNT <= '0;
			SCKI_OLD <= 0;
		end
		else if (EN && CE_R && !DISABLE) begin
			case (SMR.CKS)
				2'b00: CS_CE = CLK4_CE;
				2'b01: CS_CE = CLK16_CE;
				2'b10: CS_CE = CLK64_CE;
				2'b11: CS_CE = CLK256_CE;
			endcase
				
			INT_CE_R <= 0;
			INT_CE_F <= 0;
			if (CS_CE) begin
				CNT <= CNT + 13'd1;
				if (SMR.CA)  begin
					if (CNT[9:0] == {1'b0,BRR,1'b1}) begin
						INT_CE_R <= 1;
					end
					else if (CNT[9:0] == {BRR,2'b11}) begin
						CNT <= '0;
						INT_CE_F <= 1;
					end
				end else begin
					if (CNT == {1'b0,BRR,4'b1111}) begin
						INT_CE_R <= 1;
					end
					else if (CNT == {BRR,5'b11111}) begin
						CNT <= '0;
						INT_CE_F <= 1;
					end
				end
			end
			
			EXT_CE_R <= 0;
			EXT_CE_F <= 0;
			SCKI_OLD <= SCKI;
			if (!SCKI && SCKI_OLD) EXT_CE_F <= 1;
			else if (SCKI && !SCKI_OLD) EXT_CE_R <= 1;
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			// synopsys translate_off
			INT_SCK <= 1;
			// synopsys translate_on
		end
		else begin
			if (!RES_N) begin
				INT_SCK <= 1;
			end else if (EN && CE_R && !DISABLE) begin
				if (INT_CE_R)
					INT_SCK <= 1;
				else if (INT_CE_F) 
					INT_SCK <= 0;
			end
		end
	end
	
	assign SCE_R = !SCR.CKE[1] || !SMR.CA ? INT_CE_R : EXT_CE_R;
	assign SCE_F = !SCR.CKE[1] || !SMR.CA ? INT_CE_F : EXT_CE_F;
	
	//Transmitter
	always @(posedge CLK or negedge RST_N) begin
		bit [3:0] TBIT_CNT;
		bit       LAST_BIT;
		bit       PB;
		bit       TX_PRERUN;
		
		if (!RST_N) begin
			// synopsys translate_off
			TXD <= 1;
			SSR.TDRE <= 1;
			SSR.TEND <= 1;
			TSR <= '0;
			TXI <= 0;
			TEI <= 0;
			TBIT_CNT <= '0;
			TX_RUN <= 0;
			// synopsys translate_on
		end
		else begin
			if (!RES_N) begin
				TXD <= 1;
				SSR.TDRE <= 1;
				SSR.TEND <= 1;
				TSR <= '0;
				TXI <= 0;
				TEI <= 0;
				TBIT_CNT <= '0;
				TX_RUN <= 0;
			end else if (EN && CE_R && !DISABLE) begin
				LAST_BIT    = SMR.CA ? TBIT_CNT == 4'd7 : TBIT_CNT == 4'd11;
				
				if (!SSR.TDRE && LAST_BIT && SCE_R) begin
					TSR <= TDR;
					SSR.TDRE <= 1;
					TXI <= 1;
				end
				else if (SSR.TDRE && LAST_BIT && SCE_R) begin
					SSR.TEND <= 1;
					TEI <= 1;
				end
				
				if (SSR_WRITE) begin
					if (!IBUS_DI[31] && SSR.TDRE && SCR.TE) begin
						SSR.TDRE <= 0;
						TEI <= 0;
						SSR.TEND <= 0;
						TBIT_CNT <= SMR.CA ? 4'd7 : 4'd11;
						TXI <= 0;
					end
				end
				
				if (SCE_F) begin
					TX_PRERUN <= 0;
					if (!SSR.TEND && !TX_PRERUN && !TX_RUN) 
						TX_PRERUN <= 1;
					else if (TX_PRERUN) 
						TX_RUN <= 1;
					else if (SSR.TEND && LAST_BIT) 
						TX_RUN <= 0;
						
					if (TX_PRERUN || TX_RUN) begin
						if (SMR.CA) begin
							TXD <= TSR[0];
							TSR <= {1'b0,TSR[7:1]};
							TBIT_CNT <= !LAST_BIT ? TBIT_CNT + 4'd1 : 4'd0;
						end else begin
							if (TBIT_CNT == 4'd0) begin
								TXD <= 0;
								PB <= 0;
								TBIT_CNT <= TBIT_CNT + 4'd1;
							end else if (TBIT_CNT <= 4'd8) begin
								TXD <= TSR[0];
								TSR <= {1'b0,TSR[7:1]};
								PB <= PB + TSR[0];
								TBIT_CNT <= SMR.PE || TBIT_CNT != 4'd8 ? TBIT_CNT + 4'd1 : TBIT_CNT + 4'd2;
							end else if (TBIT_CNT == 4'd9) begin
								TXD <= PB ^ ~SMR.OE;
								TBIT_CNT <= SMR.STOP ? TBIT_CNT + 4'd1 : TBIT_CNT + 4'd2;
							end else begin
								TXD <= 1;
								TBIT_CNT <= !LAST_BIT ? TBIT_CNT + 4'd1 : 4'd0;
							end
						end
					end
				end
			end
		end
	end
	
	//Receiver
	bit RX_RUN;
	always @(posedge CLK or negedge RST_N) begin
		bit [3:0] RBIT_CNT;
		bit       LAST_BIT;
		bit       REC_END;
		bit       PB;
		
		if (!RST_N) begin
			// synopsys translate_off
			RDR <= '0;
			RSR <= '0;
			SSR.RDRF <= 0;
			SSR.ORER <= 0;
			SSR.FER <= 0;
			SSR.PER <= 0;
			SSR.MPB <= 0;
			SSR.MPBT <= 0;
			RXI <= 0;
			ERI <= 0;
			RX_RUN <= 0; 
			RBIT_CNT <= '0;
			REC_END <= 0;
			// synopsys translate_on
		end
		else begin
			if (!RES_N) begin
				RDR <= '0;
				RSR <= '0;
				SSR.RDRF <= 0;
				SSR.ORER <= 0;
				SSR.FER <= 0;
				SSR.PER <= 0;
				SSR.MPB <= 0;
				SSR.MPBT <= 0;
				RXI <= 0;
				ERI <= 0;
				RX_RUN <= 0; 
				RBIT_CNT <= '0;
				REC_END <= 0;
			end else if (EN && CE_R && !DISABLE) begin			
				if (SCE_F) begin
					if (RBIT_CNT == 4'd0) RX_RUN <= 1;
				end
				
				if (SCE_R) begin
					if (SMR.CA) begin
						if ((TX_RUN && !SCR.CKE[1]) || (RX_RUN && SCR.CKE[1])) begin
							RSR <= {RXD,RSR[7:1]};
							RBIT_CNT <= RBIT_CNT + 4'd1;
							if (RBIT_CNT == 4'd7) begin
								RBIT_CNT <= 4'd0;
								RX_RUN <= 0; 
								REC_END <= 1;
							end
						end
					end else begin
						if (RBIT_CNT == 4'd0) begin
							if (!RXD) begin
								PB <= 0;
								RBIT_CNT <= RBIT_CNT + 4'd1;
							end
						end else if (RBIT_CNT <= 4'd8) begin
							RSR <= {RXD,RSR[7:1]};
							PB <= PB + RXD;
							RBIT_CNT <= SMR.PE || RBIT_CNT != 4'd8 ? RBIT_CNT + 4'd1 : RBIT_CNT + 4'd2;
						end else if (RBIT_CNT == 4'd9) begin
							SSR.PER <= PB ^ RXD;
							RBIT_CNT <= SMR.STOP ? RBIT_CNT + 4'd1 : RBIT_CNT + 4'd2;
						end else begin
							SSR.FER <= ~RXD;
							RBIT_CNT <= RBIT_CNT + 4'd1;
							if (RBIT_CNT == 4'd11) begin
								RBIT_CNT <= 4'd0;
								REC_END <= 1;
							end
						end
					end
				end
				
				if (REC_END) begin
					if (!SSR.RDRF && SCR.RE) begin
						RDR <= RSR;
						SSR.RDRF <= 1;
						RXI <= 1;
					end
					else if (SSR.RDRF && SCR.RE) begin
						SSR.ORER <= 1;
						ERI <= 1;
					end
				REC_END <= 0;
				end
				
				if (SSR_WRITE) begin
					if (!IBUS_DI[30] && SSR.RDRF && SCR.RE) begin
						SSR.RDRF <= 0;
						RXI <= 0;
					end
					if (!IBUS_DI[29] && SSR.ORER && SCR.RE) begin
						SSR.ORER <= 0;
						ERI <= 0;
					end
					if (!IBUS_DI[28] && SSR.FER && SCR.RE) begin
						SSR.FER <= 0;
						ERI <= 0;
					end
					if (!IBUS_DI[27] && SSR.PER && SCR.RE) begin
						SSR.PER <= 0;
						ERI <= 0;
					end
					SSR.MPBT <= IBUS_DI[24];
				end
			end
		end
	end
	
	assign SCKO = INT_SCK | ~TX_RUN | SCR.CKE[1];
	
	assign TEI_IRQ = TEI & SCR.TEIE;
	assign TXI_IRQ = TXI & SCR.TIE;
	assign RXI_IRQ = RXI & SCR.RIE;
	assign ERI_IRQ = ERI & SCR.RIE;
	
	
	//Registers
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			// synopsys translate_off
			TDR <= TDR_INIT;
			SMR <= SMR_INIT;
			SCR <= SCR_INIT;
			BRR <= BRR_INIT;
			// synopsys translate_on
		end
		else begin
			if (!RES_N) begin
				TDR <= TDR_INIT;
				SMR <= SMR_INIT;
				SCR <= SCR_INIT;
				BRR <= BRR_INIT;
			end else if (EN && CE_R && !DISABLE) begin
				if (REG_SEL && IBUS_WE && IBUS_REQ) begin
					case (IBUS_A[2:0])
						3'h0: SMR <= IBUS_DI[31:24] & SMR_WMASK;
						3'h1: BRR <= IBUS_DI[23:16] & BRR_WMASK;
						3'h2: SCR <= IBUS_DI[15:8] & SCR_WMASK;
						3'h3: TDR <= IBUS_DI[7:0] & TDR_WMASK;
						default:;
					endcase
				end
			end
		end
	end
	
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
			end else if (EN && CE_F && !DISABLE) begin
				if (REG_SEL && !IBUS_WE && IBUS_REQ) begin
					case (IBUS_A[2:0])
						3'h0: REG_DO <= {4{SMR & SMR_WMASK}};
						3'h1: REG_DO <= {4{BRR & BRR_WMASK}};
						3'h2: REG_DO <= {4{SCR & SCR_WMASK}};
						3'h3: REG_DO <= {4{TDR & TDR_WMASK}};
						3'h4: REG_DO <= {4{SSR & SSR_RMASK}};
						3'h5: REG_DO <= {4{RDR & RDR_RMASK}};
						default:;
					endcase
				end
			end
		end
	end
	
	assign IBUS_DO = REG_SEL ? REG_DO : 8'h00;
	assign IBUS_BUSY = 0;
	assign IBUS_ACT = REG_SEL;
	
endmodule
