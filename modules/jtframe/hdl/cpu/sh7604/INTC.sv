module SH7604_INTC (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	input             EN,
	
	input             RES_N,
	input             NMI_N,
	input       [3:0] IRL_N,
	
	input       [3:0] INT_MASK,
	input             INT_ACK,
	input             INT_ACP,
	output reg  [3:0] INT_LVL,
	output reg  [7:0] INT_VEC,
	output            INT_REQ,
	
	input             VECT_REQ,
	output            VECT_WAIT,
	
	output reg        NMI_REQ,
	
	input      [31:0] IBUS_A,
	input      [31:0] IBUS_DI,
	output     [31:0] IBUS_DO,
	input       [3:0] IBUS_BA,
	input             IBUS_WE,
	input             IBUS_REQ,
	output            IBUS_BUSY,
	output            IBUS_ACT,
	
	output      [3:0] VBUS_A,
	input       [7:0] VBUS_DI,
	output            VBUS_REQ,
	input             VBUS_WAIT,
	
	input             UBC_IRQ,
	input             DIVU_IRQ,
	input       [7:0] DIVU_VEC,
	input             DMAC0_IRQ,
	input       [7:0] DMAC0_VEC,
	input             DMAC1_IRQ,
	input       [7:0] DMAC1_VEC,
	input             WDT_IRQ,
	input             BSC_IRQ,
	input             SCI_ERI_IRQ,
	input             SCI_RXI_IRQ,
	input             SCI_TXI_IRQ,
	input             SCI_TEI_IRQ,
	input             FRT_ICI_IRQ,
	input             FRT_OCI_IRQ,
	input             FRT_OVI_IRQ
);

	import SH7604_PKG::*;
	
	ICR_t      ICR;
	IPRA_t     IPRA;
	IPRB_t     IPRB;
	VCRWDT_t   VCRWDT;
	VCRA_t     VCRA;
	VCRB_t     VCRB;
	VCRC_t     VCRC;
	VCRD_t     VCRD;
	
	const bit [ 3:0] NMI_INT     = 4'd1;
	const bit [ 3:0] UBC_INT     = 4'd2;
	const bit [ 3:0] IRL_INT     = 4'd3; 
	const bit [ 3:0] DIVU_INT    = 4'd4;
	const bit [ 3:0] DMAC0_INT   = 4'd5;
	const bit [ 3:0] DMAC1_INT   = 4'd6;
	const bit [ 3:0] WDT_INT     = 4'd7;
	const bit [ 3:0] BSC_INT     = 4'd8;
	const bit [ 3:0] SCI_ERI_INT = 4'd9;
	const bit [ 3:0] SCI_RXI_INT = 4'd10;
	const bit [ 3:0] SCI_TXI_INT = 4'd11;
	const bit [ 3:0] SCI_TEI_INT = 4'd12;
	const bit [ 3:0] FRT_ICI_INT = 4'd13;
	const bit [ 3:0] FRT_OCI_INT = 4'd14;
	const bit [ 3:0] FRT_OVI_INT = 4'd15;
	
	bit        IRL_REQ;
	bit [ 3:0] IRL_LVL;
	bit [ 3:0] INT_ACTIVE;
	bit [ 3:0] INT_ACCEPTED;
	
	always @(posedge CLK or negedge RST_N) begin
		bit NMI_N_OLD;
		
		if (!RST_N) begin
			NMI_REQ <= 0;
		end
		else if (!RES_N) begin	
			NMI_REQ <= 0;
		end
		else if (EN && CE_R) begin	
			NMI_N_OLD <= NMI_N;
			if (!(NMI_N ^ ICR.NMIE) && (NMI_N_OLD ^ ICR.NMIE) && !NMI_REQ) begin
				NMI_REQ <= 1;
			end
			else if (INT_ACP && NMI_REQ) begin
				NMI_REQ <= 0;
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit [3:0] IRL_OLD[4];
		bit [3:0] IRL_NORM;
		
		if (!RST_N) begin
			IRL_OLD <= '{4{'1}};
			IRL_NORM <= '0;
		end
		else if (!RES_N) begin	
			IRL_OLD <= '{4{'1}};
			IRL_NORM <= '0;
		end
		else if (EN && CE_R) begin	
			IRL_OLD[0] <= ~IRL_N;
			IRL_OLD[1] <= IRL_OLD[0];
			IRL_OLD[2] <= IRL_OLD[1];
			IRL_OLD[3] <= IRL_OLD[2];
			if (IRL_OLD[0] == ~IRL_N && IRL_OLD[1] == ~IRL_N && IRL_OLD[2] == ~IRL_N && IRL_OLD[3] == ~IRL_N) begin
				IRL_LVL <= ~IRL_N;
				IRL_NORM <= ~IRL_N;
			end else begin
				IRL_LVL <= IRL_NORM;
			end
		end
	end
	assign IRL_REQ = |IRL_LVL; 
	
	always_comb begin
		if      (NMI_REQ                              ) begin INT_ACTIVE <= NMI_INT; end
		else if (UBC_IRQ     && 4'hF        > INT_MASK) begin INT_ACTIVE <= UBC_INT; end
		else if (IRL_REQ     && IRL_LVL     > INT_MASK) begin INT_ACTIVE <= IRL_INT; end
		else if (DIVU_IRQ    && IPRA.DIVUIP > INT_MASK) begin INT_ACTIVE <= DIVU_INT; end
		else if (DMAC0_IRQ   && IPRA.DMACIP > INT_MASK) begin INT_ACTIVE <= DMAC0_INT; end
		else if (DMAC1_IRQ   && IPRA.DMACIP > INT_MASK) begin INT_ACTIVE <= DMAC1_INT; end
		else if (WDT_IRQ     && IPRA.WDTIP  > INT_MASK) begin INT_ACTIVE <= WDT_INT; end
		else if (BSC_IRQ     && IPRA.WDTIP  > INT_MASK) begin INT_ACTIVE <= BSC_INT; end
		else if (SCI_ERI_IRQ && IPRB.SCIIP  > INT_MASK) begin INT_ACTIVE <= SCI_ERI_INT; end
		else if (SCI_RXI_IRQ && IPRB.SCIIP  > INT_MASK) begin INT_ACTIVE <= SCI_RXI_INT; end
		else if (SCI_TXI_IRQ && IPRB.SCIIP  > INT_MASK) begin INT_ACTIVE <= SCI_TXI_INT; end
		else if (SCI_TEI_IRQ && IPRB.SCIIP  > INT_MASK) begin INT_ACTIVE <= SCI_TEI_INT; end
		else if (FRT_ICI_IRQ && IPRB.FRTIP  > INT_MASK) begin INT_ACTIVE <= FRT_ICI_INT; end
		else if (FRT_OCI_IRQ && IPRB.FRTIP  > INT_MASK) begin INT_ACTIVE <= FRT_OCI_INT; end
		else if (FRT_OVI_IRQ && IPRB.FRTIP  > INT_MASK) begin INT_ACTIVE <= FRT_OVI_INT; end
		else                                            begin INT_ACTIVE <= '0; end
	end
	assign INT_REQ = |INT_ACTIVE;
	
	always_comb begin
		case (INT_ACTIVE)
			NMI_INT:     INT_LVL <= 4'hF;
			UBC_INT:     INT_LVL <= 4'hF;
			IRL_INT:     INT_LVL <= IRL_LVL;
			DIVU_INT:    INT_LVL <= IPRA.DIVUIP;
			DMAC0_INT:   INT_LVL <= IPRA.DMACIP;
			DMAC1_INT:   INT_LVL <= IPRA.DMACIP;
			WDT_INT:     INT_LVL <= IPRA.WDTIP;
			BSC_INT:     INT_LVL <= IPRA.WDTIP;
			SCI_ERI_INT: INT_LVL <= IPRB.SCIIP;
			SCI_RXI_INT: INT_LVL <= IPRB.SCIIP;
			SCI_TXI_INT: INT_LVL <= IPRB.SCIIP;
			SCI_TEI_INT: INT_LVL <= IPRB.SCIIP;
			FRT_ICI_INT: INT_LVL <= IPRB.FRTIP;
			FRT_OCI_INT: INT_LVL <= IPRB.FRTIP;
			FRT_OVI_INT: INT_LVL <= IPRB.FRTIP;
			default:     INT_LVL <= 4'h0;
		endcase
	end
	
	bit  [ 3: 0] IRL_LVL_SAVE;
	wire [ 7: 0] IRL_VEC = !ICR.VECMD ? {5'b01000,IRL_LVL_SAVE[3:1]} : VBUS_DI;
	always_comb begin
		case (INT_ACCEPTED)
			NMI_INT:     INT_VEC <= 8'd11;
			UBC_INT:     INT_VEC <= 8'd12;
			IRL_INT:     INT_VEC <= IRL_VEC;
			DIVU_INT:    INT_VEC <= DIVU_VEC;
			DMAC0_INT:   INT_VEC <= DMAC0_VEC;
			DMAC1_INT:   INT_VEC <= DMAC1_VEC;
			WDT_INT:     INT_VEC <= {1'b0,VCRWDT.WITV};
			BSC_INT:     INT_VEC <= {1'b0,VCRWDT.BCMV};
			SCI_ERI_INT: INT_VEC <= {1'b0,VCRA.SERV};
			SCI_RXI_INT: INT_VEC <= {1'b0,VCRA.SRXV};
			SCI_TXI_INT: INT_VEC <= {1'b0,VCRB.STXV};
			SCI_TEI_INT: INT_VEC <= {1'b0,VCRB.STEV};
			FRT_ICI_INT: INT_VEC <= {1'b0,VCRC.FICV};
			FRT_OCI_INT: INT_VEC <= {1'b0,VCRC.FOCV};
			FRT_OVI_INT: INT_VEC <= {1'b0,VCRD.FOVV};
			default:     INT_VEC <= 8'd0;
		endcase
	end
	
	bit [3:0] VBA;
	bit       VBREQ;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			VBREQ <= 0;
			VBA <= '0;
			INT_ACCEPTED <= '0;
		end else if (EN && CE_F) begin	
			if (VECT_REQ && !VBREQ) begin
				VBREQ <= 1;
				VBA <= INT_MASK;
			end else if (VBREQ && !VBUS_WAIT) begin
				VBREQ <= 0;
			end
		end else if (EN && CE_R) begin	
			if (INT_ACP) begin 
				INT_ACCEPTED <= INT_ACTIVE; 
				IRL_LVL_SAVE <= IRL_LVL; 
			end
			if (INT_ACK) INT_ACCEPTED <= '0;
		end
	end
	assign VECT_WAIT = VBREQ;
	
	assign VBUS_A   = VBA;
	assign VBUS_REQ = VBREQ && INT_ACCEPTED == IRL_INT && ICR.VECMD;
	
	
	//Registers
	wire REG_SEL = (IBUS_A >= 32'hFFFFFE60 & IBUS_A <= 32'hFFFFFE69) | (IBUS_A >= 32'hFFFFFEE0 & IBUS_A <= 32'hFFFFFEE5);
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			ICR    <= ICR_INIT;
			IPRA   <= IPRA_INIT;
			IPRB   <= IPRB_INIT;
			VCRWDT <= VCRWDT_INIT;
			VCRA   <= VCRA_INIT;
			VCRB   <= VCRB_INIT;
			VCRC   <= VCRC_INIT;
			VCRD   <= VCRD_INIT;
		end
		else if (CE_R) begin
			if (!RES_N) begin
				ICR    <= ICR_INIT;
				IPRA   <= IPRA_INIT;
				IPRB   <= IPRB_INIT;
				VCRWDT <= VCRWDT_INIT;
				VCRA   <= VCRA_INIT;
				VCRB   <= VCRB_INIT;
				VCRC   <= VCRC_INIT;
				VCRD   <= VCRD_INIT;
				ICR.NMIL <= NMI_N;
			end
			else begin
				if (REG_SEL && IBUS_WE && IBUS_REQ) begin
					case ({IBUS_A[7:1],1'b0})
						8'h60: begin
							if (IBUS_BA[3]) IPRB[15:8] = IBUS_DI[31:24] & IPRB_WMASK[15:8];
							if (IBUS_BA[2]) IPRB[ 7:0] = IBUS_DI[23:16] & IPRB_WMASK[ 7:0];
						end
						8'h62: begin
							if (IBUS_BA[1]) VCRA[15:8] = IBUS_DI[15:8] & VCRA_WMASK[15:8];
							if (IBUS_BA[0]) VCRA[ 7:0] = IBUS_DI[ 7:0] & VCRA_WMASK[ 7:0];
						end
						8'h64: begin
							if (IBUS_BA[3]) VCRB[15:8] = IBUS_DI[31:24] & VCRB_WMASK[15:8];
							if (IBUS_BA[2]) VCRB[ 7:0] = IBUS_DI[23:16] & VCRB_WMASK[ 7:0];
						end
						8'h66: begin
							if (IBUS_BA[1]) VCRC[15:8] = IBUS_DI[15:8] & VCRC_WMASK[15:8];
							if (IBUS_BA[0]) VCRC[ 7:0] = IBUS_DI[ 7:0] & VCRC_WMASK[ 7:0];
						end
						8'h68: begin
							if (IBUS_BA[3]) VCRD[15:8] = IBUS_DI[31:24] & VCRD_WMASK[15:8];
							if (IBUS_BA[2]) VCRD[ 7:0] = IBUS_DI[23:16] & VCRD_WMASK[ 7:0];
						end
						8'hE0: begin
							if (IBUS_BA[3]) ICR[15:8] = IBUS_DI[31:24] & ICR_WMASK[15:8];
							if (IBUS_BA[2]) ICR[ 7:0] = IBUS_DI[23:16] & ICR_WMASK[ 7:0];
						end
						8'hE2: begin
							if (IBUS_BA[1]) IPRA[15:8] = IBUS_DI[15:8] & IPRA_WMASK[15:8];
							if (IBUS_BA[0]) IPRA[ 7:0] = IBUS_DI[ 7:0] & IPRA_WMASK[ 7:0];
						end
						8'hE4: begin
							if (IBUS_BA[3]) VCRWDT[15:8] = IBUS_DI[31:24] & VCRWDT_WMASK[15:8];
							if (IBUS_BA[2]) VCRWDT[ 7:0] = IBUS_DI[23:16] & VCRWDT_WMASK[ 7:0];
						end
						default:;
					endcase
				end
				ICR.NMIL <= NMI_N;
			end
		end
	end
	
	bit [31:0] BUS_DO;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			BUS_DO <= '0;
		end
		else if (CE_F) begin
			if (REG_SEL && !IBUS_WE && IBUS_REQ) begin
				case ({IBUS_A[7:1],1'b0})
					8'h60: BUS_DO <= {2{IPRB & IPRB_RMASK}};
					8'h62: BUS_DO <= {2{VCRA & VCRA_RMASK}};
					8'h64: BUS_DO <= {2{VCRB & VCRB_RMASK}};
					8'h66: BUS_DO <= {2{VCRC & VCRC_RMASK}};
					8'h68: BUS_DO <= {2{VCRD & VCRD_RMASK}};
					8'hE0: BUS_DO <= {2{ICR & ICR_RMASK}};
					8'hE2: BUS_DO <= {2{IPRA & IPRA_RMASK}};
					8'hE4: BUS_DO <= {2{VCRWDT & VCRWDT_RMASK}};
					default:BUS_DO <= '0;
				endcase
			end
		end
	end
	
	assign IBUS_DO = BUS_DO;
	assign IBUS_BUSY = 0;
	assign IBUS_ACT = REG_SEL;

endmodule
