`timescale 1ns/1ps

/*

	Board A

*/

module jt_gng_test;
	`ifdef DUMP
	initial begin
		$display("DUMP ON");
		$DUMPFILE("test.lxt");
		$dumpvars(2,UUT.boardA);
		$dumpvars(2,UUT.boardB);
		$dumpvars(1,UUT.boardA.A1);
		$dumpvars(1,UUT.boardA.A2);
		$dumpvars(1,UUT.boardA.A1.main);
		$dumpvars(2,UUT.boardB.B1);
		$dumpvars(2,UUT.boardB.B2);
		$dumpon;
	end
	`endif

	// initial #(300*100*1000*1000) $finish; // 1 hour run time
	integer reps;
	initial begin
		for( reps=0; reps<`REPS; reps=reps+1)
			#(50*1000*1000);
		$finish;
	end

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

jt_gng UUT (
	.UP      (UP      ),
	.DOWN    (DOWN    ),
	.LEFT    (LEFT    ),
	.RIGHT   (RIGHT   ),
	.SHOT2   (SHOT2   ),
	.SHOT1   (SHOT1   ),
	.COUNTER (COUNTER ),
	.SYNC    (SYNC    ),
	.DIPSW_B (DIPSW_B ),
	.DIPSW_A (DIPSW_A ),
	.COIN    (COIN    ),
	.START   (START   ),
	.RESERVED(RESERVED)
);


endmodule // jt_gng_a_test