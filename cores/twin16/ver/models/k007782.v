//`timescale 1ns/100ps // 1 ns time unit, 100 ps resolution
//`include "~/github/gate_arrays/fujitsu/av/hdl/*"

//`timescale 10ns/100ps
module k007782	(
				input	p18m,
				input	exres_n,
				input	hflp,
				input	vflp,
				input	ocra_n,
				input	vcra_n,
				input	ocro_n,
				input	dma,
				input	dmac_n,
				input	tes1,
				input	tes2,
				output	cclk,
				output	cres_n,
				output	clr_n,
				output	clk2,
				output	tim,
				output	tim1,
				output	tim2,
				output	tim3,
				output	hsy_n,
				output	ras_n,
				output	cas_n,
				output	wr_n,				
				output	x1s,
				output	[8:0] ehcount,
				output	vsy_n,
				output	vcen,
				output	p256,
				output	osc_n,
				output	fbrf,
				output	syld,
				output	[7:0] evcount,
				output	cbk_n,
				output	vblk,
				output	csy,
				output	bfc_n,
				output	ordt_n,
				output	svdt_n,
				output	orad_n,
				output	dmin,
				output	db0,
				output	obin,
				output	dmc_n
				);

wire [8:0] hcount,vcount;

/*
* Clocks
*/

assign p18m_n = ~p18m;

/*
* Reset
*/ 

FJ4_jk_ff g70 (
			   .j(~exres_n), 
			   .k(exres_n),
			   .clk(p18m_n),
			   .reset_n(exres_n),
			   .q(exres_sync_n),
			   .q_bar()
			   );

assign # 26 clr_n = exres_sync_n;


/*
hc

0: P1H
1: P2H
2: P4H
3: 8H
4: 16H

*/
wire [8:0] hcount_offset;

 
//wire p18m_n,exres_sync_n,p1h,x1s,clk2,clk2_n,clk2_d1,cclk,ras_n,cas_n,wr_n;
//wire q_d56,q_b56,q_bar_b56,q_bar_c62,q_j56;
//wire co_f2,co_g8;
//wire or_out_b54, or_out_a58;


FJ4_jk_ff e56 (
			   .j(clk2), 
			   .k(clk2),
			   .clk(p18m_n),
			   .reset_n(exres_sync_n),
			   .q(x1s),
			   .q_bar()
			   );
