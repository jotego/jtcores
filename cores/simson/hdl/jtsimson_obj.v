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
    Date: 24-7-2023 */

module jtsimson_obj(
    input             rst,
    input             clk,

    input             pxl_cen,
    input             hs,
    input             vs,
    input             lvbl, // not an input in the original
    input             lhbl, // not an input in the original

    // CPU interface
    input             cs,
    input             cpu_we,
    input      [15:0] cpu_dout, // 16-bit interface
    input      [13:1] cpu_addr, // 16 kB!
    output     [15:0] cpu_din,
    input      [ 1:0] cpu_dsn,
    output            irqn,

    // ROM addressing
    output     [21:2] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,

    // pixel output
    output     [ 1:0] shd,
    output     [ 4:0] prio,
    output     [ 8:0] pxl,

    // debug
    output     [ 7:0] st_dout
);

wire [1:0] we;

assign we       = {2{cpu_we}} & ~cpu_dsn;
assign shd      = 0;
assign prio     = 0;
assign pxl      = 0;
assign rom_cs   = 0;
assign rom_addr = 0;
assign irqn     = 1;
assign st_dout  = 0;

jtframe_dual_ram16 #(.AW(13)) u_ram(
    // Port 0 - CPU access
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr  ),
    .we0    ( we        ),
    .q0     ( cpu_din   ),
    // Port 1 - Video access
    .clk1   ( clk       ),
    .data1  ( 16'd0     ),
    .addr1  ( 13'd0     ),
    .we1    ( 2'd0      ),
    .q1     (           )
);

endmodule