/*  This file is part of JT_FRAME.
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
    Date: 30-6-2021 */

module jtframe_shadow #( parameter
    AW    = 22,
    START = 22'h10_0000,
    LW    = 15  // length of data to be dumped as a power of 2
) (
    input   clk_rom,

    // Capture SDRAM bank 0 inputs
    input      [AW-1:0] ba0_addr,
    input               wr0,
    input        [15:0] din,
    input        [ 1:0] din_m,  // write mask -active low

    // Let data be dumped via NVRAM interface
    input      [AW-1:0] ioctl_addr,
    output       [ 7:0] ioctl_din
);

wire [15:0]   dout;
wire [LW-1:0] rd_addr   = ioctl_addr[LW:1];
wire [LW-1:0] wr_addr   = ba0_addr-START[AW-1:0];
wire [1:0]    wr_m      = (ba0_addr >= START && ba0_addr<( START + (1<<LW) )) ? ~din_m : 2'd0;

assign ioctl_din = ioctl_addr[0] ? dout[15:8] : dout[7:0];

jtframe_dual_ram16 #(.AW(LW)) u_ram(
    .clk0       ( clk_rom   ),
    .clk1       ( clk_rom   ),
    // SDRAM writes
    .data0      ( din       ),
    .addr0      ( wr_addr   ),
    .we0        ( wr_m      ),
    .q0         (           ),
    // hps_io reads
    .data1      (           ),
    .addr1      ( rd_addr   ),
    .we1        ( 2'b0      ),
    .q1         ( dout      )
);

endmodule