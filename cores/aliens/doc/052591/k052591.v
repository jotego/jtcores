// Konami 052591 PMC model
// 2023 furrtek
// For simulation only

module k052591(
	input pin_M12,
	input pin_RST,

	input pin_CS,
	input pin_NRD,
	input pin_START,
	input pin_BK,
	output reg pin_OUT0,

	input [12:0] pin_AB,
	inout [7:0] pin_DB,

	output [12:0] pin_EA,
	inout [7:0] pin_ED,
	output pin_ERCS,
	output pin_EROE,
	output pin_ERWE,
	
	input PIN21
);

reg rsts;					// Synchronized reset
reg A195, B193;				// Clock gen
reg flag_mux;

reg [35:0] iram [0:64];		// Internal RAM for program, 64 36-bit words
reg [35:0] iram_din;		// Storage for loading bytes to internal RAM
reg [35:0] iram_dout;
reg [5:0] iram_a_next;
reg [5:0] iram_a_curr;
reg [5:0] iram_a_mux;
wire [5:0] iram_a;
reg iram_we;
reg [5:0] LD;				// Internal RAM load address
reg [3:0] byte_cnt;         // Internal RAM byte load counter
reg [35:0] ir;				// Instruction register

reg [15:0] r [0:7];			// Registers
reg [15:0] acc;				// Accumulator
reg [15:0] reg_wr_mux;		// Data to be written to register

wire [15:0] alu_a_mux;
wire [15:0] alu_a;
reg [15:0] alu_b;
wire [15:0] alu_bx;
wire [15:0] alu_nand1;
wire [15:0] alu_nand2;
wire [15:0] alu_ax;
wire [15:0] alu_or;
wire [15:0] alu_and;
wire [15:0] alu_xnor1;
wire [15:0] alu_xnor2;
wire [15:0] bus_xnor;
wire [15:0] alu;			// ALU result

reg C181;
reg RUN, RUN_DLY;
reg J95;
reg G106;
wire [15:0] EXT;

reg [15:0] rega;			// Operand register A
reg [15:0] regb;			// Operand register B

integer cd;
initial begin
	r[0] <= 16'h0000;
	r[1] <= 16'h0000;
	r[2] <= 16'h0000;
	r[3] <= 16'h0000;
	r[4] <= 16'h0000;
	r[5] <= 16'h0000;
	r[6] <= 16'h0000;
	r[7] <= 16'h0000;
	rega <= 16'h0000;
	regb <= 16'h0000;
	acc <= 16'h0000;
	ir <= 36'h00000;
end

// Decompose register file for viewing in GTKWave
wire [15:0] r0 = r[0];
wire [15:0] r1 = r[1];
wire [15:0] r2 = r[2];
wire [15:0] r3 = r[3];
wire [15:0] r4 = r[4];
wire [15:0] r5 = r[5];
wire [15:0] r6 = r[6];
wire [15:0] r7 = r[7];

// Synchronize reset input
always @(posedge pin_M12 or negedge pin_RST) begin
	if (!pin_RST)
		rsts <= 1'b0;
	else
		rsts <= 1'b1;
end

// Clocks
always @(posedge pin_M12 or negedge rsts) begin
	if (!rsts) begin
		A195 <= 1'b0;
		B193 <= 1'b0;
	end else begin
		A195 <= B193 ? PIN21 : A195;	// Synchronized input that enables division of M12 by 2 ?
		B193 <= ~B193;	// Divide-by-2
	end
end

// A195 selects between ~B193 or M12
assign clk = ~&{~&{pin_M12, ~B193}, ~&{~A195, ~B193}, ~&{pin_M12, A195}};

// iram clock is ~clk
always @(negedge clk) begin
	if (iram_we) begin
		iram[iram_a] <= iram_din;
		$display("iram: wrote %h at %h", iram_din, iram_a);
	end
	iram_dout <= iram[iram_a];
end

