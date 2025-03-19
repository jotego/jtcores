/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-3-2025 */

// read-only dual port for a single-port RAM
// output latency of two/three clocks: 1 from mux, 1 from RAM, 1 from data register
module jtframe_ram_rdmux #(parameter
    AW=10,
    DW=8
)(
    input               clk,

    // to RAM
    output     [AW-1:0] addr,
    input      [DW-1:0] data,

    // read ports
    input      [AW-1:0] addr_a,addr_b,
    output reg [DW-1:0] douta,doutb
);

reg a_sel=0;

assign addr = a_sel ? addr_a : addr_b;

always @(posedge clk) begin
    a_sel <= ~a_sel;
    // a_sel inverted because of 1-tick latency from RAM
    if(~a_sel) douta <= data;
    if( a_sel) doutb <= data;
end

endmodule