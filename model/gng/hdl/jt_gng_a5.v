`timescale 1ns/1ps

/*

	Schematic sheet: 85606-A-2-5/8 Synchronous
	Clock generation

*/

module jt_gng_a5(
	output	phiB,		// to A-4/8
	output	H4,			// to A-7/8 and C6
	output	H2,			// to A-6/8 and D5
	output	G6M,		// 6M on schematic. To A-7/8 and C3
	output	LHBL,		// to A-8/8 and D9
	output	G4_3H,		// to A-7/8 and C4
	output	OH,			// to A-6/8 and D3
	output	G4H,		// to A-6/8, A-7/8 and D4
	output	H1,			// to C5
	output	H8,			// to A-6/8 and D6
	output	H16,		// to A-6/8 and C7
	output  H32,		// to A-6/8 and D7
	output  H64,		// to A-6/8 and C8
	output  H128,		// to A-6/8 and D8
	output  H256,		// to C9
	output	CMP_SYNC,	// to F
	output	LVBL,		// to A-8/8
	output	V1,			// to A-7/8 and C10
	output	V2,			// to A-7/8 and D10
	output	V4,			// to A-7/8 and C11
	output	V8,			// to A-6/8 and D11
	output	V16,		// to A-6/8 and C12
	output	V32,		// to A-4/8 and D12
	output	V64,		// to C13
	output	V128,		// to D13
	output	IRQ1,		// to A-1/8
	output	HINIT_b		// to C18
);

	wire H1, H1_b, H16, H8, XH4, XH2;
	wire H256, H128, H64, H32;
	wire L6M, X6M;
	wire sh5_1k_ca, sh5_2k_ca;

	wire HINIT_b;
	assign #2 HINIT_b = ~sh5_1k_ca; // 5K
	wire VCLK;

	reg X12M;

	initial begin
		X12M = 1'b0;
		forever #41.667 X12M = ~X12M;
	end

	jt7474 sh5_3ka(
		.clk	( X12M	),
		.pr_b	( 1'b1 	),
		.cl_b	( 1'b1 	),
		.d		( X6M 	),
		.q		( L6M	),
		.q_b	( X6M	)
	);

	jt7474 sh5_3kb(
		.clk	( X6M	),
		.pr_b	( 1'b1 	),
		.cl_b	( 1'b1 	),
		.d		( H1_b 	),
		.q		( H1	),
		.q_b	( H1_b	)
	);

	// horizontal line counter
	jt74161 sh5_2k(
		.clk	( X6M		),
		.ld_b	( HINIT_b	),
		.cep	( H1		),
		.cet	( H1		),
		.cl_b	( 1'b1		),
		.d		( 4'd0		),
		.q		( {H16, H8, XH4, XH2 } ),
		.ca		( sh5_2k_ca	)
	);

	jt74161 sh5_1k(
		.clk	( X6M		),
		.ld_b	( HINIT_b	),
		.cep	( sh5_2k_ca	),
		.cet	( sh5_2k_ca	),
		.cl_b	( 1'b1		),
		.d		( 4'b0100	),
		.q		( {H256, H128, H64, H32 } ),
		.ca		( sh5_1k_ca	)
	);

	wire [8:0] hcnt = {H256, H128, H64, H32, H16, H8, XH4, XH2, H1 };


	wire H1_2_4;
	assign #2 H1_2_4 = ~&{ H1, XH2, XH4 };

	wire C4, D3, D4;
	assign G4_3H = C4;
	assign OH = D3;
	assign G4H = D4;

	jt7474 sh5_4nb(
		.clk	( L6M	),
		.pr_b	( 1'b1 	),
		.cl_b	( 1'b1 	),
		.d		( H1_2_4 	),
		.q		( sh5_4nb_q	)
	);

	jt7474 sh5_4nc(
		.clk	( X6M	),
		.pr_b	( 1'b1 	),
		.cl_b	( 1'b1 	),
		.d		( sh5_4nb_q 	),
		.q_b	( D3	)
	);

	jt7474 sh5_4na(
		.clk	( L6M	),
		.pr_b	( 1'b1 	),
		.cl_b	( 1'b1 	),
		.d		( H1 & XH2 	),
		.q		( C4		)
	);

	jt7474 sh5_4nd(
		.clk	( X6M	),
		.pr_b	( 1'b1 	),
		.cl_b	( 1'b1 	),
		.d		( C4 & ~XH4	),
		.q		( D4		)
	);

	wire LHBL;
	wire sh5_5m_j, sh5_5m_k;
	assign #2 sh5_5m_j = ~H1_2_4 & ~H256;
	assign #2 sh5_5m_k = ~H1_2_4 &  H256;

	jt74112 sh5_5m(
		.clk_b	( L6M	),
		.pr_b	( 1'b1 	),
		.cl_b	( 1'b1 	),
		.j		( sh5_5m_j	),
		.k		( sh5_5m_k	),
		.q_b	( LHBL		)
	);

	// vertical line counter
	wire V1, VINIT;
	wire VINIT_b = ~VINIT;

	jt7474 sh5_3la(
		.clk	( X6M	),
		.pr_b	( 1'b1 	),
		.cl_b	( 1'b1 	),
		.d		( sh5_1k_ca	),
		.q		( VCLK	)
	);

	jt7474 sh5_3lb(
		.clk	( VCLK	),
		.pr_b	( 1'b1 	),
		.cl_b	( 1'b1 	),
		.d		( sh5_3l_q_b	),
		.q		( V1			),
		.q_b	( sh5_3l_q_b	)
	);

	jt74161 sh5_1l(
		.clk	( VCLK		),
		.ld_b	( VINIT_b	),
		.cep	( V1		),
		.cet	( V1		),
		.cl_b	( 1'b1		),
		.d		( 4'b1101	),
		.q		( {V16, V8, V4, V2 } ),
		.ca		( sh5_1l_ca	)
	);

	jt74161 sh5_2l(
		.clk	( VCLK		),
		.ld_b	( VINIT_b	),
		.cep	( sh5_1l_ca	),
		.cet	( sh5_1l_ca	),
		.cl_b	( 1'b1		),
		.d		( 4'b0111	),
		.q		( {V256, V128, V64, V32 } ),
		.ca		( VINIT	)
	);

	wire [8:0] vcnt = {V256, V128, V64, V32, V16, V8, V4, V2, V1 };

	// IRQ generation
	wire IRQ1, IRQ1_b;

	jt7474 sh5_3m_b(
		.clk	( 1'b0	),
		.pr_b	( ~&{V16, V32, V64, V128, V256}	),
		.cl_b	( ~&{V16, ~V128, V256} 	),
		.d		( 1'b0	),
		.q		( IRQ1		),
		.q_b	( IRQ1_b	)
	);

	wire LVBL;

	jt7474 sh5_3m_a(
		.clk	( D3	),
		.pr_b	( 1'b1	),
		.cl_b	( 1'b1 	),
		.d		( IRQ1_b	),
		.q		( LVBL		)
	);

	wire [7:0] sh5_2m_y_b, sh5_4k_y_b;
	wire CMP_SYNC;
	assign #2 CMP_SYNC = &{ sh5_4k_y_b[4], sh5_4k_y_b[3], sh5_2m_y_b[3] };

	jt74138 sh5_4k(
		.e1_b	( 1'b0 ),
		.e2_b	( H256 ),
		.e3		( 1'b1 ),
		.a		( {H64, H32, H16} ),
		.y_b	( sh5_4k_y_b )
	);

	jt74138 sh5_2m(
		.e1_b	( 1'b0 ),
		.e2_b	( IRQ1_b ),
		.e3		( 1'b1 ),
		.a		( {V256, V128, V8} ),
		.y_b	( sh5_2m_y_b )
	);

	// Z-buffered outputs
	wire [5:0] sh5_1j_y;

	assign #2 phiB = sh5_1j_y[3]; // 48
	assign #2   H4 = sh5_1j_y[2]; // H4
	assign #2   H2 = sh5_1j_y[1]; // H2
	assign #2	G6M = sh5_1j_y[0]; // 6M

	jt74367 sh5_1j(
		.A		( {2'b0, H1_b, XH4, XH2, X6M } ),
		.Y		( sh5_1j_y 	),
		.en4_b	( 1'b0 		),
		.en6_b	( 1'b0 		)
	);

endmodule