always @(posedge clk or negedge rsts) begin
	if (!rsts) begin
		RUN <= 1'b0;
		RUN_DLY <= 1'b0;
	end else begin
		RUN <= pin_START;
		RUN_DLY <= RUN;
		if (!RUN & pin_START) $display("Start !");
	end
end

always @(posedge clk)
	ir <= iram_dout;

// Accumulator

// assign acc_wr = clk | ~|{~|{ir[8:6]}, ~|{~ir[8], ir[6]}};
assign acc_wr = clk | &{|{ir[8:6]}, |{~ir[8], ir[6]}};

always @(posedge acc_wr) begin
	// Pre- Shift/rotate
	casex(ir[8:7])
		2'b0x: acc <= alu;
		2'b10: acc <= {ir[33] ? alu[0] : CIN0, acc[15:1]};
		2'b11: acc <= {alu[14:0], ir[33] ? 1'b0 : ~alu[15]};
	endcase
end

// Data busses

reg [7:0] ED_WR;
wire [7:0] ED_OUT;
reg [12:0] EA_OUT;
wire [7:0] D_MUX;

assign DB_DIR = pin_NRD | nCPU_ERAM;
assign D_MUX = RUN_DLY ? pin_ED : pin_DB;
assign pin_DB = DB_DIR ? 8'bzzzzzzzz : pin_ED;
assign ED_OUT = RUN_DLY ? ED_WR : pin_DB;
assign pin_ED = ED_DIR ? 8'bzzzzzzzz : ED_OUT;

assign update_ed = ir[31] | clk;

always @(posedge update_ed)
	ED_WR <= ir[30] ? EXT[15:8] : EXT[7:0];

// External RAM address

assign pin_EA = RUN ? EA_OUT : pin_AB;

