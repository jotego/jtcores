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
	input	[7:0]	DIPSW_B,
	input	[7:0]	DIPSW_A,
	input	[1:0]	COIN,
	input	[1:0]	START,
	input	[1:0]	RESERVED,
	// board-to-board connector 1
	inout	[ 7:0]	DB,			// A8-A1
	inout	[12:0]	AB,			// A25-A13
	output			SCRWIN,
	output			SCRPO_b,
	output			SCRCS_b,
	input			MRDY2_b,
	input			BLCNTEN_b,	// B23
	output			WRB_b,		// B24
	output			RDB_b,		// B25
	output			AKB_b,		// B21
	input			ROB_b,		// B22
	output			ALC1_b		// B19
);


wire IRQ1;
wire ALC1_b;
wire MRDY_b;
wire G6M;
wire WRAM_b;
wire EXTEN_b;
wire [2:0] bank;
wire ECLK;

jt_gng_a1 A1 (
	.IRQ1     (IRQ1     ),
	.ALC1_b   (ALC1_b   ),
	.ALC2_b   (ALC2_b   ),
	.ROB_b    (ROB_b    ),
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


wire SRES_b;
wire FLIP;
wire RGCS_b;
wire BCS_b;
wire SOUND;
wire OKOUT_b;
wire CHARCS_b;
wire INCS_b;
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


	wire Phi8;
	wire H4;
	wire H2;
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
	wire HINIT_b;
jt_gng_a5 A5 (
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


endmodule // jt_gng_a