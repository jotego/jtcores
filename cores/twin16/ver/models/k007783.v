module k007783	(
				input clk2,
				input clr_n,
				input dmc_n,
				input ofc_n,
				input obfi,
				input ocen,
				input fbrf,
				input osc_n,
				input [7:0] od,
				input [13:1] ab,
				input [13:1] sab,
				input mread_n,
				input sread_n,
				input mocs_n,
				input mlwr_n,
				input muwr_n,
				input socs_n,
				input slwr_n,
				input suwr_n,
				input bflg,
				input tim,
				input dmaon,
				output dma,
				output orlwr_n,
				output oruwr_n,
				output [12:0] ora,
				output ooe_n
				);

//wire reg [1:0] q_j58;
wire [12:0] oa;

assign objdmaclr_n = ofc_n & dmc_n;

assign dmaclr_n = dmc_n & o_k58;

assign dma16_n = ~dma16;
assign dma16d_n = dmaclr_n & dma16_n;
assign dma16d = ~(dmaclr_n & dma16_n);
//assign o_i50 = ~(~(oa[6] & oa[5]) & ~(oa[6] & oa[4] & oa[3])) & dma16;
assign o_i50 = ~(~(oa[6] & oa[5]) & ~(oa[6] & oa[4] & oa[3])) & dma16;
assign o_k58 = ~(co_f58 & oa[12] & o_i50 & dma16);

assign # 2 o_d32 = (dma16d_n & oa[3]) | (dma16d & (dmaclr_n & oa3_n));
FDG_d_ff	d21	(
				.d(o_d32),
				.ck(clk2),
				.cl_n(clr_n),
				.q(oa[3]),
				.q_bar(oa3_n)
				);

assign # 2 o_c19 = ((oa[4] & oa3_n) | (oa4_n & oa[3])) & dmaclr_n; 

assign o_c17 = (dma16d_n & oa[4]) | (dma16d & o_c19);
FDG_d_ff	c4	(
				.d(o_c17),
				.ck(clk2),
				.cl_n(clr_n),
				.q(oa[4]),
				.q_bar(oa4_n)
				);

assign # 2 o_c26 = dmaclr_n & (( oa[5] & oa[4] & oa[3] ) | (oa5_n & oa3_n) | (oa5_n & oa4_n));
assign o_c44 = (dma16d_n & oa[5]) | (dma16d & o_c26);
FDG_d_ff	c49	(
				.d(o_c44),
				.ck(clk2),
				.cl_n(clr_n),
				.q(oa[5]),
				.q_bar(oa5_n)
				);

assign # 2 o_c35 = dmaclr_n & ((oa6_n & oa[5]) | (oa6_n & oa[4] & oa[3]) | (oa[6] & oa5_n & oa4_n) | (oa[6] & oa5_n & oa[4] & oa3_n));
assign o_d57 = (dma16d_n & oa[6]) | (dma16d & o_c35);
FDG_d_ff	d46	(
				.d(o_d57),
				.ck(clk2),
				.cl_n(clr_n),
				.q(oa[6]),
				.q_bar(oa6_n)
				);


FJ4_jk_ff	k35	(
				.j(dmc_n),
				.k(o_k58),
				.clk(~clk2),
				.reset_n(clr_n),
				.q(dma),
				.q_bar()
				);

wire unused_q1;

