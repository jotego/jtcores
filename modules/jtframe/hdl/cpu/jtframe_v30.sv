/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtframe_v30 #(
    parameter string HEXDIR = ""
)(
    input             rst,
    input             clk,
    input             cen,
    input             cenb,
    input             ready,
    input             int_n,
    input             nmi_n,
    input             poll_n,
    output     [19:0] A,
    input      [15:0] din,
    output     [15:0] dout,
    output     [ 2:0] bs,
    output     [ 1:0] qs,
    output            rd_n,
    output            ube_n,
    output            buslock_n,
    output            wr_n
);

// cenb must occur between consecutive cen pulses, without overlap.
v30_core #(
    .HEXDIR ( HEXDIR )
) u_cpu (
    .CLK          ( clk                                  ),
    .CE           ( cen                                  ),
    .CE_HALF      ( cenb                                 ),
    .RESET        ( rst                                  ),
    .READY        ( ready                                ),
    .INT          ( ~int_n                               ),
    .NMI          ( ~nmi_n                               ),
    .POLL_N       ( poll_n                               ),
    .DATA_I       ( din                                  ),
    .ADDR_O       ( A                                    ),
    .DATA_O       ( dout                                 ),
    .STATUS_O     (                                      ),
    .QS           ( qs                                   ),
    .BS           ( bs                                   ),
    .RD_N         ( rd_n                                 ),
    .WR_N         ( wr_n                                 ),
    .UBE_N        ( ube_n                                ),
    .BUSLOCK_N    ( buslock_n                            ),
    .SS_ADDR      ( {v30_ss_pkg::SS_ADDR_W{1'b0}}          ),
    .SS_WDATA     ( 16'd0                                ),
    .SS_WE        ( 1'b0                                 ),
    .SS_RDATA     (                                      ),
    .SS_ERR       (                                      ),
    .SS_BUS_QUIET (                                      )
);

endmodule
