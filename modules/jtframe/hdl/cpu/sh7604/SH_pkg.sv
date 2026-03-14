package SH2_PKG;

	typedef enum bit[2:0] {
		GRX = 3'b000,
		SCR = 3'b001,  
		BPC = 3'b010,
		IPC = 3'b011,
		TPC = 3'b100
	} RegSource_t;
	
	typedef enum bit[1:0] {
		REGA = 2'b00, 
		REGB = 2'b01,
		REGC = 2'b10
	} ALUSource_t;
	
	typedef enum bit[2:0] {
		ZIMM4 = 3'b000,
		SIMM8 = 3'b001,
		ZIMM8 = 3'b010,
		SIMM12 = 3'b011,
		ZERO = 3'b100,
		ONE = 3'b101,
		VECT = 3'b110
	} IMMType_t;
	
	typedef enum bit[1:0] {
		ALUA = 2'b00,
		ALUB = 2'b01,
		ALURES = 2'b10
	} AddrSrc_t;
	
	typedef enum bit[2:0] {
		ADD = 3'b000, 
		LOG = 3'b001, 
		EXT = 3'b010,
		SHIFT = 3'b011,
		DIV = 3'b100,
		NOP = 3'b101
	} ALUType_t;
	
	typedef enum bit[1:0] {
		BYTE = 2'b00,
		WORD = 2'b01,
		LONG = 2'b10
	} MemSize_t;

	typedef enum bit[1:0] {
		SR_ = 2'b00,
		GBR_ = 2'b01,
		VBR_ = 2'b10
	} CtrlReg_t;
	
	typedef enum bit[2:0] {
		LOAD = 3'b000,
		ALU = 3'b001,
		DIV0S = 3'b010,
		DIV0U = 3'b011,
		IMSK = 3'b100
	} SRSet_t;
	
	typedef enum bit[1:0] {
		NOB = 2'b00,
		CB = 2'b01,
		UCB = 2'b10
	} BranchType_t;
	
	
	typedef struct packed
	{
		RegSource_t  RSA;		//REGA source
		RegSource_t  RSB;		//REGB source
		bit          RSC;		//REGC source (0-R0, 1-IMM)
		bit          PCM;		//PC masked
		bit          BPWBA;	//Bypass register A from WB.RES
		bit          BPLDA;	//Bypass register A from WB.RD
		bit          BPMAB;	//Bypass register B from MA.RES
	} Datapath_t;
	
	parameter bit RSC_REG = 1'b0;
	parameter bit RSC_IMM = 1'b1;
	
	typedef struct packed
	{
		bit          SA;
		bit          SB;
		ALUType_t    OP;		//ALU operation type
		bit [3:0]    CD;		//ALU operation code
		bit [2:0]    CMP;		//CMP operation code
	} ALU_t;
	
	typedef struct packed
	{
		AddrSrc_t    ADDS;	//Address source
		AddrSrc_t    WDS;		//Write data source
		bit [1:0]    SZ;		//Memory access size
		bit          R;		//Data memory read
		bit          W;		//Data memory write
	} Mem_t;
	
	typedef struct packed
	{
		bit [4:0]    N;		//Register address
		bit          R;		//Register read
		bit          W;		//Register write
	} Reg_t;
	
	typedef struct packed
	{
		bit [1:0]    S;		//MAC register select
		bit          R;		//MAC register read
		bit          W;		//MAC register write
		bit [3:0]    OP;		//MAC operation
	} MAC_t;
	
	typedef struct packed
	{
		bit          W;		//System control register write
		CtrlReg_t    S;		//System control register select
		SRSet_t      SRS;		//SR register set
	} Control_t;
	
	typedef struct packed
	{
		bit          BI;		//Branch instruction
		BranchType_t BT;		//Branch type
		bit          BD;		//Branch delayed
		bit          BCV;		//Branch condition value
		bit          BSR;		//Branch subrouting
	} Branch_t;
	
	typedef struct packed
	{
		Datapath_t   DP;
		IMMType_t    IMMT;	//Immediate type
		ALU_t        ALU;
		Mem_t        MEM;
		Reg_t        RA;
		Reg_t        RB;
		bit          R0R;		//Register 0 read
		bit          PCW;		//PC write
		Control_t    CTRL;
		MAC_t        MAC;
		Branch_t     BR;
		bit          TAS;		//TAS instruction
		bit          SLP;		//SLEEP instruction
		bit [2:0]    LST;		//Last state
		bit          IACP;	//Interrupt accepted
		bit          VECR;
		bit          ILI;		//Illegal instruction
	} DecInstr_t;

	parameter DecInstr_t DECI_RESET = '{'{GRX, GRX, 0, 0, 0, 0, 0},
												 SIMM8,
												 '{0, 0, NOP, 4'b0000, 3'b000},
												 '{ALURES, ALUB, BYTE, 0, 0},
												 '{5'd0, 0, 0},
												 '{5'd0, 0, 0},
												 0,
												 0,
												 '{0, SR_, LOAD},
												 '{2'b00, 0, 0, 4'b0000},
												 '{0, NOB, 0, 0, 0},
												 1'b0,
												 1'b0,
												 3'b000,
												 1'b0,
												 1'b0,
												 1'b0};
	
	parameter bit [4:0] R0 = 5'b00000;
	parameter bit [4:0] SP = 5'b01111;
	parameter bit [4:0] PR = 5'b10000;
	
	function DecInstr_t Decode(input [15:0] IR, input [2:0] STATE,	input BC, input VER);
		DecInstr_t DECI;
		bit [4:0] RAN, RBN;
		
		RAN = {1'b0,IR[11:8]};
		RBN = {1'b0,IR[7:4]};
		
		DECI = DECI_RESET;
		DECI.RA.N = RAN;
		DECI.RB.N = RBN;
		case (IR[15:12])
			4'b0000:	begin
				case (IR[3:0])
					4'b0010:	begin
						case (IR[7:4])
							4'b0000,			//STC SR,Rn
							4'b0001,			//STC GBR,Rn
							4'b0010: begin	//STC VBR,Rn
								DECI.RA = '{RAN, 0, 1};
								DECI.DP.RSB = SCR;
								case (IR[5:4])
									2'b00:  DECI.CTRL = '{0, SR_,  LOAD};
									2'b01:  DECI.CTRL = '{0, GBR_, LOAD};
									default:DECI.CTRL = '{0, VBR_, LOAD};
								endcase
							end
							default: DECI.ILI = 1;
						endcase
					end
					4'b0011:	begin
						case (IR[7:4])
							4'b0000,			//BSRF Rm
							4'b0010: begin	//BRAF Rm
								if (VER == 1) begin
									case (STATE)
										3'd0: begin
											DECI.RA = '{RAN, 1, 0};
											DECI.RB = '{PR,  0, ~IR[5]};
											DECI.DP.RSB = BPC;
											DECI.ALU = '{0, 0, ADD, 4'b0000, 3'b000};
											DECI.PCW = 1;
											DECI.BR = '{1, UCB, 1, 0, ~IR[5]};
											DECI.LST = 3'd1;
										end
										3'd1: begin
											DECI.BR = '{0, UCB, 1, 0, 0};
											DECI.LST = 3'd1;
										end
										default:;
									endcase
								end else
									DECI.ILI = 1;
							end
							default: DECI.ILI = 1;
						endcase
					end
					4'b0100,4'b0101,4'b0110:	begin	//MOV.x Rm,@(R0,Rn) (Rm->(Rn+R0))
						DECI.RA = '{RAN, 1, 0};
						DECI.RB = '{RBN, 1, 0};
						DECI.R0R = 1;
						DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
						DECI.MEM = '{ALURES, ALUB, IR[1:0], 0, 1};
					end
					4'b0111: begin	//MUL.L Rm,Rn
						if (VER == 1) begin
							case (STATE)
								3'd0: begin
									DECI.RB = '{RBN, 1, 0};
									DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 0};
									DECI.MAC = '{2'b01, 0, 1, 4'b0001};
								end
								3'd1: begin
									DECI.RA = '{ RAN, 1, 0};
									DECI.MEM = '{ALURES, ALUA, 2'b10, 0, 0};
									DECI.MAC = '{2'b10, 0, 1, 4'b0001};
								end
								default:;
							endcase
							DECI.LST = 3'd1;
						end else
							DECI.ILI = 1;
					end
					4'b1000:	begin
						case (IR[11:4])
							8'b00000000,			//CLRT (0->T)
							8'b00000001: begin	//SETT (1->T)
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = IR[4] ? ONE : ZERO;
								DECI.ALU = '{0, 1, NOP, 4'b0000, 3'b000};
								DECI.CTRL = '{1, SR_, ALU};
							end
							8'b00000010: begin	//CLRMAC
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZERO;
								DECI.ALU = '{0, 1, NOP, 4'b0000, 3'b000};
								DECI.MEM = '{ALURES, ALURES, 2'b10, 0, 0};
								DECI.MAC = '{2'b11, 0, 1, 4'b1111};
							end
							default: DECI.ILI = 1;
						endcase
					end
					4'b1001:	begin
						case (IR[7:4])
							4'b0000: begin	//NOP
							end
							4'b0001: begin
								case (IR[11:8])
									4'b0000: begin	//DIV0U
										DECI.CTRL = '{1, SR_, DIV0U};
									end
									default:;
								endcase
							end
							4'b0010: begin	//MOVT Rn (1&SR->Rn)
								DECI.RA = '{RAN, 0, 1};
								DECI.DP.RSB = SCR;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{1, 0, LOG, 4'b0000, 3'b000};
								DECI.CTRL.S = SR_;
							end
							default: DECI.ILI = 1;
						endcase
					end
					4'b1010:	begin
						case (IR[7:4])
							4'b0000,			//STS MACH,Rn
							4'b0001: begin	//STS MACL,Rn
								DECI.RA = '{RAN, 0, 1};
								DECI.MEM.SZ = 2'b10;
								DECI.MAC = '{{~IR[4],IR[4]}, 1, 0, 4'b1100};
							end
							4'b0010: begin	//STS PR,Rn
								DECI.RA = '{RAN, 0, 1};
								DECI.RB = '{PR, 1, 0};
							end
							default: DECI.ILI = 1;
						endcase
					end
					4'b1011:	begin
						case (IR[11:4])
							8'b00000000: begin	//RTS (PR->PC)
								case (STATE)
									3'd0: begin
										DECI.RB = '{PR, 1, 0};
										DECI.PCW = 1;
										DECI.BR = '{1, UCB, 1, 0, 0};
										DECI.LST = 3'd1;
									end
									3'd1: begin
										DECI.BR = '{0, UCB, 1, 0, 0};
										DECI.LST = 3'd1;
									end
									default:;
								endcase
							end
							8'b00000001: begin	//SLEEP
								case (STATE)
									3'd0: begin
										DECI.SLP = 1;
									end
									3'd1:;
									default:;
								endcase
								DECI.LST = 3'd1;
							end
							8'b00000010: begin	//RTE ((R15)->PC,R15+4->R15,(R15)->SR,R15+4->R15)
								case (STATE)
									3'd0: begin
										DECI.RB = '{SP, 1, 0};
										DECI.DP.RSC = RSC_IMM;
										DECI.IMMT = ONE;
										DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
										DECI.MEM = '{ALUB, ALUB, 2'b10, 1, 0};
										end
									3'd1: begin
										DECI.RB = '{SP, 0, 1};
										DECI.DP.BPMAB = 1;
										DECI.DP.RSC = RSC_IMM;
										DECI.IMMT = ONE;
										DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
										DECI.MEM = '{ALUB, ALUB, 2'b10, 1, 0};
										end
									3'd2: begin
										DECI.DP.BPLDA = 1;
										DECI.DP.RSC = RSC_IMM;
										DECI.IMMT = ZERO;
										DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
										DECI.PCW = 1;
										DECI.BR = '{1, UCB, 1, 0, 0};
										end
									3'd3: begin
										DECI.DP.BPLDA = 1;
										DECI.DP.RSC = RSC_IMM;
										DECI.IMMT = ZERO;
										DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
										DECI.BR = '{0, UCB, 1, 0, 0};
										DECI.CTRL = '{1, SR_, LOAD};
										end
									default:;
								endcase
								DECI.LST = 3'd3;
							end
							default: DECI.ILI = 1;
						endcase
					end
					4'b1100,4'b1101,4'b1110:	begin	//MOV.x @(R0,Rm),Rn ((Rm+R0)->Rn)
						DECI.RA = '{RAN, 0, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.R0R = 1;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
						DECI.MEM = '{ALURES, ALUB, IR[1:0], 1, 0};
					end
					4'b1111: begin	//MAC.L @Rm+,@Rn+
						if (VER == 1) begin
							case (STATE)
								3'd0: begin
									DECI.RA = '{RAN, 1, 1};
									DECI.DP.RSC = RSC_IMM;
									DECI.IMMT = ONE;
									DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
									DECI.MEM = '{ALUA, ALUA, 2'b10, 1, 0};
									DECI.MAC = '{2'b10, 0, 1, 4'b1001};
								end
								3'd1: begin
									DECI.RB = '{RBN, 1, 1};
									DECI.DP.RSC = RSC_IMM;
									DECI.IMMT = ONE;
									DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
									DECI.MEM = '{ALUB, ALUB, 2'b10, 1, 0};
									DECI.MAC = '{2'b01, 0, 1, 4'b1001};
								end
								default:;
							endcase
							DECI.LST = 3'd1;
						end else
							DECI.ILI = 1;
					end
					default: DECI.ILI = 1;
				endcase
			end
			
			4'b0001:	begin	//MOV.L Rm,@(disp,Rn) (Rm->(Rn+disp*4))
				DECI.RA = '{RAN, 1, 0};
				DECI.RB = '{RBN, 1, 0};
				DECI.DP.RSC = RSC_IMM;
				DECI.IMMT = ZIMM4;
				DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
				DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 1};
			end
			
			4'b0010:	begin
				case (IR[3:0])
					4'b0000,4'b0001,4'b0010:	begin	//MOV.x Rm,@Rn (Rm->(Rn))
						DECI.RA = '{RAN, 1, 0};
						DECI.RB = '{RBN, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZERO;
						DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
						DECI.MEM = '{ALURES, ALUB, IR[1:0], 0, 1};
					end
					4'b0100,4'b0101,4'b0110:	begin	//MOV.x Rm,@-Rn (Rm->(Rn-1/2/4), Rn-1/2/4->Rn)
						DECI.RA = '{RAN, 1, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ONE;
						DECI.ALU = '{0, 1, ADD, 4'b0001, 3'b000};
						DECI.MEM = '{ALURES, ALUB, IR[1:0], 0, 1};
					end
					4'b0111:	begin	//DIV0S Rm,Rn
						DECI.RA = '{RAN, 1,0};
						DECI.RB = '{RBN, 1,0};
						DECI.CTRL = '{1, SR_, DIV0S};
					end
					4'b1000:	begin	//TST Rm,Rn
						DECI.RA = '{RAN, 1, 0};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, LOG, 4'b0000, 3'b000};///////////
						DECI.CTRL = '{1, SR_, ALU};
					end
					4'b1001:	begin	//AND Rm,Rn
						DECI.RA = '{RAN, 1, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, LOG, 4'b0000, 3'b000};
					end
					4'b1010:	begin	//XOR Rm,Rn
						DECI.RA = '{RAN, 1, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, LOG, 4'b0010, 3'b000};
					end
					4'b1011:	begin	//OR Rm,Rn
						DECI.RA = '{RAN, 1, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, LOG, 4'b0100, 3'b000};
					end
					4'b1100:	begin	//CMP/STR Rm,Rn
						DECI.RA = '{RAN, 1, 0};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, LOG, 4'b1010, 3'b000};
						DECI.CTRL = '{1, SR_, ALU};
					end
					4'b1101:	begin	//XTRCT Rm,Rn
						DECI.RA = '{RAN, 1, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, EXT, 4'b0010, 3'b000};
					end
					4'b1110,			//MULU.W Rm,Rn
					4'b1111:	begin	//MULS.W Rm,Rn
						DECI.RA = '{RAN, 1, 0};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, EXT, 4'b0011, 3'b000};
						DECI.MEM = '{ALURES, ALURES, 2'b10, 0, 0};
						DECI.MAC = '{2'b11, 0, 1, {2'b01,IR[1:0]}};
					end
					default: DECI.ILI = 1;
				endcase
			end
			
			4'b0011:	begin
				case (IR[3:0])
					4'b0000,			//CMP/EQ Rm,Rn
					4'b0010,			//CMP/HS Rm,Rn
					4'b0011,			//CMP/GE Rm,Rn
					4'b0110,			//CMP/HI Rm,Rn
					4'b0111: begin	//CMP/GT Rm,Rn
						DECI.RA = '{RAN, 1, 0};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, ADD, 4'b0101, IR[2:0]};
						DECI.CTRL = '{1, SR_, ALU};
					end
					4'b0100: begin	//DIV1 Rm,Rn
						DECI.RA = '{RAN, 1, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, DIV, 4'b0000, 3'b000};
						DECI.CTRL = '{1, SR_, ALU};
					end
					4'b0101,			//DMULU.L Rm,Rn
					4'b1101: begin	//DMULS.L Rm,Rn
						if (VER == 1) begin
							case (STATE)
								3'd0: begin
									DECI.RB = '{RBN, 1, 0};
									DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 0};
									DECI.MAC = '{2'b01, 0, 1, {3'b001,IR[3]}};
								end
								3'd1: begin
									DECI.RA = '{RAN, 1, 0};
									DECI.MEM = '{ALURES, ALUA, 2'b10, 0, 0};
									DECI.MAC = '{2'b10, 0, 1, {3'b001,IR[3]}};
								end
								default:;
							endcase
							DECI.LST = 3'd1;
						end else 
							DECI.ILI = 1;
					end
					4'b1000,			//SUB Rm,Rn
					4'b1010,			//SUBC Rm,Rn
					4'b1011: begin	//SUBV Rm,Rn
						DECI.RA = '{RAN, 1, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, ADD, {IR[1:0],IR[1]&~IR[0],1'b1}, 3'b000};
						DECI.CTRL = '{|IR[1:0], SR_, ALU};
					end
					4'b1100,			//ADD Rm,Rn
					4'b1110,			//ADDC Rm,Rn
					4'b1111: begin	//ADDV Rm,Rn
						DECI.RA = '{RAN, 1, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, ADD, {IR[1:0],IR[1]&~IR[0],1'b0}, 3'b000};
						DECI.CTRL = '{|IR[1:0], SR_, ALU};
					end
					default: DECI.ILI = 1;
				endcase
			end
			
			4'b0100:	begin
				case (IR[7:0])
					8'b00000000,			//SHLL Rn
					8'b00000001,			//SHLR Rn
					8'b00000100,			//ROTL Rn
					8'b00000101,			//ROTR Rn
					8'b00100000,			//SHAL Rn
					8'b00100001,			//SHAR Rn
					8'b00100100,			//ROTCL Rn
					8'b00100101: begin	//ROTCR Rn
						DECI.RA = '{RAN, 1, 1};
						DECI.ALU = '{0, 0, SHIFT, {1'b0,IR[2],IR[5],IR[0]}, 3'b000};
						DECI.CTRL = '{1, SR_, ALU};
					end
					8'b00000010,			//STS.L MACH,@-Rn
					8'b00010010: begin	//STS.L MACL,@-Rn
						DECI.RA = '{RAN, 1, 1};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ONE;
						DECI.ALU = '{0, 1, ADD, 4'b0001, 3'b000};
						DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 1};
						DECI.MAC = '{{~IR[4],IR[4]}, 1, 0, 4'b1110};
					end
					8'b00100010: begin	//STS.L PR,@-Rn
						DECI.RA = '{RAN, 1, 1};
						DECI.RB = '{PR, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ONE;
						DECI.ALU = '{0, 1, ADD, 4'b0001, 3'b000};
						DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 1};
					end
					8'b00000011,			//STC.L SR,@-Rn
					8'b00010011,			//STC.L GBR,@-Rn
					8'b00100011: begin	//STC.L VBR,@-Rn
						case (STATE)
							3'd0: begin
								DECI.RA = '{RAN, 1, 1};
								DECI.DP.RSB = SCR;
								case (IR[5:4])
									2'b00:  DECI.CTRL.S = SR_;
									2'b01:  DECI.CTRL.S = GBR_;
									default:DECI.CTRL.S = VBR_;
								endcase
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{0, 1, ADD, 4'b0001, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 1};
								end
							3'd1: begin
								end
							default:;
						endcase
						DECI.LST = 3'd1;
					end
					8'b00000110,			//LDS.L @Rm+,MACH
					8'b00010110: begin	//LDS.L @Rm+,MACL
						DECI.RB = '{RAN, 1, 1};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ONE;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
						DECI.MEM = '{ALUB, ALUB, 2'b10, 1, 0};
						DECI.MAC = '{{~IR[4],IR[4]}, 0, 1, 4'b1000};
					end
					8'b00100110: begin	//LDS.L @Rm+,PR
						DECI.RA = '{PR, 0, 1};
						DECI.RB = '{RAN, 1, 1};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ONE;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
						DECI.MEM = '{ALUB, ALUB, 2'b10, 1, 0};
					end
					8'b00000111,			//LDC.L @Rm+,SR
					8'b00010111,			//LDC.L @Rm+,GBR
					8'b00100111: begin	//LDC.L @Rm+,VBR
						case (STATE)
							3'd0: begin
								DECI.RB = '{RAN, 1, 1};
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
								DECI.MEM = '{ALUB, ALUB, 2'b10, 1, 0};
							end
							3'd1: begin
							end
							3'd2: begin
								DECI.DP.BPLDA = 1;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZERO;
								DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
								case (IR[5:4])
									2'b00:  DECI.CTRL = '{1, SR_, LOAD};
									2'b01:  DECI.CTRL = '{1, GBR_, LOAD};
									default:DECI.CTRL = '{1, VBR_, LOAD};
								endcase
							end
							default:;
						endcase
						DECI.LST = 3'd2;
					end
					8'b00001000,			//SHLL2 Rn
					8'b00001001,			//SHLR2 Rn
					8'b00011000,			//SHLL8 Rn
					8'b00011001,			//SHLR8 Rn
					8'b00101000,			//SHLL16 Rn
					8'b00101001: begin	//SHLR16 Rn
						DECI.RA = '{RAN, 1, 1};
						DECI.ALU = '{0, 0, SHIFT, {1'b1,IR[5],IR[4],IR[0]}, 3'b000};
					end
					8'b00001010,			//LDS Rm,MACH
					8'b00011010: begin	//LDS Rm,MACL
						DECI.RA = '{RAN, 1, 0};
						DECI.MEM = '{ALURES, ALUA, 2'b10, 0, 0};
						DECI.MAC = '{{~IR[4],IR[4]}, 0, 1, 4'b0100};
					end
					8'b00101010: begin	//LDS Rm,PR
						DECI.RA = '{RAN, 1, 0};
						DECI.RB = '{PR,  0, 1};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZERO;
						DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
					end
					8'b00001011,			//JSR @Rm
					8'b00101011: begin	//JMP @Rm
						case (STATE)
							3'd0: begin
								DECI.RA = '{RAN, 1, 0};
								DECI.RB = '{PR, 0, ~IR[5]};
								DECI.DP.RSB = BPC;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZERO;
								DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
								DECI.PCW = 1;
								DECI.BR = '{1, UCB, 1, 0, ~IR[5]};
								DECI.LST = 3'd1;
							end
							3'd1: begin
								DECI.BR = '{0, UCB, 1, 0, 0};
								DECI.LST = 3'd1;
							end
							default:;
						endcase
					end
					8'b00001110,			//LDC Rm,SR
					8'b00011110,			//LDC Rm,GBR
					8'b00101110: begin	//LDC Rm,VBR
						DECI.RB = '{RAN, 1, 0};
						case (IR[5:4])
							2'b00:  DECI.CTRL = '{1, SR_, LOAD};
							2'b01:  DECI.CTRL = '{1, GBR_, LOAD};
							default:DECI.CTRL = '{1, VBR_, LOAD};
						endcase
					end
					8'b00010000: begin	//DT Rn (Rn-1->Rn)
						if (VER == 1) begin
							DECI.RA = '{RAN, 1, 1};
							DECI.DP.RSC = RSC_IMM;
							DECI.IMMT = ONE;
							DECI.ALU = '{0, 1, ADD, 4'b0101, 3'b000};
							DECI.CTRL = '{1, SR_, ALU};
						end else
							DECI.ILI = 1;
					end
					8'b00010001,			//CMP/PZ Rn
					8'b00010101: begin	//CMP/PL Rn
						DECI.RA = '{RAN, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZERO;
						DECI.ALU = '{0, 1, ADD, 4'b0101, {IR[2],2'b11}};
						DECI.CTRL = '{1, SR_, ALU};
					end
					8'b00011011: begin	//TAS.B @Rn
						case (STATE)
							3'd0: begin
								DECI.RA = '{RAN, 1, 0};
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZERO;
								DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b00, 1, 0};
							end
							3'd1: begin
								DECI.DP.BPMAB = 1;
							end
							3'd2: begin
								DECI.DP.BPLDA = 1;
								DECI.DP.BPMAB = 1;
								DECI.ALU = '{0, 0, LOG, 4'b0100, 3'b000};
								DECI.MEM = '{ALUB, ALURES, 2'b00, 0, 1};
							end
							3'd3: begin
								DECI.DP.BPWBA = 1;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZERO;
								DECI.ALU = '{0, 1, ADD, 4'b0101, 3'b000};
								DECI.CTRL = '{1, SR_, ALU};
							end
							default:;
						endcase
						DECI.TAS = 1;
						DECI.LST = 3'd3;
					end
					8'b00001111,
					8'b00011111,
					8'b00101111,
					8'b00111111,
					8'b01001111,
					8'b01011111,
					8'b01101111,
					8'b01111111,
					8'b10001111,
					8'b10011111,
					8'b10101111,
					8'b10111111,
					8'b11001111,
					8'b11011111,
					8'b11101111,
					8'b11111111: begin	//MAC.W @Rm+,@Rn+
						case (STATE)
							3'd0: begin
								DECI.RA = '{RAN, 1, 1};
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
								DECI.MEM = '{ALUA, ALUA, 2'b01, 1, 0};
								DECI.MAC = '{2'b10, 0, 1, 4'b1011};
							end
							3'd1: begin
								DECI.RB = '{RBN, 1, 1};
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
								DECI.MEM = '{ALUB, ALUB, 2'b01, 1, 0};
								DECI.MAC = '{2'b01, 0, 1, 4'b1011};
							end
							default:;
						endcase
						DECI.LST = 3'd1;
					end
					default: DECI.ILI = 1;
				endcase
			end
			
			4'b0101:	begin	//MOV.L @(disp,Rm),Rn ((Rm+disp*4)->Rn)
				DECI.RA = '{RAN, 0, 1};
				DECI.RB = '{RBN, 1, 0};
				DECI.DP.RSC = RSC_IMM;
				DECI.IMMT = ZIMM4;
				DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
				DECI.MEM = '{ALURES, ALUB, 2'b10, 1, 0};
			end
			
			4'b0110:	begin
				case (IR[3:0])
					4'b0000,4'b0001,4'b0010:	begin	//MOV.x @Rm,Rn ((0+Rm)->Rn)
						DECI.RA = '{RAN, 0, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZERO;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
						DECI.MEM = '{ALURES, ALUB, IR[1:0], 1, 0};
					end
					4'b0011:	begin	//MOV Rm,Rn (0+Rm->Rn)
						DECI.RA = '{RAN, 0, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZERO;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
					end
					4'b0100,4'b0101,4'b0110: begin	//MOV.x @Rm+,Rn ((Rm)->Rn, (1*size)+Rm->Rm)
						DECI.RA = '{RAN, 0, 1};
						DECI.RB = '{RBN, 1, 1};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ONE;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
						DECI.MEM = '{ALUB, ALUB, IR[1:0], 1, 0};
					end
					4'b0111:	begin	//NOT Rm,Rn (0|~Rm->Rn)
						DECI.RA = '{RAN, 0, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZERO;
						DECI.ALU = '{1, 0, LOG, 4'b0101, 3'b000};
					end
					4'b1000,			//SWAP.B Rm,Rn
					4'b1001:	begin	//SWAP.W Rm,Rn
						DECI.RA = '{RAN, 0, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, EXT, {3'b000,IR[0]}, 3'b000};
					end
					4'b1010,			//NEGC Rm,Rn (0-Rm-T->Rn)
					4'b1011:	begin	//NEG Rm,Rn (0-Rm->Rn)
						DECI.RA = '{RAN, 0, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZERO;
						DECI.ALU = '{1, 0, ADD, {~IR[0],1'b0,~IR[0],1'b1}, 3'b000};
						DECI.CTRL = '{~IR[0], SR_, ALU};
					end
					4'b1100,			//EXTU.B Rm,Rn
					4'b1101,			//EXTU.W Rm,Rn
					4'b1110,			//EXTS.B Rm,Rn
					4'b1111:	begin	//EXTS.W Rm,Rn
						DECI.RA = '{RAN, 0, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.ALU = '{0, 0, EXT, {2'b01,IR[1:0]}, 3'b000};
					end
					default: DECI.ILI = 1;
				endcase
			end
			
			4'b0111:	begin	//ADD #imm,Rn
				DECI.RA = '{RAN, 1, 1};
				DECI.DP.RSC = RSC_IMM;
				DECI.IMMT = SIMM8;
				DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
			end
			
			4'b1000:	begin
				case (IR[11:8])
					4'b0000,			//MOV.B R0,@(disp,Rm) (R0->(Rm+disp))
					4'b0001:	begin	//MOV.W R0,@(disp,Rm) (R0->(Rm+disp*2))
						DECI.RA = '{R0,  1, 0};
						DECI.RB = '{RBN, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZIMM4;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
						DECI.MEM = '{ALURES, ALUA, IR[9:8], 0, 1};
					end
					4'b0100,			//MOV.B @(disp,Rm),R0 ((Rm+disp)->R0)
					4'b0101:	begin	//MOV.W @(disp,Rm),R0 ((Rm+disp*2)->R0)
						DECI.RA = '{R0,  0, 1};
						DECI.RB = '{RBN, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZIMM4;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
						DECI.MEM = '{ALURES, ALUA, IR[9:8], 1, 0};
					end
					4'b1000:	begin	//CPM/EQ #imm,R0
						DECI.RA = '{R0, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = SIMM8;
						DECI.ALU = '{0, 1, ADD, 4'b0101, 3'b000};
						DECI.CTRL = '{1, SR_, ALU};
					end
					4'b1001,			//BT label
					4'b1011:	begin	//BF label
						case (STATE)
							3'd0: begin
								DECI.DP.RSB = BPC;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = SIMM8;
								DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
								DECI.PCW = BC;
								DECI.BR = '{1, CB, 0, ~IR[9], 0};
								DECI.LST = BC ? 3'd1 : 3'd0;
							end
							3'd1: begin
								DECI.BR = '{0, CB, 0, 0, 0};
								DECI.LST = 3'd1;
							end
							default:;
						endcase
					end
					4'b1101,			//BT/S label
					4'b1111:	begin	//BF/S label
						if (VER == 1) begin
							case (STATE)
								3'd0: begin
									DECI.DP.RSB = BPC;
									DECI.DP.RSC = RSC_IMM;
									DECI.IMMT = SIMM8;
									DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
									DECI.PCW = BC;
									DECI.BR = '{1, CB, 1, ~IR[9], 0};
									DECI.LST = BC ? 3'd1 : 3'd0;
								end
								3'd1: begin
									DECI.BR = '{0, CB, 1, 0, 0};
									DECI.LST = 3'd1;
								end
								default:;
							endcase
						end else
							DECI.ILI = 1;
					end
					default: DECI.ILI = 1;
				endcase
			end
			
			4'b1001,			//MOV.W @(disp,PC),Rn ((PC+disp*2)->Rn)
			4'b1101:	begin	//MOV.L @(disp,PC),Rn ((PC+disp*4)->Rn)
				DECI.RA = '{RAN, 0, 1};
				DECI.DP.RSB = BPC;
				DECI.DP.RSC = RSC_IMM;
				DECI.DP.PCM = IR[14];
				DECI.IMMT = ZIMM8;
				DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
				DECI.MEM = '{ALURES, ALUA, {IR[14],~IR[14]}, 1, 0};
			end
			
			4'b1010,			//BRA label
			4'b1011:	begin	//BSR label
				case (STATE)
					3'd0: begin
						DECI.RB = '{PR, 0, IR[12]};
						DECI.DP.RSB = BPC;
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = SIMM12;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
						DECI.PCW = 1;
						DECI.BR = '{1, UCB, 1, 0, IR[12]};
					end
					3'd1: begin
						DECI.BR = '{0, UCB, 1, 0, 0};
					end
					default:;
				endcase
				DECI.LST = 3'd1;
			end
			
			4'b1100:	begin
				case (IR[11:8])
					4'b0000,4'b0001,4'b0010: begin	//MOV.x R0,@(disp,GBR) (R0->(GBR+disp*1/2/4))
						DECI.RA = '{R0, 1, 0};
						DECI.DP.RSB = SCR;
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZIMM8;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
						DECI.CTRL.S = GBR_;
						DECI.MEM = '{ALURES, ALUA, IR[9:8], 0, 1};
					end
					4'b0011: begin	//TRAPA @imm
						case (STATE)
							3'd0: begin
								
							end
							3'd1: begin
								DECI.RA = '{SP, 1, 1};
								DECI.DP.RSB = SCR;
								DECI.CTRL.S = SR_;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{0, 1, ADD, 4'b0001, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 1};
							end
							3'd2: begin
								DECI.RA = '{SP, 1, 1};
								DECI.DP.RSB = TPC;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{0, 1, ADD, 4'b0001, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 1};
							end
							3'd3: begin
								DECI.DP.RSB = SCR;
								DECI.CTRL.S = VBR_;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZIMM8;
								DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 1, 0};
							end
							3'd4: begin
								
							end
							3'd5: begin
								DECI.DP.BPLDA = 1;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZERO;
								DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
								DECI.PCW = 1;
								DECI.BR = '{1, UCB, 0, 0, 0};
							end
							3'd6: begin
								DECI.BR = '{0, UCB, 0, 0, 0};
							end
							default:;
						endcase
						DECI.LST = 3'd6;
					end
					4'b0100,4'b0101,4'b0110: begin	//MOV.x @(disp,GBR),R0 ((GBR+disp*1/2/4)->R0)
						DECI.RA = '{R0, 0, 1};
						DECI.DP.RSB = SCR;
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZIMM8;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
						DECI.CTRL.S = GBR_;
						DECI.MEM = '{ALURES, ALUA, IR[9:8], 1, 0};
					end
					4'b0111:	begin	//MOVA @(disp,PC),R0 ((PC+disp*4)->R0)
						DECI.RA = '{R0, 0, 1};
						DECI.DP.RSB = BPC;
						DECI.DP.RSC = RSC_IMM;
						DECI.DP.PCM = 1;
						DECI.IMMT = ZIMM8;
						DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
						DECI.MEM.SZ = 2'b10;
					end
					4'b1000:	begin	//TST #imm,R0
						DECI.RA = '{R0, 1, 0};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZIMM8;
						DECI.ALU.OP = LOG;
						DECI.ALU = '{0, 1, LOG, 4'b0000, 3'b000};
						DECI.CTRL = '{1, SR_, ALU};
					end
					4'b1001:	begin	//AND #imm,R0
						DECI.RA = '{R0, 1, 1};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZIMM8;
						DECI.ALU = '{0, 1, LOG, 4'b0000, 3'b000};
					end
					4'b1010:	begin	//XOR #imm,R0
						DECI.RA = '{R0, 1, 1};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZIMM8;
						DECI.ALU = '{0, 1, LOG, 4'b0010, 3'b000};
					end
					4'b1011:	begin	//OR #imm,R0
						DECI.RA = '{R0, 1, 1};
						DECI.DP.RSC = RSC_IMM;
						DECI.IMMT = ZIMM8;
						DECI.ALU = '{0, 1, LOG, 4'b0100, 3'b000};
					end
					4'b1100,			//TST.B #imm,@(R0,GBR)
					4'b1101,			//AND.B #imm,@(R0,GBR)
					4'b1110,			//XOR.B #imm,@(R0,GBR)
					4'b1111:	begin	//OR.B #imm,@(R0,GBR)
						case (STATE)
							3'd0: begin
								DECI.R0R = 1;
								DECI.DP.RSB = SCR;
								DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
								DECI.CTRL.S = GBR_;
								DECI.MEM = '{ALURES, ALUB, 2'b00, 1, 0};
							end
							3'd1: begin
								DECI.DP.BPMAB = 1;
							end
							3'd2: begin
								DECI.DP.RSC = RSC_IMM;
								DECI.DP.BPLDA = 1;
								DECI.DP.BPMAB = 1;
								DECI.IMMT = ZIMM8;
								case (IR[9:8])
									2'b10:  DECI.ALU = '{0, 1, LOG, 4'b0010, 3'b000};
									2'b11:  DECI.ALU = '{0, 1, LOG, 4'b0100, 3'b000};
									default:DECI.ALU = '{0, 1, LOG, 4'b0000, 3'b000};
								endcase
								DECI.MEM = '{ALUB, ALURES, 2'b00, 0, |IR[9:8]};
								DECI.CTRL = '{~|IR[9:8], SR_, ALU};
							end
							default:;
						endcase
						DECI.LST = 3'd2;
					end
					default: DECI.ILI = 1;
				endcase
			end
			
			4'b1110:	begin	//MOV #imm,Rn
				DECI.RA = '{RAN, 0, 1};
				DECI.DP.RSC = RSC_IMM;
				DECI.ALU = '{0, 1, NOP, 4'b0000, 3'b000};
			end
			
			4'b1111:	begin	
				case (IR[11:8])
					4'b0000:	begin	//Reset Exeption
						case (STATE)
							3'd0: begin
