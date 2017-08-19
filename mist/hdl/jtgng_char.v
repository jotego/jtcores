`timescale 1ns/1ps

module jtgng_char(
	input		clk,	// 6 MHz
	input	[10:0]	AB,
	input	[ 7:0] V128, // V128-V1
	input	[ 7:0] H128, // H128-H1
	input		char_cs,
	input		flip,
	input	[7:0] din,
	output	[7:0] dout,
	input		rd,
	output		MRDY_b,

	// ROM
	output reg [12:0] char_addr,
	input  [15:0] chrom_data,
	output reg [3:0] char_pal,
	output reg [ 1:0] char_col
);

reg [10:0]	addr;
wire sel = ~H128[2];
reg	we;

wire [9:0] scan = { {10{flip}}^{V128[7:3],H128[7:3]}};

always @(*)
	if( !sel ) begin
		addr = AB;
		we   = char_cs && !rd;
	end else begin
		we	 = 1'b0; // line order is important here
		addr = { H128[1], scan };
	end

// RAM
/*
jtgng_m9k #(.addrw(11)) RAM(
	.clk ( clk  ),
	.addr( addr ),
	.din ( din  ),
	.dout( dout ),
	.we  ( we   )
);*/

jtgng_chram	RAM(
	.address( addr 	),
	.clock	( clk 	),
	.data	( din	),
	.wren	( we	),
	.q		( dout	)
);

assign MRDY_b = !( char_cs && ( &H128[2:1]==1'b0 ) );

reg [7:0] aux;
reg [5:0] aux2;
reg [9:0] AC; // ADDRESS - CHARACTER
reg char_hflip_prev;

reg [2:0] vert_addr;

reg char_vflip;
reg char_hflip;
reg half_addr;

// Set input for ROM reading
always @(negedge clk) begin
	case( H128[2:0] )
		// 3'd1: char_pal <= aux2[3:0];
		3'd2: aux <= dout;
		3'd4: begin
			AC       <= {dout[7:6], aux};
			char_hflip <= dout[4] ^ flip;
			char_vflip <= dout[5] ^ flip;
			char_hflip_prev <= char_hflip;
			aux2 <= dout[3:0];			
			vert_addr <= {3{char_vflip}}^V128[2:0];
		end
	endcase
	char_addr = { AC, vert_addr };
end

// Draw pixel on screen
reg [15:0] chd;

always @(negedge clk) begin
	//char_col <= char_hflip_prev ? { chd[4], chd[0] } : { chd[7], chd[3] };
	char_col <= char_hflip_prev ? { chd[0], chd[4] } : { chd[3], chd[7] };
	if( H128[2:0]==3'd1 ) char_pal <= aux2[3:0];
	case( H128[2:0] )
		3'd0: chd <= char_hflip ? {chrom_data[7:0],chrom_data[15:8]} : chrom_data;
		3'd4: chd[7:0] <= chd[15:8];
	/*
	if( H128[1:0]==2'd0 ) begin
		chd <= (H128[2] ^ char_hflip) ? chrom_data[15:8] : chrom_data[7:0];
	end
	else */
		default:
	begin
		if( char_hflip_prev ) begin
			chd[7:4] <= {1'b0, chd[7:5]};
			chd[3:0] <= {1'b0, chd[3:1]};
		end
		else  begin
			chd[7:4] <= {chd[6:4], 1'b0};
			chd[3:0] <= {chd[2:0], 1'b0};
		end
	end
	endcase
end

endmodule // jtgng_char