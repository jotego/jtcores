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
    Date: 22-11-2023 */

module jt680x(
);

wire   [ 7:0] op;
wire   [ 4:0] alu_sel;
wire   [15:0] op0, op1, rslt;
wire   [ 5:0] cc, cc_out;


jt680x_alu u_alu(
    .sel    ( alu_sel   ),
    .op0    ( op0       ),
    .op1    ( op1       ),
    .rslt   ( rslt      ),

    .cc     ( cc        ),
    .cc_out ( cc_out    )
)

jt680x_alu_sel u_alu_sel(
    .op     ( op        ),
    .sel    ( alu_sel   )
)


endmodule