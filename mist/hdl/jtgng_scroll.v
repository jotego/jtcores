`timescale 1ns/1ps

module jtgng_scroll(
	input		clk,	// 6 MHz
	input	[10:0]	AB,
	input	[ 7:0] V128, // V128-V1
	input	[ 8:0] H, // H256-H1
	input		scr_cs,
	input		scrpos_cs,
	input		flip,
	input	[7:0] din,
	output	[7:0] dout,
	input		rd,
	output		MRDY_b

	// ROM
	output reg 	[14:0] scr_addr,
	input  		[15:0] scrom_data,
	output reg 	[ 2:0] scr_pal,
	output reg 	[ 2:0] scr_col
);

reg [10:0]	addr;
reg [8:0] HS, VS;
reg [7:0] VF = {8{flip}}^V128;
reg [7:0] HF = {8{flip}}^H;
reg [8:0] hpos, vpos;

wire H7 = (~H[8] & (~flip ^ HF[6])) ^HF[7];

always @(*) begin
	VS = vpos + {1'b0, VF};
	HS = hpos + { ~H[8], H7, H[6:0]};
end

wire sel = ~H[2];
reg	we;

wire [9:0] scan = { HS[8:4], VS[8:4] };

always @(*)
	if( !sel ) begin
		addr = AB;
		we   = scr_cs && !rd;
	end else begin
		we	 = 1'b0; // line order is important here
		addr = { HS[1], scan };
	end


always @(posedge clk)
	if( scrpos_cs && AB[3]) 
	case(AB[2:0])
		3'd0: hpos[7:0] <= din;
		3'd1: hpos[8]	<= din[0];
		3'd2: vpos[7:0] <= din;
		3'd3: vpos[8]	<= din[0];
	endcase // AB[3:0]

jtgng_chram	RAM(
	.address( addr 	),
	.clock	( clk 	),
	.data	( din	),
	.wren	( we	),
	.q		( dout	)
);

reg [9:0] AS;

assign MRDY_b = !( scr_cs && ( &H[2:1]==1'b0 ) );
reg scr_hflip, scr_vflip;
reg scr_hflip_prev;
reg [3:0] aux2;
reg [3:0] vert_addr;

// Set input for ROM reading
always @(posedge clk) begin
	case( H128[2:0] )
		// 3'd1: char_pal <= aux2[3:0];
		3'd2: aux <= dout;
		3'd4: begin
			AS        <= {dout[7:6], aux};
			scr_vflip <= dout[5] ^ flip;
			scr_hflip <= dout[4] ^ flip;
			scr_hflip_prev <= scr_hflip;
			aux2 <= dout[3:0];			
			vert_addr <= {4{dout[5]^flip}}^V128[3:0];
		end
	endcase
	scr_addr = { AS, SH[3]^scr_hflip, vert_addr };
end

endmodule // jtgng_scroll