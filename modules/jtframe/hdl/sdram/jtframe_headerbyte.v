/* This file is part of JTFRAME.

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
    Date: 10-1-2025
*/

// captures one byte from the header at a given offset
module jtframe_headerbyte #(parameter
    OFFSET=0,
    AW    =6
)(
    input            clk,
    input            header,
    input   [AW-1:0] ioctl_addr,
    input            ioctl_wr,
    input      [7:0] ioctl_dout,
    output reg [7:0] dout=0
);

always @(posedge clk) begin
    if(header && ioctl_wr && ioctl_addr==OFFSET[AW-1:0])
        dout <= ioctl_dout;
end

endmodule