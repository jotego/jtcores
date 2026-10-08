module	twin16_main	(
						input	p18m,
						input	exres_n,
						input	hflip,
						input	vflip,
						input	ocra_n,
						input	vcra_n,
						input	ocro_n,
					//	input	dma,
						input	dmac_n,
						input	tes1,
						input	tes2,
						input [15:0] db,
						input 	dmaon,
						input	mocs_n,
						input	mlwr_n,
						input	muwr_n,
						input	mread_n,
						input	[15:0] ab,
						input 	objcs_n,
						input	[17:1] sab,
						input	slwr_n,
						input	suwr_n
/*
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
*/
						);

wire [7:0] evcount;
wire [8:0] ehcount,ehcount_p;
wire [12:0] oa;
wire [15:0] odw;
inout [15:0] od;

reg ooehiz,test;

k007782	k007782	(
				.p18m(p18m),
				.exres_n(exres_n),
				.hflp(hflip),
				.vflp(vflip),
				.ocra_n(ocra_n),
				.vcra_n(vcra_n),
				.ocro_n(ocro_n),
				.dma(dma),
				.dmac_n(dmac_n),
				.tes1(tes1),
				.tes2(tes2),
				.cclk(cclk),
				.cres_n(cres_n),
				.clr_n(clr_n),
				.clk2(clk2_p),
				.tim(tim),
				.tim1(tim1),
				.tim2(tim2),
				.tim3(tim3),
				.hsy_n(hsync_n),
				.ras_n(ras_n),
				.cas_n(cas_n),
				.wr_n(wr_n),				
				.x1s(x1s),
				.ehcount(ehcount_p),
				.vsy_n(vsy_n),
				.vcen(vcnten),
				.p256(p256),
				.osc_n(oscanclr_n),
				.fbrf(fbref),
				.syld(syncrldv),
				.evcount(evcount),
				.cbk_n(cblk_n),
				.vblk(vblk),
				.csy(csy),
				.bfc_n(objbufclr_n),
				.ordt_n(ordt_n),
				.svdt_n(svdt_n),
				.orad_n(orad_n),
				.dmin(dmainit),
				.db0(db0),
				.obin(objbufinit),
				.dmc_n(dmc_n)
				);

//LS244 t_PLH = t_PHL = 12ns 
assign # 22 clk2 = clk2_p; // estimate due to load capacitance and ls244 delay
assign # 12 clk22 = clk2_p;
assign # 12 clk21 = clk2_p;
assign clk2_blank = clk2_p;
assign # 12 clr1_n = clr_n;
assign # 22 ehcount[2:0] = ehcount_p[2:0];
assign ehcount [8:3] = ehcount_p[8:3];
assign # 12 rasb_n = ras_n;
assign # 12 casb_n = cas_n;
assign # 12 p1hb = ehcount_p[0];
assign p2h = ehcount_p[1];



