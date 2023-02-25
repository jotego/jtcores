`timescale 1ns/1ps

module jt_gng_a5_tb;

	initial begin
		$DUMPFILE("test.lxt");
		$dumpvars;
		$dumpon;
	end

	initial begin
		#(83*1000*1000) $finish;
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


endmodule