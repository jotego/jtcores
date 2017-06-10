`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-5/9 Line buffer 1

*/

module jt_gng_b5(
	input	[7:0]	OBJ2,	// OBJ2
	inout	[7:0]	COL,
	input			ST_b,
	input			OBFLIP,
	input			OB6M,
	input	[7:0]	DF,
	input			LOAD_b,
	input			HOVER,
	input			CL_b,
	input			WR_b,
	input			L6MB,

	input			DISPIM_bq,
	input			LV1_bq,
	output	reg [7:0]	OBJ // C14-C17
);

wire [7:0]	OBJ1;

// These pullups are on B6 in the original
pullup( COL[7],
		COL[6],
		COL[5],
		COL[4],
		COL[3],
		COL[2],
		COL[1],
		COL[0]);

jt_gng_b6 buffer (
	.OBJ   (OBJ1  ),
	.COL   (COL   ),
	.ST_b  (ST_b  ),
	.OBFLIP(OBFLIP),
	.OB6M  (OB6M  ),
	.DF    (DF    ),
	.LOAD_b(LOAD_b),
	.HOVER (HOVER ),
	.CL_b  (CL_b  ),
	.WR_b  (WR_b  ),
	.L6MB  (L6MB  )
);

always @(*)
	if( DISPIM_bq )
		OBJ = 8'hFF; // pullup
	else OBJ = LV1_bq ? OBJ1 : OBJ2;

endmodule // jt_gng_b5