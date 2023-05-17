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
    Date: 17-5-2023 */

module jtngp_flash(
    input        rst,
    input        clk,

    // interface to CPU
    input   [20:1] cpu_addr,
    input          cpu_we,
    input   [ 1:0] cpu_dsn,
    input   [15:0] cpu_dout,    // the original interface is really 8 bits!
    output  [15:0] cpu_din,

    // interface to SDRAM
    output  []
);

endmodule