assign update_ea = clk | ~(ir[31:30] == 2'b10);

always @(posedge update_ea)
	EA_OUT <= EXT[12:0];

// Internal RAM loading

assign P7 = pin_AB[9] | nCPU_WR;
assign rst_byte_cnt = &{~&{byte_cnt[2], byte_cnt[0]}, nSET_PC, rsts};

always @(posedge P7 or negedge rst_byte_cnt) begin
	if (!rst_byte_cnt)
		byte_cnt <= 4'd0;
	else
		byte_cnt <= byte_cnt + 1'b1;
end

assign trig_iram_wr = ~((byte_cnt == 4'd4) & ~P7);
assign L114 = ~&{(byte_cnt[2:0] == 3'd0), ~P7} & |{ir[15], ir[35], ~RUN_DLY, clk};

always @(*) begin
	if (~trig_iram_wr) iram_din[35:32] <= D_MUX;
	if ((byte_cnt == 4'd3) & ~P7) iram_din[31:24] <= D_MUX;
	if ((byte_cnt == 4'd2) & ~P7) iram_din[23:16] <= D_MUX;
	if ((byte_cnt == 4'd1) & ~P7) iram_din[15:8] <= D_MUX;
end

always @(posedge L114)
	iram_din[7:0] <= D_MUX;

// Use to increment LD after 5th byte is loaded and iram written to
reg LD_inc_en;
always @(posedge P7 or negedge nSET_PC) begin
	if (!nSET_PC)
		LD_inc_en <= 1'b1;
	else
		LD_inc_en <= ~byte_cnt[2];
end


// Internal RAM write pulse generator

assign G113 = rsts & ~iram_we;

assign G105 = ~trig_iram_wr;
always @(posedge G105 or negedge G113) begin
	if (!G113)
		G106 <= 1'b1;
	else
		G106 <= 1'b0;
end

always @(posedge clk or negedge rsts) begin
	if (!rsts)
		iram_we <= 1'b0;
	else
		iram_we <= ~G106;
end

// Internal RAM address

assign nSET_PC = nCPU_WR | ~pin_AB[9];
assign #1 P59 = nSET_PC;	// Present in silicon, required otherwise initial PC can't be set (P68 and others have synchronous load inputs)

always @(posedge nSET_PC or negedge rsts) begin
	if (!rsts)
		J95 <= 1'b1;
	else
		J95 <= D_MUX[7];
end

assign RESET_PC = ~RUN & J95;

always @(posedge nCPU_WR or negedge rsts) begin
	if (!rsts) begin
		LD <= 6'd0;
	end else begin
		if (!P59) begin
			LD <= D_MUX[5:0];
		end else if (~LD_inc_en)
			LD <= LD + 1'd1;
	end
end

always @(*) begin
	case(ir[23:22])
		2'b00: flag_mux <= ~|{alu};		// Zero flag
		2'b01: flag_mux <= flag_carry;	// Result's 17th bit
		2'b10: flag_mux <= flag_ovf;
		2'b11: flag_mux <= alu[15];		// Negative flag
	endcase
end

assign N86 = ~|{ir[15], ~|{ir[26], flag_mux}};
assign N74 = ~&{~&{ir[25:24]}, N86, RUN_DLY};
assign N77 = ~&{~&{~&{~&{ir[26], ir[24]}, ir[25]}, N86}, RUN_DLY};

assign L63 = |{clk, ir[25:24], ir[15]};

always @(posedge clk)
	iram_a_next <= iram_a + 1'b1;

always @(posedge L63)
	iram_a_curr <= iram_a_next;

always @(*) begin
	case({N77, N74})
		2'b00: iram_a_mux <= iram_a_curr;
		2'b01: iram_a_mux <= iram_a_next;
		2'b10: iram_a_mux <= ir[21:16];
		2'b11: iram_a_mux <= LD;
	endcase
end
assign iram_a = RESET_PC ? 6'd0 : iram_a_mux;

assign nCPU_WR = pin_CS | ~&{pin_NRD, ~|{pin_BK, RUN_LONG}};

// Write to register

always @(*) begin
	// Pre- Shift/rotate
	casex(ir[8:7])
		2'b0x: reg_wr_mux <= alu;
		2'b10: reg_wr_mux <= {ir[33] ? N45 : CIN0, alu[15:1]};
		2'b11: reg_wr_mux <= {alu[14:0], ir[33] ? 1'b0 : acc[15]};
	endcase

	if (~clk & |{ir[8:7]}) begin
		r[ir[14:12]] <= reg_wr_mux;
		if (RUN) $display("reg: wrote %h to reg %h", reg_wr_mux, ir[14:12]);
	end
end

// Read from register

always @(negedge clk) begin
	rega <= r[ir[11:9]];
	regb <= r[ir[14:12]];
end

// OUT0 pin
assign C150 = clk | ~&{ir[15], ~ir[34]};

always @(posedge C150 or negedge RUN_DLY) begin
	if (!RUN_DLY)
		pin_OUT0 <= 1'b1;
	else
		pin_OUT0 <= ir[16];
end

assign EXT = (ir[8:6] == 3'b010) ? rega : alu;

// External RAM control
assign RUN_LONG = RUN | RUN_DLY;
assign nCPU_ERAM = pin_CS | ~&{pin_BK, ~RUN_LONG};
assign pin_ERCS = nCPU_ERAM & ~&{RUN_DLY, RUN};

always @(posedge ~pin_M12 or negedge rsts) begin
	if (!rsts)
		C181 <= 1'b0;
	else
		C181 <= ~B193;
end

assign H114 = ir[15] | clk;

reg H87, H94;
always @(posedge H114 or negedge RUN) begin
	if (!RUN) begin
		H87 <= 1'b1;
		H94 <= 1'b1;
	end else begin
		H87 <= ir[27];
		H94 <= ir[28];
	end
end

assign G104 = ~&{~H94, ~ir[29]};
assign H108 = ~&{~ir[29], ~H87};
assign B139 = H108 | ~&{~&{~C181, ~pin_M12}, ~&{~C181, ~A195}, ~&{~pin_M12, A195}};	// TODO: Check
assign pin_EROE = ~&{~&{pin_NRD, G104}, ~&{pin_NRD, ~RUN_LONG}, ~&{G104, RUN_LONG}};
assign pin_ERWE = ~&{~&{~pin_NRD, B139}, ~&{~pin_NRD, ~RUN_LONG}, ~&{B139, RUN_LONG}};
assign ED_DIR = H108 & (nCPU_ERAM | ~pin_NRD);

reg K110;
always @(posedge clk)
	K110 <= ~&{ir[33:32]};
assign ir1p = ir[1] | ~|{acc[0], K110};

assign T40 = ir[2] & (ir[0] | ir1p);
assign T42 = ~|{ir[2], ir1p};

// ALU B input

/*
IR2 IR1 IR0  V29 T32 V31
 0   0   0    1   0   0
 0   0   1    0   1   0
 0   1   0    1   0   0
 0   1   1    0   1   0
 1   0   0    0   0   1
 1   0   1    0   0   1
 1   1   0    1   0   0
 1   1   1    0   0   0
*/

always @(*) begin
	casez(ir[2:0])
		3'b0?0: alu_b <= acc;
		3'b0?1: alu_b <= regb;
		3'b10?: alu_b <= rega;
		3'b110: alu_b <= acc;
		3'b111: alu_b <= 0;
	endcase
end

assign alu_bx = ir[4] ? ~alu_b : alu_b;

// ALU

// Forces alu_or to all ones, used for bitwise ops ?
assign AD30 = ~&{~&{ir[5], ~ir[4]}, ~&{~ir[5], ir[4], ir3p}};


assign alu_a_mux = (ir[35] & ir[15]) ? {{4{ir[28]}}, ir[27:16]} : {iram_din[7:0], D_MUX[7:0]};
assign J89 = ~|{ir[35], ir[15]};
assign alu_a = J89 ? {8'd0, alu_a_mux[7:0]} : alu_a_mux;
assign alu_nand1 = T40 ? ~alu_a : 16'hFFFF;
assign alu_nand2 = T42 ? ~rega : 16'hFFFF;
assign alu_ax = ~(alu_nand1 & alu_nand2) ^ {16{ir3p}};
assign alu_or = {16{AD30}} | alu_ax | alu_bx;
assign alu_and = alu_ax & alu_bx;
assign alu_xnor1 = ~(alu_or ^ alu_and);
assign alu_xnor2 = ~(alu_xnor1 ^ {16{~ir[5]}});
assign alu = ~(alu_xnor2 ^ bus_xnor);

assign flag_carry = ~&{nCOUT3, ~&{CIN3, &{alu_or[15:12]}}};
assign flag_ovf = (flag_carry ^ ~&{~&{CIN3, Y12}, Z13, AA9, AB10});
assign N45 = alu[15] ^ flag_ovf;

assign L59 = ir[33] | ~ir[32];
reg N68;
always @(posedge clk)
	N68 <= ~|{L59, alu[15]};
assign ir3p = ir[3] | N68;

assign AH99 = ~&{alu_or[3:0]};
assign AH41 = ~&{alu_or[7:4]};
assign AG10 = ~&{alu_or[11:8]};

assign nCOUT0 = &{~alu_and[3], ~&{alu_or[3], alu_and[2]}, ~&{alu_or[3:2], alu_and[1]}, ~&{alu_or[3:1], alu_and[0]}};
assign nCOUT1 = &{~alu_and[7], ~&{alu_or[7], alu_and[6]}, ~&{alu_or[7:6], alu_and[5]}, ~&{alu_or[7:5], alu_and[4]}};
assign nCOUT2 = &{~alu_and[11], ~&{alu_or[11], alu_and[10]}, ~&{alu_or[11:10], alu_and[9]}, ~&{alu_or[11:9], alu_and[8]}};
assign nCOUT3 = &{~alu_and[15], ~&{alu_or[15], alu_and[14]}, ~&{alu_or[15:14], alu_and[13]}, ~&{alu_or[15:13], alu_and[12]}};

assign CIN3 = &{~&{nCOUT2, nCOUT1, nCOUT0, ~CIN0}, ~&{AH99, nCOUT2, nCOUT1, nCOUT0}, ~&{AH41, nCOUT2, nCOUT1}, ~&{AG10, nCOUT2}};
assign CIN2 = &{~&{nCOUT1, nCOUT0, ~CIN0}, ~&{AH99, nCOUT1, nCOUT0}, ~&{AH41, nCOUT1}};
assign CIN1 = &{~&{nCOUT0, ~CIN0}, ~&{AH99, nCOUT0}};
assign CIN0 = ~&{~&{ir3p, ~L59}, ~&{~ir[15] & ir[34], L59}};

assign ari_en = ~ir[5] & ~&{ir[4], ir3p};

assign Y12 = &{alu_or[14:12], ari_en};
assign Z13 = ~&{alu_or[14:13], alu_and[12], ari_en};
assign AA9 = ~&{alu_or[14], alu_and[13], ari_en};
assign AB10 = ~&{alu_and[14], ari_en};

// Four 4-bit blocks for arithmetic

assign bus_xnor[15] = ~&{~&{CIN3, Y12}, Z13, AA9, AB10};
assign bus_xnor[14] = ~&{~&{alu_or[13:12], CIN3, ari_en}, ~&{alu_or[13], alu_and[12], ari_en}, ~&{alu_and[13], ari_en}};
assign bus_xnor[13] = ~&{~&{alu_or[12], CIN3, ari_en}, ~&{alu_and[12], ari_en}};
assign bus_xnor[12] = &{CIN3, ari_en};

assign bus_xnor[11] = ~&{~&{CIN2, &{alu_or[10:8], ari_en}}, ~&{alu_or[10:9], alu_and[8], ari_en}, ~&{alu_or[10], alu_and[9], ari_en}, ~&{alu_and[10], ari_en}};
assign bus_xnor[10] = ~&{~&{alu_or[9:8], CIN2, ari_en}, ~&{alu_or[9], alu_and[8], ari_en}, ~&{alu_and[9], ari_en}};
assign bus_xnor[9] =  ~&{~&{alu_or[8], CIN2, ari_en}, ~&{alu_and[8], ari_en}};
assign bus_xnor[8] =  &{CIN2, ari_en};

assign bus_xnor[7] = ~&{~&{CIN1, &{alu_or[6:4], ari_en}}, ~&{alu_or[6:5], alu_and[4], ari_en}, ~&{alu_or[6], alu_and[5], ari_en}, ~&{alu_and[6], ari_en}};
assign bus_xnor[6] = ~&{~&{alu_or[5:4], CIN1, ari_en}, ~&{alu_or[5], alu_and[4], ari_en}, ~&{alu_and[5], ari_en}};
assign bus_xnor[5] = ~&{~&{alu_or[4], CIN1, ari_en}, ~&{alu_and[4], ari_en}};
assign bus_xnor[4] = &{CIN1, ari_en};

assign bus_xnor[3] = ~&{~&{CIN0, &{alu_or[2:0], ari_en}}, ~&{alu_or[2:1], alu_and[0], ari_en}, ~&{alu_or[2], alu_and[1], ari_en}, ~&{alu_and[2], ari_en}};
assign bus_xnor[2] = ~&{~&{alu_or[1:0], CIN0, ari_en}, ~&{alu_or[1], alu_and[0], ari_en}, ~&{alu_and[1], ari_en}};
assign bus_xnor[1] = ~&{~&{alu_or[0], CIN0, ari_en}, ~&{alu_and[0], ari_en}};
assign bus_xnor[0] = &{CIN0, ari_en};

endmodule
