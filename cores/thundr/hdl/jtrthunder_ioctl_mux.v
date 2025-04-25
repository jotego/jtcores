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
    Date: 22-3-2025 */

module jtthundr_ioctl_mux(
    input            flip, bank,
    input      [7:0] backcolor, mmr0, mmr1, mmr2,
    input      [4:0] ioctl_addr,
    output reg [7:0] ioctl_din
);

always @* begin
    case(ioctl_addr[4:3])
        0: ioctl_din = mmr0;
        1: ioctl_din = mmr1;
        2: ioctl_din = mmr2;
        3: case(ioctl_addr[0])
            0: ioctl_din = backcolor;
            1: ioctl_din = {3'd0, flip, 3'd0, bank};
        endcase
    endcase
end

endmodule