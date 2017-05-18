`timescale 1ns/1ps

/*

	Schematic sheet: 85606-A- -1/8 CPU

*/

module jt_gng_b(
	input			RDB_b,		// B25
	input			WRB_b,		// B24
	input [12:0] 	AB,			// A25-A13
	input [7:0] 	DB,			// A8-A1
	input			BLCNTEN_b,	// B23
	output			ROB_b,		// B22
	input			ACL2_b,		// B19
	input			AKB_b,		// B21
	input			OKOUT_b,	// B20
	input			V1,			// C10
	input			V2,			// D10
	input			V4,			// C11
	input			V8,			// D11
	input			V16,		// C12
	input			V32,		// D12
	input			V64,		// C13
	input			V128,		// D13
	input			FLIP,		// D2
	
);


	wire V1F;
	wire V2F;
	wire V4F;
	wire V8F;
	wire V16F;
	wire V32F;
	wire V64F;
	wire V128F;
	wire [8:0] OB;
	wire OVER96_b;
	wire phi_BB;
	wire BLEN;
	wire MATCH_b;
jt_gng_b1 i_jt_gng_b1 (
	.RDB_b	  (RDB_b	),
	.WRB_b	  (WRB_b	),
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
	.AB       (AB       ),
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


endmodule // jt_gng_b