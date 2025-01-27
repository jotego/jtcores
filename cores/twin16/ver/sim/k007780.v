module k007780	(
				input clr_n,
				input clk2,
				input ampx,
				input tim2,
				input p1h,
				input vcra_n,
				input slwr_n,
				input suwr_n,
				input [17:1] sab
				);

wire [2:0] hcnt;

assign #1 d_e65 = h2 ^ p1h;

FDO_d_ff e65	(
			   .d(d_e65),
			   .clk(clk2),
			   .reset_n(clr_n),
			   .q(h2),
			   .q_bar()
				);
assign #1 out_e60 = h2 & p1h;
assign #1 out_f60 = h4 ^ out_e60;

FDO_d_ff f65	(
			   .d(out_f60),
			   .clk(clk2),
			   .reset_n(clr_n),
			   .q(h4),
			   .q_bar()
				);

assign e62_out = p1h & h2 & h4;

FDO_d_ff g60	(
			   .d(e62_out ^ h8) ,
			   .clk(clk2),
			   .reset_n(clr_n),
			   .q(h8),
			   .q_bar()
				);

assign h60_out = h8 & e62_out;

FDO_d_ff j60	(
			   .d(h60_out ^ h16) ,
			   .clk(clk2),
			   .reset_n(clr_n),
			   .q(h16),
			   .q_bar()
				);

FDM_d_ff e48	(
				.d(h4),
				.ck(clk2),
				.q(e48_q),
				.q_bar()
				);

assign e54_out = e48_q & p1h;

FDN_d_ff h51	(
				.d(1'b0),
				.ck(e54_out),
				.s_n(~vcra_n),
				.q(vcra_d_n),
				.q_bar()
				);

assign f54_out = vcra_d_n & e54_out;
assign vcra0 = ~(ampx | f54_out);
assign vcra1 = ~((~ampx) | f54_out);
assign vcra = ~vcra_d_n;
assign hcnt = {h4,h2,1'b0};

assign wrl1_n = ~(sab[1] & vcra & ~tim2 & ~slwr_n);
assign vcoe_n = h2 & h4;// /SREAD skipped for now.
assign #4 hcnt1 = ~h2 & ~h4 & p1h;

endmodule