/*  This file is part of JTGNG.
    JTGNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTGNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTGNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 23-12-2018 */

module jtgng_dual_ram #(parameter DW=8, AW=10, SIMFILE="")(
    input           clk,
    input           clk_en,
    input  [DW-1:0] data,
    input  [AW-1:0] rd_addr,
    input  [AW-1:0] wr_addr,
    input           we,
    output [DW-1:0] q
);

    jtframe_dual_ram #(.DW(DW),.AW(AW),.SIMFILE(SIMFILE))
    u_ram(
        .clk0   ( clk       ),
        .clk1   ( clk       ),
        // Port 0
        .data0  ( data      ),
        .addr0  ( wr_addr   ),
        .we0    ( we & clk_en ),
        .q0     (           ),
        // Port 1
        .data1  (           ),
        .addr1  ( rd_addr   ),
        .we1    ( 1'b0      ),
        .q1     ( q         )
    );

endmodule