/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-6-2021 */

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