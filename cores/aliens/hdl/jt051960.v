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
    Date: 15-4-2023 */

// Based on Furrtek's RE work on die shots
// and MAME documentation


module jt051960(    // sprite logic
    input             rst,
    input             clk,
    input             pxl_cen,

    // CPU interface
    input             cs,
    input             cpu_we,
    input      [ 7:0] cpu_dout,
    input      [10:0] cpu_addr,
    output     [ 7:0] cpu_din,

    // Debug
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire lut_we;

assign lut_we = cs & cpu_we & cpu_addr[10];
assign st_dout = 0;

jtframe_dual_ram #(.SIMFILE("obj.bin")) u_lut(
    // Port 0: CPU
    .clk0   ( clk            ),
    .data0  ( cpu_dout       ),
    .addr0  ( cpu_addr[9:0]  ),
    .we0    ( lut_we         ),
    .q0     ( cpu_din        ),
    // Port 1
    .clk1   ( clk            ),
    .data1  ( 8'd0           ),
    .addr1  ( 10'd0          ),
    .we1    ( 1'b0           ),
    .q1     (                )
);

endmodule
