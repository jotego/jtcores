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
    Date: 12-3-2021 */

module jts16_obj_ram(
    input              rst,
    input              clk,

    // CPU interface
    input              obj_cs,
    input      [10:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dswn,
    output     [15:0]  cpu_din,

    // Object scan
    input      [10:1]  tbl_addr,
    output     [15:0]  tbl_dout,
    input              tbl_we,
    input      [15:0]  tbl_din
);

wire [ 1:0] cpu_we = ~dswn & {2{obj_cs}};

jtframe_dual_ram16 #(
    .AW(10),
    .SIMFILE_LO("obj_lo.bin"),
    .SIMFILE_HI("obj_hi.bin")
) u_ram(
    .clk0   ( clk       ),
    .clk1   ( clk       ),

    // CPU writes
    .addr0  ( cpu_addr  ),
    .data0  ( cpu_dout  ),
    .we0    ( cpu_we    ),
    .q0     ( cpu_din   ),

    // Video reads
    .addr1  ( tbl_addr  ),
    .data1  ( tbl_din   ),
    .we1    ({2{tbl_we}}),
    .q1     ( tbl_dout  )
);

endmodule