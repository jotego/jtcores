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
    Date: 28-1-2025 */

module jtframe_beta_lock(
    input              clk,
    input       [ 1:0] ioctl_addr,
    input       [ 7:0] ioctl_dout,
    input              ioctl_wr,

    output reg         locked
);
    `ifdef JTFRAME_UNLOCKKEY // lock system inputs
        localparam [31:0] UNLOCKKEY = `JTFRAME_UNLOCKKEY;
        reg [7:0] lock_key[0:3];

        initial begin
            lock_key[0] = 0;
            lock_key[1] = 0;
            lock_key[2] = 0;
            lock_key[3] = 0;
            locked      = 1;
        end

        always @(posedge clk) begin
            if( ioctl_lock && ioctl_wr )
                lock_key[ ioctl_addr ] <= ioctl_dout;
            locked <= UNLOCKKEY != { lock_key[3], lock_key[2], lock_key[1], lock_key[0] };
        end
    `else
        initial locked=0;
    `endif
endmodule