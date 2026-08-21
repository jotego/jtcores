/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-12-2018 */

module jtgng_dual_ram #(parameter DW=8, AW=10, SIMFILE="")(
    input           clk,
    input           clk_en,
    input  [DW-1:0] data,
    input  [AW-1:0] rd_addr,
    input  [AW-1:0] wr_addr,
    input           we,
    output [DW-1:0] q
);

    jtframe_dual_ram #(.DW(DW),.AW(AW),.SIMFILE(SIMFILE))
    u_ram(
        .clk0   ( clk       ),
        .clk1   ( clk       ),
        // Port 0
        .data0  ( data      ),
        .addr0  ( wr_addr   ),
        .we0    ( we & clk_en ),
        .q0     (           ),
        // Port 1
        .data1  (           ),
        .addr1  ( rd_addr   ),
        .we1    ( 1'b0      ),
        .q1     ( q         )
    );

endmodule