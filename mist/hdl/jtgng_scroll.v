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
	output		MRDY_b,

	// ROM
	output reg 	[14:0] scr_addr,
	input  		[23:0] scrom_data,
	output reg 	[ 2:0] scr_pal,
	output reg 	[ 2:0] scr_col
);

reg [10:0]	addr;
reg [8:0] HS, VS;
wire [7:0] VF = {8{flip}}^V128;
wire [7:0] HF = {8{flip}}^H;
reg [8:0] hpos, vpos;

wire H7 = (~H[8] & (~flip ^ HF[6])) ^HF[7];

reg [2:0] HSaux;

always @(*) begin
	VS = vpos + {1'b0, VF};
	{ HS[8:3], HSaux } = hpos + { ~H[8], H7, H[6:0]};
	HS[2:0] = HSaux ^ {3{flip}};
end

reg S0H, S4H, S2H, S7H_b;

reg	we, scren_b;

wire [9:0] scan = { HS[8:4], VS[8:4] };


always @(*)
	if( !scren_b ) begin
		addr = AB;
		we   = scr_cs && !rd;
	end else begin
		we	 = 1'b0; // line order is important here
		addr = { HS[1], scan };
	end


always @(negedge clk)
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
reg pre_rdy;

always @(negedge clk) begin
	S0H <= HS[2:0]==3'd7;
	S4H <= HS[2:0]==3'd3;
	S2H <= HS[2:0]==3'd1;
	if( HS[2:0]==3'd3 ) begin
		scren_b <= !scr_cs;
	end
	if( HS[2:0]==3'd5 ) pre_rdy <= 1'b1;
	if( HS[2:0]==3'd7 ) begin
		pre_rdy <= 1'b0;
		scren_b <= 1'b1;	
	end
end

assign MRDY_b = !scr_cs || pre_rdy;
reg scr_hflip, scr_vflip;
reg scr_hflip_prev;
reg [2:0] aux2;
reg [3:0] vert_addr;
reg [7:0] aux;

// Set input for ROM reading
always @(negedge clk) begin
	case( HS[2:0] )
		3'd1: aux <= dout;
		3'd3: begin
			AS        <= {dout[7:6], aux};
			scr_vflip <= dout[5] ^ flip;
			scr_hflip <= ~dout[4] ^ flip;
			aux2 <= dout[2:0];			
			vert_addr <= {4{dout[5]^scr_vflip}}^VS[3:0];
		end
		3'd7: begin
			scr_hflip_prev <= scr_hflip^flip;
			scr_pal <= aux2;
		end
	endcase
	scr_addr = { AS, HS[3]^scr_hflip, vert_addr };
end

// Draw pixel on screen
reg [7:0] x,y,z;

always @(negedge clk) begin
	scr_col <= scr_hflip_prev ? { x[0], y[0], z[0] } : { x[7], y[7], z[7] };
	case( H[2:0] )
		3'd0: { z,y,x } <= scrom_data;
		default:
			begin
				if( scr_hflip_prev ) begin
					x <= {1'b0, x[7:1]};
					y <= {1'b0, y[7:1]};
					z <= {1'b0, z[7:1]};
				end
				else  begin
					x <= {x[6:0], 1'b0};
					y <= {y[6:0], 1'b0};
					z <= {z[6:0], 1'b0};
				end
			end
	endcase
end

endmodule // jtgng_scroll