`timescale 1ns/1ps

/*

	Schematic sheet: 85606-A- -1/8 CPU

*/

module jt_gng_a8(
	inout	[7:0]	AB,
	input			WRB_b,
	input			RDB_b,
	inout	[7:0]	DB,
	input	[3:0]	CC,
	input			CHARY,
	input			CHARZ,
	input	[5:0]	OBJ,
	input			SCRWIN,
	input	[2:0]	SCD,
	input			SCRX,
	input			SCRY,
	input			SCRZ,
	input			CH6M,
	input			LVBL,
	input			LHBL,
	input			BCS_b,
	input			RGCS_b,
	output reg [3:0] RR,
	output reg [3:0] GG,
	output reg [3:0] BB
);

reg CHARF,CHARE,CHARD,CHARC,CHARB,CHARA;
reg OBJF,OBJE,OBJD,OBJC,OBJB,OBJA;
reg SCRG,SCRF,SCRE,SCRD,SCRC,SCRB,SCRA;

// 4E, 1H, 1E
always @(posedge CH6M) begin
	{CHARF,CHARE,CHARD,CHARC,CHARB,CHARA} <=
		{ CC, CHARY,CHARZ };
	{OBJF,OBJE,OBJD,OBJC,OBJB,OBJA} <= OBJ;
	{SCRG,SCRF,SCRE,SCRD,SCRC,SCRB,SCRA} <=
		{SCRWIN,SCD,SCRX,SCRY,SCRZ};
end

// 7F, 1F
wire [5:0] pal_addr;
assign #2 pal_addr = { ~CHARB|~CHARA,
	~OBJD|~OBJC|~OBJB|~OBJB|~OBJA,
	SCRG, // scrwin
	SCRC,
	SCRB,
	SCRA};

reg [1:0] pal[0:63];

initial $readmemh("../../rom/2e.hex",pal);

reg [1:0] sel;
always @(pal_addr)
	sel <= pal[pal_addr];

// 4D + mux
reg [7:0] pixel_raw;
always @(posedge CH6M) begin
	pixel_raw[7:6] <= sel;
	case(sel)
		2'b11,2'b10: pixel_raw[5:0] <= {CHARF,CHARE,CHARD,CHARC,CHARB,CHARA};
		2'b01: pixel_raw[5:0] <= {OBJF,OBJE,OBJD,OBJC,OBJB,OBJA};
		2'b00: pixel_raw[5:0] <= {SCRF,SCRE,SCRD,SCRC,SCRB,SCRA};
	endcase // sel
end

reg ABen, ABen_pre;
reg DACen, DACen_pre;

// 6E
always @(negedge CH6M) begin
	ABen_pre <= LVBL;
	ABen <= ABen_pre;

	DACen_pre <= ~&{ LVBL, LHBL }; // 7F
	DACen <= DACen_pre; // DACen_b on schematic
end

wire [7:0] rgb_addr;

jt74245 u_5C (.a(AB), .b(rgb_addr), .dir(1'b1), .en_b(ABen));
// 4C
assign #2 rgb_addr = !ABen ? 8'hzz : pixel_raw;

wire [3:0] R,G,B;

jt_gng_genram #(.addrw(8), .dataw(4), .id(10)) ram_6D
	(.A(rgb_addr), .D(R), .cs_b(1'b0), .rd_b(~RGCS_b), .wr_b(RGCS_b));

jt_gng_genram #(.addrw(8), .dataw(4), .id(11)) ram_7D
	(.A(rgb_addr), .D(G), .cs_b(1'b0), .rd_b(~RGCS_b), .wr_b(RGCS_b));

jt_gng_genram #(.addrw(8), .dataw(4), .id(12)) ram_8D
	(.A(rgb_addr), .D(B), .cs_b(1'b0), .rd_b(~BCS_b), .wr_b(BCS_b));


// not 74245 on the original, but same functionality
jt74245 u_6B (.a(DB), .b({R,G}), .dir(1'b1), .en_b(RGCS_b));
jt74245 u_8B (.a(DB[7:4]), .b(B), .dir(1'b1), .en_b(BCS_b));

always @(posedge DACen)
	{RR,GG,BB} <= {R,G,B};

endmodule // jt_gng_a8
