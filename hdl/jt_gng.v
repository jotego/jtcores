module jt_gng;

	wire H1, H1_b, H16, H8, XH4, XH2;
	wire H256, H128, H64, H32;
	wire L6M, X6M;
	wire sh5_1k_ca, sh5_2k_ca;

	wire HINIT_b = ~sh5_1k_ca;
	wire VCLK;

	reg X12M;

	initial begin
		X12M = 1'b0;
		forever #83.334 X12M = ~X12M;
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
	jt7641 sh5_2k(
		.clk	( X6M		),
		.ld_b	( HINIT_b	),
		.cep	( H1		),
		.cet	( H1		),
		.cl_b	( 1'b1		),
		.d		( 4'd0		),
		.q		( {H16, H8, XH4, XH2 } ),
		.ca		( sh5_2k_ca	)
	);

	jt7641 sh5_1k(
		.clk	( X6M		),
		.ld_b	( HINIT_b	),
		.cep	( sh5_2k_ca	),
		.cet	( sh5_2k_ca	),
		.cl_b	( 1'b1		),
		.d		( 4'b0100	),
		.q		( {H256, H128, H64, H32 } ),
		.ca		( sh5_1k_ca	)
	);


	wire H1_2_4 = ~&{ H1, XH2, XH4 };
	wire C4, D3, D4;

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
	wire sh5_5m_j = ~H1_2_4 & ~H256;
	wire sh5_5m_k = ~H1_2_4 &  H256;

	jt74112 sh5_5m(
		.clk	( L6M	),
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
		.q		( V1			)
		.q_b	( sh5_3l_q_b	)
	);

	jt7641 sh5_1l(
		.clk	( VCLK		),
		.ld_b	( VINIT_b	),
		.cep	( V1		),
		.cet	( V1		),
		.cl_b	( 1'b1		),
		.d		( 4'd0		),
		.q		( {V16, V8, V4, V2 } ),
		.ca		( sh5_1l_ca	)
	);

	jt7641 sh5_2l(
		.clk	( VCLK		),
		.ld_b	( HINIT_b	),
		.cep	( sh5_1l_ca	),
		.cet	( sh5_1l_ca	),
		.cl_b	( 1'b1		),
		.d		( 4'b1000	),
		.q		( {V256, V128, V64, V32 } ),
		.ca		( VINIT	)
	);

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
	wire CMP_SYNC = &{ sh5_4k_y_b[4], sh5_4k_y_b[3], sh5_2m_y_b[3] };

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

	wire net48 = sh5_1j_y[3]; // 48
	wire C6 = sh5_1j_y[2]; // H4
	wire D5 = sh5_1j_y[1]; // H2
	wire C3 = sh5_1j_y[0]; // 6M

	jt74367 sh5_1j(
		.A		( {2'b0, H1_b, XH4, XH2, X6M } ),
		.Y		( sh5_1j_y )
		.en4_b	( 1'b0 ),
		.en6_b	( 1'b0 )
	);	

endmodule

