`timescale 1ns/1ps

/*

	Schematic sheet: 85606-A- -1/8 CPU

*/

module jt_gng_a1(
	input		IRQ1,	// from 5/8
	output		ALC1_b, // to 2/8
	output		ALC2_b, // to B19
	input		ROB_b,	// from B22
	input		MRDY_b,	// from 6/8
	input		G6M,	// from 5/8
	output		AKB_b,	// to B21
);

reg rst;

wire [7:0] D;
wire [7:0] DOut;
wire [15:0] ADDR;
wire RnW;
wire CLK4;
wire AVMA;
wire BUSY;
wire LIC;
wire nRESET;
wire nHALT;

initial begin
	rst = 0;
	#500 rst = 1;
end

// 8J
assign ALC2_b = ~rst;
assign ALC1_b = ~rst;
assign nRESET = ~rst;

wire	IRQI, irq_clb;

jt7474 u_9J (
	.d		(1'b1), 
	.pr_b	(1'b1), 
	.cl_b	(irq_clb), 
	.clk	(IRQI), 
	.q_b	(nIRQ)
);

wire BA,BS;
wire [3:0] BABS;

jt74139 u_9K (
	.en1_b	(1'b0), 
	.a1		({BS,BA}), 
	.y1_b	(BABS), 
	// unused:
	.en2_b	(1'b1), 
	.a2		(4'd0)
	//.y2_b	(y2_b)
);

wire HALT_b, cpuMRDY_b, cpuE;

jt74367 i_jt74367 (
	.A		( {BABS[3], ROB_b, MRDY_b, G6M}	), 
	.Y		( {AKB_b, HALT_b, cpuMRDY_b, cpuE}	), 
	.en4_b	(1'b0), 
	.en6_b	(1'b0)
);

wire nIRQ;
wire nFIRQ = 1'b1;
wire nNMI  = 1'b1;
wire EXTAL=G6M;
wire XTAL=1'b0;
wire nDMABREQ=1'b1;

mc6809 i_mc6809 (
	.D       (D       ),
	.DOut    (DOut    ),
	.ADDR    (ADDR    ),
	.RnW     (RnW     ),
	.BS      (BS      ),
	.BA      (BA      ),
	.nIRQ    (nIRQ    ),
	.nFIRQ   (nFIRQ   ),
	.nNMI    (nNMI    ),
	.EXTAL   (EXTAL   ),
	.XTAL    (XTAL    ),
	.nHALT   (nHALT   ),
	.nRESET  (nRESET  ),
	.MRDY    (MRDY_b  ),
	.nDMABREQ(nDMABREQ),
);



endmodule // jt_gng_a1