// Composite blank visible at RGB output: cblk_eff_n
//A_U7
ff_clr #(
    .WIDTH(1)
) u7a (
    .clr_n(1'b1),
    .clk(clk2_blank),
    .d(cblk_n),
    .q(cblk_col_p_n)
);

// konami 007327 contains a DFF that clocks the blanking signal, causing one pxl clock delay.
ff_clr #(
    .WIDTH(1)
) k007327 (
    .clr_n(1'b1),
    .clk(clk2_blank),
    .d(cblk_col_p_n),
    .q(cblk_col_p2_n)
);

assign # 6 cblk_eff_n = cblk_col_p2_n;

k007783	k007783	(
				.clk2(clk21),
				.clr_n(clr1_n),
				.dmc_n(dmc_n),
				.ofc_n(objbufclr_n),
				.obfi(objbufinit),
				.ocen(oscnten),
				.fbrf(fbref),
				.osc_n(oscanclr_n),
				.od(od[7:0]),
				.ab(ab),
				.sab(),
				.mread_n(mread_n),
				.sread_n(),
				.mocs_n(mocs_n),
				.mlwr_n (mlwr_n),
				.muwr_n (muwr_n),
				.socs_n(1'b1),
				.slwr_n(),
				.suwr_n(),
				.bflg(beflag),
				.tim(tim),
				.dmaon(dmaon),
				.dma(dma),
				.orlwr_n(lwr_n),
				.oruwr_n(uwr_n),
				.ora(oa),
				.ooe_n(ooe_n)
				);

pulldown(od[0]);
pulldown(od[1]);
pulldown(od[2]);
pulldown(od[3]);
pulldown(od[4]);
pulldown(od[5]);
pulldown(od[6]);
pulldown(od[7]);
pulldown(od[8]);
pulldown(od[9]);
pulldown(od[10]);
pulldown(od[11]);
pulldown(od[12]);
pulldown(od[13]);
pulldown(od[14]);
pulldown(od[15]);

assign od = ooehiz ? odw : 16'hz;

always @ (ooe_n)
begin :OE_CTRL
	if (ooe_n)
	begin
		# 20 // Max tOHZ 35ns, use 20ns.
		ooehiz <= 1;
	end
	else if (~ooe_n) // ~ooe_n
	begin
		# 10 // Datasheet for 6264 says min 5ns, use 10ns.
		ooehiz <= 0;
	end
end

//odw = objcs_n + n2hp4h_n
assign odw = ~((objcs_n | ~(~ehcount[1] & ehcount[2])) | dmainit) ? db : 16'hz;

// MCPU tri-state buffers LS245



sram_6264 obj_ram_hi(
					.addr(oa),
					.data(od[15:8]),
					.cs1_n(1'b0),
					.cs2(1'b1),
					.oe_n(ooe_n),
					.rw_n(urw_n)
					);

sram_6264 obj_ram_lo(
					.addr(oa),
					.data(od[7:0]),
					.cs1_n(1'b0),
					.cs2(1'b1),
					.oe_n(ooe_n),
					.rw_n(lrw_n)
					);

k007779	k007779	(
				.clk2  (clk22),
				.p1h    (ehcount[0]),
				.clr_n	(clr_n),
				.v1    (evcount[0]),
				.hsync_n(hsync_n),
				.vcen(vcnten),
				.syld(syncrldv)
				);

assign vramoe_n = ~ehcount[2];
assign v1ram = ~ehcount[1];
assign v2ram = ehcount[1];
assign v1ramoe_n =  ~(~ehcount[1] & ~ehcount[2]);
assign v2ramoe_n = ~(ehcount[1] & ~ehcount[2]);


k007784	k007784	(
				.clk2	(clk21),
				.clr_n	(clr_n),
				.dma	(dma),
				.obfi (objbufinit),
				.od		(od),	
				.bflg	(beflag)
				);



ls7474_d_ff h11a	(
					.d(dmaon),
					.clk(objbufinit),
					.pre_n(1'b1),
					.clr_n(1'b1),
					.q(),
					.q_bar(dmaons_n)
					);

assign lrw_n =
	~((dmaons_n & objbufinit & clk2) | 
		(beflag & dma & ehcount[0] & dmaons_n & clk2 & (~ehcount[3] & hflip | ehcount[3] & ~hflip)) |
	(~lwr_n & ~dmainit));
assign urw_n =
	~((dmaons_n & objbufinit & clk2) | 
		(beflag & dma & ehcount[0] & dmaons_n & clk2 & (~ehcount[3] & hflip | ehcount[3] & ~hflip)) |
	(~uwr_n & ~dmainit));

assign test_lrw = ~(beflag & dma & ehcount[0] & dmaons_n & clk2 & (~ehcount[3] & hflip | ehcount[3] & ~hflip));	


assign lrw_n1 = ~(dmaons_n & objbufinit & clk2);
assign lrw_n2 = ~(beflag & dma & ehcount[0] & dmaons_n & clk2 & (~ehcount[3] & hflip | ehcount[3] & ~hflip));
assign lrw_n3 = (~lwr_n & ~dmainit);


k007785 k007785	(
				.clr_n(clr1_n),
				.clk2(clk21),
				.p1h(ehcount[0]),
				.p256vd(p256),
				.fbref (fbref),
				.dinit(dmainit),	
				.sclr_n(oscanclr_n),
				.od(od),
				.c(c),
				.cx(cx),
				.hpoj(hj),
				.hpd(hd),
				.vpd({vpd8,vd}),
				.oca(o),
				.oscen(oscnten),
				.ochf(ochf),
				.fb1_n(fbwm1_n),
				.fb2_n(fbwm2_n)
				);

k007786 k007786	(
				.clr_n(clr1_n),
				.clk2(clk21),
				.ampx(x1s),
				.vcen(vcnten),
				.p256(p256vd),
				.hsy_n(hsync_n),	
				.hflp(hflip),
				.vflp(vflip),
				.sel(1'b0),
				.hpd(hd),
				.vpd(vd),
				.fa(),
				.fb(),
				.fc(),
				.fd()
				);

k007787 k007787	(
				.clr_n(clr1_n),
				.clk2(clk21),
				.hflp(hflip),
				.p256vd(p256vd),
				.r(),
				.rx(),
				.ocd()
				);

k007780 k007780	(
				.clr_n(clr1_n),
				.clk2(clk22),
				.ampx(x1s),
				.tim2(tim2),
				.p1h(p1hb),
				.vcra_n(vcra_n),
				.suwr_n(suwr_n),
				.slwr_n(slwr_n),
				.sab(sab)
				);

k007781 k007781 (
				.clk2(clk2),
				.clr_n(clr_n)
				);


endmodule


