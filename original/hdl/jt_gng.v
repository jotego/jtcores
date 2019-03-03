module jt_gng(
	input [1:0] UP,
	input [1:0] DOWN,
	input [1:0] LEFT,
	input [1:0] RIGHT,
	input [1:0] SHOT2,
	input [1:0] SHOT1,
	output [1:0] COUNTER,
	output SYNC,
	inout [7:0] DIPSW_B,
	inout [7:0] DIPSW_A,
	input [1:0] COIN,
	input [1:0] START,
	input [1:0] RESERVED
);

wire [7:0]	DB, OBJ;
wire [12:0] AB;
wire [2:0]	SCD;
wire SCRWIN, OH;
wire SCRPO_b;
wire SCRCS_b;
wire MRDY2_b;
wire BLCNTEN_b;
wire WRB_b;
wire RDB_b;
wire AKB_b;
wire RQB_b;
wire ALC2_b;
wire OKOUT_b;
wire G4H;

jt_gng_a boardA (
	.UP       (UP       ),
	.DOWN     (DOWN     ),
	.LEFT     (LEFT     ),
	.RIGHT    (RIGHT    ),
	.SHOT2    (SHOT2    ),
	.SHOT1    (SHOT1    ),
	.COUNTER  (COUNTER  ),
	.SYNC     (SYNC     ),
	.DIPSW_B  (DIPSW_B  ),
	.DIPSW_A  (DIPSW_A  ),
	.COIN     (COIN     ),
	.START    (START    ),
	.RESERVED (RESERVED ),
	// Board-to-board connector
	.RDB_b    (RDB_b    ),
	.WRB_b    (WRB_b    ),
	.AB       (AB       ),
	.DB       (DB       ),
	.BLCNTEN_b(BLCNTEN_b),
	.RQB_b    (RQB_b    ),
	.ALC2_b   (ALC2_b   ),
	.AKB_b    (AKB_b    ),
	.OKOUT_b  (OKOUT_b  ),
	.V1       (V1       ),
	.V2       (V2       ),
	.V4       (V4       ),
	.V8       (V8       ),
	.V16      (V16      ),
	.V32      (V32      ),
	.V64      (V64      ),
	.V128     (V128     ),
	.FLIP     (FLIP     ),
	.OH		  (OH		),
	.CBCS_b   (CBCS_b   ),
	.SCRCS_b  (SCRCS_b  ),
	.MRDY2_b  (MRDY2_b  ),
	.G6M      (G6M      ),
	.G4H	  (G4H		),
	.G4_3H	  (G4_3H    ),
	.HINIT_b  (HINIT_b  ),
	.H256     (H256     ),
	.H128     (H128     ),
	.H64      (H64      ),
	.H32      (H32      ),
	.H16      (H16      ),
	.H8       (H8       ),
	.H4       (H4       ),
	.H2       (H2       ),
	.H1       (H1       ),
	.LHBL	  (LHBL		),
	.OBJ      (OBJ      ),
	.SCRWIN   (SCRWIN   ),
	.SCD      (SCD      ),
	.SCRX     (SCRX     ),
	.SCRY     (SCRY     ),
	.SCRZ     (SCRZ     )
);

jt_gng_b boardB (
	.RDB_b    (RDB_b    ),
	.WRB_b    (WRB_b    ),
	.AB       (AB       ),
	.DB       (DB       ),
	.BLCNTEN_b(BLCNTEN_b),
	.RQB_b    (RQB_b    ),
	.ALC2_b   (ALC2_b   ),
	.AKB_b    (AKB_b    ),
	.OKOUT_b  (OKOUT_b  ),
	.V1       (V1       ),
	.V2       (V2       ),
	.V4       (V4       ),
	.V8       (V8       ),
	.V16      (V16      ),
	.V32      (V32      ),
	.V64      (V64      ),
	.V128     (V128     ),
	.FLIP     (FLIP     ),
	.OH		  (OH		),
	.CBCS_b   (CBCS_b   ),
	.SCRCS_b  (SCRCS_b  ),
	.MRDY2_b  (MRDY2_b  ),
	.G6M      (G6M      ),
	.G4H	  (G4H		),
	.G4_3H	  (G4_3H    ),
	.HINIT_b  (HINIT_b  ),
	.H256     (H256     ),
	.H128     (H128     ),
	.H64      (H64      ),
	.H32      (H32      ),
	.H16      (H16      ),
	.H8       (H8       ),
	.H4       (H4       ),
	.H2       (H2       ),
	.H1       (H1       ),
	.LHBL	  (LHBL		),
	.OBJ      (OBJ      ),
	.SCRWIN   (SCRWIN   ),
	.SCD      (SCD      ),
	.SCRX     (SCRX     ),
	.SCRY     (SCRY     ),
	.SCRZ     (SCRZ     )
);


endmodule

