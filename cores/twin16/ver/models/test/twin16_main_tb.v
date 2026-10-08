module twin16_main_tb;

`define OBJRAMWR(ADDR,DATA) \
	# 5\
	mocs_n = 0;\
	mread_n	= 1;\
	objcs_n = 0;\
	mlwr_n = 0;\
	muwr_n = 0;\
	ab = ADDR;\
	db = DATA;\
	# 5\
	mocs_n = 1;\
	mlwr_n = 1;\
	muwr_n = 1;\
	mread_n	= 1;\
	objcs_n = 1;\
	ab = 13'hz;\
	db = 16'hz;\
	# 1

`define OBJRAMRD(ADDR) \
	# 10\
	mocs_n = 0;\
	mread_n	= 0;\
	objcs_n = 0;\
	mlwr_n = 1;\
	muwr_n = 1;\
	ab = ADDR;\
	# 10\
	mocs_n = 1;\
	mlwr_n = 1;\
	muwr_n = 1;\
	mread_n	= 1;\
	objcs_n = 1;\
	# 1

	reg p18m,exres_n,hflip,vflip,ocra_n,vcra_n,ocro_n,dma,dmac_n,tes1,tes2,dmaon,mocs_n,mlwr_n,muwr_n,objcs_n,mread_n;
	reg [15:0] db,ab;
	wire [8:0] ehcount;
	wire [7:0] evcount;
	reg [17:1] sab;
	reg slwr_n, suwr_n;

	initial begin
		$dumpfile("twin16_main_tb.vcd");
		$dumpvars(0,twin16_main_tb);

		p18m = 0;
		exres_n = 0;
		hflip = 0;
		vflip = 0;
		ocra_n = 1;
		vcra_n = 1;
		ocro_n = 1;
		dma = 0;
		dmac_n = 1;
		tes1 = 0;
		tes2 = 0;
		db = 16'h00;
		objcs_n = 1;
		mread_n	= 1;
		dmaon = 1'b1;
		# 5 exres_n = 1;
		# 725 ocra_n = 0;
		vcra_n = 0;
		ocro_n = 0;
		mlwr_n = 1;
		muwr_n = 1;
		mocs_n = 1;
		sab = 17'b0000_0000_0000_0000_1;
		slwr_n = 1; 

		`OBJRAMWR(13'h0000,16'h8000); // Word 0 in
		`OBJRAMWR(13'h0001,16'h1111); // Word 1 in
		`OBJRAMWR(13'h0002,16'h2222); // Word 2 in
		`OBJRAMWR(13'h0003,16'h3333); // Word 3 in
		`OBJRAMWR(13'h0004,16'h4444); // Word 4 in
		`OBJRAMWR(13'h0005,16'h5555); // Word 5 in
		`OBJRAMWR(13'h0006,16'h6666); // Word 6 in
		`OBJRAMWR(13'h0007,16'h7777); // Word 7 in
		`OBJRAMWR(13'h0008,16'h0000); // Clear buffer

		//`OBJRAMWR(13'h0028,16'h8001); // Word 0 in
		//`OBJRAMRD(13'h0028);
		//`OBJRAMWR(13'h0029,16'h1111); // Word 1 in
		//`OBJRAMWR(13'h002A,16'h2222); // Word 2 in
		//`OBJRAMWR(13'h002B,16'h3333); // Word 3 in
		//`OBJRAMWR(13'h002C,16'h4444); // Word 4 in
		//`OBJRAMWR(13'h002D,16'h5555); // Word 5 in
		//`OBJRAMWR(13'h002E,16'h6666); // Word 6 in
		//`OBJRAMWR(13'h002F,16'h7777); // Word 7 in
		
		# 400 ocra_n = 1;
		vcra_n = 1;
		# 300 ocro_n = 1;
		# 100 ocro_n = 0;
		# 400 ocro_n = 1;
		# 100 dmac_n = 0;
		# 100 dma = 1;
//		# 500 dma = 0;
		# 4000 hflip = 0;
		vflip = 0;
		# 1000 hflip = 0;
		vflip = 0;
		dmaon = 1'b0;
		vcra_n = 0;	
		slwr_n = 0;
		//exres_n = 0;	
		# 1000 vcra_n = 1;


	//	# 14560000
	//	#  1000000
	//	# 20000000
//		db = 16'bz;		
		# 50000000 $finish;
		//$finish;		
	end

	/* make a regular pulsing clock. */
	always begin
		#27 p18m = !p18m;
	end
	twin16_main	test
					(
					p18m,
					exres_n,
					hflip,
					vflip,
					ocra_n,
					vcra_n,
					ocro_n,
				//	dma,
					dmac_n,
					tes1,
					tes2,
					db,
					dmaon,
					mocs_n,
					mlwr_n,
					muwr_n,
					mread_n,
					ab,
					objcs_n,
					sab,
					slwr_n,
					suwr_n
/*
					cclk,
					cres_n,
					clr_n,
					clk2,
					tim,
					tim1,
					tim2,
					tim3,
					hsy_n,
					ras_n,
					cas_n,
					wr_n,				
					x1s,
					ehcount,
					vsy_n,
					vcen,
					p256,
					osc_n,
					fbrf,
					syld,
					evcount,
					cbk_n,
					vblk,
					csy,
					bfc_n,
					ordt_n,
					svdt_n,
					orad_n,
					dmin,
					db0,
					obin,
					dmc_n
*/
					);

endmodule // 