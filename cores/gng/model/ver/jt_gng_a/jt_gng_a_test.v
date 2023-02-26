`timescale 1ns/1ps

/*

	Board A

*/

module jt_gng_a_test;
	`ifdef DUMP
	initial begin
		$DUMPFILE("test.lxt");
		$dumpvars(0,UUT.A1);
		$dumpvars(1,UUT.A2);
		//$dumpvars(1,UUT.A2.u_2C);
		$dumpvars(1,UUT.A3);
		$dumpvars(1,UUT.A6);
		$dumpon;
	end
	`endif

	initial #(10*1000*1000*1000) $finish;

	wire [1:0] UP		= 2'd0;
	wire [1:0] DOWN		= 2'd0;
	wire [1:0] LEFT		= 2'd0;
	wire [1:0] RIGHT	= 2'd0;
	wire [1:0] SHOT2	= 2'd0;
	wire [1:0] SHOT1	= 2'd0;
	wire [1:0] COUNTER	= 2'd0;
	wire SYNC;
	wire [7:0] DIPSW_B	= 8'd0;
	wire [7:0] DIPSW_A	= 8'd0;
	wire [1:0] COIN		= 2'd0;
	wire [1:0] START	= 2'd0;
	wire [1:0] RESERVED	= 2'd0;
	wire [7:0] DB;
	wire [12:0] AB;
	wire SCRWIN;
	wire SCRPO_b;
	wire SCRCS_b;
	wire MRDY2_b		= 1'b1;
	wire BLCNTEN_b		= 1'b1;
	wire WRB_b;
	wire RDB_b;
	wire AKB_b;
	wire ROB_b = 1'b1;
	wire ALC1_b;

jt_gng_a UUT (
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

endmodule // jt_gng_a_test