//								DECI.CTRL = '{1, SR_, IMSK};
//								DECI.IACP = 1;
							end
							3'd1: begin
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZERO;
								DECI.ALU = '{0, 1, NOP, 4'b0000, 3'b000};
								DECI.CTRL = '{1, VBR_, LOAD};
							end
							3'd2: begin
								DECI.DP.BPMAB = 1;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = VECT;
								DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 1, 0};
							end
							3'd3: begin
								DECI.DP.BPMAB = 1;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 1, 0};
							end
							3'd4: begin
								DECI.DP.BPLDA = 1;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZERO;
								DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
								DECI.PCW = 1;
								DECI.BR = '{1, UCB, 0, 0, 0};
							end
							3'd5: begin
								DECI.RA = '{SP, 0, 1};
								DECI.DP.BPLDA = 1;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZERO;
								DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
								DECI.BR = '{0, UCB, 0, 0, 0};
							end
							default:;
						endcase
						DECI.LST = 3'd5;
					end
					4'b0001:	begin	//Interrupt Exeption
						case (STATE)
							3'd0: begin
								DECI.IACP = 1;
							end
							3'd1: begin
								DECI.RA = '{SP, 1, 1};
								DECI.DP.RSB = SCR;
								DECI.CTRL.S = SR_;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{0, 1, ADD, 4'b0001, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 1};
							end
							3'd2: begin
								DECI.RA = '{SP, 1, 1};
								DECI.DP.RSB = IPC;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{0, 1, ADD, 4'b0001, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 1};
							end
							3'd3: begin
								DECI.CTRL = '{1, SR_, IMSK};
								DECI.VECR = 1;
							end
							3'd4: begin
								DECI.DP.RSB = SCR;
								DECI.CTRL.S = VBR_;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = VECT;
								DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 1, 0};
							end
							3'd5: begin
								
							end
							3'd6: begin
								DECI.DP.BPLDA = 1;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZERO;
								DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
								DECI.PCW = 1;
								DECI.BR = '{1, UCB, 0, 0, 0};
							end
							3'd7: begin
								DECI.BR = '{0, UCB, 0, 0, 0};
							end
							default:;
						endcase
						DECI.LST = 3'd7;
					end
					4'b0010:	begin	//Illegal Slot/Instruction Exeption
						case (STATE)
							3'd0: begin
								DECI.IACP = 1;
							end
							3'd1: begin
								DECI.RA = '{SP, 1, 1};
								DECI.DP.RSB = SCR;
								DECI.CTRL.S = SR_;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{0, 1, ADD, 4'b0001, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 1};
							end
							3'd2: begin
								DECI.RA = '{SP, 1, 1};
								DECI.DP.RSB = IPC;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ONE;
								DECI.ALU = '{0, 1, ADD, 4'b0001, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 0, 1};
							end
							3'd3: begin
								DECI.DP.RSB = SCR;
								DECI.CTRL.S = VBR_;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = VECT;
								DECI.ALU = '{1, 0, ADD, 4'b0000, 3'b000};
								DECI.MEM = '{ALURES, ALUB, 2'b10, 1, 0};
							end
							3'd4: begin
								
							end
							3'd5: begin
								DECI.DP.BPLDA = 1;
								DECI.DP.RSC = RSC_IMM;
								DECI.IMMT = ZERO;
								DECI.ALU = '{0, 1, ADD, 4'b0000, 3'b000};
								DECI.PCW = 1;
								DECI.BR = '{1, UCB, 0, 0, 0};
							end
							3'd6: begin
								DECI.BR = '{0, UCB, 0, 0, 0};
							end
							default:;
						endcase
						DECI.LST = 3'd6;
					end
					default: DECI.ILI = 1;
				endcase
			end
			
			default: DECI.ILI = 1;
		endcase
		
		return DECI;
	endfunction
	
	
	typedef struct
	{
		bit [15:0] IR;
		bit [31:0] PC;
	} IFtoID_t;
	
	typedef struct
	{
		bit [15:0] IR;
		DecInstr_t DI;			//Decoded instruction
		bit [31:0] PC;
		bit        BC;			//Branch condition
		bit [31:0] RA;
		bit [31:0] RB;
		bit [31:0] R0;
	} IDtoEX_t;

	typedef struct
	{
		bit [15:0] IR;
		DecInstr_t DI;			//Decoded instruction
		bit [31:0] PC;
		bit        BC;			//Branch condition
		bit [31:0] RES;		//ALU output
		bit [31:0] ADDR;		//Data memory address
		bit [31:0] WD;			//Write data
	} EXtoMA_t;

	typedef struct
	{
		bit [15:0] IR;
		DecInstr_t DI;			//Decoded instruction
		bit [31:0] PC;
		bit [31:0] RES;
		bit [31:0] RD;			//Read data
		bit        LOCK;
	} MAtoWB_t;
	
	typedef struct
	{
		bit [15:0] IR;
		DecInstr_t DI;			//Decoded instruction
		bit [31:0] PC;
		bit [31:0] RESA;
		bit [31:0] RESB;
		bit        LOCK;
	} WB_t;
	
	typedef struct
	{
		IFtoID_t ID;
		IDtoEX_t EX;
		EXtoMA_t MA;
		MAtoWB_t WB;
		WB_t     WB2;
	} PipelineState_t;
	
	function bit[31:0] ByteShiftRigth(input bit[31:0] val, input bit[1:0] s);
		bit[31:0] temp0, temp1;
		
		temp1 = s[1] ? val >> 16 : val;
		temp0 = s[0] ? temp1 >> 8 : temp1;
		return temp0;
	endfunction

	typedef struct packed
	{
		bit [21: 0] UNUSED;
		bit         M;
		bit         Q;
		bit [ 3: 0] I;
		bit [ 1: 0] UNUSED2;
		bit         S;
		bit         T;
	} SR_t;
	
	parameter bit [31:0] SR_RESET = 32'h000000F0;
	
	localparam SR_T 	= 0;
	localparam SR_S 	= 1;
	localparam SR_I0 	= 4;
	localparam SR_I1 	= 5;
	localparam SR_I2 	= 6;
	localparam SR_I3 	= 7;
	localparam SR_Q 	= 8;
	localparam SR_M 	= 9;


	//ALU
	function bit [32:0] Adder(input bit [31:0] a, input bit [31:0] b, input bit ci, input bit [3:0] code);
		bit [31:0] b2;
		bit        ci2;
		bit [32:0] sum;
		
		b2 = b ^ {32{code[0]}};
		ci2 = code[1] ? ci ^ code[0] : code[0];
		sum = {1'b0,a} + {1'b0,b2} + {{32{1'b0}},ci2};
		
		return {sum[32] ^ code[0],sum[31:0]};
	endfunction
	
	function bit [31:0] Log(input bit [31:0] a, input bit [31:0] b, input bit [3:0] code);
		bit [31:0] b2;
		bit [31:0] res;
		
		b2 = b ^ {32{code[0]}};
		case (code[2:1])
			2'b00: res = a & b2;
			2'b01: res = a ^ b2;
			2'b10: res = a | b2;
			2'b11: res = b2;
		endcase
	
		return res;
	endfunction
	
	function bit [31:0] Ext(input bit [31:0] a, input bit [31:0] b, input bit [3:0] code);
		bit [31:0] res;
	
		case (code[2:0])
			3'b000: res = {b[31:16],b[7:0],b[15:8]};
			3'b001: res = {b[15:0],b[31:16]};
			3'b010: res = {b[15:0],a[31:16]};
			3'b011: res = {b[15:0],a[15:0]};
			3'b100: res = {{24{1'b0}},b[7:0]};
			3'b101: res = {{16{1'b0}},b[15:0]};
			3'b110: res = {{24{b[7]}},b[7:0]};
			3'b111: res = {{16{b[15]}},b[15:0]};
		endcase
	
		return res;
	endfunction
	
	function bit [32:0] Shifter(input bit [31:0] a, input bit ci, input bit [3:0] code);
		bit [31:0] res;
		bit        ci2;
		bit        co;
	
		case (code[2:0])
			3'b000: ci2 = 0;
			3'b001: ci2 = 0;
			3'b010: ci2 = 0;
			3'b011: ci2 = a[31];
			3'b100: ci2 = a[31];
			3'b101: ci2 = a[0];
			3'b110: ci2 = ci;
			3'b111: ci2 = ci;
		endcase
		
		if (!code[3]) begin
			res = !code[0] ? {a[30:0],ci2} : {ci2, a[31:1]};
		end else begin
			case (code[2:0])
				3'b000: res = {a[29:0],{2{1'b0}}};
				3'b001: res = {{2{1'b0}},a[31:2]};
				3'b010: res = {a[23:0],{8{1'b0}}};
				3'b011: res = {{8{1'b0}},a[31:8]};
				3'b100: res = {a[15:0],{16{1'b0}}};
				3'b101: res = {{16{1'b0}},a[31:16]};
				3'b110: res = {a[15:0],{16{1'b0}}};
				3'b111: res = {{16{1'b0}},a[31:16]};
			endcase
		end
		co = !code[0] ? a[31] : a[0];
		
		return {co,res};
	endfunction
	
endpackage