C45_4bit_cnt	e58	(
					.d(4'b0000),
					.l_n(dmaclr_n),
					.ck(clk2),
					.en(dma),
					.ci(dma),
					.cl_n(clr_n),
					.q({unused_q1,oa[2:0]}),
					.co(dma16)
					);


C45_4bit_cnt	f58	(
					.d(4'b0000),
					.l_n(dmaclr_n),
					.ck(clk2),
					.en(o_i50),
					.ci(o_i50),
					.cl_n(clr_n),
					.q(oa[10:7]),	
					.co(co_f58)
					);

wire [1:0] unused_q3;

C45_4bit_cnt	j58	(
					.d(4'b0000),
					.l_n(dmaclr_n),
					.ck(clk2),
					.en(co_f58),
					.ci(co_f58),
					.cl_n(clr_n),
					.q({unused_q3,oa[12:11]}),	
					.co()
					);

//assign ora =  {q_j58,q_f58,oa[6],oa[5],oa[4],oa[3],oa[2:0]};

/*
*	Clocking data in
*/

wire [3:0] hcount;

C42_4bit_cnt	f16	(
					.ck(clk2),
					.cl_n(clr_n),
					.q(hcount)
					);

assign oden = (|hcount) | ~dma;
assign oden_n = ~oden;

// odd[1] = OD1'
// oddd[1] = OD1''
wire [7:0] odd,oddd;

assign odd = od & {8{oden_n}} | oddd & {8{oden}};


FDR_4bit_dff	o9	(
					.d(odd[3:0]),
					.ck(clk2),
					.cl_n(clr_n),
					.q(oddd[3:0])
					);

FDR_4bit_dff	r8	(
					.d(odd[7:4]),
					.ck(clk2),
					.cl_n(clr_n),
					.q(oddd[7:4])
					);

/*
*	Object Data (OD) horizontal counters.
*/



assign o_e30 = ~(obfi | dma);
assign dmaobfi = (obfi | dma);
assign odh2 = o_e30 & hcount[1];
assign odh2_n = ~odh2;
assign odh2d_n = ~odh2;
assign odh4 = o_e30 & hcount[2];
assign odh4_n = ~odh4;
assign odh4d_n = ~odh4;

wire [1:0] unused_q4;
wire [9:0] opda;
C43_4bit_cnt	l63	(
					.d(4'b0000),
					.l_n(osc_n),
					.ck(clk2),
					.en(~(ocen|dmaobfi|fbrf)),
					.ci(~(ocen|dmaobfi|fbrf)),
					.cl_n(clr_n),
					.q({unused_q4,opda[1:0]}),
					.co()
					);

C43_4bit_cnt	k61	(
					.d(4'b0000),
					.l_n(osc_n),
					.ck(clk2),
					.en(~co_m58),
					.ci(&opda[1:0]),
					.cl_n(clr_n),
					.q(opda[5:2]),
					.co(co_k61)
					);

C43_4bit_cnt	m58	(
					.d(4'b0000),
					.l_n(osc_n),
					.ck(clk2),
					.en(~co_m58),
					.ci(co_k61),
					.cl_n(clr_n),
					.q(opda[9:6]),
					.co(co_m58)
					);


// Inputs a-d is in the order from top to bottom in the schematics.



`define t34(a,b,c,d) (odh2_n & odh4_n & a) | (odh2 & odh4_n & b) | (odh2_n & odh4 & c) | (odh2 & odh4 & d)

assign o_j19 = ~(objdmaclr_n & dmaobfi);
assign o_h9 = (obfia[0] & o_j19 & objdmaclr_n) | (~o_j19 & q_bar_h41);

FDG_d_ff	h41	(
				.d(o_h9),
				.ck(clk2),
				.cl_n(clr_n),
				.q(obfia[0]),
				.q_bar(q_bar_h41)
				);
assign o_i14 = ~(obfia[0] & ~o_j19);
assign o_17 = ~(obfia[1] & o_i14 & objdmaclr_n);
assign o_i22 = ~(obfia[0] & ~o_j19 & q_bar_i39);
assign o_i27 = ~(o_17 & o_i22);

FDG_d_ff	i39	(
				.d(o_i27),
				.ck(clk2),
				.cl_n(clr_n),
				.q(obfia[1]),
				.q_bar(q_bar_i39)
				);

wire [9:0] obfia;
wire [9:0] orad;

C43_4bit_cnt	n10	(
					.d(4'b0000),
					.l_n(objdmaclr_n),
					.ck(clk2),
					.en(dmaobfi & obfia[0] & obfia[1]),
					.ci(dmaobfi & obfia[0] & obfia[1]),
					.cl_n(clr_n),
					.q(obfia[5:2]),
					.co(co_n10)
					);

C43_4bit_cnt	q10	(
					.d(4'b0000),
					.l_n(objdmaclr_n),
					.ck(clk2),
					.en(co_n10),
					.ci(co_n10),
					.cl_n(clr_n),
					.q(obfia[9:6]),
					.co()
					);

// wire [12:0] oa
// wire [9:0] orad
// wire [12:0] ora
// wire [9:0] opda;
// input ab[13:1]
// input sab[13:1]

wire [12:0] oad;

assign orad[9:2] = obfi ? obfia[9:2] : oddd;
assign orad[1] = obfi ? obfia[1] : obfia[2];
assign orad[0] = obfi ? obfia[0] : obfia[1];

// H8 & OBFI
assign oad = (hcount[3] | obfi) ? {3'b110,orad} : oa;
assign oadoe_n = (hcount[3] | obfi) ? 1'b1 : 1'b0;

assign test_h8obfi = hcount[3] | obfi;
assign test_h8obfi_n = ~(hcount[3] | obfi);


assign ora = (~odh4 & ~odh2) ? oad : (~odh4 & odh2) ? {3'b110,opda} : (odh4 & ~odh2) ? ab : sab;
assign ooe_n = (~odh4 & ~odh2) ? oadoe_n : (~odh4 & odh2) ? 1'b0 : (odh4 & ~odh2) ? mread_n : sread_n;

/* /ORLWR and /ORUWR*/
assign o_b55 = (~socs_n & ~slwr_n & odh4 & odh2) | (~mocs_n & ~mlwr_n & odh4 & odh2_n);
assign o_b57 = (~socs_n & ~suwr_n & odh4 & odh2) | (~mocs_n & ~muwr_n & odh4 & odh2_n);

FDG_d_ff	e20	(
				.d(dmaon),
				.ck(obfi),
				.cl_n(clr_n),
				.q(q_e20),
				.q_bar()
				);

assign o_e11 = ~(bflg & hcount[3] & hcount[1] & dma & odh4d_n & odh2d_n & q_e20);
assign o_e5  = ~(obfi & odh4d_n | odh2d_n & q_e20);
assign # 12 o_d10 = clk2;
assign o_e3 = ~(o_e11 & o_e5);
assign o_d4 = o_e3 & o_d10;

assign orlwr_n = ~((o_b55 & tim) | o_d4); 
assign oruwr_n = ~((o_b57 & tim) | o_d4); 


endmodule