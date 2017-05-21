`timescale 1ns/1ps

/*

	Schematic sheet: 85606-A- -1/8 CPU

*/

module jt_gng_a1(
	input		IRQ1,	// from 5/8
	output		ALC1_b, // to 2/8
	output		ALC2_b, // to B19
	input		RQB_b,	// from B22
	input		MRDY_b,	// from 6/8
	input		G6M,	// from 5/8
	output		AKB_b,	// to B21
	output		WRAM_b, // to 2/8
	output		EXTEN_b,
	input		BLCNTEN_b, // B23
	inout	[7:0] DB,	// to pins A8:A1
	inout	[12:0] AB,	// to pins A25:A13
	output		RDB_b,	// to pin B25
	output		WRB_b,   // to pin B24
	input	[2:0] bank,	// from 2/8
	output		ECLK
);


wire [7:0] D;
wire [7:0] Dinout, DOut;
wire [15:0] A;
wire RnW;
wire CLK4;
wire AVMA;
wire BUSY;
wire LIC;
reg nRESET;
wire HALT_b;

initial begin
	nRESET = 0;
	#2500 nRESET = 1;
end

// 8J
assign ALC2_b = ~nRESET;
assign ALC1_b = ~nRESET;

wire	IRQ1, irq_clb;

jt7474 u_9J (
	.d		(1'b1), 
	.pr_b	(1'b1), 
	.cl_b	(irq_clb), 
	.clk	(IRQ1), 
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
	.a2		(2'd0)
	//.y2_b	(y2_b)
);

assign irq_clb = BABS[2];

wire cpuMRDY_b, cpuE;

jt74367 u_10J (
	.A		( { BABS[3], RQB_b, MRDY_b, G6M}	), 
	.Y		( { AKB_b, HALT_b, cpuMRDY_b, cpuE}	), 
	.en4_b	(1'b0), 
	.en6_b	(1'b0)
);

wire EXTAL=G6M;
wire XTAL=1'b0;
wire E, Q;

assign ECLK = E;


mc6809 i_mc6809 (
	.Q		 (Q		  ),
	.E		 (E		  ),
	.D       (Dinout  ),
	.DOut    (DOut    ),
	.ADDR    (A		  ),
	.RnW     (RnW     ),
	.BS      (BS      ),
	.BA      (BA      ),
	.nIRQ    (nIRQ    ),
	.nFIRQ   (1'b1    ),
	.nNMI    (1'b1    ),
	.EXTAL   (EXTAL   ),
	.XTAL    (XTAL    ),
	.nHALT   (HALT_b  ),
	.nRESET  (nRESET  ),
	.MRDY    (MRDY_b  ),
	.nDMABREQ(1'b1    )
);

// ROMs
reg [7:0] rom_8n[ 0:32767];
reg [7:0] rom_10n[0:16383];
reg [7:0] rom_13n[0:32767];

initial begin
	$readmemh("../../rom/8n.hex",rom_8n);
	$readmemh("../../rom/10n.hex",rom_10n);
	$readmemh("../../rom/13n.hex",rom_13n);
end

wire [7:0] decod_ce_b, decod_bank_b;

jt74138 u_8K (
	.e1_b(1'b0), 
	.e2_b(1'b0), 
	.e3( Q | E ), 
	.a(A[15:13]), 
	.y_b(decod_ce_b)
);

jt74138 u_7L (
	.e1_b	(decod_ce_b[2]), 
	.e2_b	(decod_ce_b[2]), 
	.e3		( 1'b1 ), 
	//.a		( {bank[0],bank[1], bank[2]} ), 
	.a		( bank[2:0] ), 
	.y_b	(decod_bank_b)
);


wire ce8n_b = &decod_ce_b[7:6];
wire ce9n_b = &decod_ce_b[5:4];
wire ce10n_b = decod_ce_b[3] & decod_bank_b[4];
wire ce12n_b = &decod_bank_b[3:2];
wire ce13n_b = &decod_bank_b[1:0];

reg [7:0] rom_data;
wire [13:0] A_10n = {decod_bank_b[4], A[12:0]};
wire [14:0] A_13n = {bank[1:0], A[12:0]};

always @(A, ce8n_b, ce10n_b, ce13n_b ) 
	case( {ce8n_b, ce10n_b, ce13n_b} )
		3'b011: rom_data = rom_8n[A[14:0]];
		3'b101: rom_data = rom_10n[A_10n];
		3'b110: rom_data = rom_13n[A_13n];
		default: rom_data = 8'hzz;
	endcase // {ce8n_b, ce10n_b, ce13n_b}

assign D = &{ce8n_b, ce10n_b, ce13n_b}==1'b0 ? rom_data : 8'hzz;
assign Dinout = &{BA,BS} ? 8'hzz : (!RnW ? DOut : D);

wire bus_rd_b = ~(E &  RnW);
wire bus_wr_b = ~(E & ~RnW);
assign EXTEN_b = decod_ce_b[1];
wire drive_bus_b = ~BLCNTEN_b | (EXTEN_b&decod_ce_b[0]);
assign WRAM_b = decod_ce_b[0] & BLCNTEN_b;

jt74245 u_5N (
	.a		({ bus_rd_b, bus_wr_b, A[12:8]}	), 
	.b		({ RDB_b, WRB_b, AB[12:8]}		), 
	.dir	(1'b1							), 
	.en_b	(drive_bus_b					)
);

jt74245 u_6N (
	.a		( A[7:0]	), 
	.b		(AB[7:0]	), 
	.dir	(1'b1		), 
	.en_b	(drive_bus_b)
);

jt74245 u_11H (
	.a		(Dinout		), 
	.b		(DB[7:0]	), 
	.dir	(1'b1		), 
	.en_b	(drive_bus_b)
);



endmodule // jt_gng_a1 