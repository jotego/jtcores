/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtframe_v20 #(
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
    input      [ 7:0] din,
    output     [ 7:0] dout,
    output     [ 2:0] bs,
    output     [ 1:0] qs,
    output            req,
    output            rd_n,
    output            wr_n,
    output            buslock_n
);

wire [19:0] cpu_addr;
wire [15:0] cpu_din, cpu_dout;
wire [ 2:0] cpu_bs;
wire        cpu_rd_n, cpu_wr_n, cpu_ube_n, cpu_ready;

jtframe_v30 #(
    .HEXDIR       ( HEXDIR       )
) u_cpu (
    .rst          ( rst          ),
    .clk          ( clk          ),
    .cen          ( cen          ),
    .cenb         ( cenb         ),
    .ready        ( cpu_ready    ),
    .int_n        ( int_n        ),
    .nmi_n        ( nmi_n        ),
    .poll_n       ( poll_n       ),
    .A            ( cpu_addr     ),
    .din          ( cpu_din      ),
    .dout         ( cpu_dout     ),
    .bs           ( cpu_bs       ),
    .qs           ( qs           ),
    .rd_n         ( cpu_rd_n     ),
    .wr_n         ( cpu_wr_n     ),
    .ube_n        ( cpu_ube_n    ),
    .buslock_n    ( buslock_n    )
);

jtframe_v20_bus u_bus (
    .rst          ( rst          ),
    .clk          ( clk          ),
    .cen          ( cen          ),
    .cpu_addr     ( cpu_addr     ),
    .cpu_dout     ( cpu_dout     ),
    .cpu_bs       ( cpu_bs       ),
    .cpu_rd_n     ( cpu_rd_n     ),
    .cpu_wr_n     ( cpu_wr_n     ),
    .cpu_ube_n    ( cpu_ube_n    ),
    .cpu_din      ( cpu_din      ),
    .cpu_ready    ( cpu_ready    ),
    .A            ( A            ),
    .dout         ( dout         ),
    .din          ( din          ),
    .bs           ( bs           ),
    .req          ( req          ),
    .rd_n         ( rd_n         ),
    .wr_n         ( wr_n         ),
    .ready        ( ready        )
);

endmodule
