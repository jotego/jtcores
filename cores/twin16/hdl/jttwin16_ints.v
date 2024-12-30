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
    Date: 24-12-2024 */

module jttwin16_ints(
    input        rst,
    input        clk,
    input        LVBL,
    input        ASn,
    input        A23,

    // request from the other CPU
    input        intn,
    input        int_en,

    output       VPAn,
    output [2:0] IPLn
);

wire vb_intn, pair_intn;

localparam IPL5=~3'd5, IPL6=~3'd6, NOINT=3'd7;

assign VPAn     = ~( A23 & ~ASn );
assign IPLn     = !pair_intn ? IPL6 : !vb_intn ? IPL5 : NOINT;

jtframe_edge #(.QSET(0))u_vbl(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     ( ~LVBL     ),
    .clr        ( ~int_en   ),
    .q          ( vb_intn   )
);

jtframe_edge #(.QSET(0))u_subint(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     ( intn      ),
    .clr        ( ~VPAn     ),
    .q          ( pair_intn )
);

endmodule