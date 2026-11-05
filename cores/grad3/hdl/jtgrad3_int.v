/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jtgrad3_int(
    input              rst,
    input              clk,
    input              LVBL,
    input              cpu_trig,
    input       [2:0]  din,
    input              wr,
    output      [2:0]  IPLn
);

wire [2:0] edgeof;
reg  [2:0] clr;

assign edgeof = { cpu_trig, ~LVBL, LVBL };

always @(posedge clk, posedge rst) begin
    if( rst )
        clr <= 3'b111;
    else if( wr )
        clr <= ~din;
end

jtframe_edge #(.QSET(0)) u_ipl0(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( edgeof[0] ),
    .clr    ( clr[0]    ),
    .q      ( IPLn[0]   )
);

jtframe_edge #(.QSET(0)) u_ipl1(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( edgeof[1] ),
    .clr    ( clr[1]    ),
    .q      ( IPLn[1]   )
);

jtframe_edge #(.QSET(0)) u_ipl2(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( edgeof[2] ),
    .clr    ( clr[2]    ),
    .q      ( IPLn[2]   )
);

endmodule
