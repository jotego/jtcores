/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 26-2-2025 */

module jtframe_coremod(
    input  [6:0] core_mod,

    output       vertical,
                 lightgun_en,
                 dipflip_xor,
                 dial_raw_en,
                 dial_reverse,
    output [1:0] black_frame
);

assign vertical     = core_mod[0];
assign lightgun_en  = `ifdef JTFRAME_LIGHTGUN_ON 1'b1 `else core_mod[1]; `endif
assign dipflip_xor  = core_mod[2];
assign dial_raw_en  = core_mod[3];
assign dial_reverse = core_mod[4];
assign black_frame  = core_mod[6:5];

endmodule