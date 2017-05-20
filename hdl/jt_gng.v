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
jt_gng_a i_jt_gng_a (
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


endmodule

