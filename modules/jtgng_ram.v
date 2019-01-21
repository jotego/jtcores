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

module jtgng_ram #(parameter dw=8, aw=10, simfile="ram.hex")(
    input   clk,
    input   cen  /* synthesis direct_enable = 1 */,
    input   [dw-1:0] data,
    input   [aw-1:0] addr,
    input   we,
    output reg [dw-1:0] q
);

reg [dw-1:0] mem[0:(2**aw)-1];

`ifdef SIMULATION
initial $readmemh(simfile, mem );
`endif

always @(posedge clk) begin
    q <= mem[addr];
    if( cen && we) mem[addr] <= data;
end

endmodule // jtgng_ram