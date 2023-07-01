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
    Date: 18-21-2022 */

// Copy one BRAM to another at the edge of a signal
// cen can be used to slow down the process
// cen cannot bet set to 1 or the copy will fail

module jtframe_bram_dma #( parameter
    AW  = 11
)(
    input               rst,
    input               clk,
    input               cen, // cannot be 1'b1 or the copy will fail
    output reg [AW-1:0] addr,
    input               start,
    output reg          we
);

reg sl;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        we   <= 0;
        addr <= 0;
    end else if(cen) begin
        sl <= start;
        if( start & ~sl ) begin
            addr <= 0;
            we   <= 1;
        end
        if( we ) begin
            addr <= addr + 1'd1;
            we   <= ~&addr;
        end
    end
end

endmodule
