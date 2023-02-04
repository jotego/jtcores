`timescale 1ns/1ps

module char_tb;

	initial begin
		$dumpfile("test.lxt");
		$dumpvars;
		$dumpon;
		#(100*1000*1000) $finish;
	end

	wire Phi8;
	wire H4;
	wire H2;
	wire G6M;
	wire LHBL;
	wire G4_3H;
	wire OH;
	wire G4H;
	wire H1;
	wire H8;
	wire H16;
	wire H32;
	wire H64;
	wire H128;
	wire H256;
	wire CMP_SYNC;
	wire LVBL;
	wire V1;
	wire V2;
	wire V4;
	wire V8;
	wire V16;
	wire V32;
	wire V64;
	wire V128;
	wire IRQ1;
	wire HINIT_b;

jt_gng_a5 i_jt_gng_a5 (
	.Phi8    (Phi8    ),
	.H4      (H4      ),
	.H2      (H2      ),
	.G6M     (G6M     ),
	.LHBL    (LHBL    ),
	.G4_3H   (G4_3H   ),
	.OH      (OH      ),
	.G4H     (G4H     ),
	.H1      (H1      ),
	.H8      (H8      ),
	.H16     (H16     ),
	.H32     (H32     ),
	.H64     (H64     ),
	.H128    (H128    ),
	.H256    (H256    ),
	.CMP_SYNC(CMP_SYNC),
	.LVBL    (LVBL    ),
	.V1      (V1      ),
	.V2      (V2      ),
	.V4      (V4      ),
	.V8      (V8      ),
	.V16     (V16     ),
	.V32     (V32     ),
	.V64     (V64     ),
	.V128    (V128    ),
	.IRQ1    (IRQ1    ),
	.HINIT_b (HINIT_b )
);


	wire FLIP = 1'b0;
	wire MRDY_b;
	wire MRDY2_b  = 1'b1;
	wire CHARCS_b = 1'b1;
	wire N4H;
	wire [3:0] CC;
	wire CHHFLIP;
	wire CHHFLIPq;
	wire CHVFLIP;
	wire [9:0] AC;
	wire [7:0] DB;
	wire RDB_b = 1'b1;
	wire [10:0] AB = 11'b0;

jt_gng_a6 i_jt_gng_a6 (
	.H2      (H2      ),
	.H4      (H4      ),
	.H8      (H8      ),
	.H16     (H16     ),
	.H32     (H32     ),
	.H64     (H64     ),
	.H128    (H128    ),
	.H256    (H256    ),
	.V8      (V8      ),
	.V16     (V16     ),
	.V32     (V32     ),
	.V64     (V64     ),
	.V128    (V128    ),
	.G4H     (G4H     ),
	.FLIP    (FLIP    ),
	.MRDY_b  (MRDY_b  ),
	.MRDY2_b (MRDY2_b ),
	.CHARCS_b(CHARCS_b),
	.OH      (OH      ),
	.N4H     (N4H     ),
	.CC      (CC      ),
	.CHHFLIP (CHHFLIP ),
	.CHHFLIPq(CHHFLIPq),
	.CHVFLIP (CHVFLIP ),
	.AC      (AC      ),
	.DB      (DB      ),
	.RDB_b   (RDB_b   ),
	.AB      (AB      )
);


	wire CH6M;
	wire CHARZ;
	wire CHARY;
jt_gng_a7 i_jt_gng_a7 (
	.G4H     (G4H     ),
	.V4      (V4      ),
	.V2      (V2      ),
	.V1      (V1      ),
	.H4      (H4      ),
	.G6M     (G6M     ),
	.G4_3H   (G4_3H   ),
	.CHVFLIP (CHVFLIP ),
	.CHHFLIP (CHHFLIP ),
	.CHHFLIPq(CHHFLIPq),
	.AC      (AC      ),
	.FLIP    (FLIP    ),
	.CH6M    (CH6M    ),
	.CHARZ   (CHARZ   ),
	.CHARY   (CHARY   )
);

reg lastIRQ;

always @(posedge G6M) begin
	lastIRQ <= HINIT_b;
	if( !HINIT_b && lastIRQ) $write("\n");
	else
	case( ~{CHARY, CHARZ} )
		2'b00: $write(" ");
		2'b01: $write("·");
		2'b10: $write("+");
		2'b11: $write("#");
	endcase // {CHARY, CHARZ}
end

endmodule // char_tb