FJ4_jk_ff b56 (
			   .j(q_d56), 
			   .k(1'b0),
			   .clk(p18m_n),
			   .reset_n(exres_sync_n),
			   .q(q_b56),
			   .q_bar(q_bar_b56)
			   );
FJ4_jk_ff d56 (
			   .j(q_bar_b56), 
			   .k(1'b0),
			   .clk(p18m_n),
			   .reset_n(exres_sync_n),
			   .q(q_d56),
			   .q_bar(clk2)
			   );
assign # 2 clk2_d1 = clk2;
assign # 1 clk2_n = q_d56;

FDO_d_ff c62  (
			   .d(x1s),
			   .clk(q_b56),
			   .reset_n(exres_sync_n),
			   .q(),
			   .q_bar(q_bar_c62)
				);
FDO_d_ff f62  ( 
			   .d(x1s),
			   .clk(clk2_d1),
			   .reset_n(exres_sync_n),
			   .q(p1h_d1),
			   .q_bar()
				);

assign # 1 p1h = p1h_d1;

FDO_d_ff j56  (
			   .d(x1s),
			   .clk(p18m),
			   .reset_n(exres_sync_n),
			   .q(q_j56),
			   .q_bar()
				);
FDO_d_ff j63  (
			   .d(q_j56),
			   .clk(p18m),
			   .reset_n(exres_sync_n),
			   .q(wr_n),
			   .q_bar()
				);
FDO_d_ff k67  (
			   .d(wr_n),
			   .clk(p18m),
			   .reset_n(exres_sync_n),
			   .q(q_k67),
			   .q_bar()
				);
assign ras_n = q_k67 & wr_n;

FDO_d_ff k60  (
			   .d(q_k67),
			   .clk(p18m),
			   .reset_n(exres_sync_n),
			   .q(cas_n),
			   .q_bar()
				);

FJ4_jk_ff o44 (
			   .j(1'b0), 
			   .k(1'b0),
			   .clk(p18m_n),
			   .reset_n(exres_sync_n),
			   .q(cclk),
			   .q_bar()
			   );

/* Horizontal counters */

assign hcount [0] = p1h;
assign hcount_offset [4:0] = 5'b00000;
assign # 1 co_f2_n = ~co_f2;
C43_4bit_cnt g8 (
				.d(4'b0000),
				.l_n (co_f2_n),
				.ck  (clk2_d1),
				.en  (~tes1 & p1h),
				.ci  (~tes1 & p1h),
				.cl_n(exres_sync_n),
				.q   (hcount [4:1]),
				.co  (co_g8)
				);

C43_4bit_cnt f2 (
				.d		(4'b0100),
				.l_n	(co_f2_n),
				.ck		(clk2_d1),
				.en  	(co_g8),
				.ci  	(co_g8),
				.cl_n	(exres_sync_n),
				.q		(hcount_offset [8:5]),
				.co  	(co_f2)
				);

assign # 24 h16_d_n = ~hcount [4];

C43_4bit_cnt n8 (
				.d   ({~hflp,1'b1,~hflp,1'b1}),
				.l_n (hsy_n),
				.ck  (h16_d_n),
				.en  (1'b1),
				.ci  (1'b1),
				.cl_n(exres_sync_n),
				.q   (hcount [8:5]),
				.co  ()
				);


assign ehcount [2:0] = hcount [2:0];
assign # 24 ehcount [4:3] = {2{hflp}} ^ hcount [4:3];
assign ehcount [8:5] = {4{hflp}} ^ hcount [8:5];

/* End horizontal counters */

/* Horizontal sync vertical counter enable generation - START */
/*
output [4:0] hcount;
0: P1H
1: P2H
2: P4H
3: 8H
4: 16H
output [8:0] hcount_offset;

hcount_offset [4:0] 
4:0 = 0
5: 32H4
6: 64H4
7: 128H4
8: 256H4

*/
/* 32H4 & ~64H4 & 128H4 & ~256H4*/
assign o_a56 = ~( ~hcount_offset [8] & hcount_offset [7] & ~hcount_offset [6] & hcount_offset [5]);
/* P1H & P2H & P4H & 8H & ~16H*/
assign o_g56 = ~( hcount [0] & hcount [1] & hcount [2] & hcount [3] & ~hcount [4] );
assign o_b52 = ~(hcount_offset [6] & hcount_offset [7] & ~hcount_offset [5] & ~hcount_offset [8]);
assign o_b54 = o_g56 | o_b52;
assign o_a58 = o_g56 | o_a56;

FJ4_jk_ff b37 (
			  .j      (o_a58),
			  .clk    (clk2_n),
			  .k	  (o_b54),
			  .reset_n(exres_sync_n & ~hcount_offset [8]),
			  .q      (),
			  .q_bar  (hsy_n)
			  );

/* Vertical counters

vcount [8:0]
0: 1V
1: 2V
2: 4V
3: 8V
4: 16V
5: 32V
6: 64V
7: 128V
8: 256V

end Vertical Counters */


FJ4_jk_ff e44	(
				.j      (~(~o_a58 | tes1)),
				.clk    (clk2_n),
				.k      (o_a58),
				.reset_n(exres_sync_n),
				.q      (vcount [0]),
				.q_bar  (q_bar_e44)
				);

assign vcnten = ~(~(~o_a58 | tes1) | q_bar_e44);
assign # 24 vcen = vcnten; // Vertical counter enable output from 007782.

C43_4bit_cnt j6	(
				.d   (4'b1100),
				.l_n (syld),
				.ck  (clk2_d1),
				.en  (vcnten),
				.ci  (vcnten),
				.cl_n(exres_sync_n),
				.q   (vcount [4:1]),
				.co  (co_j6)
				);

C43_4bit_cnt l8	(
				.d   (4'b0111),
				.l_n (syld),
				.ck  (clk2_d1),
				.en  (co_j6),
				.ci  (co_j6),
				.cl_n(exres_sync_n),
				.q   (vcount [8:5]),
				.co  (syld_n)
				);
assign syld = ~syld_n;

assign evcount [7:0] = {8{vflp}} ^ vcount [7:0];

assign # 24 vsy_n = vcount [8];
assign vcnt2v_n = ~((&vcount [3:1]) & vcnten);

/* vcnt2v_n | (~16V & 32V & 64V & 128V) */
assign bufclear_n = vcnt2v_n | ~(~vcount [4] &(& vcount [7:5]));
assign # 24 bfc_n = bufclear_n;

/* vcnt2v_n | (16V & 32V & 64V & 128V) */
assign o_k27 = vcnt2v_n | (&vcount [7:4]);

FJ4_jk_ff 	i45	(
				.j      (bufclear_n),
				.clk    (clk2_n),
				.k      (o_k27),
				.reset_n(exres_sync_n),
				.q      (vblank),
				.q_bar  (vblank_n)
				);

assign # 24 vblk = vblank;

wire [2:0] unused_q;

C41_4bit_async_cnt 	o61	(
						.ck  (vblank | cres_n | tes2),
						.cl_n(exres_sync_n),
						.q   ({cres_n, unused_q})
						);

assign fbrf = (& vcount [5:1]) & vcount [8];

/*
*
*	Timers
*	 
*/

assign tim 	= ~(q_j56 & wr_n);
assign tim1	= ~(~hcount [1] & hcount [2] & tim);
assign tim2 = ~(hcount [1] & hcount [2] & tim);
assign tim3 = ~(tim & ~hcount [1]);

/*
*	Chip select signals and data acknowledge
*/

FDN_d_ff	a74	(
				.d		(1'b0),
				.ck		(~tim3),
				.s_n	(~ocra_n),
				.q		(orad_n),
				.q_bar	()
				);

FJ5_jk_ff	h7	(
				.j_n	(1'b1),
				.k_n	(~(~hcount [0] & hcount [1] & hcount [2])),
				.ck		(clk2_n),
				.pr_n	(~vcra_n),
				.cl_n	(1'b1),
				.q		(svdt_n),
				.q_bar	()
				);

FJ5_jk_ff	k40	(
				.j_n	(1'b1),
				.k_n	(~&hcount [1:0]),
				.ck		(clk2_n),
				.pr_n	(~ocro_n),
				.q		(),
				.q_bar	(q_k40)
				);

FJ5_jk_ff	l64	(
				.j_n	(1'b1),
				.k_n	(|hcount [1:0]),
				.ck		(clk2_n),
				.pr_n	(q_k40),
				.q		(ordt_n),
				.q_bar	()
				);

/*
*	P256
*/

assign oscanclr_n = ~(&vcount [7:4]) | vcount [8] | vcnt2v_n;
assign # 24 osc_n = oscanclr_n;

FJ4_jk_ff	h24	(
				.j		(oscanclr_n),
				.k		(oscanclr_n),
				.clk	(clk2_n),
				.reset_n(exres_sync_n),
				.q		(q_h24),
				.q_bar	()
				);

assign o_h54 = ~&hcount [2:0];
assign o_h40 = ~( ~(o_h54 & p256) & ~(q_h24 & ~o_h54) );

FDO_d_ff	h47	(
				.d		(o_h40),
				.clk	(clk2_d1),
				.reset_n(exres_sync_n),
				.q		(p256),
				.q_bar	()
				);

/*
* Composite sync
*/

FDO_d_ff	m47	(
				.d		(hsy_n ^ vcount [8]),
				.clk	(p1h),
				.reset_n(exres_sync_n),
				.q		(q_m47),
				.q_bar	()
				);

FDO_d_ff	m40	(
				.d		(q_m47),
				.clk	(p1h),
				.reset_n(exres_sync_n),
				.q		(q_m40),
				.q_bar	()
				);

FDO_d_ff	m22	(
				.d		(q_m40),
				.clk	(p1h),
				.reset_n(exres_sync_n),
				.q		(q_m22),
				.q_bar	()
				);

FDO_d_ff	m29	(
				.d		(q_m22),
				.clk	(p1h),
				.reset_n(exres_sync_n),
				.q		(q_m29),
				.q_bar	()
				);

assign # 26 csy = ~q_m29;

/*
* Composite Blanking
*/

assign # 3 o_f50 = ~(&hcount [4:0] & ~hcount_offset [5] & hcount_offset [7] & ~hcount_offset [8]);

FJ5_jk_ff	c37	(
				.j_n	(o_f50 | hcount_offset [6]),
				.k_n	(o_f50 | ~hcount_offset [6]),
				.ck		(clk2_n),
				.pr_n	(exres_sync_n),
				.q		(),
				.q_bar	(q_bar_c37)
				);

FDO_d_ff	d35	(
				.d		(q_bar_c37),
				.clk	(p1h),
				.reset_n(exres_sync_n),
				.q		(q_d35),
				.q_bar	()
				);

FDO_d_ff	d42	(
				.d		(q_d35),
				.clk	(p1h),
				.reset_n(exres_sync_n),
				.q		(q_d42),
				.q_bar	()
				);

FDO_d_ff	d49	(
				.d		(q_d42),
				.clk	(p1h),
				.reset_n(exres_sync_n),
				.q		(q_d49),
				.q_bar	()
				);

FDO_d_ff	d19	(
				.d		(q_d49),
				.clk	(p1h),
				.reset_n(exres_sync_n),
				.q		(q_d19),
				.q_bar	()
				);

FDO_d_ff	d26	(
				.d		(q_d19),
				.clk	(p1h),
				.reset_n(exres_sync_n),
				.q		(q_d26),
				.q_bar	()
				);

FDO_d_ff	d2	(
				.d		(q_d26),
				.clk	(p1h),
				.reset_n(exres_sync_n),
				.q		(q_d2),
				.q_bar	()
				);

FDO_d_ff	d10	(
				.d		(q_d2),
				.clk	(p1h),
				.reset_n(exres_sync_n),
				.q		(hblank_n),
				.q_bar	()
				);

assign # 26 cbk_n = vblank_n & hblank_n;

/* 3 : 8
* DMA
*/

assign o_k16 = ~&vcount [7:5];
assign o_k3 = ~(~vcount [3] & vcount [4]);
assign o_k18 = o_k16 | o_k3;

assign obin  = ~( o_k18 | |vcount [2:1] );
assign # 26 dmin = obin | dma;
assign db0 = (~dmac_n ? (obin | dma) : 1'bz); 
assign # 26 dmc_n = ~(vcnten & obin);

endmodule/* P1H_X1S */