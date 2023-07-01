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
    Date: 27-12-2020 */

module jtframe_rom_sync(
    input       clk,
    input       rdy_in,
    input       ack_in,
    output      rdy_out,
    output      ack_out
);

reg last_rdy, last_ack;

assign rdy_out = rdy_in & last_rdy;
assign ack_out = ack_in & last_ack;

always @(posedge clk) begin
    last_rdy <= rdy_in;
    last_ack <= ack_in;
end

endmodule
