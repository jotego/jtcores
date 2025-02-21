module k007786	(
				input clr_n,
				input clk2,
				input ampx,
				input vcen,
				input p256,
				input hsy_n,	
				input hflp,
				input vflp,
				input sel,
				input [8:0] hpd,
				input [7:0] vpd,
				output [7:0] fa,
				output [7:0] fb,
				output [7:0] fc,
				output [7:0] fd
				);

wire [6:0] vcnt;
wire vcnten;

DFR_d_ff	q49	(
				.clk(clk2),
				.rst(~clr_n),
				.d(vcen^vcnt[0]),// cnten_n
				.q(vcnt[0]),
				.q_bar()
				);

assign o_e27b = vcnt[0] & vcen;

DFR_d_ff	f27	(
				.clk(clk2),
				.rst(~clr_n),
				.d(o_e27b ^ vcnt[1]),// cnten_n
				.q(vcnt[1]),
				.q_bar()
				);

assign o_e27a = vcnt[1] & o_e27b;
assign o_c34 = vcen & &vcnt[4:0];

DFR_d_ff	c54	(
				.clk(clk2),
				.rst(~clr_n),
				.d( (vcnt[2] ^ o_e27a) | o_b16),// cnten_n
				.q(vcnt[2]),
				.q_bar()
				);

assign o_b10b = o_e27a & vcnt[2]; 

DFR_d_ff	e65	(
				.clk(clk2),
				.rst(~clr_n),
				.d( (o_b10b ^ vcnt[3]) | o_b16 ),// cnten_n
				.q(vcnt[3]),
				.q_bar()
				);
assign o_b10a = o_b10b & vcnt[3]; 

DFR_d_ff	n59	(
				.clk(clk2),
				.rst(~clr_n),
				.d( (o_b10a ^ vcnt[4]) | o_b16 ),// cnten_n
				.q(vcnt[4]),
				.q_bar()
				);

assign o_a21b = vcnt[5] & o_c34;
assign o_a21a = o_a21b & vcnt[6];

DFR_d_ff	b54	(
				.clk(clk2),
				.rst(~clr_n),
				.d( o_a21a ^ vcnten),// cnten_n
				.q(vcnten),
				.q_bar()
				);

assign o_b16 = vcnten & &vcnt[6:5] & o_c34;
assign o_a15 = vcnt[6] ^ o_a21b;

DFR_d_ff	a52	(
				.clk(clk2),
				.rst(~clr_n),
				.d( o_a15 | o_b16 ),// cnten_n
				.q(vcnt[6]),
				.q_bar()
				);

DFR_d_ff	p51	(
				.clk(clk2),
				.rst(~clr_n),
				.d( (vcnt[5] ^ o_c34) | o_b16 ),// cnten_n
				.q(vcnt[5]),
				.q_bar()
				);

assign o_b34 = &vcnt[4:0] & vcnten;

DFR_d_ff	d57	(
				.clk(clk2),
				.rst(~clr_n),
				.d( o_b34 ),
				.q(q_d57),
				.q_bar()
				);

DFR_d_ff	f62	(
				.clk(clk2),
				.rst(~clr_n),
				.d(q_d57),
				.q(q_f62),
				.q_bar()
				);

DFR_d_ff	g64	(
				.clk(clk2),
				.rst(~clr_n),
				.d(q_f62),
				.q(q_g64),
				.q_bar()
				);

DFR_d_ff	k66	(
				.clk(clk2),
				.rst(~clr_n),
				.d(q_g64),
				.q(o_j116),
				.q_bar(o_k116)
				);

DFR_d_ff	g80	(
				.clk(clk2),
				.rst(~clr_n),
				.d(q_bar_g80),
				.q(h1),
				.q_bar(q_bar_g80)
				);

DFR_d_ff	j70	(
				.clk(clk2),
				.rst(~clr_n),
				.d(h2 ^ h1),
				.q(h2),
				.q_bar(h2_n)
				);

assign _2h = h1 & h2;

DFR_d_ff	i76	(
				.clk(clk2),
				.rst(~clr_n),
				.d(_2h ^ h4),
				.q(h4),
				.q_bar()
				);

assign o_d115b = _2h & h4;

DFR_d_ff	j81	(
				.clk(clk2),
				.rst(~clr_n),
				.d(o_d115b ^ h8),
				.q(h8),
				.q_bar()
				);

assign o_d115a = h8 & o_d115b;

DFR_d_ff	h74	(
				.clk(clk2),
				.rst(~clr_n),
				.d(o_d115a ^ h16),
				.q(h16),
				.q_bar(h16_n)
				);

assign o_k104b = o_d115a & h16;

DFR_d_ff	o85	(
				.clk(clk2),
				.rst(~clr_n),
				.d(o_k104b ^ h32),
				.q(h32),
				.q_bar()
				);


assign h1h2h4 = h1 & h2 & h4;
assign h1h2h4_n = ~h1h2h4;

assign o_f91 = h8 & h1h2h4 | h8b & h1h2h4_n;

DFF_d_ff	f82	(
				.clk(clk2),
				.d(o_f91),
				.q(h8b),
				.q_bar()
				);

assign o_j92 = h1h2h4_n & h16b | h1h2h4 & h16;

DFF_d_ff	h85	(
				.clk(clk2),
				.d(o_j92),
				.q(h16b),
				.q_bar()
				);

assign o_q115b = ~(hsy_n & h32s);

DFR_d_ff	l86	(
				.clk(h16_n),
				.rst(~clr_n),
				.d(o_q115b),
				.q(h32s),
				.q_bar()
				);

assign o_c98 = h1h2h4_n & h32b | h1h2h4 & h32s;

DFF_d_ff	e93	(
				.clk(clk2),
				.d(o_c98),
				.q(h32b),
				.q_bar()
				);

assign hflp_n = ~hflp;
assign hsy = ~hsy_n;

assign o_p107 = hflp_n & hsy | hsy_n & (h64s ^ h32s);

DFR_d_ff	m81	(
				.clk(h16_n),
				.rst(~clr_n),
				.d(o_p107),
				.q(h64s),
				.q_bar()
				);

assign o_q94 = h1h2h4_n & h64b | h1h2h4 & h64s;

DFF_d_ff	p90	(
				.clk(clk2),
				.d(o_q94),
				.q(h64b),
				.q_bar()
				);

assign o_107b = h32s & h64s;
assign o_q115a = ~(hsy_n & ~(h128s ^ o_107b));

DFR_d_ff	k81	(
				.clk(h16_n),
				.rst(~clr_n),
				.d(o_q115a),
				.q(h128s),
				.q_bar()
				);

assign o_d97 = h1h2h4_n & h128b | h1h2h4 & h128s;

DFF_d_ff	d88	(
				.clk(clk2),
				.d(o_d97),
				.q(h128b),
				.q_bar()
				);

DFR_d_ff	n70	(
				.clk(~hsy_n),
				.rst(~clr_n),
				.d(q_bar_n70),
				.q(q_n70),
				.q_bar(q_bar_n70)
				);


endmodule				