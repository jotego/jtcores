/*
 * Copyright (C) 2023 nukeykt
 *
 * This file is part of Nuked-MD.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

*/

module vram
	(
	input MCLK,
	input RAS,
	input CAS,
	input WE,
	input OE,
	input SC,
	input SE,
	input [7:0] AD,
	input [7:0] RD_i,
	output reg [7:0] RD_o,
	output RD_d,
	output [7:0] SD_o,
	output SD_d
	);
	
	reg [15:0] addr;
	reg dt;
	reg [7:0] addr_ser;
	reg [7:0] addr_ser_page;
	
	reg o_OE;
	reg o_RAS;
	reg o_cas;
	reg o_SC;
	reg o_valid;
	
	wire cas = ~RAS & ~CAS;
	wire wr = ~RAS & ~CAS & ~WE;
	wire rd = ~RAS & ~CAS & ~OE & ~dt;

	reg [7:0] mem[65536];
	reg [7:0] ser_o;

	always @(posedge MCLK) begin
		RD_o <= mem[addr];
		if (wr) mem[addr] <= RD_i;

		ser_o <= mem[{addr_ser_page, addr_ser}];
	end

	assign RD_d = ~o_valid;
	assign SD_d = SE;
	
	reg [7:0] vram_ser;
	
	assign SD_o = vram_ser;
	
	always @(posedge MCLK)
	begin
		if (dt & !o_OE & OE)
		begin
			addr_ser <= addr[7:0];
			addr_ser_page <= addr[15:8];
		end
		else if (~o_SC & SC)
		begin
			addr_ser <= addr_ser + 8'h1;
			vram_ser <= ser_o;
		end
		if (o_RAS & ~RAS)
		begin
			dt <= ~OE;
			addr[15:8] <= AD;
		end
		if (~o_cas & cas)
		begin
			addr[7:0] <= AD;
		end
		
		if (rd)
		begin
			o_valid <= 1'h1;
		end
		else if (CAS | OE)
		begin
			o_valid <= 1'h0;
		end
		
		o_OE <= OE;
		o_RAS <= RAS;
		o_cas <= cas;
		o_SC <= SC;
	end

endmodule
