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
    Date: 2-3-2025 */

module jtgaiden_header(
    input            clk,
                     header, prog_we,
    input      [2:0] prog_addr,
    input      [7:0] prog_data,
    output reg [1:0] frmbuf=0,
    output reg       objdly=0,
                     mcutype=0,
                     vsize_en=0
);

localparam [2:0] FRAMEBUFFER=0, MCUTYPE=1;

always @(posedge clk) begin
    if( header && prog_addr[2:0]==FRAMEBUFFER  && prog_we ) begin
        {objdly,frmbuf} <= prog_data[2:0];
        vsize_en        <= prog_data[4];
    end
    if( header && prog_addr[2:0]==MCUTYPE  && prog_we )
        mcutype <= prog_data[0];
end

endmodule