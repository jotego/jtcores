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
    Date: 19-3-2024 */

// Compatible with Ricoh RF5C68A

module jtpcm568(
    input                rst,
    input                clk,
    input                cen,

    // CPU interface
    input                wr,
    input                cs,
    input         [12:0] addr,
    input         [ 7:0] din,
    output        [ 7:0] dout,

    // ADPCM RAM
    output        [15:0] ram_addr,
    output               ram_cs0,
    output               ram_cs1,
    input         [ 7:0] ram_dout,
    output        [ 7:0] ram_din,

    output        [ 9:0] snd
);

endmodule