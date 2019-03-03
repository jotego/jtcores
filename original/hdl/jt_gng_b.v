`timescale 1ns/1ps

/*

	Schematic sheet: 85606-A- -1/8 CPU

*/

module jt_gng_b(
	inout [7:0] 	DB,			// A8-A1
	inout [12:0] 	AB,			// A25-A13
	output			SCRWIN,		// B12
	input			CBCS_b,		// B13
	input			SCRCS_b,	// B14
	output			MRDY2_b,	// B15
	output	[2:0] 	SCD,		// B18-16
	input			ALC2_b,		// B19
	input			OKOUT_b,	// B20
	input			AKB_b,		// B21
	output			RQB_b,		// B22
	output			BLCNTEN_b,	// B23
	input			WRB_b,		// B24
	input			RDB_b,		// B25

	output			SCRX,		// C1
	output			SCRZ,		// C2
	input			G6M,		// C3
	input			G4_3H,		// C4
	input			H1,			// C5
	input			H4,			// C6
	input			H16,		// C17
	input			H64,		// C8
	input			H256,		// C9
	input			V1,			// C10
	input			V4,			// C11
	input			V16,		// C12
	input			V64,		// C13
	output	[7:0]	OBJ,		// C14-D17
	input			HINIT_b,	// C18

	output			SCRY,		// D1
	input			FLIP,		// D2
	input			OH,			// D3
	input			G4H,		// D4
	input			H2,			// D5
	input			H8,			// D6
	input			H32,		// D7
	input			H128,		// D8
	input			LHBL,		// D9
	input			V2,			// D10
	input			V8,			// D11
	input			V32,		// D12
	input			V128		// D13
);


	wire [7:0] DEA;
	wire [7:0] DEB;
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
	wire phiBB;
	wire BLEN;
	wire MATCH_b;
	wire OBASEL_b;
	wire OBBSEL_b;

jt_gng_b1 B1 (
	.V1       (V1       ),
	.V2       (V2       ),
	.V4       (V4       ),
	.V8       (V8       ),
	.V16      (V16      ),
	.V32      (V32      ),
	.V64      (V64      ),
	.V128     (V128     ),
	.FLIP     (FLIP     ),
	.RDB_b    (RDB_b    ),
	.WRB_b    (WRB_b    ),
	.V1F      (V1F      ),
	.V2F      (V2F      ),
	.V4F      (V4F      ),
	.V8F      (V8F      ),
	.V16F     (V16F     ),
	.V32F     (V32F     ),
	.V64F     (V64F     ),
	.V128F    (V128F    ),
	.AB       (AB       ), // TODO: Check connection ! Incompatible port direction not an inout
	.OB       (OB       ),
	.DB       (DB       ),
	.BLCNTEN_b(BLCNTEN_b),
	.OBASEL_b (OBASEL_b ),
	.OBBSEL_b (OBBSEL_b ),
	.DEA      (DEA      ),
	.DEB      (DEB      ),
	.OKOUT_b  (OKOUT_b  ),
	.RQB_b    (RQB_b    ),
	.ALC2_b   (ALC2_b   ),
	.AKB_b    (AKB_b    ),
	.OVER96_b (OVER96_b ),
	.phiBB    (phiBB    ),
	.BLEN     (BLEN     ),
	.MATCH_b  (MATCH_b  )
);


	wire [4:0] OBA;
	wire BLTIMING;
	wire TM2496_b;
	wire LV1;
	wire OBJABWR_b;
jt_gng_b2 B2 (
	.HINIT_b  (HINIT_b  ),
	.H1       (H1       ),
	.H256     (H256     ),
	.phiBB    (phiBB    ),
	.MATCH_b  (MATCH_b  ),
	.AKB_b    (AKB_b    ),
	.BLEN     (BLEN     ),
	.OB       (OB       ),
	.OBA      (OBA      ),
	.BLTIMING (BLTIMING ),
	.TM2496_b (TM2496_b ),
	.LV1      (LV1      ),
	.OBASEL_b (OBASEL_b ),
	.OBBSEL_b (OBBSEL_b ),
	.OBJABWR_b(OBJABWR_b),
	.OVER96_b (OVER96_b )
);

	wire TR3_b;
	wire OBHFLIPq;
	wire OBH4;
	wire OBH8;
	wire HOVER;
	wire [3:0] Vbeta;
	wire VINZONE;
	wire [9:0] AD;
	wire [7:0] DF;

	wire [7:0] COL;
jt_gng_b3 B3 (
	.OB       (OB[1:0]  ),
	.OBA      (OBA      ),
	.DEA      (DEA      ),
	.DEB      (DEB      ),
	.OBASEL_b (OBASEL_b ),
	.OBBSEL_b (OBBSEL_b ),
	.OBJABWR_b(OBJABWR_b),
	.OH       (OH       ),
	.H1       (H1       ),
	.H2       (H2       ),
	.H4       (H4       ),
	.H8       (H8       ),
	.H16      (H16      ),
	.H32      (H32      ),
	.H64      (H64      ),
	.H128     (H128     ),
	.H256     (H256     ),
	.G4H	  (G4H		),
	.LV1      (LV1      ),
	.TM2496_b (TM2496_b ),
	.TR3_b    (TR3_b    ),
	.OBHFLIPq (OBHFLIPq ),
	.COL4     (COL[4]   ),
	.COL5     (COL[5]   ),
	.OBH4     (OBH4     ),
	.OBH8     (OBH8     ),
	.HOVER    (HOVER    ),
	.Vbeta    (Vbeta    ),
	.VINZONE  (VINZONE  ),
	.AD       (AD       ),
	.DF       (DF       ),
	.V128F    (V128F    ),
	.V64F     (V64F     ),
	.V32F     (V32F     ),
	.V16F     (V16F     ),
	.V8F      (V8F      ),
	.V4F      (V4F      ),
	.V2F      (V2F      ),
	.V1F      (V1F      ),
	.FLIP     (FLIP     )
);

pullup( COL[7],
		COL[6],
		COL[5],
		COL[4],
		COL[3],
		COL[2],
		COL[1],
		COL[0] );

	wire LV1_bq;
	wire OBFLIP1;
	wire OBFLIP2;
	wire DISPIM_bq;
	wire L6MB;
	wire OB6M;
	wire ST1_b;
	wire CL1_b;
	wire WR1_b;
	wire LOAD1_b;
	wire ST2_b;
	wire CL2_b;
	wire WR2_b;
	wire LOAD2_b;
jt_gng_b4 B4 (
	.AD       (AD       ),
	.Vbeta    (Vbeta    ),
	.OBH4     (OBH4     ),
	.OBH8     (OBH8     ),
	.V1       (V1       ),
	.V2       (V2       ),
	.V4       (V4       ),
	.V8       (V8       ),
	.V16      (V16      ),
	.V32      (V32      ),
	.V64      (V64      ),
	.V128     (V128     ),
	.OH       (OH       ),
	.VINZONE  (VINZONE  ),
	.FLIP     (FLIP     ),
	.OBHFLIPq (OBHFLIPq ),
	.G4_3H    (G4_3H    ),
	.BLTIMING (BLTIMING ),
	.LV1      (LV1      ),
	.LV1_bq   (LV1_bq   ),
	.OBFLIP1  (OBFLIP1  ),
	.OBFLIP2  (OBFLIP2  ),
	.DISPIM_bq(DISPIM_bq),
	.COL      (COL[3:0] ),
	.G6M      (G6M      ),
	.L6MB     (L6MB     ),
	.OB6M     (OB6M     ),
	.TR3_b    (TR3_b    ),
	.LHBL     (LHBL     ),
	.ST1_b    (ST1_b    ),
	.CL1_b    (CL1_b    ),
	.WR1_b    (WR1_b    ),
	.LOAD1_b  (LOAD1_b  ),
	.ST2_b    (ST2_b    ),
	.CL2_b    (CL2_b    ),
	.WR2_b    (WR2_b    ),
	.LOAD2_b  (LOAD2_b  )
);


	wire [7:0] OBJ2;
jt_gng_b5 B5 (
	.OBJ2     (OBJ2     ),
	.COL      (COL      ),
	.ST_b     (ST1_b    ),
	.OBFLIP   (OBFLIP1  ),
	.OB6M     (OB6M     ),
	.DF       (DF       ),
	.LOAD_b   (LOAD1_b  ),
	.HOVER    (HOVER    ),
	.CL_b     (CL1_b    ),
	.WR_b     (WR1_b    ),
	.L6MB     (L6MB     ),
	.DISPIM_bq(DISPIM_bq),
	.LV1_bq   (LV1_bq   ),
	.OBJ      (OBJ      )
);


jt_gng_b6 B6 (
	.OBJ   (OBJ2  ),
	.COL   (COL   ),
	.ST_b  (ST2_b ),
	.OBFLIP(OBFLIP2),
	.OB6M  (OB6M  ),
	.DF    (DF    ),
	.LOAD_b(LOAD2_b),
	.HOVER (HOVER ),
	.CL_b  (CL2_b ),
	.WR_b  (WR2_b ),
	.L6MB  (L6MB  )
);


	wire SH2;
	wire SH8;
	wire SH16;
	wire SH32;
	wire SH64;
	wire SH128;
	wire SH256;
	wire SCREN_b;
	wire POS2;
	wire POS3;
	wire S0H;
	wire S2H;
	wire S4H;
	wire FLIP_buf;
	wire S7H_b;
	wire S6M;
jt_gng_b7 B7 (
	.DB     (DB     ),
	.AB     (AB[3:0]),
	.CBCS_b (CBCS_b ),
	.G6M    (G6M    ),
	.FLIP   (FLIP   ),
	.H256   (H256   ),
	.H128   (H128   ),
	.H64    (H64    ),
	.H32    (H32    ),
	.H16    (H16    ),
	.H8     (H8     ),
	.H4     (H4     ),
	.H2     (H2     ),
	.H1     (H1     ),
	.SH2    (SH2    ),
	.SH8    (SH8    ),
	.SH16   (SH16   ),
	.SH32   (SH32   ),
	.SH64   (SH64   ),
	.SH128  (SH128  ),
	.SH256  (SH256  ),
	.SCRCS_b(SCRCS_b),
	.MRDY2_b(MRDY2_b),
	.SCREN_b(SCREN_b),
	.POS2   (POS2   ),
	.POS3   (POS3   ),
	.S0H    (S0H    ),
	.S2H    (S2H    ),
	.S4H    (S4H    ),
	.FLIP_buf(FLIP_buf),
	.S7H_b  (S7H_b  ),
	.S6M    (S6M    )
);


	wire OH;
	wire [9:0] AS;
	wire SVFLIP;
	wire SHFLIP;
	wire SHFLIP_q;
jt_gng_b8 B8 (
	.DB      (DB      ),
	.V128F   (V128F   ),
	.V64F    (V64F    ),
	.V32F    (V32F    ),
	.V16F    (V16F    ),
	.V8F     (V8F     ),
	.V4F     (V4F     ),
	.V2F     (V2F     ),
	.V1F     (V1F     ),
	.OH      (OH      ),
	.POS3    (POS3    ),
	.POS2    (POS2    ),
	.WRB_b   (WRB_b   ),
	.SCREN_b (SCREN_b ),
	.SCRCS_b (SCRCS_b ),
	.SH256   (SH256   ),
	.SH128   (SH128   ),
	.SH64    (SH64    ),
	.SH32    (SH32    ),
	.SH16    (SH16    ),
	.SH2     (SH2     ),
	.S2H     (S2H     ),
	.S0H     (S0H     ),
	.S4H     (S4H     ),
	.AB      (AB[10:0]),
	.AS      (AS      ),
	.V256S   (V256S   ),
	.V128S   (V128S   ),
	.V64S    (V64S    ),
	.V32S    (V32S    ),
	.V16S    (V16S    ),
	.V8S     (V8S     ),
	.V4S     (V4S     ),
	.V2S     (V2S     ),
	.V1S     (V1S     ),
	.SVFLIP  (SVFLIP  ),
	.SHFLIP  (SHFLIP  ),
	.SHFLIP_q(SHFLIP_q),
	.SCRWIN  (SCRWIN  ),
	.SCD     (SCD     )
);

jt_gng_b9 B9 (
	.AS      (AS      ),
	.SH8     (SH8     ),
	.SHFLIP  (SHFLIP  ),
	.SHFLIP_q(SHFLIP_q),
	.V8S     (V8S     ),
	.V4S     (V4S     ),
	.V2S     (V2S     ),
	.V1S     (V1S     ),
	.SVFLIP  (SVFLIP  ),
	.S6M     (S6M     ),
	.FLIP_buf(FLIP_buf),
	.SCRX    (SCRX    ),
	.SCRY    (SCRY    ),
	.SCRZ    (SCRZ    ),
	.S7H_b   (S7H_b   )
);



endmodule // jt_gng_b