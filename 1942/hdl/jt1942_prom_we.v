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
    Date: 20-1-2019 */

module jt1942_prom_we(
    input             downloading, 
    input [24:0]      romload_addr,
    output reg [9:0]  prom_we
);

always @(*)
    if( !downloading ) prom_we = 10'd0;
    else case(romload_addr[11:8])
        4'd0: prom_we = 10'h0_01;      // k6
        4'd1: prom_we = 10'h0_02;      // d1
        4'd2: prom_we = 10'h0_04;      // d2
        4'd3: prom_we = 10'h0_08;      // d6
        4'd4: prom_we = 10'h0_10;     // e8
        4'd5: prom_we = 10'h0_20;     // e9
        4'd6: prom_we = 10'h0_40;     // e10
        4'd7: prom_we = 10'h0_80;     // f1
        4'd8: prom_we = 10'h1_00;    // k3
        4'd9: prom_we = 10'h2_00;    // m11
        default: prom_we = 10'h0;   // 
    endcase // romload_addr[10:8]

endmodule // jt1492_promprog