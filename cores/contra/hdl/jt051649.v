/*  This file is part of JTCONTRA.
    JTCONTRA program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCONTRA program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCONTRA.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 24-8-2021 */

// Mostly equivalent to the SCC chip in MSX cartridges

module jt051649(
    input                rst,
    input                clk,
    input                cen,
    input                cs,
    input                wrn,
    input         [15:0] addr, // bits 10-8 ignored
    input         [ 7:0] din,
    output        [ 7:0] dout,
    output signed [10:0] snd
);

endmodule