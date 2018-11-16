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

module jtgng_m9k #(parameter addrw=12, id=0)(
	input	clk,
	input	[addrw-1:0] addr,
	input	[7:0] din,
	output	reg [7:0] dout,
	input	we
);

reg [addrw-1:0] addr_latch;
reg [7:0] mem[0:(2**addrw-1)];
reg [7:0] data_latch;
reg we_latch;

`ifdef SIMULATION
initial begin
	case(id)
		10: begin
				$display("ram.hex loaded");
				$readmemh("ram.hex",mem);
			end
	endcase
end
`endif

always @(posedge clk) begin
	addr_latch <= addr;
	data_latch <= din;
	we_latch <= we;
	if( we_latch )
		mem[addr_latch] <= data_latch;	
end

always @(addr_latch)
	dout <= mem[addr_latch];


endmodule // jtgng_m9k