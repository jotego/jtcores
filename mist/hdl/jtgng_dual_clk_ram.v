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
    Date: 23-12-2018 */

module jtgng_dual_clk_ram #(parameter dw=8, aw=10)(
    input   clka,
    input   clka_en,
    input   clkb,
    input   clkb_en,
    input   [dw-1:0] data_a,
    input   [dw-1:0] data_b,
    input   [aw-1:0] addr_a,
    input   [aw-1:0] addr_b,
    input   we_a,
    input   we_b,
    output reg [dw-1:0] q_a,
    output reg [dw-1:0] q_b
);

reg [dw-1:0] mem[0:(2**aw)-1];

always @(posedge clka) if(clka_en) begin
    q_a <= mem[addr_a];
    if(we_a) mem[addr_a] <= data_a;
end

always @(posedge clkb) if(clkb_en) begin
    q_b <= mem[addr_b];
    if(we_b) mem[addr_b] <= data_b;
end

endmodule // jtgng_ram