/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

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
	output	[2:0] HSlow,

	// ROM
	output reg 	[14:0]	scr_addr,
	input  		[23:0]	scrom_data,
	output  	[ 2:0]	scr_pal,
	output  	[ 2:0]	scr_col,
	output				scrwin
);

reg [10:0]	addr;
reg [8:0] HS, VS;
wire [7:0] VF = {8{flip}}^V128;
wire [7:0] HF = {8{flip}}^H[7:0];
reg [8:0] hpos=9'd0, vpos=9'd0;

wire H7 = (~H[8] & (~flip ^ HF[6])) ^HF[7];

reg [2:0] HSaux;

always @(*) begin
	VS = vpos + {1'b0, VF};
	{ HS[8:3], HSaux } = hpos + { ~H[8], H7, HF[6:0]};
	HS[2:0] = HSaux ^ {3{flip}};
end

assign HSlow = HS[2:0];

reg	we, scren_b;

wire [9:0] scan = { HS[8:4], VS[8:4] };


always @(*)
	if( scren_b ) begin
		we	 = 1'b0; // line order is important here
		addr = { HS[0], scan }; 
	end else begin
		addr = AB;
		we   = scr_cs && !rd;
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
reg scr_hflip;
reg scr_hflip_prev;
reg [2:0] pal_in;
reg [3:0] vert_addr;
reg [7:0] ASlow;
reg scrwin_in;

wire scr_vflip = dout[5];

localparam 	SDRAM_stage = 3'd6,
			ASlo_stage	= 3'd1,
			AShi_stage	= 3'd2;


// Set input for ROM reading
always @(negedge clk) begin
	case( HS[2:0] )
		ASlo_stage: ASlow <= dout;
		AShi_stage: begin
			AS        	<= {dout[7:6], ASlow};
			scr_hflip 	<= dout[4];
			pal_in 		<= dout[2:0];
			scrwin_in	<= dout[3];
			vert_addr 	<= {4{scr_vflip}}^VS[3:0];
			scr_addr <= { 	{dout[7:6], ASlow}, // AS
							HS[3]^dout[4] /*scr_hflip*/, 
							{4{scr_vflip}}^VS[3:0] /*vert_addr*/ };
		end
	endcase
end

// Draw pixel on screen
reg [7:0] x,y,z;

reg [2:0] pxl_aux, pal_aux;

// delays pixel data so it comes out on a multiple of 8

jtgng_sh #(.width(3),.stages(7-SDRAM_stage)) pixel_sh (
	.clk	( clk		), 
	.din	( pxl_aux	), 
	.drop	( scr_col	)
);

//assign scr_col=pxl_aux;
jtgng_sh #(.width(1), .stages(8-SDRAM_stage)) scrwin_sh 
	(.clk(clk), .din(scrwin_in), .drop(scrwin));

jtgng_sh #(.width(3),.stages(8-SDRAM_stage)) pal_sh (
	.clk	( clk		), 
	.din	( pal_aux	), 
	.drop	( scr_pal	)
);

always @(negedge clk) begin
	pxl_aux <= scr_hflip_prev ? { x[0], y[0], z[0] } : { x[7], y[7], z[7] };
	if( HS[2:0]==SDRAM_stage ) begin
			{ z,y,x } <= scrom_data;
			scr_hflip_prev <= scr_hflip^flip;
			pal_aux <= pal_in;
		end
	else
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
end

endmodule // jtgng_scroll