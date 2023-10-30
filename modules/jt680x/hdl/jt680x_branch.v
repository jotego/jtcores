module jt680x_branch(
	input	   [3:0] sel,
	input	   [5:0] cc,
	output reg       branch
);

always @* case(sel)
	4'b0000: branch = 1; // bra
	4'b0001: branch = 0; // brn
	4'b0010: branch = !(cc[CBIT] | cc[ZBIT]); // bhi
	4'b0011: branch =   cc[CBIT] | cc[ZBIT];  // bls
	4'b0100: branch = ! cc[CBIT]; // bcc/bhs
	4'b0101: branch =   cc[CBIT]; // bcs/blo
	4'b0110: branch = ! cc[ZBIT]; // bne
	4'b0111: branch =   cc[ZBIT]; // beq
	4'b1000: branch = ! cc[VBIT]; // bvc
	4'b1001: branch =   cc[VBIT]; // bvs
	4'b1010: branch = ! cc[NBIT]; // bpl
	4'b1011: branch =   cc[NBIT]; // bmi
	4'b1100: branch = !(cc[NBIT] ^ cc[VBIT]); // bge
	4'b1101: branch =   cc[NBIT] ^ cc[VBIT];  // blt
	4'b1110: branch = !(cc[ZBIT] | (cc[NBIT] ^ cc[VBIT])); // bgt
	4'b1111: branch =   cc[ZBIT] | (cc[NBIT] ^ cc[VBIT]);// ble
endcase

endmodule