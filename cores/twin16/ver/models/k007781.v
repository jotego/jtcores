module k007781	(
				input clk2,
				input clr_n
				);

assign clr = ~clr_n;

TFR_t_ff i4(
		.clk(clk2), 
		.rst(clr),
		.q(h1), 
		.q_bar(h1_n)
);

TFRE_t_ff j13(
	.clk(clk2), 
	.rst(clr), 
	.t_n(h1_n), 
	.q(h2), 
	.q_bar(h2_n)
);

TFRE_t_ff k15(
	.clk(clk2), 
	.rst(clr), 
	.t_n(h1_n | h2_n), 
	.q(h4_pre), 
	.q_bar(h4_n)
);

assign #5 h4 = h4_pre;// guess

DFR_d_ff m4(
	.clk(clk2),
	.rst(clr),
	.d(h4),
	.q(h4d),
	.q_bar()
);

DFR_d_ff o6(
	.clk(clk2),
	.rst(clr),
	.d(h4d),
	.q(h4d2),
	.q_bar()
);

DFR_d_ff i13(
	.clk(clk2),
	.rst(clr),
	.d(h1 & h2_n & h4_n),
	.q(hcnt2_pre),
	.q_bar()
);

assign #5 hcnt2 = hcnt2_pre; // guess
endmodule