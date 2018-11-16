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

module jtgng_timer(
	input				clk,	// 6MHz
	input				rst,
	output	reg [8:0]	V,
	output	reg [8:0]	H,
	output	reg			Hinit,
	output	reg			Vinit,
	output	reg			LHBL,
	output	reg			LHBL_short,
	output	reg			LVBL,
	output	reg			G4_3H,	// high on 3/4 H transition
	output	reg			G4H, // high on 4H transition
	output	reg			OH   // high on 0H transition
);

// H/V counters
always @(negedge clk) begin
	if( rst ) begin
		{ Hinit, H } <= 10'd0;
		V <= 9'd250;
	end
	else begin
		Hinit <= H == 9'h86;
		if( H == 9'd511 ) begin
			//Hinit <= 1'b1;
			H <= 9'd128;
			Vinit <= &V;
			V <= &V ? 9'd250 : V + 1'd1;
		end
		else begin
			//Hinit <= 1'b0;
			H <= H + 1'b1;
		end
	end
end

// L Horizontal/Vertical Blanking
always @(negedge clk) 
	if( rst ) LVBL <= 1'b0;
	else begin
		if( &H[2:0] ) begin
			LHBL <= H[8];
		// LHBL <= H>=256;
			if( V==9'd496 ) LVBL <= 1'b0;
			if( V==9'd271 ) LVBL <= 1'b1;
		end
		if (H==9'd136) LHBL_short <= 1'b0;
		if (H==9'd248) LHBL_short <= 1'b1;
	end

// H indicators
always @(negedge clk) begin
	G4H <= &H[1:0];
	OH  <= &H[2:0];
end

always @(posedge clk) begin
	G4_3H <= &H[1:0];
end

endmodule // jtgng_timer