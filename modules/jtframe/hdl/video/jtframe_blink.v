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
    Date: 3-1-2025 */

// blink output toggles every frame as long as en==1
// if en==0, blink=0
module jtframe_blink(
    input      clk,
    input      vs,
    input      en,      
    output reg blink=0
);

reg vs_l=0, odd=0;

always @(posedge clk) begin
    vs_l <= vs;
    if( vs & ~vs_l ) odd<=~odd;
    blink <= !en || odd;
end

endmodule