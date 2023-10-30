module jt680x_alu_sel(
	input	[ 7:0] op,
	output	[ 7:0] sel
);

casez( op )
	8'b0000_000?, // SBA, CBA
	8'b1?00_00??: sel = ALU_SUB8; // SUBA, SUBB, CMPA, CMPB, SBCA, SBCB
	8'b1000_1100: // CPX
	8'b1000_0011: sel = ALU_SUB16; // SUBD
	8'b1100_0011: sel = ALU_ADD16; // ADDD
	8'b1?00_010?: sel = ALU_AND;   // AND, BIT
	8'b1?00_0101: sel = ALU_AND;
	8'b1?00_0110: sel = ALU_LD8;   // LDAA, LDAB
	8'b1?00_0111: sel = ALU_ST8;
	8'b1?00_1000: sel = ALU_EOR;
	8'b1?00_10?1: sel = ALU_ADD8;
	8'b1?00_1010: sel = ALU_ORA;
	8'b1100_11?0: sel = ALU_LD16;
	8'b1100_11?1: sel = ALU_ST16;
endcase

endmodule