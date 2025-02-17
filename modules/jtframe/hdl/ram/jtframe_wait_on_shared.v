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
    Date: 9-2-2025 */

module jtframe_wait_on_shared(
    input             rst, clk,  
                      mreq,    sreq,
    output reg        mwait=0, swait=0
);

reg sbsy=0, mbsy;

always @(posedge clk)
    if(rst) begin
        mwait <= 0;
        swait <= 0;
        sbsy  <= 0;
    end else begin
        mwait <= sbsy & mreq;
        swait <= sreq & mreq & ~sbsy;
        if( !swait )
            sbsy <= sreq & ~mreq;
    end
endmodule