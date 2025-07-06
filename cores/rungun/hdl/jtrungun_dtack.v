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
    Date: 4-7-2025 */

module jtrungun_dtack(
    input       clk, pxl_cen,
    input       bus_dtackn,
    input       fix_cs,
    input [1:0] dsn,
    output      dtackn
);

wire fix_acc, fix_dt;

assign fix_acc = ~dsn[0] & fix_cs;
assign dtackn  =~(~fix_acc | fix_dt) | bus_dtackn;

jtframe_sh u_fixsh(
    .clk    ( clk       ),
    .clk_en ( pxl_cen   ),
    .din    ( fix_acc   ),
    .drop   ( fix_dt    )
);

endmodule 