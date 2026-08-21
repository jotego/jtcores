/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-12-2024 */

module jttwin16_ints(
    input        rst,
    input        clk,
    input        LVBL,
    input        ASn,
    input        A23,

    // request from the other CPU
    input        intn,
    input        int_en,

    output       VPAn,
    output [2:0] IPLn
);

wire vb_intn, pair_intn;

localparam IPL5=~3'd5, IPL6=~3'd6, NOINT=3'd7;

assign VPAn     = ~( A23 & ~ASn );
assign IPLn     = !pair_intn ? IPL6 : !vb_intn ? IPL5 : NOINT;

jtframe_edge #(.QSET(0))u_vbl(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     ( ~LVBL     ),
    .clr        ( ~int_en   ),
    .q          ( vb_intn   )
);

jtframe_edge #(.QSET(0))u_subint(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     ( intn      ),
    .clr        ( ~VPAn     ),
    .q          ( pair_intn )
);

endmodule