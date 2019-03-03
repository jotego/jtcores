`timescale 1ns/1ps

module scr_tb;

	`ifdef DUMP
	initial begin
		$dumpfile("test.lxt");
		$dumpvars;
		$dumpon;
	end
	`endif

	initial #(20*1000*1000) $finish;

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
	wire [7:0] DB = 8'd0;
	wire RDB_b = 1'b1;
	wire [12:0] AB = 13'b0;
/*
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
*/

wire V128F, V64F, V32F, V16F, V8F, V4F, V2F, V1F;
wire AKB_b=1'b1;
wire [8:0] OB =8'd0;


wire BLCNTEN_b;
wire OKOUT_b=1'b1;
wire ROB_b;
wire ACL2_b;
wire OVER96_b=1'b1;
wire phi_BB=~H1;
wire BLEN;
wire MATCH_b;

jt_gng_b1 i_jt_gng_b1 (
	.V1       (V1       ),
	.V2       (V2       ),
	.V4       (V4       ),
	.V8       (V8       ),
	.V16      (V16      ),
	.V32      (V32      ),
	.V64      (V64      ),
	.V128     (V128     ),
	.FLIP     (FLIP     ),
	.V1F      (V1F      ),
	.V2F      (V2F      ),
	.V4F      (V4F      ),
	.V8F      (V8F      ),
	.V16F     (V16F     ),
	.V32F     (V32F     ),
	.V64F     (V64F     ),
	.V128F    (V128F    ),
	.AB       (AB       ), // TODO: Check connection ! Signal/port not matching : Expecting logic [12:0]  -- Found logic [10:0]
	.OB       (OB       ),
	.DB       (DB       ),
	.BLCNTEN_b(BLCNTEN_b),
	.OKOUT_b  (OKOUT_b  ),
	.ROB_b    (ROB_b    ),
	.ACL2_b   (ACL2_b   ),
	.AKB_b    (AKB_b    ),
	.OVER96_b (OVER96_b ),
	.phi_BB   (phi_BB   ),
	.BLEN     (BLEN     ),
	.MATCH_b  (MATCH_b  )
);


	wire CBCS_b=1'b1;
	wire SH2;
	wire SH8;
	wire SH16;
	wire SH32;
	wire SH64;
	wire SH128;
	wire SH256;
	wire SCRCS_b=1'b1;
	wire SCREN_b;
	wire POS2;
	wire POS3;
	wire S0H;
	wire S2H;
	wire S4H;
	wire FLIPbuf;
	wire S7H_b;
	wire S6M;
jt_gng_b7 i_jt_gng_b7 (
	.DB     (DB     ),
	.AB     (AB[3:0]),
	.CBCS_b (CBCS_b ),
	.G6M    (G6M    ),
	.FLIP   (FLIP   ),
	.H256   (H256   ),
	.H128   (H128   ),
	.H64    (H64    ),
	.H32    (H32    ),
	.H16    (H16    ),
	.H8     (H8     ),
	.H4     (H4     ),
	.H2     (H2     ),
	.H1     (H1     ),
	.SH2    (SH2    ),
	.SH8    (SH8    ),
	.SH16   (SH16   ),
	.SH32   (SH32   ),
	.SH64   (SH64   ),
	.SH128  (SH128  ),
	.SH256  (SH256  ),
	.SCRCS_b(SCRCS_b),
	.MRDY2_b(MRDY2_b),
	.SCREN_b(SCREN_b),
	.POS2   (POS2   ),
	.POS3   (POS3   ),
	.S0H    (S0H    ),
	.S2H    (S2H    ),
	.S4H    (S4H    ),
	.FLIPbuf(FLIPbuf),
	.S7H_b  (S7H_b  ),
	.S6M    (S6M    )
);


wire WR_b=1'b1;
wire [9:0] AS;
wire V256S;
wire V128S;
wire V64S;
wire V32S;
wire V16S;
wire V8S;
wire V4S;
wire V2S;
wire V1S;
wire SVFLIP;
wire SHFLIP;
wire SHFLIP_q;
wire SCRWIN;
wire [2:0] SCO;

jt_gng_b8 i_jt_gng_b8 (
	.DB      (DB      ),
	.V128F   (V128F   ),
	.V64F    (V64F    ),
	.V32F    (V32F    ),
	.V16F    (V16F    ),
	.V8F     (V8F     ),
	.V4F     (V4F     ),
	.V2F     (V2F     ),
	.V1F     (V1F     ),
	.OH      (OH      ),
	.POS3    (POS3    ),
	.POS2    (POS2    ),
	.WR_b    (WR_b    ),
	.SCREN_b (SCREN_b ),
	.SCRCS_b (SCRCS_b ),
	.SH256   (SH256   ),
	.SH128   (SH128   ),
	.SH64    (SH64    ),
	.SH32    (SH32    ),
	.SH16    (SH16    ),
	.SH2	 (SH2	  ),
	.S2H     (S2H     ),
	.S0H     (S0H     ),
	.S4H     (S4H     ),
	.AB      (AB[10:0]),
	.AS      (AS      ),
	.V256S   (V256S   ),
	.V128S   (V128S   ),
	.V64S    (V64S    ),
	.V32S    (V32S    ),
	.V16S    (V16S    ),
	.V8S     (V8S     ),
	.V4S     (V4S     ),
	.V2S     (V2S     ),
	.V1S     (V1S     ),
	.SVFLIP  (SVFLIP  ),
	.SHFLIP  (SHFLIP  ),
	.SHFLIP_q(SHFLIP_q),
	.SCRWIN  (SCRWIN  ),
	.SCO     (SCO     )
);


	wire SCRX;
	wire SCRY;
	wire SCRZ;

jt_gng_b9 i_jt_gng_b9 (
	.AS      (AS      ),
	.SH8     (SH8     ),
	.SHFLIP  (SHFLIP  ),
	.SHFLIP_q(SHFLIP_q),
	.V8S     (V8S     ),
	.V4S     (V4S     ),
	.V2S     (V2S     ),
	.V1S     (V1S     ),
	.SVFLIP  (SVFLIP  ),
	.S6M     (S6M     ),
	.FLIP_buf(FLIP	  ),
	.SCRX    (SCRX    ),
	.SCRY    (SCRY    ),
	.SCRZ    (SCRZ    ),
	.S7H_b   (S7H_b   )
);



reg lastIRQ;

always @(posedge G6M) begin
	lastIRQ <= HINIT_b;
	if( !HINIT_b && lastIRQ) $write("\n");
	else
	case( {SCRX, SCRY, SCRZ} )
		3'd0: $write(" ");
		3'd1: $write("·");
		3'd2: $write("-");
		3'd3: $write("~");
		3'd4: $write("=");
		3'd5: $write("+");
		3'd6: $write("#");
		3'd7: $write("@");
	endcase
end

endmodule // char_tb