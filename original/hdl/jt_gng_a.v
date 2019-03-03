`timescale 1ns/1ps

/*

	Board A

*/

module jt_gng_a(
	// I/O connector
	input	[1:0]	UP,
	input	[1:0]	DOWN,
	input	[1:0]	LEFT,
	input	[1:0]	RIGHT,
	input	[1:0]	SHOT2,
	input	[1:0]	SHOT1,
	output	[1:0]	COUNTER,
	output			SYNC,
	inout	[7:0]	DIPSW_B,
	inout	[7:0]	DIPSW_A,
	input	[1:0]	COIN,
	input	[1:0]	START,
	input	[1:0]	RESERVED,
	// board-to-board connector 1
	inout [7:0] 	DB,			// A8-A1
	inout [12:0] 	AB,			// A25-A13
	input			SCRWIN,		// B12
	output			CBCS_b,		// B13
	output			SCRCS_b,	// B14
	input			MRDY2_b,	// B15
	input	[2:0] 	SCD,		// B18-16
	output			ALC2_b,		// B19
	output			OKOUT_b,	// B20
	output			AKB_b,		// B21
	input			RQB_b,		// B22
	input			BLCNTEN_b,	// B23
	output			WRB_b,		// B24
	output			RDB_b,		// B25

	input			SCRX,		// C1
	input			SCRZ,		// C2
	output			G6M,		// C3
	output			G4_3H,		// C4
	output			H1,			// C5
	output			H4,			// C6
	output			H16,		// C7
	output			H64,		// C8
	output			H256,		// C9
	output			V1,			// C10
	output			V4,			// C11
	output			V16,		// C12
	output			V64,		// C13
	input	[7:0]	OBJ,		// C14-D17
	output			HINIT_b,	// C18

	input			SCRY,		// D1
	output			FLIP,		// D2
	output			OH,			// D3
	output			G4H,		// D4
	output			H2,			// D5
	output			H8,			// D6
	output			H32,		// D7
	output			H128,		// D8
	output			LHBL,		// D9
	output			V2,			// D10
	output			V8,			// D11
	output			V32,		// D12
	output			V128		// D13
);


wire IRQ1;
wire ALC1_b;
wire MRDY_b;
wire WRAM_b;
wire EXTEN_b;
wire [2:0] bank;
wire ECLK;

jt_gng_a1 A1 (
	.IRQ1     (IRQ1     ),
	.ALC1_b   (ALC1_b   ),
	.ALC2_b   (ALC2_b   ),
	.RQB_b    (RQB_b    ),
	.MRDY_b   (MRDY_b   ),
	.G6M      (G6M      ),
	.AKB_b    (AKB_b    ),
	.WRAM_b   (WRAM_b   ),
	.EXTEN_b  (EXTEN_b  ),
	.BLCNTEN_b(BLCNTEN_b),
	.DB       (DB       ),
	.AB       (AB       ),
	.RDB_b    (RDB_b    ),
	.WRB_b    (WRB_b    ),
	.bank     (bank     ),
	.ECLK     (ECLK     )
);

pullup pu_bus(RDB_b, WRB_b);


wire SRES_b;
wire RGCS_b;
wire BCS_b;
wire SOUND;
wire CHARCS_b;
wire INCS_b;
wire SCRPO_b;
assign CBCS_b = SCRPO_b;
jt_gng_a2 A2 (
	.AB      (AB      ),
	.WRAM_b  (WRAM_b  ),
	.WRB_b   (WRB_b   ),
	.RDB_b   (RDB_b   ),
	.DB      (DB      ),
	.bank    (bank    ),
	.counter (COUNTER ),
	.SRES_b  (SRES_b  ),
	.FLIP    (FLIP    ),
	.ALC1_b  (ALC1_b  ),
	.RGCS_b  (RGCS_b  ),
	.BCS_b   (BCS_b   ),
	.SOUND   (SOUND   ),
	.SCRPO_b (SCRPO_b ),
	.OKOUT_b (OKOUT_b ),
	.ECLK    (ECLK    ),
	.EXTEN_b (EXTEN_b ),
	.CHARCS_b(CHARCS_b),
	.SCRCS_b (SCRCS_b ),
	.INCS_b  (INCS_b  )
);


jt_gng_a3 A3 (
	.INCS_b  (INCS_b  ),
	.AB      (AB[2:0] ),
	.DB      (DB      ),
	.UP      (UP      ),
	.DOWN    (DOWN    ),
	.LEFT    (LEFT    ),
	.RIGHT   (RIGHT   ),
	.SHOT2   (SHOT2   ),
	.SHOT1   (SHOT1   ),
	.DIPSW_B (DIPSW_B ),
	.DIPSW_A (DIPSW_A ),
	.COIN    (COIN    ),
	.START   (START   ),
	.RESERVED(RESERVED)
);


	wire phiB;
	wire H4;
	wire H2;
	wire OH;
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
	wire HINIT_b;
jt_gng_a5 A5 (
	.phiB    (phiB    ),
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


	wire N4H;
	wire [3:0] CC;
	wire CHHFLIP;
	wire CHHFLIPq;
	wire CHVFLIP;
	wire [9:0] AC;
jt_gng_a6 A6 (
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
	.AB      (AB[10:0])
);


	wire CH6M;
	wire CHARZ;
	wire CHARY;
jt_gng_a7 A7 (
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


wire [3:0] RR, GG, BB;

jt_gng_a8 A8 (
	.AB    (AB[7:0]),
	.WRB_b (WRB_b ),
	.RDB_b (RDB_b ),
	.DB    (DB    ),
	.CC    (CC    ),
	.CHARY (CHARY ),
	.CHARZ (CHARZ ),
	.OBJ   (OBJ[5:0]),
	.SCRWIN(SCRWIN),
	.SCD   (SCD   ),
	.SCRX  (SCRX  ),
	.SCRY  (SCRY  ),
	.SCRZ  (SCRZ  ),
	.CH6M  (CH6M  ),
	.LVBL  (LVBL  ),
	.LHBL  (LHBL  ),
	.BCS_b (BCS_b ),
	.RGCS_b(RGCS_b),
	.RR    (RR    ),
	.GG    (GG    ),
	.BB    (BB    )
);

`ifdef CHR_DUMP
reg lastHINIT, lastIRQ;

always @(posedge G6M) begin
	lastHINIT <= HINIT_b;
	lastIRQ   <= IRQ1;
	if( IRQ1 && !lastIRQ )
		$write("-----------------------------------------------\n");
	else
	if( !HINIT_b && lastHINIT) $write("\n");
	else
	case( ~{CHARY, CHARZ} )
		2'b00: $write(" ");
		2'b01: $write("·");
		2'b10: $write("+");
		2'b11: $write("#");
	endcase // {CHARY, CHARZ}
end
`endif
endmodule // jt_gng_a