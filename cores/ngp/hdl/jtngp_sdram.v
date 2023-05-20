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

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 20-5-2023 */

module jtngp_sdram(
    input                rst,
    input                clk,

    input                downloading,
    input      [25:0]    ioctl_addr, // max 64 MB
    input      [ 7:0]    ioctl_dout,
    input                ioctl_wr,
    input      [ 7:0]    ioctl_idx,
    output reg [22:1]    prog_addr,
    output     [15:0]    prog_data,
    output reg [ 1:0]    prog_mask, // active low
    output reg           prog_we,
    output               prog_rd,
    output reg [ 1:0]    prog_ba,
    output               dwnld_busy,

    input                sdram_ack
);

localparam [1:0] BA_ROM  = 0,
                 BA_CART = 1;

assign prog_rd = 0;
assign dwnld_busy = downloading;

always @(posedge clk) begin
    prog_ba <= ioctl_idx==0 ? BA_ROM : BA_CART;
end

jtframe_dwnld u_dwnld(
    .clk            ( clk           ),
    .downloading    ( downloading   ),
    .ioctl_addr     ( ioctl_addr    ), // max 64 MB
    .ioctl_dout     ( ioctl_dout    ),
    .ioctl_wr       ( ioctl_wr      ),
    .prog_addr      ( prog_addr     ),
    .prog_data      ( prog_data     ),
    .prog_mask      ( prog_mask     ), // active low
    .prog_we        ( prog_we       ),
    .prog_rd        (               ),
    .prog_ba        (               ),
    .prom_we        (               ),
    .header         (               ),
    .sdram_ack      ( sdram_ack     )
);

endmodule