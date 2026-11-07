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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 9-8-2026 */

module jttrcdoc_snd(
    input                rst,
    input                clk,       // 24 MHz
    input                cen,       // 2.5 MHz

    input                cs,
    input                addr,
    input                wr_n,
    input        [ 7:0]  din,
    output       [ 7:0]  dout,

    output signed [15:0] fm
);

`ifndef NOSND
jtopl2 u_opl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .din    ( din       ),
    .addr   ( addr      ),
    .cs_n   ( ~cs       ),
    .wr_n   ( wr_n      ),
    .dout   ( dout      ),
    .irq_n  (           ),
    .snd    ( fm        ),
    .sample (           )
);
`else
assign dout = 8'hff;
assign fm   = 16'sd0;
`endif

endmodule
