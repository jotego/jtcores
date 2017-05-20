module jt_gng;


	wire [1:0] UP;
	wire [1:0] DOWN;
	wire [1:0] LEFT;
	wire [1:0] RIGHT;
	wire [1:0] SHOT2;
	wire [1:0] SHOT1;
	wire [1:0] COUNTER;
	wire SYNC;
	wire [7:0] DIPSW_B;
	wire [7:0] DIPSW_A;
	wire [1:0] COIN;
	wire [1:0] START;
	wire [1:0] RESERVED;
	wire [7:0] DB;
	wire [12:0] AB;
	wire SCRWIN;
	wire SCRPO_b;
	wire SCRCS_b;
	wire MRDY2_b;
	wire BLCNTEN_b;
	wire WRB_b;
	wire RDB_b;
	wire AKB_b;
	wire ROB_b;
	wire ALC1_b;

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
	.DB       (DB       ),
	.AB       (AB       ),
	.SCRWIN   (SCRWIN   ),
	.SCRPO_b  (SCRPO_b  ),
	.SCRCS_b  (SCRCS_b  ),
	.MRDY2_b  (MRDY2_b  ),
	.BLCNTEN_b(BLCNTEN_b),
	.WRB_b    (WRB_b    ),
	.RDB_b    (RDB_b    ),
	.AKB_b    (AKB_b    ),
	.ROB_b    (ROB_b    ),
	.ALC1_b   (ALC1_b   )
);


	wire ACL2_b;
	wire OKOUT_b;
	wire V1;
	wire V2;
	wire V4;
	wire V8;
	wire V16;
	wire V32;
	wire V64;
	wire V128;
	wire FLIP;
	wire CBCS_b;
	wire G6M;
	wire HINIT_b;
	wire H256;
	wire H128;
	wire H64;
	wire H32;
	wire H16;
	wire H8;
	wire H4;
	wire H2;
	wire H1;
	wire [7:0] OBJ;
	wire [2:0] SCO;
	wire SCRX;
	wire SCRY;
	wire SCRZ;
jt_gng_b i_jt_gng_b (
	.RDB_b    (RDB_b    ),
	.WRB_b    (WRB_b    ),
	.AB       (AB       ),
	.DB       (DB       ),
	.BLCNTEN_b(BLCNTEN_b),
	.ROB_b    (ROB_b    ),
	.ACL2_b   (ACL2_b   ),
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
	.CBCS_b   (CBCS_b   ),
	.SCRCS_b  (SCRCS_b  ),
	.MRDY2_b  (MRDY2_b  ),
	.G6M      (G6M      ),
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
	.OBJ      (OBJ      ),
	.SCRWIN   (SCRWIN   ),
	.SCO      (SCO      ),
	.SCRX     (SCRX     ),
	.SCRY     (SCRY     ),
	.SCRZ     (SCRZ     )
);


endmodule

